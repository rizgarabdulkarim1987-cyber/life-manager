import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/vault/crypto/base32.dart';
import 'package:life_manager/features/vault/crypto/recovery_key.dart';

void main() {
  group('base32 (RFC 4648 §10 vectors, no padding)', () {
    const vectors = {
      '': '',
      'f': 'MY',
      'fo': 'MZXQ',
      'foo': 'MZXW6',
      'foob': 'MZXW6YQ',
      'fooba': 'MZXW6YTB',
      'foobar': 'MZXW6YTBOI',
    };
    for (final MapEntry(key: plain, value: encoded) in vectors.entries) {
      test('"$plain" ↔ "$encoded"', () {
        expect(base32Encode(utf8.encode(plain)), encoded);
        expect(utf8.decode(base32Decode(encoded)!), plain);
      });
    }

    test('decode rejects characters outside the alphabet', () {
      expect(base32Decode('MZXW1'), isNull);
      expect(base32Decode('mzxw6'), isNull);
    });
  });

  group('RecoveryKey', () {
    test('160 random bits shown as 8 groups of 4', () {
      final k = RecoveryKey.generate();
      expect(k.bytes, hasLength(20));
      expect(k.display, matches(RegExp(r'^([A-Z2-7]{4}-){7}[A-Z2-7]{4}$')));
      expect(RecoveryKey.generate().display, isNot(k.display));
    });

    test('parse(display) gives the same bytes', () {
      final k = RecoveryKey.generate();
      expect(RecoveryKey.parse(k.display)!.bytes, k.bytes);
    });

    test('parse is lenient with case, spaces, dashes and look-alike digits', () {
      final k = RecoveryKey.generate();
      final compact = k.display.replaceAll('-', '');
      expect(RecoveryKey.parse(compact.toLowerCase())!.bytes, k.bytes);
      expect(RecoveryKey.parse(' ${k.display.replaceAll('-', ' ')} ')!.bytes, k.bytes);
      final looksAlike = compact.replaceAll('O', '0').replaceAll('I', '1').replaceAll('B', '8');
      expect(RecoveryKey.parse(looksAlike)!.bytes, k.bytes);
    });

    test('parse rejects the wrong length or bad characters', () {
      final compact = RecoveryKey.generate().display.replaceAll('-', '');
      expect(RecoveryKey.parse(compact.substring(1)), isNull);
      expect(RecoveryKey.parse('${compact}A'), isNull);
      expect(RecoveryKey.parse('${compact.substring(1)}!'), isNull);
      expect(RecoveryKey.parse(''), isNull);
    });

    test('toString never shows the key, and destroy zero-fills it', () {
      final k = RecoveryKey.generate();
      expect('$k', isNot(contains(k.display.substring(0, 4))));
      k.destroy();
      expect(() => k.bytes, throwsStateError);
    });
  });
}
