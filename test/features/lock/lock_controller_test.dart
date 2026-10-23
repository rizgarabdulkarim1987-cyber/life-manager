import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/lock/lock_controller.dart';

void main() {
  final paused = DateTime.utc(2026, 10, 22, 12);

  test('shouldRelock boundary', () {
    const t = Duration(seconds: 300);
    expect(shouldRelock(pausedAt: paused, resumedAt: paused.add(const Duration(seconds: 299)), timeout: t), isFalse);
    expect(shouldRelock(pausedAt: paused, resumedAt: paused.add(const Duration(seconds: 300)), timeout: t), isTrue);
    expect(shouldRelock(pausedAt: paused, resumedAt: paused, timeout: Duration.zero), isTrue);
  });

  test('starts locked, unlocks, relocks after the timeout', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(lockControllerProvider.notifier);
    expect(c.read(lockControllerProvider), LockStatus.locked);
    n.unlock();
    expect(c.read(lockControllerProvider), LockStatus.unlocked);

    n.onPaused(paused);
    n.onResumed(paused.add(const Duration(seconds: 10)), timeout: const Duration(minutes: 5));
    expect(c.read(lockControllerProvider), LockStatus.unlocked);

    n.onPaused(paused);
    n.onResumed(paused.add(const Duration(minutes: 6)), timeout: const Duration(minutes: 5));
    expect(c.read(lockControllerProvider), LockStatus.locked);
  });

  test('resume without a recorded pause keeps the current state', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(lockControllerProvider.notifier)..unlock();
    n.onResumed(paused, timeout: Duration.zero);
    expect(c.read(lockControllerProvider), LockStatus.unlocked);
  });

  test('lockNow locks', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(lockControllerProvider.notifier)
      ..unlock()
      ..lockNow();
    expect(c.read(lockControllerProvider), LockStatus.locked);
  });
}
