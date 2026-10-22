import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:life_manager/core/crypto/aead.dart';
import 'package:life_manager/core/crypto/kdf.dart';
import 'package:life_manager/core/crypto/random.dart';

/// Runs on a phone: `flutter test integration_test/crypto_device_test.dart -d <id>`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  FlutterCryptography.enable();

  testWidgets('AES-GCM round-trips through the platform implementation', (_) async {
    const aead = AesGcmAead();
    final key = secureRandomBytes(32);
    final plain = Uint8List.fromList(utf8.encode('device check'));
    final box = await aead.seal(plain, key, aad: Uint8List.fromList([1, 2, 3]));
    expect(await aead.open(box, key, aad: Uint8List.fromList([1, 2, 3])), plain);
  });

  testWidgets('default Argon2id params run on this device', (_) async {
    final sw = Stopwatch()..start();
    final p = await calibrateKdf(const DartArgon2idKdf());
    sw.stop();
    // Printed so the owner's phone timing is recorded in the test log.
    // ignore: avoid_print
    print('kdf params m=${p.memoryKiB} t=${p.iterations} took ${sw.elapsedMilliseconds} ms');
    expect(p.memoryKiB, anyOf(kDefaultKdfParams.memoryKiB, kFallbackKdfParams.memoryKiB));
  });
}
