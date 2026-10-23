import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'crypto/vault_key.dart';
import 'data/vault_providers.dart';

/// Reveal and copy need an auth newer than this (spec §9.2).
const kFreshAuthWindow = Duration(seconds: 30);

sealed class VaultState {
  const VaultState();
}

/// Reading the database to see whether a vault exists.
final class VaultChecking extends VaultState {
  const VaultChecking();
}

final class VaultNotSetUp extends VaultState {
  const VaultNotSetUp();
}

final class VaultLocked extends VaultState {
  const VaultLocked();
}

final class VaultUnlocked extends VaultState {
  const VaultUnlocked();
}

/// Holds the vault key while the vault is open, and nothing else. Locking
/// (idle, app hidden, app lock, or by hand) zero-fills the key (spec §9.2).
class VaultSession extends Notifier<VaultState> {
  VaultKey? _key;
  Timer? _idle;
  DateTime? _lastAuthAt;

  DateTime _now() => ref.read(vaultClockProvider)();

  @override
  VaultState build() {
    ref.onDispose(_wipe);
    unawaited(Future.microtask(refresh));
    return const VaultChecking();
  }

  /// Re-reads whether a vault exists (after setup or a restore).
  Future<void> refresh() async {
    final setUp = await ref.read(vaultKeyServiceProvider).isSetUp();
    if (_key != null) return;
    state = setUp ? const VaultLocked() : const VaultNotSetUp();
  }

  void unlocked(VaultKey k) {
    _wipe();
    _key = k;
    _lastAuthAt = _now();
    state = const VaultUnlocked();
    _armIdle();
  }

  VaultKey requireKey() {
    final k = _key;
    if (k == null || k.isDestroyed) throw StateError('vault is locked');
    return k;
  }

  bool get isUnlocked => _key != null;

  /// Any touch inside the vault restarts the idle timer.
  void touch() {
    if (_key != null) _armIdle();
  }

  void lock() {
    if (_key == null) return;
    _wipe();
    state = const VaultLocked();
  }

  bool needsFreshAuth() {
    final at = _lastAuthAt;
    return at == null || _now().difference(at) > kFreshAuthWindow;
  }

  void freshAuth() {
    if (_key != null) _lastAuthAt = _now();
  }

  void _armIdle() {
    _idle?.cancel();
    final seconds = ref.read(settingsProvider).value?.vaultAutoLockSeconds ?? 120;
    _idle = Timer(Duration(seconds: seconds), lock);
  }

  void _wipe() {
    _idle?.cancel();
    _idle = null;
    _key?.destroy();
    _key = null;
    _lastAuthAt = null;
  }
}

final vaultSessionProvider = NotifierProvider<VaultSession, VaultState>(VaultSession.new);
