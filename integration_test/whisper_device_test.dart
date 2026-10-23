import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:life_manager/core/net/http_port.dart';
import 'package:life_manager/features/capture/speech/local_whisper_stt.dart';
import 'package:life_manager/features/capture/speech/model_manager.dart';
import 'package:path_provider/path_provider.dart';

import 'fixtures/lunch_wav.dart';

/// Runs on a phone: `flutter test integration_test/whisper_device_test.dart -d <id>`.
/// Downloads ggml-base (148 MB, hash-checked) on the first run.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('on-device Whisper transcribes an English WAV with ggml-base', (_) async {
    final models = ModelManager(PackageHttpPort(), getApplicationSupportDirectory);
    if (await models.installed('base') == null) await models.download('base').drain<void>();
    final file = (await models.installed('base'))!;
    final sw = Stopwatch()..start();
    final text = await LocalWhisperStt(file).transcribe(base64Decode(kLunchWavBase64));
    // ignore: avoid_print
    print('whisper base took ${sw.elapsedMilliseconds} ms: "$text"');
    expect(text.toLowerCase(), contains('lunch'));
  }, timeout: const Timeout(Duration(minutes: 15)));
}
