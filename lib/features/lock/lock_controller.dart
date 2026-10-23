import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'biometric_authenticator.dart';

enum LockStatus { locked, unlocked }

bool shouldRelock({required DateTime pausedAt, required DateTime resumedAt, required Duration timeout}) =>
    resumedAt.difference(pausedAt) >= timeout;

/// How long an unlock counts for the sensitive sections (redesign §8.2).
const kFreshAuth = Duration(seconds: 60);

class LockController extends Notifier<LockStatus> {
  DateTime? _pausedAt;

  /// When the owner last passed face, fingerprint or screen lock.
  DateTime? lastAuthAt;

  @override
  LockStatus build() => LockStatus.locked;

  void unlock() {
    lastAuthAt = DateTime.now();
    state = LockStatus.unlocked;
  }

  void lockNow() => state = LockStatus.locked;

  bool authFresh(DateTime now, {Duration within = kFreshAuth}) {
    final at = lastAuthAt;
    return at != null && now.difference(at) <= within;
  }

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

final biometricAuthenticatorProvider = Provider<BiometricAuthenticator>((ref) => LocalAuthBiometricAuthenticator());
