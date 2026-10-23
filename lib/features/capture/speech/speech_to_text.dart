import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../ai/ai_config.dart';
import '../ai/groq_client.dart';
import 'groq_stt.dart';
import 'local_whisper_stt.dart';
import 'model_manager.dart';

abstract interface class SpeechToText {
  Future<String> transcribe(Uint8List wav);
}

/// No way to turn speech into text right now: online AI is off or not allowed
/// and no offline model is installed. The capture stays in the Inbox.
class SpeechUnavailable implements Exception {
  const SpeechUnavailable();
}

class NoSpeechEngine implements SpeechToText {
  const NoSpeechEngine();

  @override
  Future<String> transcribe(Uint8List wav) => Future.error(const SpeechUnavailable());
}

/// Groq when the owner allows sending voice; else the selected offline model
/// when it is installed; else nothing.
Future<SpeechToText> pickSpeechEngine(AppSetting s, GroqKeyStore keys, GroqClient client, ModelManager models) async {
  if (await canUseOnline(AiFeature.voice, s, keys)) return GroqStt(client, () => s.groqSttModel);
  return await localSpeechEngine(s, models) ?? const NoSpeechEngine();
}

Future<LocalWhisperStt?> localSpeechEngine(AppSetting s, ModelManager models) async {
  final file = await models.installed(s.localWhisperModel);
  return file == null ? null : LocalWhisperStt(file);
}

final modelManagerProvider = Provider<ModelManager>(
  (ref) => ModelManager(ref.watch(httpPortProvider), getApplicationSupportDirectory),
);

/// Recomputed on every capture: settings and installed files change.
final speechEngineProvider = FutureProvider.autoDispose<SpeechToText>((ref) async {
  final s = await ref.watch(settingsProvider.future);
  return pickSpeechEngine(
    s,
    ref.read(groqKeyStoreProvider),
    ref.read(groqClientProvider),
    ref.read(modelManagerProvider),
  );
});
