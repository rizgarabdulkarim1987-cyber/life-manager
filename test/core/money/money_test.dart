import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/money/amount_parse.dart';
import 'package:life_manager/core/money/conversion.dart';
import 'package:life_manager/core/money/currency.dart';
import 'package:life_manager/core/money/money.dart';
import 'package:life_manager/core/money/money_format.dart';
import 'package:life_manager/core/money/rounding.dart';

void main() {
  final d0 = DateTime.utc(2026, 1, 1);
  final r1310 = RateValue(base: 'USD', quote: 'IQD', rateE6: 1310000000, effectiveFrom: d0);

  group('currency', () {
    test('exponents', () {
      expect(currencyExponent('IQD'), 0);
      expect(currencyExponent('USD'), 2);
      expect(currencyExponent('KWD'), 3);
      expect(currencyExponent('XYZ'), 2);
    });
  });

  group('rounding', () {
    test('half-even', () {
      BigInt r(int n, int d) => divRoundHalfEven(BigInt.from(n), BigInt.from(d));
      expect([r(5, 10), r(15, 10), r(25, 10), r(26, 10), r(-15, 10), r(-25, 10), r(7, 1)].map((b) => b.toInt()),
          [0, 2, 2, 3, -2, -2, 7]);
    });
  });

  group('Money', () {
    test('arithmetic and equality', () {
      expect(const Money(5, 'IQD') + const Money(7, 'IQD'), const Money(12, 'IQD'));
      expect(const Money(5, 'IQD') - const Money(7, 'IQD'), const Money(-2, 'IQD'));
      expect(-const Money(5, 'IQD'), const Money(-5, 'IQD'));
      expect(const Money(0, 'USD').isZero, isTrue);
    });
    test('mixing currencies throws', () {
      expect(() => const Money(1, 'IQD') + const Money(1, 'USD'), throwsA(isA<CurrencyMismatch>()));
    });
  });

  group('convert', () {
    test('USD→IQD', () => expect(convert(const Money(10000, 'USD'), 'IQD', r1310), const Money(131000, 'IQD')));
    test('IQD→USD', () => expect(convert(const Money(131000, 'IQD'), 'USD', r1310), const Money(10000, 'USD')));
    test('same currency is identity', () => expect(convert(const Money(3, 'IQD'), 'IQD', r1310), const Money(3, 'IQD')));
    test('half-even at rate 1000', () {
      final r = RateValue(base: 'USD', quote: 'IQD', rateE6: 1000000000, effectiveFrom: d0);
      expect([5, 15, 25].map((i) => convert(Money(i, 'IQD'), 'USD', r).minor), [0, 2, 2]);
    });
    test('wrong pair throws', () {
      expect(() => convert(const Money(1, 'EUR'), 'IQD', r1310), throwsA(isA<RateMismatch>()));
    });
    test('huge amounts do not overflow', () {
      expect(convert(const Money(999999999999, 'USD'), 'IQD', r1310).minor, 13099999999987);
    });
  });

  group('parseDecimalToMinor', () {
    test('parse', () {
      expect(parseDecimalToMinor('١٢٬٥٠٠', 'IQD')!.minor, 12500);
      expect(parseDecimalToMinor('12.5', 'USD')!.minor, 1250);
      expect(parseDecimalToMinor('١٢٫٥', 'USD')!.minor, 1250);
      expect(parseDecimalToMinor('1,250,000', 'IQD')!.minor, 1250000);
      expect(parseDecimalToMinor('1 250 000', 'IQD')!.minor, 1250000);
      final r = parseDecimalToMinor('10.005', 'USD')!;
      expect((r.minor, r.rounded), (1000, true));
      expect(parseDecimalToMinor('10.015', 'USD')!.minor, 1002);
      expect(parseDecimalToMinor('12.5', 'USD')!.rounded, isFalse);
      expect(parseDecimalToMinor('12a', 'IQD'), isNull);
      expect(parseDecimalToMinor('', 'IQD'), isNull);
      expect(parseDecimalToMinor('1.2.3', 'IQD'), isNull);
      expect(parseDecimalToMinor('-5', 'IQD')!.minor, -5);
    });
  });

  group('formatMoney', () {
    test('format', () {
      expect(formatMoney(const Money(1250000, 'IQD'), localeCode: 'en'), '1,250,000 IQD');
      expect(formatMoney(const Money(1250000, 'IQD'), localeCode: 'ar'), '1,250,000 د.ع');
      expect(formatMoney(const Money(1250, 'USD'), localeCode: 'ar'), contains('12.50'));
      expect(formatMoney(const Money(-1250, 'USD'), localeCode: 'en'), '−\$12.50');
      expect(formatMoney(const Money(5, 'IQD'), localeCode: 'en', showCode: false), '5');
    });
  });
}
