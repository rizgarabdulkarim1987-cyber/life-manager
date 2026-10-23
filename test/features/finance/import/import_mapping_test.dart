import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/finance/import/import_mapping.dart';
import 'package:life_manager/features/finance/import/sheet.dart';

Cell _c(String s) => s.isEmpty ? const EmptyCell() : TextCell(s);
Sheet _sheet(List<List<String>> rows) => Sheet('', [
  for (final r in rows) [for (final v in r) _c(v)],
]);

const _defaults = ImportDefaults(
  currency: 'IQD',
  workspaceId: 1,
  accountByWorkspaceCurrency: {'1:IQD': 11, '1:USD': 12, '2:IQD': 21},
);
const _maps = ValueMaps();

void main() {
  test('split columns: income column 500000 and expense column empty → income', () {
    final rows = planImport(
      _sheet([
        ['date', 'in', 'out', 'note'],
        ['1/1/2025', '500000', '', 'salary'],
        ['2/1/2025', '', '20,000', 'lunch'],
      ]),
      0,
      const ColumnMapping(
        dateCol: 0,
        amountMode: AmountMode.splitColumns,
        incomeCol: 1,
        expenseCol: 2,
        descriptionCol: 3,
      ),
      _defaults,
      _maps,
      existingKeys: const {},
    );
    expect(rows.map((r) => (r.type, r.amountMinor, r.accountId, r.problem)), [
      ('income', 500000, 11, null),
      ('expense', 20000, 11, null),
    ]);
    expect(rows.first.occurredAt, DateTime(2025, 1, 1));
    expect(rows.first.sourceRow, 2);
  });

  test('signed mode: −20000 → expense 20000', () {
    final rows = planImport(
      _sheet([
        ['date', 'amount'],
        ['1/1/2025', '−20000'],
        ['1/1/2025', '(5,000)'],
        ['1/1/2025', '7000'],
      ]),
      0,
      const ColumnMapping(dateCol: 0, amountCol: 1),
      _defaults,
      _maps,
      existingKeys: const {},
    );
    expect(rows.map((r) => (r.type, r.amountMinor)), [('expense', 20000), ('expense', 5000), ('income', 7000)]);
  });

  test('row with unreadable amount gets problem "amount"', () {
    final rows = planImport(
      _sheet([
        ['date', 'amount'],
        ['1/1/2025', 'lots'],
        ['someday', '100'],
        ['', ''],
      ]),
      0,
      const ColumnMapping(dateCol: 0, amountCol: 1),
      _defaults,
      _maps,
      existingKeys: const {},
    );
    expect(rows.map((r) => r.problem), ['amount', 'date']);
  });

  test('type column uses the value map; unmapped values are a problem, skip drops the row', () {
    final rows = planImport(
      _sheet([
        ['date', 'amount', 'kind', 'ws', 'cat', 'cur'],
        ['1/1/2025', '100', 'دخل', 'Buzz', 'اكل', 'iqd'],
        ['1/1/2025', '100', 'صرف', '', '', 'USD'],
        ['1/1/2025', '100', 'نقل', '', '', ''],
        ['1/1/2025', '100', '???', '', '', ''],
      ]),
      0,
      const ColumnMapping(
        dateCol: 0,
        amountMode: AmountMode.typeColumn,
        amountCol: 1,
        typeCol: 2,
        workspaceCol: 3,
        categoryCol: 4,
        currencyCol: 5,
      ),
      _defaults,
      const ValueMaps(
        typeValues: {'دخل': 'income', 'صرف': 'expense', 'نقل': 'skip'},
        workspaces: {'Buzz': 2},
        categories: {'اكل': 7},
      ),
      existingKeys: const {},
    );
    expect(rows.map((r) => (r.type, r.accountId, r.categoryId, r.amountMinor, r.problem)), [
      ('income', 21, 7, 100, null),
      ('expense', 12, null, 10000, null),
      ('', 0, null, 0, 'type'),
    ]);
  });

  test('same row twice in one file → second flagged duplicate', () {
    final rows = planImport(
      _sheet([
        ['date', 'amount', 'note'],
        ['1/1/2025', '-500', 'Tea'],
        ['1/1/2025', '-500', ' tea '],
        ['1/1/2025', '-500', 'coffee'],
      ]),
      0,
      const ColumnMapping(dateCol: 0, amountCol: 1, descriptionCol: 2),
      _defaults,
      _maps,
      existingKeys: const {},
    );
    expect(rows.map((r) => r.duplicate), [false, true, false]);
  });

  test('a key already in the database flags the row', () {
    final rows = planImport(
      _sheet([
        ['date', 'amount', 'note'],
        ['1/1/2025', '-500', 'Tea'],
      ]),
      0,
      const ColumnMapping(dateCol: 0, amountCol: 1, descriptionCol: 2),
      _defaults,
      _maps,
      existingKeys: {importKey(DateTime(2025, 1, 1), 11, 500, 'tea')},
    );
    expect(rows.single.duplicate, isTrue);
  });
}
