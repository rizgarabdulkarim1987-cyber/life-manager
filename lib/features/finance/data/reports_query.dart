import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../domain/reports.dart';
import 'rates_repository.dart';

/// Rows and context for one report screen, loaded once.
class ReportData {
  const ReportData({required this.transactions, required this.context, required this.openingByAccount});

  final List<Transaction> transactions;
  final ReportContext context;
  final Map<int, int> openingByAccount;
}

class ReportsQuery {
  ReportsQuery(this._db, this._rates);

  final AppDatabase _db;
  final RatesRepository _rates;

  /// Loads every transaction before [to] (balance over time needs history).
  Future<ReportData> load({required DateTime to}) async {
    final txs = await (_db.select(_db.transactions)..where((t) => t.occurredAt.isSmallerThanValue(to.toUtc()))).get();
    final accounts = await _db.select(_db.accounts).get();
    final debts = await _db.select(_db.debts).get();
    final book = await _rates.book();
    return ReportData(
      transactions: txs,
      openingByAccount: {for (final a in accounts) a.id: a.openingBalanceMinor},
      context: ReportContext(
        rates: book.on,
        workspaceOfAccount: {for (final a in accounts) a.id: a.workspaceId},
        currencyOfAccount: {for (final a in accounts) a.id: a.currencyCode},
        debtDirection: {for (final d in debts) d.id: d.direction},
      ),
    );
  }
}
