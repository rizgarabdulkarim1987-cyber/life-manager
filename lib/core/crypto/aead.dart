import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

final class SealedBox {
  const SealedBox(this.nonce, this.cipherText);

  final Uint8List nonce;

  /// Ciphertext followed by the 16-byte GCM tag.
  final Uint8List cipherText;
}

class AeadAuthException implements Exception {
  const AeadAuthException();
}

abstract interface class Aead {
  Future<SealedBox> seal(Uint8List plain, Uint8List key, {Uint8List? aad});
  Future<Uint8List> open(SealedBox box, Uint8List key, {Uint8List? aad});
}

/// AES-256-GCM with a fresh 12-byte nonce per seal. On Android the
/// cryptography_flutter plugin registers itself and routes this to the platform.
final class AesGcmAead implements Aead {
  const AesGcmAead();

  static const _tagLength = 16;

  AesGcm get _algo => AesGcm.with256bits();

  void _checkKey(Uint8List key) {
    if (key.length != 32) throw ArgumentError('AES-256 key must be 32 bytes');
  }

  @override
  Future<SealedBox> seal(Uint8List plain, Uint8List key, {Uint8List? aad}) async {
    _checkKey(key);
    final box = await _algo.encrypt(plain, secretKey: SecretKey(key), aad: aad ?? const <int>[]);
    return SealedBox(Uint8List.fromList(box.nonce), Uint8List.fromList([...box.cipherText, ...box.mac.bytes]));
  }

  @override
  Future<Uint8List> open(SealedBox box, Uint8List key, {Uint8List? aad}) async {
    _checkKey(key);
    if (box.cipherText.length < _tagLength) throw const AeadAuthException();
    final split = box.cipherText.length - _tagLength;
    try {
      final plain = await _algo.decrypt(
        SecretBox(box.cipherText.sublist(0, split), nonce: box.nonce, mac: Mac(box.cipherText.sublist(split))),
        secretKey: SecretKey(key),
        aad: aad ?? const <int>[],
      );
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      throw const AeadAuthException();
    }
  }
}
