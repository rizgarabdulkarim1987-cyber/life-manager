import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/core/money/money.dart';
import 'package:life_manager/features/finance/data/accounts_repository.dart';
import 'package:life_manager/features/finance/data/transactions_repository.dart';
import 'package:life_manager/features/finance/data/workspaces_repository.dart';
import 'package:life_manager/features/finance/domain/ledger.dart';

import '../../../helpers/finance_fixtures.dart';

void main() {
  late FinanceFixture f;
  late TransactionsRepository tx;
  late AccountsRepository acc;
  final d = DateTime.utc(2026, 10, 1, 9);

  setUp(() async {
    f = await financeFixture();
    tx = TransactionsRepository(f.db);
    acc = AccountsRepository(f.db);
  });
  tearDown(() => f.db.close());

  test('opening + income − expense + refund', () async {
    await f.setOpening(f.personalIqd, 100000);
    await tx.addSimple(type: 'income', accountId: f.personalIqd, amountMinor: 50000, occurredAt: d);
    await tx.addSimple(type: 'expense', accountId: f.personalIqd, amountMinor: 20000, occurredAt: d);
    await tx.addSimple(type: 'refund', accountId: f.personalIqd, amountMinor: 5000, occurredAt: d);
    expect(await acc.balanceOf(f.personalIqd), const Money(135000, 'IQD'));
  });

  test('adjustment is signed', () async {
    await tx.addSimple(type: 'adjustment', accountId: f.personalIqd, amountMinor: -700, occurredAt: d);
    expect(await acc.balanceOf(f.personalIqd), const Money(-700, 'IQD'));
  });

  test('pending income does not move the balance until marked paid', () async {
    final id = await tx.addSimple(
      type: 'income',
      accountId: f.personalIqd,
      amountMinor: 50000,
      occurredAt: d,
      paymentStatus: 'pending',
    );
    expect(await acc.balanceOf(f.personalIqd), const Money(0, 'IQD'));
    await tx.update(id, const TransactionsCompanion(paymentStatus: Value('paid')));
    expect(await acc.balanceOf(f.personalIqd), const Money(50000, 'IQD'));
  });

  test('IQD→USD exchange transfer moves both legs and is not income or expense', () async {
    final id = await tx.addTransfer(
      fromAccountId: f.personalIqd,
      toAccountId: f.personalUsd,
      amountMinor: 131000,
      toAmountMinor: 10000,
      rateE6: 1310000000,
      occurredAt: d,
    );
    expect(await acc.balanceOf(f.personalIqd), const Money(-131000, 'IQD'));
    expect(await acc.balanceOf(f.personalUsd), const Money(10000, 'USD'));
    final row = await tx.get(id);
    expect((row!.type, row.transferKind, row.rateE6), ('transfer', 'transfer', 1310000000));
  });

  test('same-currency transfer copies the amount and stores no rate', () async {
    final id = await tx.addTransfer(
      fromAccountId: f.buzzIqd,
      toAccountId: f.personalIqd,
      amountMinor: 5000,
      occurredAt: d,
    );
    final row = await tx.get(id);
    expect((row!.toAmountMinor, row.rateE6), (5000, null));
  });

  test('cross-currency transfer without rate → ArgumentError', () async {
    await expectLater(
      tx.addTransfer(fromAccountId: f.personalIqd, toAccountId: f.personalUsd, amountMinor: 131000, occurredAt: d),
      throwsArgumentError,
    );
  });

  test('transfer to the same account → ArgumentError', () async {
    await expectLater(
      tx.addTransfer(fromAccountId: f.personalIqd, toAccountId: f.personalIqd, amountMinor: 1, occurredAt: d),
      throwsArgumentError,
    );
  });

  test('workspace and currency come from the account', () async {
    final id = await tx.addSimple(type: 'expense', accountId: f.buzzUsd, amountMinor: 1250, occurredAt: d);
    final row = await tx.get(id);
    expect((row!.workspaceId, row.currencyCode), (f.buzzWs, 'USD'));
  });

  test('a category of the wrong kind is rejected', () async {
    await expectLater(
      tx.addSimple(
        type: 'expense',
        accountId: f.personalIqd,
        amountMinor: 1,
        occurredAt: d,
        categoryId: f.cat('salary'),
      ),
      throwsArgumentError,
    );
  });

  test('edit and delete keep balances', () async {
    final e = await tx.addSimple(type: 'expense', accountId: f.personalIqd, amountMinor: 20000, occurredAt: d);
    await tx.update(e, const TransactionsCompanion(amountMinor: Value(25000)));
    expect(await acc.balanceOf(f.personalIqd), const Money(-25000, 'IQD'));
    await tx.delete(e);
    expect(await acc.balanceOf(f.personalIqd), const Money(0, 'IQD'));

    final t = await tx.addTransfer(
      fromAccountId: f.buzzIqd,
      toAccountId: f.personalIqd,
      amountMinor: 9000,
      occurredAt: d,
    );
    await tx.update(t, TransactionsCompanion(accountId: Value(f.eoIqd)));
    expect(await acc.balanceOf(f.buzzIqd), const Money(0, 'IQD'));
    expect(await acc.balanceOf(f.eoIqd), const Money(-9000, 'IQD'));
    await tx.delete(t);
    expect(await acc.balanceOf(f.eoIqd), const Money(0, 'IQD'));
    expect(await acc.balanceOf(f.personalIqd), const Money(0, 'IQD'));
  });

  test('moving to another account re-derives workspace and currency', () async {
    final e = await tx.addSimple(type: 'expense', accountId: f.personalIqd, amountMinor: 20000, occurredAt: d);
    await tx.update(e, TransactionsCompanion(accountId: Value(f.personalUsd)));
    final row = await tx.get(e);
    expect((row!.currencyCode, row.workspaceId), ('USD', f.personalWs));
  });

  test('editing an allocated income throws AllocationsLocked unless clearAllocations', () async {
    final id = await tx.addSimple(type: 'income', accountId: f.personalIqd, amountMinor: 10000, occurredAt: d);
    final bucket = (await f.db.select(f.db.buckets).get()).first;
    await f.db
        .into(f.db.bucketAllocations)
        .insert(
          BucketAllocationsCompanion.insert(
            transactionId: id,
            bucketId: bucket.id,
            amountBaseMinor: 10000,
            baseCurrency: 'IQD',
            createdAt: d,
          ),
        );
    await expectLater(
      tx.update(id, const TransactionsCompanion(amountMinor: Value(9000))),
      throwsA(isA<AllocationsLocked>()),
    );
    await tx.update(id, const TransactionsCompanion(description: Value('ok')));
    await tx.update(id, const TransactionsCompanion(amountMinor: Value(9000)), clearAllocations: true);
    expect(await f.db.select(f.db.bucketAllocations).get(), isEmpty);
  });

  test('asOf balance ignores later transactions', () async {
    await tx.addSimple(type: 'income', accountId: f.personalIqd, amountMinor: 100, occurredAt: d);
    await tx.addSimple(
      type: 'income',
      accountId: f.personalIqd,
      amountMinor: 50,
      occurredAt: d.add(const Duration(days: 3)),
    );
    expect(await acc.balanceOf(f.personalIqd, asOf: d.add(const Duration(days: 1))), const Money(100, 'IQD'));
  });

  test('watchBalances matches balanceEffect for every account', () async {
    await f.setOpening(f.personalUsd, 777);
    await tx.addSimple(type: 'income', accountId: f.personalIqd, amountMinor: 500, occurredAt: d);
    await tx.addTransfer(
      fromAccountId: f.personalIqd,
      toAccountId: f.personalUsd,
      amountMinor: 131,
      toAmountMinor: 10,
      rateE6: 1310000000,
      occurredAt: d,
    );
    final balances = await acc.watchBalances().first;
    final rows = await f.db.select(f.db.transactions).get();
    for (final a in await f.db.select(f.db.accounts).get()) {
      final expected = a.openingBalanceMinor + rows.fold<int>(0, (s, t) => s + balanceEffect(t, a.id));
      expect(balances[a.id], Money(expected, a.currencyCode), reason: a.name);
    }
  });

  test('filter by text matches Arabic without diacritics', () async {
    await tx.addSimple(
      type: 'expense',
      accountId: f.personalIqd,
      amountMinor: 1,
      occurredAt: d,
      description: 'أكلة غداء',
    );
    await tx.addSimple(type: 'expense', accountId: f.personalIqd, amountMinor: 2, occurredAt: d, description: 'تكسي');
    final rows = await tx.watch(const TxFilter(text: 'اكله')).first;
    expect(rows.map((r) => r.amountMinor), [1]);
  });

  test('filter by workspace and type', () async {
    await tx.addSimple(type: 'expense', accountId: f.personalIqd, amountMinor: 1, occurredAt: d);
    await tx.addSimple(type: 'income', accountId: f.buzzIqd, amountMinor: 2, occurredAt: d);
    expect((await tx.watch(TxFilter(workspaceIds: {f.buzzWs})).first).map((r) => r.amountMinor), [2]);
    expect((await tx.watch(const TxFilter(types: {'expense'})).first).map((r) => r.amountMinor), [1]);
  });

  test('account currency is locked once it has transactions', () async {
    await tx.addSimple(type: 'expense', accountId: f.personalIqd, amountMinor: 1, occurredAt: d);
    final a = (await (f.db.select(f.db.accounts)..where((x) => x.id.equals(f.personalIqd))).getSingle());
    await expectLater(acc.update(a.copyWith(currencyCode: 'USD')), throwsStateError);
    await acc.update(a.copyWith(name: 'Renamed'));
  });

  test('workspaces: aliases round-trip and archive', () async {
    final ws = WorkspacesRepository(f.db);
    await ws.setAliases(f.buzzWs, ['بز', ' buzz ', '']);
    final all = await ws.watchAll().first;
    expect(all.firstWhere((w) => w.id == f.buzzWs).aliases, 'بز,buzz');
    expect(workspaceAliases(all.firstWhere((w) => w.id == f.buzzWs)), ['بز', 'buzz']);
    final id = await ws.create(name: 'New', iconKey: 'folder', colorArgb: 0);
    await ws.archive(id);
    expect((await ws.watchAll().first).any((w) => w.id == id), isFalse);
  });

  test('a workspace with active accounts cannot be archived', () async {
    await expectLater(WorkspacesRepository(f.db).archive(f.personalWs), throwsStateError);
  });
}
