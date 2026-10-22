import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

class KdfParams {
  const KdfParams({required this.memoryKiB, required this.iterations, this.parallelism = 1});

  final int memoryKiB;
  final int iterations;
  final int parallelism;

  Map<String, Object> toJson() => {
        'alg': 'argon2id',
        'm': memoryKiB,
        't': iterations,
        'p': parallelism,
      };

  factory KdfParams.fromJson(Map<String, Object?> j) {
    if (j['alg'] != 'argon2id') throw const FormatException('unsupported kdf');
    return KdfParams(
      memoryKiB: j['m']! as int,
      iterations: j['t']! as int,
      parallelism: j['p']! as int,
    );
  }
}

/// Spec §9.1: m = 64 MiB, t = 3, p = 1; OWASP minimum as fallback.
const kDefaultKdfParams = KdfParams(memoryKiB: 65536, iterations: 3);
const kFallbackKdfParams = KdfParams(memoryKiB: 19456, iterations: 2);

class KdfOutOfMemory implements Exception {
  const KdfOutOfMemory();
}

abstract interface class Kdf {
  Future<Uint8List> derive({
    required Uint8List password,
    required Uint8List salt,
    required KdfParams params,
    int length = 32,
  });
}

/// Argon2id v1.3 from package:cryptography, run off the UI isolate.
final class DartArgon2idKdf implements Kdf {
  const DartArgon2idKdf();

  @override
  Future<Uint8List> derive({
    required Uint8List password,
    required Uint8List salt,
    required KdfParams params,
    int length = 32,
  }) async {
    try {
      return await Isolate.run(() async {
        final algo = DartArgon2id(
          parallelism: params.parallelism,
          memory: params.memoryKiB,
          iterations: params.iterations,
          hashLength: length,
        );
        final key = await algo.deriveKey(secretKey: SecretKey(password), nonce: salt);
        return Uint8List.fromList(await key.extractBytes());
      });
    } on OutOfMemoryError {
      throw const KdfOutOfMemory();
    } on IsolateSpawnException {
      rethrow;
    } on RemoteError catch (e) {
      if (e.toString().contains('OutOfMemory')) throw const KdfOutOfMemory();
      rethrow;
    }
  }
}

/// Picks the strongest params this device can run (spec §9.1).
Future<KdfParams> calibrateKdf(Kdf kdf) async {
  try {
    await kdf.derive(password: Uint8List(1), salt: Uint8List(16), params: kDefaultKdfParams);
    return kDefaultKdfParams;
  } on KdfOutOfMemory {
    return kFallbackKdfParams;
  }
}
