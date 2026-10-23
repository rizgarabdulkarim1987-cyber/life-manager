import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/vault/domain/password_generator.dart';

void main() {
  test('length honoured 8..64; out of range throws', () {
    for (final n in [8, 20, 64]) {
      expect(generatePassword(GeneratorOptions(length: n)).value.length, n);
    }
    expect(() => generatePassword(const GeneratorOptions(length: 7)), throwsArgumentError);
    expect(() => generatePassword(const GeneratorOptions(length: 65)), throwsArgumentError);
  });

  test('no class chosen throws', () {
    const none = GeneratorOptions(lower: false, upper: false, digits: false, symbols: false);
    expect(none.anyClass, isFalse);
    expect(() => generatePassword(none), throwsArgumentError);
  });

  test('each chosen class appears at least once over 1000 runs', () {
    final r = Random(1);
    for (var i = 0; i < 1000; i++) {
      final pw = generatePassword(const GeneratorOptions(length: 8), random: r).value;
      expect(pw, matches(RegExp('[a-z]')));
      expect(pw, matches(RegExp('[A-Z]')));
      expect(pw, matches(RegExp('[0-9]')));
      expect(pw, matches(RegExp(r'[^a-zA-Z0-9]')));
    }
  });

  test('a class switched off never appears', () {
    final r = Random(2);
    for (var i = 0; i < 200; i++) {
      final pw = generatePassword(const GeneratorOptions(symbols: false, upper: false), random: r).value;
      expect(pw, matches(RegExp(r'^[a-z0-9]+$')));
    }
  });

  test('avoidLookAlikes never yields I l 1 O 0', () {
    final r = Random(3);
    final avoided = StringBuffer();
    final allowed = StringBuffer();
    for (var i = 0; i < 500; i++) {
      avoided.write(generatePassword(const GeneratorOptions(length: 64), random: r).value);
      allowed.write(generatePassword(const GeneratorOptions(length: 64, avoidLookAlikes: false), random: r).value);
    }
    expect(avoided.toString(), isNot(matches(RegExp('[Il1O0]'))));
    expect(allowed.toString(), matches(RegExp('[Il1O0]')));
  });

  test('digits only: rough uniformity over 20000 chars (each digit 8–12 %)', () {
    final r = Random(4);
    const o = GeneratorOptions(length: 50, lower: false, upper: false, symbols: false, avoidLookAlikes: false);
    final counts = <String, int>{};
    var total = 0;
    while (total < 20000) {
      for (final c in generatePassword(o, random: r).value.split('')) {
        counts[c] = (counts[c] ?? 0) + 1;
        total++;
      }
    }
    expect(counts.keys.toSet(), '0123456789'.split('').toSet());
    for (final n in counts.values) {
      expect(n / total, inInclusiveRange(0.08, 0.12));
    }
  });

  test('entropy: 20 chars from 4 classes without look-alikes is 20·log2(pool)', () {
    const o = GeneratorOptions();
    final pool = generatorPool(o).length;
    expect(pool, 26 + 26 + 10 + kGeneratorSymbols.length - 5);
    expect(estimateEntropyBits(o), closeTo(20 * log(pool) / ln2, 1e-9));
  });

  test('toString of the result is redacted', () {
    final pw = generatePassword(const GeneratorOptions());
    expect(pw.toString(), isNot(contains(pw.value)));
    expect('$pw', '‹redacted›');
  });
}
