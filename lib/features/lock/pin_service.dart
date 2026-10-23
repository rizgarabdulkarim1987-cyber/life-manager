import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/crypto/kdf.dart';
import '../../core/crypto/random.dart';
import '../../core/storage/secure_store.dart';
import 'digits.dart';

sealed class PinCheckResult {
  const PinCheckResult();
}

final class PinOk extends PinCheckResult {
  const PinOk();
}

final class PinWrong extends PinCheckResult {
  const PinWrong(this.attemptsBeforeLockout);
  final int attemptsBeforeLockout;
}

final class PinLockedOut extends PinCheckResult {
  const PinLockedOut(this.remaining);
  final Duration remaining;
}

/// The app-lock PIN (spec §15): 6 digits, Argon2id-hashed in Keystore-backed
/// storage, with a persisted exponential lockout.
class PinService {
  PinService(this._store, this._kdf, {DateTime Function()? now, KdfParams params = kDefaultKdfParams})
    : _now = now ?? DateTime.now,
      _params = params; // ignore: prefer_initializing_formals

  static const recordKey = 'app_pin_v1';
  static const failuresKey = 'app_pin_failures_v1';
  static const freeAttempts = 5;
  static const firstLockout = Duration(seconds: 30);
  static const maxLockout = Duration(hours: 1);

  final SecureStore _store;
  final Kdf _kdf;
  final DateTime Function() _now;
  final KdfParams _params;

  static final _sixDigits = RegExp(r'^[0-9]{6}$');

  Future<bool> hasPin() async => await _store.read(recordKey) != null;

  Future<void> setPin(String pin) async {
    final p = normalizeDigits(pin);
    if (!_sixDigits.hasMatch(p)) throw ArgumentError('PIN must be exactly 6 digits');
    final salt = secureRandomBytes(16);
    var params = _params;
    Uint8List hash;
    try {
      hash = await _hash(p, salt, params);
    } on KdfOutOfMemory {
      params = kFallbackKdfParams;
      hash = await _hash(p, salt, params);
    }
    await _store.write(
      recordKey,
      jsonEncode({'salt': base64Encode(salt), 'hash': base64Encode(hash), 'kdf': params.toJson()}),
    );
    await _store.delete(failuresKey);
  }

  Future<bool> changePin({required String current, required String next}) async {
    if (await verify(current) is! PinOk) return false;
    await setPin(next);
    return true;
  }

  Future<PinCheckResult> verify(String pin) async {
    final raw = await _store.read(recordKey);
    if (raw == null) throw StateError('no PIN set');

    final failures = await _readFailures();
    final now = _now();
    final lockedUntil = failures.lockedUntil;
    if (lockedUntil != null && now.isBefore(lockedUntil)) {
      return PinLockedOut(lockedUntil.difference(now));
    }

    final rec = jsonDecode(raw) as Map<String, dynamic>;
    final salt = base64Decode(rec['salt'] as String);
    final expected = base64Decode(rec['hash'] as String);
    final params = KdfParams.fromJson((rec['kdf'] as Map).cast<String, Object?>());
    final actual = await _hash(normalizeDigits(pin), salt, params);

    if (_constantTimeEquals(actual, expected)) {
      await _store.delete(failuresKey);
      return const PinOk();
    }

    final count = failures.count + 1;
    if (count < freeAttempts) {
      await _writeFailures(count, null);
      return PinWrong(freeAttempts - count);
    }
    final lockout = _lockoutFor(count);
    await _writeFailures(count, now.add(lockout));
    return PinLockedOut(lockout);
  }

  Duration _lockoutFor(int count) {
    final doublings = math.min(count - freeAttempts, 20);
    final seconds = firstLockout.inSeconds * math.pow(2, doublings).toInt();
    return Duration(seconds: math.min(seconds, maxLockout.inSeconds));
  }

  Future<Uint8List> _hash(String pin, Uint8List salt, KdfParams params) =>
      _kdf.derive(password: Uint8List.fromList(utf8.encode(pin)), salt: salt, params: params);

  Future<({int count, DateTime? lockedUntil})> _readFailures() async {
    final raw = await _store.read(failuresKey);
    if (raw == null) return (count: 0, lockedUntil: null);
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final until = j['lockedUntil'] as String?;
    return (count: j['count'] as int, lockedUntil: until == null ? null : DateTime.parse(until));
  }

  Future<void> _writeFailures(int count, DateTime? lockedUntil) =>
      _store.write(failuresKey, jsonEncode({'count': count, 'lockedUntil': lockedUntil?.toUtc().toIso8601String()}));

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
