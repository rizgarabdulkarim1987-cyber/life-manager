import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

abstract interface class BiometricAuthenticator {
  /// Whether the phone has any screen lock (PIN, pattern, password or biometrics).
  Future<bool> deviceSecure();

  Future<bool> authenticate(String reason);
}

/// Face or fingerprint, weak or strong class, with the phone's own screen lock
/// as the fallback (redesign §8.1). There is no app PIN.
final class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  LocalAuthBiometricAuthenticator([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> deviceSecure() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      // biometricOnly false: weak and strong biometrics plus the device credential.
      return await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }
}
