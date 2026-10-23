import 'dart:typed_data';

import '../../../core/crypto/random.dart';

/// The Vault Data Key (spec §9.1) while the vault is unlocked. It holds the
/// only copy of the key bytes and zero-fills them on [destroy]; Dart can't
/// promise no other copy ever existed (GC moves, platform calls), so this is
/// best effort, as the spec allows.
final class VaultKey {
  VaultKey(Uint8List bytes) : _bytes = bytes {
    if (bytes.length != 32) throw ArgumentError('vault key must be 32 bytes');
  }

  final Uint8List _bytes;
  bool _destroyed = false;

  bool get isDestroyed => _destroyed;

  Uint8List get bytes {
    if (_destroyed) throw StateError('vault key destroyed');
    return _bytes;
  }

  void destroy() {
    _bytes.fillRange(0, _bytes.length, 0);
    _destroyed = true;
  }

  /// Constant-time comparison of the key bytes.
  bool sameAs(VaultKey other) => constantTimeEquals(bytes, other.bytes);

  @override
  String toString() => 'VaultKey(‹redacted›)';
}

VaultKey generateVaultKey() => VaultKey(secureRandomBytes(32));

bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
