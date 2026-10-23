import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/core/money/conversion.dart';
import 'package:life_manager/features/finance/domain/reports.dart';

// Workspaces: 1 Personal, 2 Buzzify, 3 EO. Accounts: 11 P-IQD, 12 P-USD, 21 B-IQD, 22 B-USD, 31 E-IQD.
const ws = {11: 1, 12: 1, 21: 2, 22: 2, 31: 3, 41: 1};
const cur = {11: 'IQD', 12: 'USD', 21: 'IQD', 22: 'USD', 31: 'IQD', 41: 'EUR'};
const food = 1, transport = 2, marketing = 9, salary = 101, client = 104;

var _id = 0;
Transaction tx(
  String type,
  int account,
  int amount,
  DateTime at, {
  int? cat,
  int? to,
  int? toAmount,
  String? kind,
  String status = 'paid',
  int? debtId,
  String? leg,
}) => Transaction(
  id: ++_id,
  type: type,
  accountId: account,
  workspaceId: ws[account]!,
  amountMinor: amount,
  currencyCode: cur[account]!,
  toAccountId: to,
  toAmountMinor: toAmount,
  transferKind: kind,
  categoryId: cat,
  paymentStatus: status,
  debtId: debtId,
  debtLeg: leg,
  occurredAt: at,
  createdAt: at,
  updatedAt: at,
);

DateTime sep(int d) => DateTime.utc(2026, 9, d, 9);
DateTime oct(int d) => DateTime.utc(2026, 10, d, 9);

final rows = [
  tx('income', 11, 1000000, sep(1), cat: salary),
  tx('expense', 11, 50000, sep(2), cat: food),
  tx('expense', 12, 10000, sep(3), cat: transport),
  tx('refund', 11, 10000, sep(4), cat: food),
  tx('transfer', 11, 131000, sep(5), to: 12, toAmount: 10000, kind: 'transfer'),
  tx('transfer', 21, 500000, sep(10), to: 11, toAmount: 500000, kind: 'owner_draw'),
  tx('income', 21, 2000000, sep(15), cat: client),
  tx('expense', 21, 300000, sep(16), cat: marketing),
  tx('income', 11, 70000, sep(20), status: 'pending'),
  tx('adjustment', 11, -5000, sep(21)),
  tx('debt_payment', 11, 200000, sep(22), debtId: 1, leg: 'principal'),
  tx('income', 22, 50000, oct(1), cat: client),
  tx('expense', 11, 40000, oct(2), cat: food),
  tx('expense', 31, 60000, oct(3), cat: marketing),
  tx('debt_payment', 11, 50000, oct(5), debtId: 1, leg: 'repayment'),
];

final rate = RateValue(base: 'USD', quote: 'IQD', rateE6: 1310000000, effectiveFrom: DateTime.utc(2026, 1, 1));

ReportContext ctx() => ReportContext(
  rates: (a, b, day) => rate.covers(a, b) && !day.isBefore(rate.effectiveFrom) ? rate : null,
  workspaceOfAccount: ws,
  currencyOfAccount: cur,
  debtDirection: const {1: 'owed_by_me'},
);

ReportScope scope({Set<int>? workspaces, String currency = 'IQD', DateTime? from, DateTime? to}) => ReportScope(
  from: from ?? DateTime(2026, 9),
  to: to ?? DateTime(2026, 11),
  workspaceIds: workspaces,
  currency: currency,
);

void main() {
  test('monthly income vs expense, IQD scope', () {
    final r = incomeVsExpense(rows, scope(), Period.month, ctx());
    expect(r.data.map((p) => (p.period, p.income, p.expense, p.surplus)), [
      (DateTime(2026, 9), 3500000, 971000, 2529000),
      (DateTime(2026, 10), 655000, 100000, 555000),
    ]);
    expect(r.skippedCount, 0);
  });

  test('IQD↔USD exchange is neither income nor expense', () {
    final only = [rows[4]];
    final r = incomeVsExpense(only, scope(), Period.month, ctx());
    expect(r.data.every((p) => p.income == 0 && p.expense == 0), isTrue);
  });

  test('owner draw: Buzzify expense, Personal income; whole-scope total unchanged', () {
    final buzz = incomeVsExpense(rows, scope(workspaces: {2}), Period.month, ctx()).data.first;
    expect((buzz.income, buzz.expense), (2000000, 800000));
    final personal = incomeVsExpense(rows, scope(workspaces: {1}), Period.month, ctx()).data.first;
    expect((personal.income, personal.expense), (1500000, 171000));
    final withoutDraw = [...rows]..removeAt(5);
    final all = incomeVsExpense(rows, scope(), Period.month, ctx()).data.first;
    final allNoDraw = incomeVsExpense(withoutDraw, scope(), Period.month, ctx()).data.first;
    expect(all.surplus, allNoDraw.surplus);
  });

  test('weekly buckets start on Saturday', () {
    expect(periodStart(DateTime(2026, 10, 23), Period.week), DateTime(2026, 10, 17));
    expect(periodStart(DateTime(2026, 10, 17, 22), Period.week), DateTime(2026, 10, 17));
    expect(periodStart(DateTime(2026, 10, 16), Period.week), DateTime(2026, 10, 10));
    expect(periodStart(DateTime(2026, 10, 23, 15), Period.day), DateTime(2026, 10, 23));
    expect(periodStart(DateTime(2026, 10, 23), Period.month), DateTime(2026, 10));
  });

  test('daily periods include empty days', () {
    final r = incomeVsExpense(rows, scope(from: DateTime(2026, 9, 1), to: DateTime(2026, 9, 4)), Period.day, ctx());
    expect(r.data.map((p) => p.expense), [0, 50000, 131000]);
  });

  test('byCategory sorts descending and nets refunds', () {
    final r = byCategory(rows, scope(), ctx());
    expect(r.data, [(marketing, 360000), (transport, 131000), (food, 80000)]);
  });

  test('byWorkspace', () {
    final r = byWorkspace(rows, scope(), ctx());
    expect(r.data, [(1, 1500000, 211000), (2, 2655000, 800000), (3, 0, 60000)]);
  });

  test('cash flow counts debt principal as inflow', () {
    final p = cashFlow(rows, scope(workspaces: {1}), Period.month, ctx()).data.first;
    expect((p.inflow, p.outflow), (1710000, 186000));
    final all = cashFlow(rows, scope(), Period.month, ctx()).data.first;
    expect((all.inflow, all.outflow), (3210000, 486000));
  });

  test('balanceOverTime matches the ledger on each day', () {
    final s = balanceOverTime(
      rows,
      const {11: 0},
      {11},
      scope(from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1)),
      ctx(),
    );
    expect(s.data.points.first, (DateTime(2026, 9, 1), 1000000));
    expect(s.data.points.last, (DateTime(2026, 9, 30), 1524000));
    expect(s.data.points, hasLength(30));
  });

  test('USD rows with no rate are skipped and reported', () {
    final noRate = ReportContext(
      rates: (a, b, day) => null,
      workspaceOfAccount: ws,
      currencyOfAccount: cur,
      debtDirection: const {1: 'owed_by_me'},
    );
    final r = incomeVsExpense(rows, scope(), Period.month, noRate);
    expect(r.skippedCount, 2);
    expect(r.missingRates, {'USD'});
    expect(r.data.first.expense, 971000 - 131000);
  });

  test('USD scope converts IQD rows', () {
    final r = incomeVsExpense(rows, scope(workspaces: {3}, currency: 'USD'), Period.month, ctx());
    expect(r.data.last.expense, 4580); // 60,000 IQD at 1310 = 45.80 USD
  });
}
