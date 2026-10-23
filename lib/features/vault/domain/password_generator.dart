import 'dart:math';

import '../../../core/security/sensitive.dart';

const kGeneratorMinLength = 8;
const kGeneratorMaxLength = 64;
const kGeneratorSymbols = r'!@#$%^&*()-_=+[]{};:,.?/~';
const _lower = 'abcdefghijklmnopqrstuvwxyz';
const _upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const _digits = '0123456789';
const _lookAlikes = 'Il1O0';

class GeneratorOptions {
  const GeneratorOptions({
    this.length = 20,
    this.lower = true,
    this.upper = true,
    this.digits = true,
    this.symbols = true,
    this.avoidLookAlikes = true,
  });

  final int length;
  final bool lower, upper, digits, symbols, avoidLookAlikes;

  GeneratorOptions copyWith({
    int? length,
    bool? lower,
    bool? upper,
    bool? digits,
    bool? symbols,
    bool? avoidLookAlikes,
  }) => GeneratorOptions(
    length: length ?? this.length,
    lower: lower ?? this.lower,
    upper: upper ?? this.upper,
    digits: digits ?? this.digits,
    symbols: symbols ?? this.symbols,
    avoidLookAlikes: avoidLookAlikes ?? this.avoidLookAlikes,
  );

  bool get anyClass => lower || upper || digits || symbols;
}

List<String> _classes(GeneratorOptions o) {
  String strip(String s) => o.avoidLookAlikes ? s.split('').where((c) => !_lookAlikes.contains(c)).join() : s;
  return [
    if (o.lower) strip(_lower),
    if (o.upper) strip(_upper),
    if (o.digits) strip(_digits),
    if (o.symbols) kGeneratorSymbols,
  ];
}

/// Every character [generatePassword] can pick with these options.
String generatorPool(GeneratorOptions o) => _classes(o).join();

/// `length × log2(pool)`, the figure shown next to the generator (plan Decision 20).
/// The one-per-class rule lowers the true value slightly; that is ignored.
double estimateEntropyBits(GeneratorOptions o) {
  final pool = generatorPool(o).length;
  return pool == 0 ? 0 : o.length * log(pool) / ln2;
}

/// A random password with at least one character from each chosen class,
/// picked uniformly with `Random.secure()` and shuffled with Fisher–Yates.
Sensitive<String> generatePassword(GeneratorOptions o, {Random? random}) {
  if (o.length < kGeneratorMinLength || o.length > kGeneratorMaxLength) {
    throw ArgumentError.value(o.length, 'length', 'must be $kGeneratorMinLength–$kGeneratorMaxLength');
  }
  final classes = _classes(o);
  if (classes.isEmpty) throw ArgumentError('choose at least one character class');
  final r = random ?? Random.secure();
  final pool = classes.join();
  String pick(String s) => s[r.nextInt(s.length)];
  final chars = [for (final c in classes) pick(c), for (var i = classes.length; i < o.length; i++) pick(pool)];
  for (var i = chars.length - 1; i > 0; i--) {
    final j = r.nextInt(i + 1);
    final t = chars[i];
    chars[i] = chars[j];
    chars[j] = t;
  }
  return Sensitive(chars.join());
}
