import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/crypto/aead.dart';
import 'package:life_manager/core/crypto/random.dart';

Uint8List utf8b(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  const aead = AesGcmAead();
  final key = secureRandomBytes(32);
  final plain = utf8b('مرحبا secret 123');

  test('seal/open round-trips with aad', () async {
    final box = await aead.seal(plain, key, aad: utf8b('hdr'));
    expect(await aead.open(box, key, aad: utf8b('hdr')), plain);
  });

  test('ciphertext carries a 16-byte tag and hides the plaintext', () async {
    final box = await aead.seal(plain, key);
    expect(box.cipherText.length, plain.length + 16);
    expect(box.cipherText.sublist(0, plain.length), isNot(plain));
  });

  test('fresh 12-byte nonce per seal', () async {
    final a = await aead.seal(plain, key);
    final b = await aead.seal(plain, key);
    expect(a.nonce.length, 12);
    expect(a.nonce, isNot(b.nonce));
  });

  test('wrong key throws AeadAuthException', () async {
    final box = await aead.seal(plain, key);
    expect(() => aead.open(box, secureRandomBytes(32)), throwsA(isA<AeadAuthException>()));
  });

  test('tampered ciphertext throws AeadAuthException', () async {
    final box = await aead.seal(plain, key);
    final bad = Uint8List.fromList(box.cipherText)..[0] ^= 0x01;
    expect(() => aead.open(SealedBox(box.nonce, bad), key), throwsA(isA<AeadAuthException>()));
  });

  test('different aad throws AeadAuthException', () async {
    final box = await aead.seal(plain, key, aad: utf8b('a'));
    expect(() => aead.open(box, key, aad: utf8b('b')), throwsA(isA<AeadAuthException>()));
  });

  test('rejects keys that are not 32 bytes', () async {
    expect(() => aead.seal(plain, Uint8List(16)), throwsArgumentError);
  });

  test('secureRandomBytes returns distinct values of the requested length', () {
    final a = secureRandomBytes(32);
    expect(a.length, 32);
    expect(a, isNot(secureRandomBytes(32)));
  });
}
