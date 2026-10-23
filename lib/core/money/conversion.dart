import 'currency.dart';
import 'money.dart';
import 'rounding.dart';

/// 1 [base] = rateE6 / 10⁶ [quote], valid from [effectiveFrom].
final class RateValue {
  const RateValue({required this.base, required this.quote, required this.rateE6, required this.effectiveFrom});

  final String base;
  final String quote;
  final int rateE6;
  final DateTime effectiveFrom;

  bool covers(String a, String b) => (a == base && b == quote) || (a == quote && b == base);

  @override
  bool operator ==(Object other) =>
      other is RateValue &&
      other.base == base &&
      other.quote == quote &&
      other.rateE6 == rateE6 &&
      other.effectiveFrom == effectiveFrom;

  @override
  int get hashCode => Object.hash(base, quote, rateE6, effectiveFrom);
}

final class RateMismatch implements Exception {
  const RateMismatch(this.from, this.to);
  final String from;
  final String to;

  @override
  String toString() => 'RateMismatch($from→$to)';
}

final _e6 = BigInt.from(1000000);

/// Converts with round-half-even (spec §10.2), in BigInt so nothing overflows.
Money convert(Money m, String to, RateValue r) {
  if (m.currency == to) return m;
  if (!r.covers(m.currency, to)) throw RateMismatch(m.currency, to);
  final eIn = currencyExponent(m.currency);
  final eOut = currencyExponent(to);
  final up = pow10(eOut > eIn ? eOut - eIn : 0);
  final down = pow10(eIn > eOut ? eIn - eOut : 0);
  final rate = BigInt.from(r.rateE6);
  final forward = m.currency == r.base;
  final n = (forward ? rate : _e6) * up;
  final d = (forward ? _e6 : rate) * down;
  return Money(divRoundHalfEven(BigInt.from(m.minor) * n, d).toInt(), to);
}
