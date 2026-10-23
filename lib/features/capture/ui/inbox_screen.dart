import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/theme/tokens.dart';
import '../../finance/ui/ui_format.dart';
import '../ai/ai_config.dart';
import '../ai/consent.dart';
import '../ai/groq_client.dart';
import '../capture_pipeline.dart';
import '../data/capture_providers.dart';
import '../data/capture_repository.dart';
import '../domain/proposal.dart';
import 'capture_sheet.dart' show showCaptureOutcome;
import '../chat/describe.dart' show inboxReason;

bool _hasAudio(Capture c) => c.audio != null && c.audio!.isNotEmpty;
bool _hasText(Capture c) => (c.transcript ?? '').trim().isNotEmpty;

List<Proposal> _proposals(Capture c) {
  if (c.parsedJson == null) return const [];
  try {
    return decodeProposals(c.parsedJson!);
  } on FormatException {
    return const [];
  } on ArgumentError {
    return const [];
  }
}

/// The features a capture needs from Groq to be finished online.
List<AiFeature> _needs(Capture c) => [if (!_hasText(c) && _hasAudio(c)) AiFeature.voice, AiFeature.parse];

/// Online AI is on, a key is saved, and the owner has not said no to any of [needs].
bool _aiAllowed(AppSetting? s, bool keySaved, List<AiFeature> needs) {
  if (s == null || !s.aiOnlineEnabled || !keySaved) return false;
  return needs.every((f) => (f == AiFeature.voice ? s.aiVoiceConsent : s.aiParseConsent) != ConsentState.declined.name);
}

