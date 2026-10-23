import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/crypto/aead.dart';
import 'package:life_manager/core/crypto/kdf.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/features/backup/backup_format.dart';

void main() {
  const cheap = KdfParams(memoryKiB: 1024, iterations: 1);
  final codec = BackupCodec(const DartArgon2idKdf(), const AesGcmAead());
  final bytes = Uint8List.fromList(utf8.encode('SECRET-PAYLOAD-Buzzify-ledger ' * 20));

  Future<Uint8List> encode({String pw = 'correct horse'}) => codec.encode(
    payload: bytes,
    password: Sensitive(pw),
    schemaVersion: 1,
    appVersion: '1.0.0',
    kdf: cheap,
    now: DateTime.utc(2026, 10, 22),
  );

  bool contains(Uint8List hay, List<int> needle) {
    outer:
    for (var i = 0; i + needle.length <= hay.length; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (hay[i + j] != needle[j]) continue outer;
      }
      return true;
    }
    return false;
  }

  test('round-trip', () async {
    final f = await encode();
    final (h, p) = await codec.decode(f, const Sensitive('correct horse'));
    expect(p, bytes);
    expect(h.schemaVersion, 1);
    expect(h.appVersion, '1.0.0');
    expect(h.createdAtUtc, DateTime.utc(2026, 10, 22));
    expect(h.formatVersion, kBackupFormatVersion);
  });

  test('starts with PLMB magic', () async {
    final f = await encode();
    expect(ascii.decode(f.sublist(0, 4)), 'PLMB');
  });

  test('readHeader works without the password', () async {
    final h = codec.readHeader(await encode());
    expect(h.createdAtUtc, DateTime.utc(2026, 10, 22));
    expect(h.salt, hasLength(16));
    expect(h.nonce, hasLength(12));
  });

  test('wrong password throws BackupWrongPasswordException', () async {
    final f = await encode();
    expect(() => codec.decode(f, const Sensitive('wrong')), throwsA(isA<BackupWrongPasswordException>()));
  });

  test('flipping a header byte fails authentication (AAD)', () async {
    final f = await encode();
    // Change a digit inside the appVersion string so the JSON stays valid.
    final idx = utf8.decode(f, allowMalformed: true).indexOf('1.0.0');
    f[idx] = '9'.codeUnitAt(0);
    expect(() => codec.decode(f, const Sensitive('correct horse')), throwsA(isA<BackupWrongPasswordException>()));
  });

  test('flipping a body byte fails authentication', () async {
    final f = await encode();
    f[f.length - 20] ^= 0x01;
    expect(() => codec.decode(f, const Sensitive('correct horse')), throwsA(isA<BackupWrongPasswordException>()));
  });

  test('truncated file throws BackupFormatException', () async {
    final f = await encode();
    expect(() => codec.readHeader(f.sublist(0, 10)), throwsA(isA<BackupFormatException>()));
    expect(() => codec.decode(f.sublist(0, 10), const Sensitive('x')), throwsA(isA<BackupFormatException>()));
  });

  test('random bytes throw BackupFormatException', () {
    final junk = Uint8List.fromList(List.generate(300, (i) => (i * 37) & 0xff));
    expect(() => codec.readHeader(junk), throwsA(isA<BackupFormatException>()));
  });

  test('rejects a newer formatVersion', () async {
    final f = await encode();
    f[4] = 0;
    f[5] = 2;
    expect(() => codec.readHeader(f), throwsA(isA<BackupTooNewException>().having((e) => e.found, 'found', 2)));
  });

  test('rejects absurd KDF parameters in the header', () async {
    final f = await encode();
    final text = latin1.decode(f);
    final patched = text.replaceFirst('"m":1024', '"m":9999999');
    final out = Uint8List.fromList(latin1.encode(patched));
    // Keep the declared header length consistent with the longer JSON.
    final view = ByteData.sublistView(out);
    view.setUint32(6, view.getUint32(6) + 3);
    expect(() => codec.readHeader(out), throwsA(isA<BackupFormatException>()));
  });

  test('file has no plaintext of payload or password', () async {
    final f = await encode();
    expect(contains(f, utf8.encode('SECRET-PAYLOAD')), isFalse);
    expect(contains(f, utf8.encode('correct horse')), isFalse);
  });

  test('two encodes of the same payload differ (fresh salt and nonce)', () async {
    expect(await encode(), isNot(await encode()));
  });
}
