import 'dart:typed_data';

const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

/// RFC 4648 Base32, upper case, without padding.
String base32Encode(List<int> bytes) {
  final out = StringBuffer();
  var buffer = 0;
  var bits = 0;
  for (final b in bytes) {
    buffer = (buffer << 8) | (b & 0xff);
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      out.write(_alphabet[(buffer >> bits) & 0x1f]);
    }
    buffer &= (1 << bits) - 1;
  }
  if (bits > 0) out.write(_alphabet[(buffer << (5 - bits)) & 0x1f]);
  return out.toString();
}

/// Inverse of [base32Encode]; `null` for any character outside the alphabet.
Uint8List? base32Decode(String s) {
  final out = BytesBuilder(copy: false);
  var buffer = 0;
  var bits = 0;
  for (final c in s.codeUnits) {
    final v = _alphabet.indexOf(String.fromCharCode(c));
    if (v < 0) return null;
    buffer = (buffer << 5) | v;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      out.addByte((buffer >> bits) & 0xff);
    }
    buffer &= (1 << bits) - 1;
  }
  return out.toBytes();
}
