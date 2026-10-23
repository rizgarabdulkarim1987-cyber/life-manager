import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/money/money.dart';

/// Mirrors `balanceEffect` (domain/ledger.dart) in one query for all accounts.
const _balanceSql = '''
SELECT a.id AS id, a.currency_code AS currency,
  a.opening_balance_minor
  + COALESCE((
      SELECT SUM(CASE t.type
        WHEN 'income' THEN CASE WHEN t.payment_status = 'paid' THEN t.amount_minor ELSE 0 END
        WHEN 'expense' THEN -t.amount_minor
        WHEN 'refund' THEN t.amount_minor
        WHEN 'adjustment' THEN t.amount_minor
        WHEN 'transfer' THEN -t.amount_minor
        WHEN 'debt_payment' THEN CASE WHEN (d.direction = 'owed_by_me') = (t.debt_leg = 'principal')
          THEN t.amount_minor ELSE -t.amount_minor END
        ELSE 0 END)
      FROM transactions t LEFT JOIN debts d ON d.id = t.debt_id
      WHERE t.account_id = a.id AND (?1 IS NULL OR t.occurred_at <= ?1)), 0)
  + COALESCE((
      SELECT SUM(t.to_amount_minor) FROM transactions t
      WHERE t.type = 'transfer' AND t.to_account_id = a.id AND (?1 IS NULL OR t.occurred_at <= ?1)), 0)
  AS balance
FROM accounts a
''';

class AccountsRepository {
  AccountsRepository(this._db);

  final AppDatabase _db;

  Stream<List<Account>> watchAll({bool includeArchived = false}) {
    final q = _db.select(_db.accounts)..orderBy([(a) => OrderingTerm.asc(a.sortOrder), (a) => OrderingTerm.asc(a.id)]);
    if (!includeArchived) q.where((a) => a.isArchived.equals(false));
    return q.watch();
  }

  Future<Account> get(int id) => (_db.select(_db.accounts)..where((a) => a.id.equals(id))).getSingle();

  Future<int> create({
    required int workspaceId,
    required String name,
    required String kind,
    required String currencyCode,
    int openingBalanceMinor = 0,
  }) async {
    final last =
        await (_db.select(_db.accounts)
              ..orderBy([(a) => OrderingTerm.desc(a.sortOrder)])
              ..limit(1))
            .getSingleOrNull();
    return _db
        .into(_db.accounts)
        .insert(
          AccountsCompanion.insert(
            workspaceId: workspaceId,
            name: name.trim(),
            kind: kind,
            currencyCode: currencyCode,
            openingBalanceMinor: Value(openingBalanceMinor),
            sortOrder: (last?.sortOrder ?? -1) + 1,
            createdAt: DateTime.now().toUtc(),
          ),
        );
  }

  /// The currency (and workspace) are locked once the account has
  /// transactions, because stored amounts are in its minor units.
  Future<void> update(Account a) => _db.transaction(() async {
    final old = await get(a.id);
    if (old.currencyCode != a.currencyCode || old.workspaceId != a.workspaceId) {
      final used =
          await (_db.select(_db.transactions)
                ..where((t) => t.accountId.equals(a.id) | t.toAccountId.equals(a.id))
                ..limit(1))
              .get();
      if (used.isNotEmpty) throw StateError('account currency is locked');
    }
    await _db.update(_db.accounts).replace(a);
  });

  Future<void> archive(int id) =>
      (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(const AccountsCompanion(isArchived: Value(true)));

  Selectable<(int, Money)> _balances(DateTime? asOf) => _db
      .customSelect(
        _balanceSql,
        variables: [Variable<DateTime>(asOf)],
        readsFrom: {_db.accounts, _db.transactions, _db.debts},
      )
      .map((r) => (r.read<int>('id'), Money(r.read<int>('balance'), r.read<String>('currency'))));

  Future<Money> balanceOf(int accountId, {DateTime? asOf}) async =>
      (await _balances(asOf).get()).firstWhere((b) => b.$1 == accountId).$2;

  Stream<Map<int, Money>> watchBalances() => _balances(null).watch().map((rows) => {for (final (id, m) in rows) id: m});
}
