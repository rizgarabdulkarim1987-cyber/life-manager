import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/storage/secure_store.dart';
import 'package:life_manager/features/vault/data/unlock_throttle.dart';

void main() {
  late DateTime now;
  late InMemorySecureStore store;
  late UnlockThrottle t;

  setUp(() {
    now = DateTime.utc(2026, 10, 23);
    store = InMemorySecureStore();
    t = UnlockThrottle(store, now: () => now);
  });

  test('five free attempts, then 30 s doubling up to an hour', () async {
    for (var i = 4; i >= 1; i--) {
      expect(await t.recordFailure(), (attemptsLeft: i, lockedFor: null));
    }
    expect((await t.recordFailure()).lockedFor, const Duration(seconds: 30));
    expect(await t.blockedFor(), const Duration(seconds: 30));
    now = now.add(const Duration(seconds: 30));
    expect(await t.blockedFor(), isNull);
    expect((await t.recordFailure()).lockedFor, const Duration(seconds: 60));
    for (var i = 0; i < 20; i++) {
      now = now.add(const Duration(hours: 2));
      await t.recordFailure();
    }
    expect(await t.blockedFor(), const Duration(hours: 1));
  });

  test('reset clears the counter', () async {
    for (var i = 0; i < 5; i++) {
      await t.recordFailure();
    }
    await t.reset();
    expect(await t.blockedFor(), isNull);
    expect((await t.recordFailure()).attemptsLeft, 4);
  });

  test('the counter survives a restart (persisted)', () async {
    for (var i = 0; i < 5; i++) {
      await t.recordFailure();
    }
    final again = UnlockThrottle(store, now: () => now);
    expect(await again.blockedFor(), const Duration(seconds: 30));
  });

  test('an unreadable record counts as a lockout, not as a free pass', () async {
    await store.write(UnlockThrottle.storeKey, 'garbage');
    expect(await t.blockedFor(), isNotNull);
  });
}
