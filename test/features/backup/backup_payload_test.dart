import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/backup/backup_payload.dart';

void main() {
  final files = {
    'db/app.db': Uint8List.fromList(List.generate(5000, (i) => i & 0xff)),
    'notes/readme.txt': Uint8List.fromList(utf8.encode('hello')),
  };

  Uint8List zipOf(Map<String, List<int>> entries) {
    final a = Archive();
    entries.forEach((name, data) => a.addFile(ArchiveFile.bytes(name, data)));
    return ZipEncoder().encodeBytes(a);
  }

  Map<String, Object> manifestFor(Map<String, List<int>> entries) => {
    'files': [
      for (final e in entries.entries)
        {'path': e.key, 'size': e.value.length, 'sha256': sha256.convert(e.value).toString()},
    ],
  };

  test('payload round-trip with manifest', () {
    final out = readPayload(buildPayload(files));
    expect(out.keys, unorderedEquals(files.keys));
    expect(out['db/app.db'], files['db/app.db']);
    expect(out['notes/readme.txt'], files['notes/readme.txt']);
  });

  test('modified file content throws BackupCorruptException', () {
    final good = {'a.bin': utf8.encode('original')};
    final zip = zipOf({'a.bin': utf8.encode('tampered'), 'manifest.json': utf8.encode(jsonEncode(manifestFor(good)))});
    expect(() => readPayload(zip), throwsA(isA<BackupCorruptException>()));
  });

  test('extra file not in manifest throws', () {
    final entries = {'a.bin': utf8.encode('x')};
    final zip = zipOf({
      ...entries,
      'extra.bin': utf8.encode('y'),
      'manifest.json': utf8.encode(jsonEncode(manifestFor(entries))),
    });
    expect(() => readPayload(zip), throwsA(isA<BackupCorruptException>()));
  });

  test('missing file throws', () {
    final entries = {'a.bin': utf8.encode('x'), 'b.bin': utf8.encode('y')};
    final zip = zipOf({'a.bin': entries['a.bin']!, 'manifest.json': utf8.encode(jsonEncode(manifestFor(entries)))});
    expect(() => readPayload(zip), throwsA(isA<BackupCorruptException>()));
  });

  test('zip with ../evil path throws BackupCorruptException', () {
    final entries = {'../evil': utf8.encode('x')};
    final zip = zipOf({...entries, 'manifest.json': utf8.encode(jsonEncode(manifestFor(entries)))});
    expect(() => readPayload(zip), throwsA(isA<BackupCorruptException>()));
  });

  test('absolute and backslash paths are refused when building', () {
    expect(() => buildPayload({'/etc/x': Uint8List(1)}), throwsArgumentError);
    expect(() => buildPayload({r'a\b': Uint8List(1)}), throwsArgumentError);
    expect(() => buildPayload({'manifest.json': Uint8List(1)}), throwsArgumentError);
  });

  test('not a zip throws BackupCorruptException', () {
    expect(() => readPayload(Uint8List.fromList(utf8.encode('nope'))), throwsA(isA<BackupCorruptException>()));
  });
}
