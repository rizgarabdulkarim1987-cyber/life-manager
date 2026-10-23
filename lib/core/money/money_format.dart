import 'package:intl/intl.dart';

import 'currency.dart';
import 'money.dart';

String currencyLabel(String code, String localeCode) => switch (code) {
  'IQD' => localeCode == 'en' ? 'IQD' : 'د.ع',
  'USD' => r'$',
  _ => code,
};

final _grouped = NumberFormat.decimalPattern('en');

/// Western digits in every locale, with grouping and as many fraction digits
/// as the currency has. The minus sign is U+2212 so it never reads as a dash.
String formatMoney(Money m, {required String localeCode, bool showCode = true}) {
  final e = currencyExponent(m.currency);
  final abs = m.minor.abs();
  final unit = pow10(e).toInt();
  final whole = _grouped.format(abs ~/ unit);
  final number = e == 0 ? whole : '$whole.${(abs % unit).toString().padLeft(e, '0')}';
  final sign = m.minor < 0 ? '−' : '';
  if (!showCode) return '$sign$number';
  if (m.currency == 'USD') return '$sign\$$number';
  return '$sign$number ${currencyLabel(m.currency, localeCode)}';
}
