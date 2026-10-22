import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/money/money.dart';
import 'package:life_manager/features/finance/data/accounts_repository.dart';
import 'package:life_manager/features/finance/data/debts_repository.dart';

import '../../../helpers/finance_fixtures.dart';

void main() {
  late FinanceFixture f;
  late DebtsRepository debts;
  late AccountsRepository acc;
  final d = DateTime.utc(2026, 10, 1);

  setUp(() async {
    f = await financeFixture();
    debts = DebtsRepository(f.db);
    acc = AccountsRepository(f.db);
  });
  tearDown(() => f.db.close());

  Future<int> borrow({String direction = 'owed_by_me', int principal = 100000, int installments = 0}) => debts.create(
    direction: direction,
    counterparty: 'Ahmed',
    workspaceId: f.personalWs,
    principalMinor: principal,
    currencyCode: 'IQD',
    startDate: d,
    recordPrincipalFromAccountId: f.personalIqd,
    installmentCount: installments,
    firstInstallmentDue: installments > 0 ? DateTime.utc(2026, 11, 1) : null,
  );

  Future<int> incomeExpenseCount() async =>
      (await f.db.select(f.db.transactions).get()).where((t) => t.type == 'income' || t.type == 'expense').length;

  test('borrowed money adds cash, repayment removes it, neither is income or expense', () async {
    final id = await borrow();
    expect(await acc.balanceOf(f.personalIqd), const Money(100000, 'IQD'));
    await debts.recordRepayment(debtId: id, accountId: f.personalIqd, amountMinor: 30000, occurredAt: d);
    expect(await acc.balanceOf(f.personalIqd), const Money(70000, 'IQD'));
    expect(await incomeExpenseCount(), 0);
    final s = (await debts.watchSummaries().first).single;
    expect((s.repaidMinor, s.remainingMinor), (30000, 70000));
  });

  test('lent money removes cash, repayment adds it', () async {
    final id = await borrow(direction: 'owed_to_me');
    expect(await acc.balanceOf(f.personalIqd), const Money(-100000, 'IQD'));
    await debts.recordRepayment(debtId: id, accountId: f.personalIqd, amountMinor: 40000, occurredAt: d);
    expect(await acc.balanceOf(f.personalIqd), const Money(-60000, 'IQD'));
  });

  test('repayment over remaining → ArgumentError; exact remaining closes the debt', () async {
    final id = await borrow();
    await expectLater(
      debts.recordRepayment(debtId: id, accountId: f.personalIqd, amountMinor: 100001, occurredAt: d),
      throwsArgumentError,
    );
    await debts.recordRepayment(debtId: id, accountId: f.personalIqd, amountMinor: 100000, occurredAt: d);
    expect(await debts.watchSummaries().first, isEmpty);
    expect((await debts.watchSummaries(includeClosed: true).first).single.debt.closedAt, isNotNull);
  });

  test('repayment from an account in another currency is rejected', () async {
    final id = await borrow();
    await expectLater(
      debts.recordRepayment(debtId: id, accountId: f.personalUsd, amountMinor: 1, occurredAt: d),
      throwsArgumentError,
    );
  });

  test('installments: schedule and next due', () async {
    final id = await borrow(principal: 90000, installments: 3);
    final inst = await debts.installments(id, today: DateTime.utc(2026, 10, 15));
    expect(inst.map((i) => i.inst.amountMinor), [30000, 30000, 30000]);
    await debts.recordRepayment(debtId: id, accountId: f.personalIqd, amountMinor: 30000, occurredAt: d);
    final s = (await debts.watchSummaries().first).single;
    expect(s.nextDue!.toUtc(), DateTime.utc(2026, 12, 1));
  });

  test('summary is overdue after the due date', () async {
    await debts.create(
      direction: 'owed_to_me',
      counterparty: 'Sara',
      workspaceId: f.personalWs,
      principalMinor: 5000,
      currencyCode: 'IQD',
      startDate: d,
      dueDate: DateTime.utc(2020, 1, 1),
    );
    final s = (await debts.watchSummaries().first).single;
    expect((s.overdue, s.nextDue!.toUtc()), (true, DateTime.utc(2020, 1, 1)));
  });
}
