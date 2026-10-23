import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/storage/secure_store.dart';
import '../crypto/vault_errors.dart';

/// Text for the system fingerprint prompt.
class BioPromptText {
  const BioPromptText({required this.title, required this.subtitle, required this.cancel});

  final String title;
  final String subtitle;
  final String cancel;
}

/// An AES-256-GCM key inside Android Keystore that only a strong biometric can
/// use, once per operation, and that dies when a fingerprint is added (spec
/// §9.1, plan Decision 12). The key never leaves the Keystore.
abstract interface class BiometricKeyStore {
  Future<bool> isAvailable();

  /// Shows the prompt, then seals [data]; returns `iv ‖ ciphertext ‖ tag`.
  Future<Uint8List> encrypt(Uint8List data, BioPromptText t);

  /// Shows the prompt, then opens what [encrypt] returned.
  Future<Uint8List> decrypt(Uint8List data, BioPromptText t);

  Future<void> deleteKey();
}

/// Talks to `VaultChannel.kt`. The platform answers with error codes only,
/// never messages, so nothing from Android reaches a log through here.
final class PlatformBiometricKeyStore implements BiometricKeyStore {
  const PlatformBiometricKeyStore([this._channel = channel]);

  static const channel = MethodChannel('com.personal.lifemanager/vault');

  final MethodChannel _channel;

  static VaultUnlockError _map(PlatformException e) => switch (e.code) {
    'invalidated' => const VaultBiometricInvalidated(),
    'cancelled' => const VaultBiometricCancelled(),
    'unavailable' => const VaultBiometricUnavailable(),
    'lockout' => const VaultLockedOut(Duration.zero),
    _ => const VaultWrongSecret(),
  };

  Future<Uint8List> _crypt(String method, Uint8List data, BioPromptText t) async {
    try {
      final out = await _channel.invokeMethod<Uint8List>(method, {
        'data': data,
        'title': t.title,
        'subtitle': t.subtitle,
        'cancel': t.cancel,
      });
      if (out == null) throw const VaultWrongSecret();
      return out;
    } on PlatformException catch (e) {
      throw _map(e);
    } on MissingPluginException {
      throw const VaultBiometricUnavailable();
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('bioAvailable') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<Uint8List> encrypt(Uint8List data, BioPromptText t) => _crypt('bioEncrypt', data, t);

  @override
  Future<Uint8List> decrypt(Uint8List data, BioPromptText t) => _crypt('bioDecrypt', data, t);

  @override
  Future<void> deleteKey() async {
    try {
      await _channel.invokeMethod<void>('bioDelete');
    } on PlatformException {
      // Nothing to delete, or the Keystore is unavailable; the wrap is gone either way.
    } on MissingPluginException {
      // Same.
    }
  }
}

/// The vault key sealed by the biometric key, tagged with the vault it belongs to.
final class BioWrap {
  const BioWrap({required this.vaultId, required this.blob});

  final String vaultId;
  final Uint8List blob;

  @override
  String toString() => 'BioWrap(‹redacted›)';
}

abstract interface class BioWrapStore {
  Future<BioWrap?> read();
  Future<void> write(BioWrap w);
  Future<void> clear();
}

/// Kept in Keystore-backed secure storage, never in the database, so it is
/// never part of a backup (plan Decision 1).
final class SecureBioWrapStore implements BioWrapStore {
  SecureBioWrapStore(this._store);

  static const storeKey = 'vault_bio_wrap_v1';

  final SecureStore _store;

  @override
  Future<BioWrap?> read() async {
    final raw = await _store.read(storeKey);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return BioWrap(vaultId: j['vaultId'] as String, blob: base64Decode(j['blob'] as String));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(BioWrap w) =>
      _store.write(storeKey, jsonEncode({'vaultId': w.vaultId, 'blob': base64Encode(w.blob)}));

  @override
  Future<void> clear() => _store.delete(storeKey);
}
