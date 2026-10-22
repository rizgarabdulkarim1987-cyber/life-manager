import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/features/finance/export/csv_export.dart';

final _at = DateTime.utc(2026, 10, 5, 9, 30);

Transaction _tx(
  int id,
  String type,
  int account,
  int amount,
  String currency, {
  String? description,
  int? cat,
  int? to,
  int? toAmount,
  int? rateE6,
}) => Transaction(
  id: id,
  type: type,
  accountId: account,
  workspaceId: 1,
  amountMinor: amount,
  currencyCode: currency,
  toAccountId: to,
  toAmountMinor: toAmount,
  rateE6: rateE6,
  categoryId: cat,
  paymentStatus: 'paid',
  occurredAt: _at,
  description: description,
  createdAt: _at,
  updatedAt: _at,
);

final labels = CsvLabels(
  type: (t) => t.type,
  workspaces: const {1: 'Personal'},
  accounts: const {1: 'Cash IQD', 2: 'Cash USD'},
  accountCurrencies: const {1: 'IQD', 2: 'USD'},
  categories: const {5: 'اكل'},
);

void main() {
  test('csv amounts are exact decimals and Arabic survives', () {
    final s = transactionsCsv([
      _tx(1, 'expense', 2, 1250, 'USD', cat: 5),
      _tx(2, 'income', 1, 250000, 'IQD', description: 'راتب'),
    ], labels);
    expect(s.startsWith('\uFEFF'), isTrue);
    expect(s, contains('12.50'));
    expect(s, contains('اكل'));
    expect(s, contains('250000'));
    expect(s, isNot(contains('e+')));
    expect(
      s.substring(1).split('\r\n').first,
      'date,type,workspace,account,category,amount,currency,description,transfer_to,to_amount,rate',
    );
  });

  test('csv quotes commas, quotes and newlines; neutralises =SUM(', () {
    final s = transactionsCsv([
      _tx(1, 'expense', 1, 500, 'IQD', description: 'tea, "good"\nsecond line'),
      _tx(2, 'expense', 1, 500, 'IQD', description: '=SUM(A1:A9)'),
      _tx(3, 'transfer', 2, 10000, 'USD', to: 1, toAmount: 131000, rateE6: 1310000000),
      _tx(4, 'adjustment', 1, -700, 'IQD', description: '@cmd'),
    ], labels);
    expect(s, contains('"tea, ""good""\nsecond line"'));
    expect(s, contains(",'=SUM(A1:A9),"));
    expect(s, contains(",'@cmd,"));
    expect(s, contains(',-700,'));
    expect(s, contains('100.00,USD,,Cash IQD,131000,1310'));
  });
}
