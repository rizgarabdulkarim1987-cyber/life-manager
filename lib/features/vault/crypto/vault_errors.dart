/// Everything the vault can report about an unlock or a decryption. None of
/// these carries text that came from the owner's input or the stored data.
sealed class VaultUnlockError implements Exception {
  const VaultUnlockError();
}

/// Wrong master password or recovery key. GCM can't tell that from a damaged
/// wrap, so both look the same to the owner (spec §9.1).
final class VaultWrongSecret extends VaultUnlockError {
  const VaultWrongSecret([this.attemptsLeft]);

  /// Tries left before a lockout, when the throttle counted this attempt.
  final int? attemptsLeft;
}

/// Stored vault data failed authentication or has an impossible shape.
final class VaultCorrupt extends VaultUnlockError {
  const VaultCorrupt();
}

/// Too many wrong attempts; try again after [remaining].
final class VaultLockedOut extends VaultUnlockError {
  const VaultLockedOut(this.remaining);
  final Duration remaining;
}

/// The biometric key is gone (new fingerprint enrolled, or a restore); unlock
/// with the master password and turn fingerprint unlock on again.
final class VaultBiometricInvalidated extends VaultUnlockError {
  const VaultBiometricInvalidated();
}

final class VaultBiometricCancelled extends VaultUnlockError {
  const VaultBiometricCancelled();
}

final class VaultBiometricUnavailable extends VaultUnlockError {
  const VaultBiometricUnavailable();
}
