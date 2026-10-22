import 'dart:typed_data';

import 'package:life_manager/core/crypto/kdf.dart';
import 'package:life_manager/features/lock/biometric_authenticator.dart';

/// Fast deterministic stand-in so widget tests don't wait on a real KDF isolate.
class FakeKdf implements Kdf {
  @override
  Future<Uint8List> derive({
    required Uint8List password,
    required Uint8List salt,
    required KdfParams params,
    int length = 32,
  }) async => Uint8List.fromList(
    List.generate(length, (i) => (password[i % password.length] * 31 + salt[i % salt.length] + i) & 0xff),
  );
}

class FakeBiometric implements BiometricAuthenticator {
  FakeBiometric({required this.available, required this.result});
  final bool available;
  final bool result;
  int prompts = 0;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    return result;
  }
}
