import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

abstract interface class BiometricAuthenticator {
  Future<bool> isAvailable();
  Future<bool> authenticate(String reason);
}

/// Fingerprint/face with the device credential allowed as a fallback (spec §15).
final class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  LocalAuthBiometricAuthenticator([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported() && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }
}
