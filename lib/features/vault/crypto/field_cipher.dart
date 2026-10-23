import 'dart:convert';
import 'dart:typed_data';

import '../../../core/crypto/aead.dart';
import '../../../core/security/sensitive.dart';
import 'vault_errors.dart';
import 'vault_key.dart';

const _blobVersion = 1;
const _nonceLength = 12;
const _tagLength = 16;

/// `0x01 ‖ nonce(12) ‖ ciphertext ‖ tag(16)`. The version byte lets a later
/// release change the algorithm without guessing (plan Decision 5).
Uint8List encodeBlob(SealedBox box) {
  if (box.nonce.length != _nonceLength) throw ArgumentError('nonce must be 12 bytes');
  return (BytesBuilder(copy: false)
        ..addByte(_blobVersion)
        ..add(box.nonce)
        ..add(box.cipherText))
      .toBytes();
}

SealedBox decodeBlob(Uint8List blob) {
  if (blob.length < 1 + _nonceLength + _tagLength || blob.first != _blobVersion) throw const VaultCorrupt();
  return SealedBox(
    Uint8List.fromList(blob.sublist(1, 1 + _nonceLength)),
    Uint8List.fromList(blob.sublist(1 + _nonceLength)),
  );
}

/// The secret fields of a vault item (spec §9.1). Everything else on an item is
/// protected only by the SQLCipher database layer.
enum VaultField { password, notes, recoveryCodes }

/// AES-256-GCM per field with a fresh nonce, bound to its item and field by
/// the associated data, so a ciphertext copied elsewhere fails to open.
class FieldCipher {
  const FieldCipher(this._aead);

  final Aead _aead;

  static Uint8List _aad(String uid, VaultField f) => utf8.encode('plm-vault-field-v1|$uid|${f.name}');

  Future<Uint8List> seal(VaultKey k, String uid, VaultField f, Sensitive<String> value) async {
    final plain = Uint8List.fromList(utf8.encode(value.value));
    try {
      return encodeBlob(await _aead.seal(plain, k.bytes, aad: _aad(uid, f)));
    } finally {
      plain.fillRange(0, plain.length, 0);
    }
  }

  Future<Sensitive<String>> open(VaultKey k, String uid, VaultField f, Uint8List blob) async {
    final Uint8List plain;
    try {
      plain = await _aead.open(decodeBlob(blob), k.bytes, aad: _aad(uid, f));
    } on AeadAuthException {
      throw const VaultCorrupt();
    }
    try {
      return Sensitive(utf8.decode(plain));
    } on FormatException {
      throw const VaultCorrupt();
    } finally {
      plain.fillRange(0, plain.length, 0);
    }
  }
}
