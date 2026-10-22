import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/finance/data/accounts_repository.dart';
import 'package:life_manager/features/finance/data/transactions_repository.dart';
import 'package:life_manager/features/finance/import/csv_reader.dart';
import 'package:life_manager/features/finance/import/import_mapping.dart';
import 'package:life_manager/features/finance/import/import_service.dart';
import 'package:life_manager/features/finance/import/ui/import_wizard_screen.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/finance_ui.dart';

class _FakeFiles implements ImportFiles {
  _FakeFiles(this.name, this.bytes);

  final String name;
  final Uint8List bytes;

  @override
  Future<PickedImportFile?> pick() async => (name: name, bytes: bytes);
}

final _csv = File('test/fixtures/import/sample.csv').readAsBytesSync();

Future<ProviderContainer> _open(WidgetTester t) async {
  final c = await pumpApp(
    t,
    locale: 'en',
    overrides: [importFilesProvider.overrideWithValue(_FakeFiles('bank.csv', _csv))],
  );
  await pushRoute(t, c, '/finance/import');
  return c;
}

Future<void> _next(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('wizard-next')));
  await settle(t);
}

Future<void> _pickFile(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('import-pick')));
  await settle(t);
}

void main() {
  testWidgets('full happy path with the CSV fixture creates the batch; preview counts match planImport', (t) async {
    final c = await _open(t);
    final p = await accountId(c, 'Personal', 'IQD');
    final ws = await workspaceId(c, 'Personal');
    await _pickFile(t);
    expect(t.widget<ListTile>(find.byKey(const ValueKey('header-row-0'))).selected, isTrue);
    await _next(t); // columns, guessed from the Arabic headers
    await _next(t); // defaults
    await _next(t); // values: nothing to map
    await _next(t); // preview

    final expected = planImport(
      readCsv(_csv).single,
      0,
      const ColumnMapping(dateCol: 0, amountCol: 1, descriptionCol: 2),
      ImportDefaults(currency: 'IQD', workspaceId: ws, accountByWorkspaceCurrency: {'$ws:IQD': p}),
      const ValueMaps(),
      existingKeys: const {},
    );
    String count(String key) =>
        t.widget<Text>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Text)).first).data!;
    expect(count('count-ready'), '${expected.where((r) => r.problem == null && !r.duplicate).length}');
    expect(count('count-duplicate'), '0');
    expect(count('count-problem'), '${expected.where((r) => r.problem != null).length}');

    await t.tap(find.byKey(const ValueKey('import-commit')));
    await settle(t);
    final db = dbOf(c);
    final batch = (await t.runAsync(() => db.select(db.importBatches).getSingle()))!;
    expect((batch.fileName, batch.rowCount), ('bank.csv', 2));
    expect(find.byKey(ValueKey('actual-$p')), findsOneWidget);
  });

  testWidgets('backing out at step 4 leaves the DB unchanged', (t) async {
    final c = await _open(t);
    final db = dbOf(c);
    final txBefore = (await t.runAsync(() => db.select(db.transactions).get()))!.length;
    final catBefore = (await t.runAsync(() => db.select(db.categories).get()))!.length;
    await _pickFile(t);
    await _next(t);
    await _next(t);
    await _next(t);
    expect(find.byKey(const ValueKey('wizard-step-3')), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await t.tap(find.byKey(const ValueKey('wizard-back')));
      await settle(t);
    }
    await t.pageBack();
    await settle(t);
    expect((await t.runAsync(() => db.select(db.transactions).get()))!.length, txBefore);
    expect((await t.runAsync(() => db.select(db.categories).get()))!.length, catBefore);
    expect((await t.runAsync(() => db.select(db.importBatches).get()))!, isEmpty);
  });

  testWidgets('opening balance: an actual amount 10,000 above the computed one adds +10000', (t) async {
    final c = await _open(t);
    final p = await accountId(c, 'Personal', 'IQD');
    await _pickFile(t);
    for (var i = 0; i < 4; i++) {
      await _next(t);
    }
    await t.tap(find.byKey(const ValueKey('import-commit')));
    await settle(t);
    final db = dbOf(c);
    final computed = (await t.runAsync(() => AccountsRepository(db).balanceOf(p)))!;
    await t.enterText(find.byKey(ValueKey('actual-$p')), '${computed.minor + 10000}');
    await settle(t);
    await t.tap(find.byKey(const ValueKey('opening-save')));
    await settle(t);
    final adj = (await t.runAsync(
      () => (db.select(db.transactions)..where((x) => x.type.equals('adjustment'))).get(),
    ))!;
    expect(adj.map((a) => (a.accountId, a.amountMinor, a.description)), [(p, 10000, 'تسوية بعد الاستيراد')]);
  });

  testWidgets('undo from the batches list asks for confirmation and removes the rows', (t) async {
    final c = await pumpApp(t, locale: 'en');
    final db = dbOf(c);
    final p = await accountId(c, 'Personal', 'IQD');
    final svc = ImportService(db, TransactionsRepository(db));
    final id = await svc.commit('old.xlsx', [
      ImportRow(sourceRow: 2, type: 'expense', accountId: p, amountMinor: 500, occurredAt: DateTime(2026, 10, 1)),
      ImportRow(sourceRow: 3, type: 'expense', accountId: p, amountMinor: 700, occurredAt: DateTime(2026, 10, 2)),
    ]);
    await pushRoute(t, c, '/finance/import');
    await t.tap(find.byKey(ValueKey('undo-batch-$id')));
    await settle(t);
    expect(find.textContaining('2'), findsWidgets);
    await t.tap(find.byKey(const ValueKey('undo-confirm')));
    await settle(t);
    expect((await t.runAsync(() => db.select(db.transactions).get()))!, isEmpty);
    expect((await t.runAsync(() => db.select(db.importBatches).getSingle()))!.undoneAt, isNotNull);
  });

  testWidgets('every step fits a small phone in Arabic with the xlsx fixture', (t) async {
    t.view.physicalSize = const Size(340, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final xlsx = File('test/fixtures/import/sample.xlsx').readAsBytesSync();
    final c = await pumpApp(t, overrides: [importFilesProvider.overrideWithValue(_FakeFiles('كشف حساب.xlsx', xlsx))]);
    await pushRoute(t, c, '/finance/import');
    await _pickFile(t);
    expect(find.byKey(const ValueKey('import-sheet')), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await _next(t);
    }
    expect(find.byKey(const ValueKey('count-ready')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('import-commit')));
    await settle(t);
    expect(find.byKey(const ValueKey('wizard-step-5')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
