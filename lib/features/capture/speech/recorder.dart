import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Recording stops on its own after this; the level stream then closes.
const kMaxRecording = Duration(seconds: 120);

abstract interface class AudioRecorderPort {
  Future<bool> ensurePermission();
  Future<void> start();

  /// 0 (silence) … 1 (loud), a few times a second.
  Stream<double> get level;

  /// The 16 kHz mono WAV; the temp file is deleted.
  Future<Uint8List> stop();
  Future<void> cancel();
}

/// Temp audio lives here only while recording or transcribing.
Future<Directory> captureTmpDir() async =>
    Directory(p.join((await getTemporaryDirectory()).path, 'capture_tmp')).create(recursive: true);

/// App start: removes audio left behind by a crash or a killed app.
Future<void> sweepCaptureTmp() async {
  try {
    final d = Directory(p.join((await getTemporaryDirectory()).path, 'capture_tmp'));
    if (await d.exists()) await d.delete(recursive: true);
  } on FileSystemException {
    // Best effort; the next start tries again.
  }
}

class RecordAudioRecorder implements AudioRecorderPort {
  final _rec = AudioRecorder();
  final _level = StreamController<double>.broadcast();
  StreamSubscription<Amplitude>? _amp;
  Timer? _cap;
  String? _path;

  @override
  Future<bool> ensurePermission() => _rec.hasPermission();

  @override
  Stream<double> get level => _level.stream;

  @override
  Future<void> start() async {
    final path = p.join((await captureTmpDir()).path, 'rec.wav');
    _path = path;
    await _rec.start(const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1), path: path);
    _amp = _rec.onAmplitudeChanged(const Duration(milliseconds: 120)).listen((a) {
      // dBFS: about -60 is silence, 0 is the loudest.
      _level.add(((a.current + 60) / 60).clamp(0.0, 1.0));
    });
    _cap = Timer(kMaxRecording, () async {
      await _rec.stop();
      await _stopLevels();
    });
  }

  Future<void> _stopLevels() async {
    _cap?.cancel();
    await _amp?.cancel();
    _amp = null;
  }

  @override
  Future<Uint8List> stop() async {
    await _stopLevels();
    if (await _rec.isRecording()) await _rec.stop();
    final f = File(_path ?? '');
    _path = null;
    if (!await f.exists()) return Uint8List(0);
    try {
      return await f.readAsBytes();
    } finally {
      await f.delete();
    }
  }

  @override
  Future<void> cancel() async {
    await _stopLevels();
    await _rec.cancel();
    final f = File(_path ?? '');
    _path = null;
    if (await f.exists()) await f.delete();
  }

  Future<void> dispose() async {
    await cancel();
    await _level.close();
    await _rec.dispose();
  }
}

/// One recorder per open mic sheet.
final audioRecorderProvider = Provider.autoDispose<AudioRecorderPort>((ref) {
  final r = RecordAudioRecorder();
  ref.onDispose(r.dispose);
  return r;
});
