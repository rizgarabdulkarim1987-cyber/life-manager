import 'dart:typed_data';

import '../../../core/crypto/random.dart';
import '../../../core/text/digits.dart';
import 'base32.dart';

const _keyBytes = 20; // 160 bits (spec §9.1)
const _keyChars = 32;

/// The one-time recovery key. It is shown once, typed back to confirm, and
/// never stored; only its wrap of the vault key is (plan Decision 8).
final class RecoveryKey {
  RecoveryKey._(this._bytes);

  final Uint8List _bytes;
  bool _destroyed = false;

  static RecoveryKey generate() => RecoveryKey._(secureRandomBytes(_keyBytes));

  /// Reads what the owner typed. Case, spaces and dashes don't matter, and
  /// 0, 1 and 8 (not in the alphabet) are read as O, I and B.
  static RecoveryKey? parse(String typed) {
    final s = normalizeDigits(typed)
        .toUpperCase()
        .replaceAll(RegExp(r'[\s\-‐-―]'), '')
        .replaceAll('0', 'O')
        .replaceAll('1', 'I')
        .replaceAll('8', 'B');
    if (s.length != _keyChars) return null;
    final bytes = base32Decode(s);
    if (bytes == null || bytes.length != _keyBytes) return null;
    return RecoveryKey._(bytes);
  }

  Uint8List get bytes {
    if (_destroyed) throw StateError('recovery key destroyed');
    return _bytes;
  }

  /// Eight groups of four, e.g. `ABCD-EFGH-…`.
  String get display {
    final s = base32Encode(bytes);
    return [for (var i = 0; i < s.length; i += 4) s.substring(i, i + 4)].join('-');
  }

  void destroy() {
    _bytes.fillRange(0, _bytes.length, 0);
    _destroyed = true;
  }

  @override
  String toString() => 'RecoveryKey(‹redacted›)';
}
