import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/crypto/aead.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/features/vault/crypto/field_cipher.dart';
import 'package:life_manager/features/vault/crypto/vault_errors.dart';
import 'package:life_manager/features/vault/crypto/vault_key.dart';

const _secret = 'TEST-ONLY-pw-7731';

void main() {
  final fc = FieldCipher(const AesGcmAead());

  group('VaultKey', () {
    test('must be 32 bytes', () {
      expect(() => VaultKey(Uint8List(16)), throwsArgumentError);
    });

    test('destroy zero-fills the bytes it holds and blocks further use', () {
      final raw = Uint8List.fromList(List.filled(32, 7));
      final k = VaultKey(raw);
      k.destroy();
      expect(raw.every((b) => b == 0), isTrue);
      expect(k.isDestroyed, isTrue);
      expect(() => k.bytes, throwsStateError);
    });

    test('sameAs compares contents', () {
      final a = generateVaultKey();
      expect(a.sameAs(VaultKey(Uint8List.fromList(a.bytes))), isTrue);
      expect(a.sameAs(generateVaultKey()), isFalse);
    });

    test('toString is redacted', () {
      final k = VaultKey(Uint8List.fromList(List.filled(32, 0x41)));
      expect('$k', isNot(contains('65')));
      expect('$k', contains('redacted'));
    });
  });

  group('blob layout', () {
    test('version byte, 12-byte nonce, ciphertext and tag', () {
      final box = SealedBox(Uint8List(12), Uint8List(20));
      final blob = encodeBlob(box);
      expect(blob.first, 1);
      expect(blob, hasLength(1 + 12 + 20));
      final back = decodeBlob(blob);
      expect(back.nonce, box.nonce);
      expect(back.cipherText, box.cipherText);
    });

    test('unknown version or short blob → VaultCorrupt', () {
      expect(() => decodeBlob(Uint8List.fromList([2, ...List.filled(40, 0)])), throwsA(isA<VaultCorrupt>()));
      expect(() => decodeBlob(Uint8List.fromList([1, ...List.filled(20, 0)])), throwsA(isA<VaultCorrupt>()));
    });
  });

  group('FieldCipher', () {
    test('round-trips and binds the ciphertext to its item and field', () async {
      final k = generateVaultKey();
      final blob = await fc.seal(k, 'uid-a', VaultField.password, const Sensitive(_secret));
      expect((await fc.open(k, 'uid-a', VaultField.password, blob)).value, _secret);
      await expectLater(fc.open(k, 'uid-b', VaultField.password, blob), throwsA(isA<VaultCorrupt>()));
      await expectLater(fc.open(k, 'uid-a', VaultField.notes, blob), throwsA(isA<VaultCorrupt>()));
      await expectLater(fc.open(generateVaultKey(), 'uid-a', VaultField.password, blob), throwsA(isA<VaultCorrupt>()));
    });

    test('Arabic and Kurdish text survive', () async {
      final k = generateVaultKey();
      const notes = 'ملاحظة سرية — تێبینی نهێنی ١٢٣';
      final blob = await fc.seal(k, 'u', VaultField.notes, const Sensitive(notes));
      expect((await fc.open(k, 'u', VaultField.notes, blob)).value, notes);
    });

    test('a fresh nonce on every seal', () async {
      final k = generateVaultKey();
      final a = await fc.seal(k, 'u', VaultField.password, const Sensitive(_secret));
      final b = await fc.seal(k, 'u', VaultField.password, const Sensitive(_secret));
      expect(a, isNot(b));
    });

    test('a flipped bit fails authentication', () async {
      final k = generateVaultKey();
      final blob = await fc.seal(k, 'u', VaultField.password, const Sensitive(_secret));
      blob[blob.length - 3] ^= 0x01;
      await expectLater(fc.open(k, 'u', VaultField.password, blob), throwsA(isA<VaultCorrupt>()));
    });

    test('the blob does not contain the plaintext', () async {
      final blob = await fc.seal(generateVaultKey(), 'u', VaultField.password, const Sensitive(_secret));
      expect(String.fromCharCodes(blob), isNot(contains(_secret)));
    });
  });
}
