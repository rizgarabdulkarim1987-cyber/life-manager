import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/money/money.dart';
import 'package:life_manager/features/finance/data/rates_repository.dart';

import '../../../helpers/finance_fixtures.dart';

void main() {
  late FinanceFixture f;
  late RatesRepository rates;
  setUp(() async {
    f = await financeFixture();
    rates = RatesRepository(f.db);
  });
  tearDown(() => f.db.close());

  test('rateOn picks latest effective ≤ day and works in reverse direction', () async {
    await rates.setRate(base: 'USD', quote: 'IQD', rateE6: 1300000000, effectiveFrom: DateTime.utc(2026, 1, 1));
    await rates.setRate(base: 'USD', quote: 'IQD', rateE6: 1310000000, effectiveFrom: DateTime.utc(2026, 6, 1));
    expect((await rates.rateOn('IQD', 'USD', DateTime.utc(2026, 3, 1)))!.rateE6, 1300000000);
    expect((await rates.rateOn('USD', 'IQD', DateTime.utc(2026, 6, 1)))!.rateE6, 1310000000);
    expect(await rates.rateOn('USD', 'IQD', DateTime.utc(2025, 12, 31)), isNull);
    expect(await rates.rateOn('EUR', 'IQD', DateTime.utc(2026, 7, 1)), isNull);
  });

  test('setting a rate for the same day replaces it', () async {
    await rates.setRate(base: 'USD', quote: 'IQD', rateE6: 1300000000, effectiveFrom: DateTime.utc(2026, 1, 1));
    await rates.setRate(base: 'USD', quote: 'IQD', rateE6: 1320000000, effectiveFrom: DateTime.utc(2026, 1, 1));
    expect(await rates.watchHistory('USD', 'IQD').first, hasLength(1));
    expect((await rates.rateOn('USD', 'IQD', DateTime.utc(2026, 2, 1)))!.rateE6, 1320000000);
  });

  test('history is newest first', () async {
    await rates.setRate(base: 'USD', quote: 'IQD', rateE6: 1300000000, effectiveFrom: DateTime.utc(2026, 1, 1));
    await rates.setRate(base: 'USD', quote: 'IQD', rateE6: 1310000000, effectiveFrom: DateTime.utc(2026, 6, 1));
    expect((await rates.watchHistory('IQD', 'USD').first).map((r) => r.rateE6), [1310000000, 1300000000]);
  });

  test('consolidate without a rate hides the total but keeps subtotals', () async {
    final c = await rates.consolidate(
      {1: const Money(500, 'IQD'), 2: const Money(1000, 'USD'), 3: const Money(250, 'IQD')},
      base: 'IQD',
      day: DateTime.utc(2026, 10, 1),
    );
    expect(c.total, isNull);
    expect(c.subtotals, {'IQD': const Money(750, 'IQD'), 'USD': const Money(1000, 'USD')});
    expect(c.missingRates, ['USD']);
  });

  test('consolidate with a rate shows every converted line', () async {
    await rates.setRate(base: 'USD', quote: 'IQD', rateE6: 1310000000, effectiveFrom: DateTime.utc(2026, 1, 1));
    final c = await rates.consolidate(
      {1: const Money(500, 'IQD'), 2: const Money(10000, 'USD')},
      base: 'IQD',
      day: DateTime.utc(2026, 10, 1),
    );
    expect(c.total, const Money(131500, 'IQD'));
    final usd = c.lines.firstWhere((l) => l.original.currency == 'USD');
    expect((usd.converted, usd.rate!.rateE6), (const Money(131000, 'IQD'), 1310000000));
    expect(c.lines.firstWhere((l) => l.original.currency == 'IQD').rate, isNull);
  });

  test('parseRateE6', () {
    expect(parseRateE6('١٣١٠'), 1310000000);
    expect(parseRateE6('1,312.5'), 1312500000);
    expect(parseRateE6('0.000001'), 1);
    expect(parseRateE6('0'), isNull);
    expect(parseRateE6('-3'), isNull);
    expect(parseRateE6('abc'), isNull);
  });
}
