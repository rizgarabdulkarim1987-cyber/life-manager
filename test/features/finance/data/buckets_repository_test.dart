import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/features/finance/data/buckets_repository.dart';
import 'package:life_manager/features/finance/domain/buckets_math.dart';
import 'package:life_manager/features/finance/data/rates_repository.dart';
import 'package:life_manager/features/finance/data/transactions_repository.dart';

import '../../../helpers/finance_fixtures.dart';

void main() {
  late FinanceFixture f;
  late BucketsRepository buckets;
  late TransactionsRepository tx;
  late RatesRepository rates;
  late List<Bucket> all;
  int id(String key) => all.firstWhere((b) => b.systemKey == key).id;
  final oct = DateTime(2026, 10, 1);

  setUp(() async {
    f = await financeFixture();
    rates = RatesRepository(f.db);
    buckets = BucketsRepository(f.db, rates);
    tx = TransactionsRepository(f.db);
    all = await buckets.watch().first;
  });
  tearDown(() => f.db.close());

  Future<int> income(int minor, {int? account, DateTime? at}) =>
      tx.addSimple(type: 'income', accountId: account ?? f.personalIqd, amountMinor: minor, occurredAt: at ?? oct);

  Future<int> expense(int minor, {int? account, DateTime? at, String? tag}) => tx.addSimple(
    type: 'expense',
    accountId: account ?? f.personalIqd,
    amountMinor: minor,
    occurredAt: at ?? oct,
    bucketTag: tag,
  );

  BucketStatus of(List<BucketStatus> s, String key) => s.firstWhere((x) => x.bucket.systemKey == key);

  test('setPercents must sum to 10000', () async {
    await expectLater(
      buckets.setPercents({id('expenses'): 6000, id('emergency'): 2000, id('investment'): 1000}),
      throwsArgumentError,
    );
    await buckets.setPercents({id('expenses'): 6000, id('emergency'): 3000, id('investment'): 1000});
    expect((await buckets.watch().first).map((b) => b.percentBp), [6000, 3000, 1000]);
  });

  test('USD income allocated in IQD base uses the income-date rate', () async {
    await rates.setRate(base: 'USD', quote: 'IQD', rateE6: 1310000000, effectiveFrom: DateTime.utc(2026, 1, 1));
    final t = await income(10000, account: f.personalUsd, at: DateTime.utc(2026, 2, 1));
    expect(await buckets.incomeInBase(t), 131000);
    await buckets.allocate(t, {id('expenses'): 91700, id('emergency'): 26200, id('investment'): 13100});
    final rows = await f.db.select(f.db.bucketAllocations).get();
    expect(rows.every((r) => r.rateE6Used == 1310000000 && r.baseCurrency == 'IQD'), isTrue);
  });

  test('allocate without a rate → MissingRate', () async {
    final t = await income(10000, account: f.personalUsd);
    await expectLater(buckets.allocate(t, {id('expenses'): 1}), throwsA(isA<MissingRate>()));
  });

  test('allocations above the income → ArgumentError; below is allowed', () async {
    final t = await income(1000);
    await expectLater(buckets.allocate(t, {id('expenses'): 900, id('emergency'): 200}), throwsArgumentError);
    await buckets.allocate(t, {id('expenses'): 600});
    expect(await f.db.select(f.db.bucketAllocations).get(), hasLength(1));
  });

  test('allocating twice or allocating an expense is rejected', () async {
    final t = await income(1000);
    await buckets.allocate(t, {id('expenses'): 600});
    await expectLater(buckets.allocate(t, {id('expenses'): 100}), throwsStateError);
    final e = await expense(10);
    await expectLater(buckets.allocate(e, {id('expenses'): 1}), throwsStateError);
  });

  test('percent change does not alter past allocations', () async {
    final t = await income(1000);
    await buckets.allocate(t, {id('expenses'): 700, id('emergency'): 300});
    await buckets.setPercents({id('expenses'): 5000, id('emergency'): 4000, id('investment'): 1000});
    final rows = await f.db.select(f.db.bucketAllocations).get();
    expect(rows.map((r) => r.amountBaseMinor).toList()..sort(), [300, 700]);
  });

  test('expenses bucket resets each month; emergency carries over', () async {
    final t1 = await income(100000, at: DateTime(2026, 9, 5));
    await buckets.allocate(t1, {id('expenses'): 70000, id('emergency'): 30000});
    await expense(20000, at: DateTime(2026, 9, 10));
    await expense(5000, at: DateTime(2026, 10, 2), tag: 'emergency');
    final sep = await buckets.status(DateTime(2026, 9));
    expect((of(sep, 'expenses').allocatedMinor, of(sep, 'expenses').spentMinor), (70000, 20000));
    final octS = await buckets.status(DateTime(2026, 10));
    expect((of(octS, 'expenses').allocatedMinor, of(octS, 'expenses').spentMinor), (0, 0));
    expect(of(octS, 'emergency').availableMinor, 25000);
  });

  test('business workspace expenses do not count against the Expenses bucket', () async {
    final t = await income(10000);
    await buckets.allocate(t, {id('expenses'): 10000});
    await expense(4000, account: f.buzzIqd);
    await expense(1000);
    expect(of(await buckets.status(oct), 'expenses').spentMinor, 1000);
  });

  test('refunds reduce Expenses spending', () async {
    await expense(4000);
    await tx.addSimple(type: 'refund', accountId: f.personalIqd, amountMinor: 1500, occurredAt: oct);
    expect(of(await buckets.status(oct), 'expenses').spentMinor, 2500);
  });

  test('deleting income removes its allocations', () async {
    final t = await income(1000);
    await buckets.allocate(t, {id('expenses'): 700});
    await tx.delete(t);
    expect(await f.db.select(f.db.bucketAllocations).get(), isEmpty);
    expect(of(await buckets.status(oct), 'expenses').allocatedMinor, 0);
  });

  test('unallocatedIncomeCount counts this month income without allocations', () async {
    final a = await income(1000);
    await income(2000);
    await income(3000, at: DateTime(2026, 9, 1));
    await buckets.allocate(a, {id('expenses'): 1});
    expect(await buckets.unallocatedIncomeCount(oct), 1);
  });

  test('targets', () async {
    await buckets.setTarget(id('emergency'), 500000);
    expect((await buckets.watch().first).firstWhere((b) => b.systemKey == 'emergency').targetMinor, 500000);
  });

  test('deleting an allocated income and restoring it brings the allocations back', () async {
    final t = await income(100000);
    await buckets.allocate(t, {id('expenses'): 60000, id('emergency'): 30000, id('investment'): 10000});
    final row = await (f.db.select(f.db.transactions)..where((x) => x.id.equals(t))).getSingle();
    final allocs = await tx.delete(t);
    expect(allocs, hasLength(3));
    expect(await f.db.select(f.db.bucketAllocations).get(), isEmpty);
    await tx.restore(row, allocs);
    expect(await f.db.select(f.db.bucketAllocations).get(), hasLength(3));
  });

  test('split sums exactly to total; the remainder goes to the largest bucket', () async {
    await buckets.setPercents({id('expenses'): 3333, id('emergency'): 3333, id('investment'): 3334});
    all = await buckets.watch().first;
    final split = splitByPercents(100001, all);
    expect(split.values.fold<int>(0, (s, v) => s + v), 100001);
    expect(split[id('investment')], 33341, reason: '33340 plus the 1 left over');
    expect(splitByPercents(0, all).values.every((v) => v == 0), isTrue);
  });
}
