import '../text/digits.dart';
import 'currency.dart';
import 'rounding.dart';

final class ParsedAmount {
  const ParsedAmount(this.minor, {this.rounded = false});

  final int minor;

  /// True when the text had more fraction digits than the currency allows.
  final bool rounded;
}

final _decimal = RegExp(r'^-?\d+(\.\d+)?$');
final _grouping = RegExp('[,٬\\s  ]');

/// Parses a typed or spoken decimal into minor units. Accepts Arabic-Indic
/// digits, `,` `٬` and spaces as grouping, and `.` `٫` as the decimal point.
ParsedAmount? parseDecimalToMinor(String s, String currency) {
  final t = normalizeDigits(s.trim()).replaceAll(_grouping, '').replaceAll('٫', '.').replaceAll('−', '-');
  if (!_decimal.hasMatch(t)) return null;
  return decimalToMinor(t, currencyExponent(currency));
}

/// [t] is a plain `-?digits(.digits)?` string; rounds half-even to [exponent].
ParsedAmount decimalToMinor(String t, int exponent) {
  final negative = t.startsWith('-');
  final body = negative ? t.substring(1) : t;
  final dot = body.indexOf('.');
  final whole = dot < 0 ? body : body.substring(0, dot);
  final frac = dot < 0 ? '' : body.substring(dot + 1);
  final digits = BigInt.parse('$whole$frac');
  final scale = frac.length;
  BigInt minor;
  var rounded = false;
  if (scale <= exponent) {
    minor = digits * pow10(exponent - scale);
  } else {
    minor = divRoundHalfEven(digits, pow10(scale - exponent));
    rounded = frac.substring(exponent).replaceAll('0', '').isNotEmpty;
  }
  return ParsedAmount((negative ? -minor : minor).toInt(), rounded: rounded);
}
