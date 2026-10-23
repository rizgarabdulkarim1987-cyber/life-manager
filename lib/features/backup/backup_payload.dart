import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

const _manifestName = 'manifest.json';

/// The decrypted payload is not a valid zip, or doesn't match its manifest.
class BackupCorruptException implements Exception {
  const BackupCorruptException(this.reason);
  final String reason;
  @override
  String toString() => 'BackupCorruptException: $reason';
}

bool _isSafePath(String p) =>
    p.isNotEmpty &&
    !p.startsWith('/') &&
    !p.contains(r'\') &&
    !p.contains(':') &&
    !p.split('/').any((s) => s.isEmpty || s == '.' || s == '..');

/// Zips [files] with a `manifest.json` listing each path, size and SHA-256.
Uint8List buildPayload(Map<String, Uint8List> files) {
  final archive = Archive();
  final entries = <Map<String, Object>>[];
  for (final MapEntry(key: path, value: data) in files.entries) {
    if (!_isSafePath(path) || path == _manifestName) throw ArgumentError.value(path, 'path', 'unsafe backup path');
    archive.addFile(ArchiveFile.bytes(path, data));
    entries.add({'path': path, 'size': data.length, 'sha256': sha256.convert(data).toString()});
  }
  archive.addFile(ArchiveFile.bytes(_manifestName, utf8.encode(jsonEncode({'files': entries}))));
  return ZipEncoder().encodeBytes(archive);
}

/// Unzips and verifies every file against the manifest: no extra, missing,
/// resized or altered files, and no path that could escape a directory.
Map<String, Uint8List> readPayload(Uint8List zip) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(zip, verify: true);
  } catch (_) {
    throw const BackupCorruptException('not a zip');
  }

  final byName = <String, ArchiveFile>{};
  for (final f in archive.files) {
    if (!f.isFile) continue;
    if (!_isSafePath(f.name)) throw const BackupCorruptException('unsafe path');
    if (byName.containsKey(f.name)) throw const BackupCorruptException('duplicate entry');
    byName[f.name] = f;
  }

  final manifestFile = byName.remove(_manifestName);
  if (manifestFile == null) throw const BackupCorruptException('no manifest');

  final List<({String path, int size, String sha})> expected;
  try {
    final j = jsonDecode(utf8.decode(manifestFile.readBytes()!)) as Map<String, dynamic>;
    expected = [
      for (final e in (j['files'] as List).cast<Map<String, dynamic>>())
        (path: e['path'] as String, size: e['size'] as int, sha: e['sha256'] as String),
    ];
  } catch (_) {
    throw const BackupCorruptException('bad manifest');
  }

  if (expected.length != byName.length || !expected.every((e) => byName.containsKey(e.path))) {
    throw const BackupCorruptException('files do not match manifest');
  }

  final out = <String, Uint8List>{};
  for (final e in expected) {
    final f = byName[e.path]!;
    // Check the declared size before inflating, so a zip bomb is refused early.
    if (f.size != e.size) throw const BackupCorruptException('size mismatch');
    final data = f.readBytes();
    if (data == null || data.length != e.size || sha256.convert(data).toString() != e.sha) {
      throw const BackupCorruptException('content mismatch');
    }
    out[e.path] = data;
  }
  return out;
}
