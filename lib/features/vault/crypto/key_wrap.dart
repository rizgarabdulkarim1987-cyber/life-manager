import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../../core/crypto/aead.dart';
import '../../../core/crypto/kdf.dart';
import '../../../core/crypto/random.dart';
import '../../../core/security/sensitive.dart';
import '../../../core/text/digits.dart';
import 'field_cipher.dart';
import 'recovery_key.dart';
import 'vault_errors.dart';
import 'vault_kdf.dart';
import 'vault_key.dart';

const _saltLength = 16;
const _checkLabel = 'plm-vault-check-v1';

/// The vault key sealed under a key-encryption key. [kdf] is set only for the
/// master-password wrap; the recovery wrap uses HKDF and needs no parameters.
final class WrappedKey {
  const WrappedKey({required this.kind, required this.kdf, required this.salt, required this.blob});

  final String kind;
  final KdfParams? kdf;
  final Uint8List salt;
  final Uint8List blob;

  @override
  String toString() => 'WrappedKey($kind)';
}

/// Wraps and unwraps the Vault Data Key (spec §9.1) with the master password
/// (Argon2id) or the recovery key (HKDF-SHA256), using AES-256-GCM.
class KeyWrapper {
  KeyWrapper(this._kdf, this._aead);

  final Kdf _kdf;
  final Aead _aead;

  static Uint8List _aad(String kind, String vaultId) => utf8.encode('plm-vault-wrap-v1|$kind|$vaultId');

  /// Digits typed on an Arabic or Kurdish keyboard hash like Western ones (Decision 6).
  static Uint8List _passwordBytes(Sensitive<String> pw) => Uint8List.fromList(utf8.encode(normalizeDigits(pw.value)));

  Future<Uint8List> _passwordKek(Sensitive<String> pw, Uint8List salt, KdfParams p) async {
    final bytes = _passwordBytes(pw);
    try {
      return await _kdf.derive(password: bytes, salt: salt, params: p);
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  static Future<Uint8List> _recoveryKek(RecoveryKey r, Uint8List salt) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final k = await hkdf.deriveKey(
      secretKey: SecretKey(Uint8List.fromList(r.bytes)),
      nonce: salt,
      info: utf8.encode('plm-vault-recovery-v1'),
    );
    return Uint8List.fromList(await k.extractBytes());
  }

  Future<Uint8List> _seal(VaultKey vdk, Uint8List kek, String kind, String vaultId) async {
    try {
      return encodeBlob(await _aead.seal(vdk.bytes, kek, aad: _aad(kind, vaultId)));
    } finally {
      kek.fillRange(0, kek.length, 0);
    }
  }

  Future<VaultKey> _open(Uint8List blob, Uint8List kek, String kind, String vaultId) async {
    try {
      final plain = await _aead.open(decodeBlob(blob), kek, aad: _aad(kind, vaultId));
      if (plain.length != 32) throw const VaultCorrupt();
      return VaultKey(plain);
    } on AeadAuthException {
      throw const VaultWrongSecret();
    } finally {
      kek.fillRange(0, kek.length, 0);
    }
  }

  Future<WrappedKey> wrapWithPassword(VaultKey vdk, Sensitive<String> password, String vaultId, KdfParams p) async {
    checkVaultKdf(p);
    final salt = secureRandomBytes(_saltLength);
    final kek = await _passwordKek(password, salt, p);
    return WrappedKey(kind: 'password', kdf: p, salt: salt, blob: await _seal(vdk, kek, 'password', vaultId));
  }

  Future<VaultKey> unwrapWithPassword(WrappedKey w, Sensitive<String> password, String vaultId) async {
    final p = w.kdf;
    if (w.kind != 'password' || p == null || w.salt.length != _saltLength) throw const VaultCorrupt();
    checkVaultKdf(p);
    return _open(w.blob, await _passwordKek(password, w.salt, p), 'password', vaultId);
  }

  Future<WrappedKey> wrapWithRecovery(VaultKey vdk, RecoveryKey r, String vaultId) async {
    final salt = secureRandomBytes(_saltLength);
    final kek = await _recoveryKek(r, salt);
    return WrappedKey(kind: 'recovery', kdf: null, salt: salt, blob: await _seal(vdk, kek, 'recovery', vaultId));
  }

  Future<VaultKey> unwrapWithRecovery(WrappedKey w, RecoveryKey r, String vaultId) async {
    if (w.kind != 'recovery' || w.salt.length != _saltLength) throw const VaultCorrupt();
    return _open(w.blob, await _recoveryKek(r, w.salt), 'recovery', vaultId);
  }

  /// A seal of a fixed label under the vault key. Every unlock path must open
  /// it, so a stale or foreign key is never taken for this vault's (Decision 2).
  Future<Uint8List> makeCheck(VaultKey vdk, String vaultId) async =>
      encodeBlob(await _aead.seal(utf8.encode(_checkLabel), vdk.bytes, aad: utf8.encode('$_checkLabel|$vaultId')));

  Future<bool> verifyCheck(VaultKey vdk, String vaultId, Uint8List check) async {
    try {
      final plain = await _aead.open(decodeBlob(check), vdk.bytes, aad: utf8.encode('$_checkLabel|$vaultId'));
      return constantTimeEquals(plain, utf8.encode(_checkLabel));
    } on AeadAuthException {
      return false;
    } on VaultCorrupt {
      return false;
    }
  }
}
