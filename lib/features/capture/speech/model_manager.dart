import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../core/net/http_port.dart';

class WhisperModelSpec {
  const WhisperModelSpec({
    required this.id,
    required this.fileName,
    required this.url,
    required this.sha256,
    required this.sizeBytes,
  });

  final String id;
  final String fileName;
  final Uri url;
  final String sha256;
  final int sizeBytes;
}

WhisperModelSpec _hf(String id, String sha256, int size) => WhisperModelSpec(
  id: id,
  fileName: 'ggml-$id.bin',
  url: Uri.parse('https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-$id.bin'),
  sha256: sha256,
  sizeBytes: size,
);

/// Pinned from the Hugging Face LFS metadata of ggerganov/whisper.cpp (main).
final kWhisperModels = {
  'small': _hf('small', '1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b', 487601967),
  'base': _hf('base', '60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe', 147951465),
};

sealed class ModelDownloadProgress {
  const ModelDownloadProgress();
}

class Downloading extends ModelDownloadProgress {
  const Downloading(this.received, this.total);

  final int received;
  final int total;
}

class Verifying extends ModelDownloadProgress {
  const Verifying();
}

class Installed extends ModelDownloadProgress {
  const Installed();
}

class ModelChecksumMismatch implements Exception {
  const ModelChecksumMismatch();
}

/// Downloads speech models into app support storage and keeps only files
/// whose SHA-256 matches the pinned value.
class ModelManager {
  ModelManager(this._http, this._supportDir, {Map<String, WhisperModelSpec>? specs}) : _specs = specs ?? kWhisperModels;

  final HttpPort _http;
  final Future<Directory> Function() _supportDir;
  final Map<String, WhisperModelSpec> _specs;

  static const _connectTimeout = Duration(seconds: 30);

  WhisperModelSpec spec(String id) => _specs[id] ?? (throw ArgumentError.value(id, 'id', 'unknown model'));

  Future<Directory> _dir() async => Directory(p.join((await _supportDir()).path, 'models')).create(recursive: true);

  Future<File> _file(String id) async => File(p.join((await _dir()).path, spec(id).fileName));

  /// The model file when it is fully installed (checked by size; the hash was checked on install).
  Future<File?> installed(String id) async {
    final f = await _file(id);
    return await f.exists() && await f.length() == spec(id).sizeBytes ? f : null;
  }

  /// Starts from zero every time; a failed or wrong download leaves nothing behind.
  Stream<ModelDownloadProgress> download(String id) async* {
    final s = spec(id);
    final target = await _file(id);
    final part = File('${target.path}.part');
    final digest = _DigestSink();
    final hasher = sha256.startChunkedConversion(digest);
    final out = part.openWrite();
    var received = 0;
    var ok = false;
    try {
      await for (final chunk in _http.getStream(s.url, _connectTimeout)) {
        out.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        yield Downloading(received, s.sizeBytes);
      }
      await out.flush();
      await out.close();
      hasher.close();
      yield const Verifying();
      if (received != s.sizeBytes || digest.value.toString() != s.sha256) throw const ModelChecksumMismatch();
      await part.rename(target.path);
      ok = true;
      yield const Installed();
    } finally {
      if (!ok) {
        await out.close().catchError((_) {});
        if (await part.exists()) await part.delete();
      }
    }
  }

  Future<void> delete(String id) async {
    final f = await _file(id);
    if (await f.exists()) await f.delete();
    final part = File('${f.path}.part');
    if (await part.exists()) await part.delete();
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
