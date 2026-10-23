import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/money/money.dart';
import 'package:life_manager/features/finance/data/accounts_repository.dart';
import 'package:life_manager/features/finance/data/transactions_repository.dart';
import 'package:life_manager/features/finance/import/import_mapping.dart';
import 'package:life_manager/features/finance/import/import_service.dart';
import 'package:life_manager/features/finance/import/sheet.dart';

import '../../../helpers/finance_fixtures.dart';

void main() {
  late FinanceFixture f;
  late ImportService svc;

  setUp(() async {
    f = await financeFixture();
    svc = ImportService(f.db, TransactionsRepository(f.db));
  });
  tearDown(() => f.db.close());

  const sheet = Sheet('', [
    [TextCell('date'), TextCell('amount'), TextCell('note')],
    [TextCell('1/10/2026'), TextCell('500000'), TextCell('salary')],
    [TextCell('2/10/2026'), TextCell('-20000'), TextCell('lunch')],
    [TextCell('3/10/2026'), TextCell('x'), TextCell('broken')],
  ]);

  Future<List<ImportRow>> plan() async => planImport(
    sheet,
    0,
    const ColumnMapping(dateCol: 0, amountCol: 1, descriptionCol: 2),
    ImportDefaults(
      currency: 'IQD',
      workspaceId: f.personalWs,
      accountByWorkspaceCurrency: {'${f.personalWs}:IQD': f.personalIqd},
    ),
    const ValueMaps(),
    existingKeys: await svc.existingKeys(DateTime(2026, 10, 1), DateTime(2026, 10, 4)),
  );

  test('commit stores the readable rows in one batch', () async {
    final id = await svc.commit('bank.xlsx', await plan());
    final batch = (await svc.watchBatches().first).single;
    expect((batch.id, batch.fileName, batch.rowCount), (id, 'bank.xlsx', 2));
    final txs = await f.db.select(f.db.transactions).get();
    expect(txs.map((t) => (t.type, t.amountMinor, t.importBatchId)), [('income', 500000, id), ('expense', 20000, id)]);
  });

  test('re-importing the same file flags every row duplicate', () async {
    await svc.commit('bank.xlsx', await plan());
    final again = await plan();
    expect(again.where((r) => r.problem == null).map((r) => r.duplicate), [true, true]);
    final id = await svc.commit('bank.xlsx', again);
    expect((await (f.db.select(f.db.importBatches)..where((b) => b.id.equals(id))).getSingle()).rowCount, 0);
    expect((await f.db.select(f.db.transactions).get()).length, 2);
  });

  test('undo removes every transaction of the batch and restores balances', () async {
    final acc = AccountsRepository(f.db);
    await TransactionsRepository(f.db)
        .addSimple(type: 'expense', accountId: f.personalIqd, amountMinor: 1000, occurredAt: DateTime.utc(2026, 9, 1));
    final before = await acc.balanceOf(f.personalIqd);
    final id = await svc.commit('bank.xlsx', await plan());
    expect(await acc.balanceOf(f.personalIqd), Money(before.minor + 480000, 'IQD'));
    await svc.undo(id);
    expect(await acc.balanceOf(f.personalIqd), before);
    expect((await f.db.select(f.db.transactions).get()).length, 1);
    expect((await svc.watchBatches().first).single.undoneAt, isNotNull);
  });
}
