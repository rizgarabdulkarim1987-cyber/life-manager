import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'biometric_authenticator.dart';
import 'pin_service.dart';

enum LockStatus { locked, unlocked }

bool shouldRelock({required DateTime pausedAt, required DateTime resumedAt, required Duration timeout}) =>
    resumedAt.difference(pausedAt) >= timeout;

class LockController extends Notifier<LockStatus> {
  DateTime? _pausedAt;

  @override
  LockStatus build() => LockStatus.locked;

  void unlock() => state = LockStatus.unlocked;

  void lockNow() => state = LockStatus.locked;

  void onPaused(DateTime at) => _pausedAt = at;

  void onResumed(DateTime at, {required Duration timeout}) {
    final paused = _pausedAt;
    _pausedAt = null;
    if (paused != null && shouldRelock(pausedAt: paused, resumedAt: at, timeout: timeout)) {
      state = LockStatus.locked;
    }
  }
}

final lockControllerProvider = NotifierProvider<LockController, LockStatus>(LockController.new);

final pinServiceProvider = Provider<PinService>(
  (ref) => PinService(ref.watch(secureStoreProvider), ref.watch(kdfProvider)),
);

final biometricAuthenticatorProvider = Provider<BiometricAuthenticator>(
  (ref) => LocalAuthBiometricAuthenticator(),
);
