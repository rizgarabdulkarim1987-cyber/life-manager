import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/db/app_database.dart';
import '../../core/logging/app_logger.dart';
import '../../l10n/gen/app_localizations.dart';
import '../settings/settings_repository.dart';
import 'ai/ai_config.dart';
import 'ai/groq_client.dart';
import 'ai/llm_parser.dart';
import 'data/capture_repository.dart';
import 'domain/lexicon.dart';
import 'domain/proposal.dart';
import 'rules/rule_parser.dart';
import 'speech/model_manager.dart';
import 'speech/speech_to_text.dart';

/// Where a capture went after the pipeline: to Capture Review, or to the Inbox.
sealed class CaptureOutcome {
  const CaptureOutcome(this.captureId);

  final int captureId;
}

class ReadyForReview extends CaptureOutcome {
  const ReadyForReview(super.captureId);
}

/// [reasonKey]: `sttFailed`, `empty`, `lowConfidence`, or why there was no
/// speech engine (`noSpeechOnlineOff`, `noSpeechNoKey`, `noSpeechNotAsked`,
/// `noSpeechDeclined`, `noSpeechOffline`, else `noSpeechEngine`).
class SavedToInbox extends CaptureOutcome {
  const SavedToInbox(super.captureId, this.reasonKey);

  final String reasonKey;
}

/// Voice or text in, proposals out. The capture row is written before anything
/// else, so nothing the owner said is lost to a crash or the network. Consent
/// is the UI's job ([ensureConsent]); this only checks what is already allowed.
class CapturePipeline {
  CapturePipeline({
    required AppDatabase db,
    required this._keys,
    required this._client,
    required this._models,
    this._localEngine,
  }) : _db = db,
       _captures = CaptureRepository(db),
       _settings = SettingsRepository(db);

  final AppDatabase _db;
  final GroqKeyStore _keys;
  final GroqClient _client;
  final ModelManager _models;
  final CaptureRepository _captures;
  final SettingsRepository _settings;
  final Future<SpeechToText?> Function(AppSetting s)? _localEngine;

  /// The Groq failure seen during the last call, if any (the Inbox stops "finish all" on a rejected key).
  GroqError? lastOnlineError;

  Future<SpeechToText?> _local(AppSetting s) => _localEngine?.call(s) ?? localSpeechEngine(s, _models);

  Future<CaptureOutcome> fromVoice(Uint8List wav) async {
    lastOnlineError = null;
    final id = await _captures.createVoice(wav);
    return _fromAudio(id, wav, await _settings.get(), online: true);
  }

  Future<CaptureOutcome> fromText(String text) async {
    lastOnlineError = null;
    final id = await _captures.createText(text.trim());
    return _parse(id, text.trim(), await _settings.get(), online: true);
  }

  /// Runs a pending capture again: transcribes its kept audio when it has no
  /// text yet, then parses the current transcript (after the owner edited it).
  /// [allowOnline] false keeps everything on the phone (the Inbox's offline retry).
  Future<CaptureOutcome> reparse(int captureId, {bool allowOnline = true}) async {
    lastOnlineError = null;
    final c = await _captures.get(captureId);
    if (c == null) throw ArgumentError.value(captureId, 'captureId', 'unknown capture');
    final s = await _settings.get();
    final text = (c.transcript ?? '').trim();
    if (text.isEmpty && c.audio != null && c.audio!.isNotEmpty) {
      return _fromAudio(captureId, c.audio!, s, online: allowOnline);
    }
    return _parse(captureId, text, s, online: allowOnline);
  }

  Future<CaptureOutcome> _fromAudio(int id, Uint8List wav, AppSetting s, {required bool online}) async {
    final String text;
    try {
      text = await _transcribe(s, wav, online: online);
    } on SpeechUnavailable catch (e) {
      await _captures.setFailure(id, e.runtimeType.toString());
      final gap = online ? onlineVoiceGap(s, keySaved: await _keys.read() != null) : 'noSpeechOffline';
      return SavedToInbox(id, gap ?? 'noSpeechEngine');
    } on _SttFailed catch (e) {
      await _captures.setFailure(id, e.type);
      return SavedToInbox(id, 'sttFailed');
    }
    await _captures.setTranscript(id, text);
    return _parse(id, text, s, online: online);
  }

  /// Groq when allowed; a Groq failure tries the offline model once.
  Future<String> _transcribe(AppSetting s, Uint8List wav, {required bool online}) async {
    final engine = online ? await pickSpeechEngine(s, _keys, _client, _models) : const NoSpeechEngine();
    if (engine is NoSpeechEngine) {
      final local = await _local(s);
      if (local == null) throw const SpeechUnavailable();
      return _run(local, wav);
    }
    try {
      return (await engine.transcribe(wav)).trim();
    } on GroqError catch (e) {
      lastOnlineError = e;
      AppLogger.warn('online speech failed, trying the offline model', e);
      final local = await _local(s);
      if (local == null) throw _SttFailed(e.runtimeType.toString());
      return _run(local, wav);
    } on Object catch (e) {
      throw _SttFailed(e.runtimeType.toString());
    }
  }

  Future<String> _run(SpeechToText engine, Uint8List wav) async {
    try {
      return (await engine.transcribe(wav)).trim();
    } on Object catch (e) {
      AppLogger.warn('offline speech failed', e);
      throw _SttFailed(e.runtimeType.toString());
    }
  }

  Future<CaptureOutcome> _parse(int id, String text, AppSetting s, {required bool online}) async {
    if (text.isEmpty) return SavedToInbox(id, 'empty');
    final lex = await loadLexicon(_db, lookupAppLocalizations(Locale(s.localeCode)));
    const rules = RuleParser();
    final List<Proposal> proposals;
    final String by;
    if (online && await canUseOnline(AiFeature.parse, s, _keys)) {
      final llm = LlmParser(_client, () => s.groqLlmModel, rules);
      proposals = await llm.parse(text, lex, DateTime.now());
      by = llm.lastParsedBy;
      lastOnlineError ??= llm.lastError;
    } else {
      proposals = await rules.parse(text, lex, DateTime.now());
      by = 'rules';
    }
    await _captures.setParsed(id, proposals, by: by);
    final money = proposals.whereType<MoneyProposal>();
    final unsure = proposals.isEmpty || (money.isNotEmpty && money.every((p) => p.confidence < kLowConfidence));
    return unsure ? SavedToInbox(id, 'lowConfidence') : ReadyForReview(id);
  }
}

class _SttFailed implements Exception {
  const _SttFailed(this.type);

  final String type;
}

final capturePipelineProvider = Provider<CapturePipeline>(
  (ref) => CapturePipeline(
    db: ref.watch(appDatabaseProvider),
    keys: ref.watch(groqKeyStoreProvider),
    client: ref.watch(groqClientProvider),
    models: ref.watch(modelManagerProvider),
  ),
);
