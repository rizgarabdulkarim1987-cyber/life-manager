import 'dart:typed_data';

import '../../../core/crypto/kdf.dart';
import 'vault_errors.dart';

const _target = Duration(milliseconds: 750);
const _raiseBelow = Duration(milliseconds: 500);
const _maxIterations = 8;

Future<Duration> _stopwatch(Future<void> Function() run) async {
  final sw = Stopwatch()..start();
  await run();
  return sw.elapsed;
}

/// Spec §9.1: start at m = 64 MiB, t = 3, p = 1 and aim for 0.5–1 s. A fast
/// phone gets more iterations (up to 8); a slow one never gets fewer than the
/// spec start. Only running out of memory drops to OWASP's m = 19 MiB, t = 2.
Future<KdfParams> calibrateVaultKdf(Kdf kdf, {Future<Duration> Function(Future<void> Function() run)? time}) async {
  final measure = time ?? _stopwatch;
  final Duration elapsed;
  try {
    elapsed = await measure(() => kdf.derive(password: Uint8List(1), salt: Uint8List(16), params: kDefaultKdfParams));
  } on KdfOutOfMemory {
    return kFallbackKdfParams;
  }
  if (elapsed >= _raiseBelow || elapsed <= Duration.zero) return kDefaultKdfParams;
  final t = (kDefaultKdfParams.iterations * _target.inMicroseconds / elapsed.inMicroseconds).ceil();
  return KdfParams(
    memoryKiB: kDefaultKdfParams.memoryKiB,
    iterations: t.clamp(kDefaultKdfParams.iterations, _maxIterations),
  );
}

/// Parameters read back from the database (possibly from a restored backup)
/// must not make the phone allocate gigabytes or spin for minutes.
void checkVaultKdf(KdfParams p) {
  final ok =
      p.memoryKiB >= kFallbackKdfParams.memoryKiB &&
      p.memoryKiB <= 256 * 1024 &&
      p.iterations >= 1 &&
      p.iterations <= 10 &&
      p.parallelism >= 1 &&
      p.parallelism <= 8;
  if (!ok) throw const VaultCorrupt();
}