/// A friendly line for why a capture is waiting; never the raw error type.
/// A missing speech engine is explained from the current settings, not the ones at capture time.
String? _reason(BuildContext context, Capture c, List<Proposal> ps, AppSetting? s, bool keySaved) {
  final l = context.l10n;
  final f = c.failureType;
  if (f == 'SpeechUnavailable') {
    return inboxReason(l, (s == null ? null : onlineVoiceGap(s, keySaved: keySaved)) ?? 'noSpeechEngine');
  }
  if (f != null) return inboxReason(l, 'sttFailed');
  if (!_hasText(c)) return _hasAudio(c) ? null : l.capReason_empty;
  final money = ps.whereType<MoneyProposal>();
  if (ps.isEmpty || (money.isNotEmpty && money.every((p) => p.confidence < kLowConfidence))) {
    return l.capReason_lowConfidence;
  }
  return null;
}

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  /// Capture ids being worked on, so their buttons wait.
  final Set<int> _busy = {};
  (int, int)? _progress;

  Future<bool> _consent(List<AiFeature> needs) async {
    for (final f in needs) {
      if (!mounted || !await ensureConsent(context, f)) return false;
    }
    return true;
  }

  Future<CaptureOutcome?> _run(int id, {required bool online}) async {
    setState(() => _busy.add(id));
    try {
      return await ref.read(capturePipelineProvider).reparse(id, allowOnline: online);
    } on Exception catch (e) {
      AppLogger.warn('inbox retry failed', e);
      return null;
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  void _show(CaptureOutcome? outcome) {
    if (outcome != null && mounted) showCaptureOutcome(context, outcome);
  }

  void _keyRejected() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.aiTestUnauthorized)));
  }

  Future<void> _offline(Capture c) async => _show(await _run(c.id, online: false));

  Future<void> _finishWithAi(Capture c) async {
    if (!await _consent(_needs(c))) return;
    final outcome = await _run(c.id, online: true);
    if (ref.read(capturePipelineProvider).lastOnlineError is GroqUnauthorized) return _keyRejected();
    _show(outcome);
  }

  /// One after another, so the free tier's rate limit is respected; a rejected key stops the run.
  Future<void> _finishAll(List<Capture> all) async {
    final needs = {for (final c in all) ..._needs(c)}.toList()..sort((a, b) => a.index - b.index);
    if (!await _consent(needs)) return;
    final pipeline = ref.read(capturePipelineProvider);
    for (final (i, c) in all.indexed) {
      if (!mounted) return;
      setState(() => _progress = (i + 1, all.length));
      await _run(c.id, online: true);
      if (pipeline.lastOnlineError is GroqUnauthorized) {
        _keyRejected();
        break;
      }
    }
    if (mounted) setState(() => _progress = null);
  }

  Future<void> _discard(Capture c) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.capDiscardTitle),
        content: Text(l.capDiscardBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(
            key: const ValueKey('inbox-discard-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.capDiscard),
          ),
        ],
      ),
    );
    if (ok ?? false) await ref.read(captureRepositoryProvider).discard(c.id);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final captures = ref.watch(pendingCapturesProvider).value;
    final settings = ref.watch(settingsProvider).value;
    final keySaved = ref.watch(groqKeySavedProvider).value ?? false;
    final aiRows = [
      for (final c in captures ?? const <Capture>[])
        if ((_hasText(c) || _hasAudio(c)) && _aiAllowed(settings, keySaved, _needs(c))) c,
    ];
    final progress = _progress;

    return Scaffold(
      key: const ValueKey('inbox-screen'),
      appBar: AppBar(
        title: Text(l.capInbox),
        actions: [
          if (aiRows.isNotEmpty)
            TextButton.icon(
              key: const ValueKey('inbox-ai-all'),
              onPressed: progress != null || _busy.isNotEmpty ? null : () => _finishAll(aiRows),
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: Text(l.capFinishAllAi),
            ),
          const SizedBox(width: 4),
        ],
        bottom: progress == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2, color: k.accent)),
                      const SizedBox(width: 10),
                      Text(
                        l.capFinishing(progress.$1, progress.$2),
                        key: const ValueKey('inbox-progress'),
                        style: text.bodySmall?.copyWith(color: k.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      body: captures == null
          ? const SizedBox.shrink()
          : captures.isEmpty
          ? Center(
              key: const ValueKey('inbox-empty'),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_outlined, size: 48, color: k.textMuted),
                    const SizedBox(height: 16),
                    Text(
                      l.capInboxEmpty,
                      textAlign: TextAlign.center,
                      style: text.bodyLarge?.copyWith(color: k.textMuted),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              key: const ValueKey('inbox-list'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: captures.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final c = captures[i];
                return _InboxRow(
                  key: ValueKey('inbox-row-${c.id}'),
                  capture: c,
                  busy: _busy.contains(c.id) || progress != null,
                  aiAllowed: aiRows.contains(c),
                  settings: settings,
                  keySaved: keySaved,
                  onOpen: () => context.push('/capture/${c.id}'),
                  onOffline: () => _offline(c),
                  onAi: () => _finishWithAi(c),
                  onDiscard: () => _discard(c),
                );
              },
            ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  const _InboxRow({
    super.key,
    required this.capture,
    required this.busy,
    required this.aiAllowed,
    required this.settings,
    required this.keySaved,
    required this.onOpen,
    required this.onOffline,
    required this.onAi,
    required this.onDiscard,
  });

  final Capture capture;
  final bool busy;
  final bool aiAllowed;
  final AppSetting? settings;
  final bool keySaved;
  final VoidCallback onOpen;
  final VoidCallback onOffline;
  final VoidCallback onAi;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = capture;
    final id = c.id;
    final ps = _proposals(c);
    final reason = _reason(context, c, ps, settings, keySaved);
    final voice = c.source == 'voice';
    final at = c.createdAt.toLocal();
    final later = [
      if (ps.any((p) => p is TaskProposal)) l.capWillBecomeTask(4),
      if (ps.any((p) => p is NoteProposal)) l.capWillBecomeNote(4),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      decoration: BoxDecoration(
        color: k.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        border: Border.all(color: k.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(voice ? Icons.mic_none_rounded : Icons.keyboard_outlined, size: 18, color: k.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${formatDate(context, at)} · ${DateFormat.Hm('en').format(at)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(color: k.textMuted),
                ),
              ),
              IconButton(
                key: ValueKey('inbox-discard-$id'),
                tooltip: l.capDiscard,
                onPressed: busy ? null : onDiscard,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Text(
              _hasText(c) ? c.transcript!.trim() : l.capNotTranscribed,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: _hasText(c) ? text.bodyLarge : text.bodyLarge?.copyWith(color: k.textMuted),
            ),
          ),
          if (reason != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: k.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(reason, style: text.bodySmall?.copyWith(color: k.warning)),
                ),
              ],
            ),
          ],
          for (final s in later) ...[
            const SizedBox(height: 4),
            Text(s, style: text.bodySmall?.copyWith(color: k.textMuted)),
          ],
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: [
              if (ps.isNotEmpty || _hasText(c))
                TextButton(
                  key: ValueKey('inbox-open-$id'),
                  onPressed: busy ? null : onOpen,
                  child: Text(l.capOpenReview),
                ),
              if (!_hasText(c) && _hasAudio(c))
                TextButton(
                  key: ValueKey('inbox-transcribe-$id'),
                  onPressed: busy ? null : onOffline,
                  child: Text(l.capTranscribe),
                ),
              if (_hasText(c))
                TextButton(
                  key: ValueKey('inbox-parse-$id'),
                  onPressed: busy ? null : onOffline,
                  child: Text(l.capParseAgain),
                ),
              if (aiAllowed)
                TextButton.icon(
                  key: ValueKey('inbox-ai-$id'),
                  onPressed: busy ? null : onAi,
                  icon: busy
                      ? SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: k.accent),
                        )
                      : const Icon(Icons.auto_awesome_outlined, size: 18),
                  label: Text(l.capFinishAi),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
