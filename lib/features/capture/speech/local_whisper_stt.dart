import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:whisper_ggml/whisper_ggml.dart';

import 'recorder.dart';
import 'speech_to_text.dart';

/// On-device whisper.cpp with a model file we downloaded and verified
/// ([ModelManager]); the plugin is never asked to fetch a model itself.
/// Inference runs in a background isolate inside the plugin.
class LocalWhisperStt implements SpeechToText {
  LocalWhisperStt(this.modelFile);

  final File modelFile;

  @override
  Future<String> transcribe(Uint8List wav) async {
    final dir = await captureTmpDir();
    final input = File(p.join(dir.path, 'whisper_in.wav'));
    // The plugin writes its resampled copy next to the input.
    final converted = File('${input.path}.wav');
    try {
      await input.writeAsBytes(wav, flush: true);
      final res = await const Whisper(model: WhisperModel.base).transcribe(
        transcribeRequest: TranscribeRequest(audio: input.path, language: 'auto', isNoTimestamps: true),
        modelPath: modelFile.path,
      );
      return res.text.trim();
    } finally {
      for (final f in [input, converted]) {
        if (await f.exists()) await f.delete();
      }
    }
  }
}
