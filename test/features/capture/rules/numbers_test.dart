import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/money/amount_parse.dart';
import 'package:life_manager/core/text/digits.dart';
import 'package:life_manager/features/capture/rules/numbers.dart';

/// Expected (minor units, currency); a null currency means none was said,
/// so the amount is read in the base currency (IQD).
final amounts = <String, (int, String?)>{
  'صرفت ٢٥ ألف على الغدا': (25000, null),
  'خمسة وعشرين الف دينار': (25000, 'IQD'),
  'ربع مليون': (250000, null),
  'مليون ونص': (1500000, null),
  '12.5 دولار': (1250, 'USD'),
  '١٢٫٥ \$': (1250, 'USD'),
  'ورقة': (10000, 'USD'),
  'دفترين': (2000000, 'USD'),
  '25k': (25000, null),
  'سێ هەزار دینار': (3000, 'IQD'),
  'twenty five thousand': (25000, null),
  'ثلاث تلاف': (3000, null),
  'الفين و خمسمية': (2500, null),
  'خمس مية ألف': (500000, null),
  '25,000 ع': (25000, 'IQD'),
  '100 اخضر': (10000, 'USD'),
  'نص مليون دينار': (500000, 'IQD'),
  '1.5m': (1500000, null),
};

void main() {
  test('amount phrases', () {
    for (final e in amounts.entries) {
      final found = findAmounts(normalizeForMatch(e.key));
      expect(found, isNotEmpty, reason: e.key);
      final m = found.first;
      final currency = m.currency ?? 'IQD';
      expect(m.currency, e.value.$2, reason: e.key);
      expect(parseDecimalToMinor(m.digitsText, currency)!.minor, e.value.$1, reason: e.key);
    }
  });

  test('two amounts in one phrase are found separately, in order', () {
    final found = findAmounts(normalizeForMatch('صرفت 100 دولار ب 131 الف'));
    expect(found.map((m) => (m.digitsText, m.currency)), [('100', 'USD'), ('131000', null)]);
  });

  test('no number, no amount; a weekday is not a number', () {
    expect(findAmounts(normalizeForMatch('ذكرني اتصل بالعميل')), isEmpty);
    expect(findAmounts(normalizeForMatch('يوم الاثنين')), isEmpty);
  });
}
