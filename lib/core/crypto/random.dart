import 'dart:math';
import 'dart:typed_data';

final _rng = Random.secure();

Uint8List secureRandomBytes(int length) {
  final out = Uint8List(length);
  for (var i = 0; i < length; i++) {
    out[i] = _rng.nextInt(256);
  }
  return out;
}
