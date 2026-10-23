import 'dart:convert';
import 'dart:math' as math;

import '../../../core/storage/secure_store.dart';

/// Rate limit for wrong master passwords and recovery keys (spec §9.1, plan
/// Decision 11): five free attempts, then 30 s doubling to an hour. Persisted,
/// so killing the app doesn't reset it. Nothing is ever deleted.
class UnlockThrottle {
  UnlockThrottle(this._store, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const storeKey = 'vault_unlock_failures_v1';
  static const freeAttempts = 5;
  static const firstLockout = Duration(seconds: 30);
  static const maxLockout = Duration(hours: 1);

  final SecureStore _store;
  final DateTime Function() _now;

  /// How long unlocking is still blocked, or `null` when it isn't.
  Future<Duration?> blockedFor() async {
    final rec = await _read();
    final until = rec.lockedUntil;
    if (until == null) return null;
    final now = _now();
    return now.isBefore(until) ? until.difference(now) : null;
  }

  Future<({int attemptsLeft, Duration? lockedFor})> recordFailure() async {
    final count = (await _read()).count + 1;
    if (count < freeAttempts) {
      await _write(count, null);
      return (attemptsLeft: freeAttempts - count, lockedFor: null);
    }
    final doublings = math.min(count - freeAttempts, 20);
    final seconds = math.min(firstLockout.inSeconds * math.pow(2, doublings).toInt(), maxLockout.inSeconds);
    final lockout = Duration(seconds: seconds);
    await _write(count, _now().add(lockout));
    return (attemptsLeft: 0, lockedFor: lockout);
  }

  Future<void> reset() => _store.delete(storeKey);

  Future<({int count, DateTime? lockedUntil})> _read() async {
    final raw = await _store.read(storeKey);
    if (raw == null) return (count: 0, lockedUntil: null);
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final until = j['lockedUntil'] as String?;
      return (count: j['count'] as int, lockedUntil: until == null ? null : DateTime.parse(until));
    } catch (_) {
      // A damaged record must not become a free pass: start one full lockout,
      // written back so it ends an hour from now rather than never.
      const count = freeAttempts + 20;
      final until = _now().add(maxLockout);
      await _write(count, until);
      return (count: count, lockedUntil: until);
    }
  }

  Future<void> _write(int count, DateTime? lockedUntil) =>
      _store.write(storeKey, jsonEncode({'count': count, 'lockedUntil': lockedUntil?.toUtc().toIso8601String()}));
}
