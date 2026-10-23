import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../domain/installments.dart';
import 'transactions_repository.dart';

DateTime _today() {
  final n = DateTime.now().toUtc();
  return DateTime.utc(n.year, n.month, n.day);
}

/// Debts and installments. Principal and repayments are `debt_payment`
/// transactions: they move cash but are never income or expense.
class DebtsRepository {
  DebtsRepository(this._db);

  final AppDatabase _db;

  TransactionsRepository get _tx => TransactionsRepository(_db);

  Future<int> _repaid(int debtId) async {
    final row = await _db
        .customSelect(
          "SELECT COALESCE(SUM(amount_minor), 0) AS s FROM transactions WHERE debt_id = ?1 AND debt_leg = 'repayment'",
          variables: [Variable<int>(debtId)],
          readsFrom: {_db.transactions},
        )
        .getSingle();
    return row.read<int>('s');
  }

  Future<DebtSummary> _summary(Debt d, DateTime today) async {
    final repaid = await _repaid(d.id);
    final remaining = d.principalMinor - repaid;
    final schedule = await (_db.select(_db.installments)..where((i) => i.debtId.equals(d.id))).get();
    DateTime? next;
    if (remaining > 0) {
      if (schedule.isEmpty) {
        next = d.dueDate;
      } else {
        final states = applyPayments(schedule, repaid, today);
        next = states.where((s) => !s.isPaid).map((s) => s.inst.dueDate).firstOrNull;
      }
    }
    return DebtSummary(
      debt: d,
      repaidMinor: repaid,
      remainingMinor: remaining,
      nextDue: next,
      overdue: next != null && next.isBefore(today),
    );
  }

  Stream<List<DebtSummary>> watchSummaries({bool includeClosed = false}) {
    final q = _db.select(_db.debts)..orderBy([(d) => OrderingTerm.asc(d.createdAt)]);
    if (!includeClosed) q.where((d) => d.closedAt.isNull());
    // Re-read when repayments change, not only the debts table.
    return _db
        .customSelect('SELECT COUNT(*) FROM transactions', readsFrom: {_db.transactions, _db.debts, _db.installments})
        .watch()
        .asyncMap((_) async {
          final today = _today();
          final rows = await q.get();
          return [for (final d in rows) await _summary(d, today)];
        });
  }

  Future<int> create({
    required String direction,
    required String counterparty,
    required int workspaceId,
    required int principalMinor,
    required String currencyCode,
    required DateTime startDate,
    DateTime? dueDate,
    String? notes,
    int? recordPrincipalFromAccountId,
    int installmentCount = 0,
    DateTime? firstInstallmentDue,
  }) => _db.transaction(() async {
    final schedule = installmentCount > 0
        ? equalInstallments(
            totalMinor: principalMinor,
            count: installmentCount,
            firstDue: firstInstallmentDue ?? (throw ArgumentError('first installment date needed')),
          )
        : const <(DateTime, int)>[];
    final id = await _db
        .into(_db.debts)
        .insert(
          DebtsCompanion.insert(
            direction: direction,
            counterparty: counterparty.trim(),
            workspaceId: workspaceId,
            principalMinor: principalMinor,
            currencyCode: currencyCode,
            startDate: startDate,
            dueDate: Value(dueDate ?? (schedule.isEmpty ? null : schedule.last.$1)),
            notes: Value(notes),
            createdAt: DateTime.now().toUtc(),
          ),
        );
    for (var i = 0; i < schedule.length; i++) {
      await _db
          .into(_db.installments)
          .insert(
            InstallmentsCompanion.insert(debtId: id, seq: i, dueDate: schedule[i].$1, amountMinor: schedule[i].$2),
          );
    }
    if (recordPrincipalFromAccountId != null) {
      await _movement(id, recordPrincipalFromAccountId, principalMinor, startDate, 'principal', currencyCode);
    }
    return id;
  });

  Future<int> _movement(int debtId, int accountId, int amountMinor, DateTime at, String leg, String currency) async {
    final account = await (_db.select(_db.accounts)..where((a) => a.id.equals(accountId))).getSingle();
    if (account.currencyCode != currency) throw ArgumentError('the account currency must match the debt');
    final now = DateTime.now().toUtc();
    return _tx.insertRaw(
      TransactionsCompanion.insert(
        type: 'debt_payment',
        accountId: accountId,
        workspaceId: 0,
        amountMinor: amountMinor,
        currencyCode: '',
        occurredAt: at,
        debtId: Value(debtId),
        debtLeg: Value(leg),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<int> recordRepayment({
    required int debtId,
    required int accountId,
    required int amountMinor,
    required DateTime occurredAt,
  }) => _db.transaction(() async {
    final d = await (_db.select(_db.debts)..where((x) => x.id.equals(debtId))).getSingle();
    final remaining = d.principalMinor - await _repaid(debtId);
    if (amountMinor <= 0 || amountMinor > remaining) {
      throw ArgumentError.value(amountMinor, 'amountMinor', 'must be within the remaining amount');
    }
    final id = await _movement(debtId, accountId, amountMinor, occurredAt, 'repayment', d.currencyCode);
    if (amountMinor == remaining) await close(debtId);
    return id;
  });

  Future<void> close(int debtId) => (_db.update(
    _db.debts,
  )..where((d) => d.id.equals(debtId))).write(DebtsCompanion(closedAt: Value(DateTime.now().toUtc())));

  Future<List<InstallmentState>> installments(int debtId, {DateTime? today}) async {
    final schedule = await (_db.select(_db.installments)..where((i) => i.debtId.equals(debtId))).get();
    return applyPayments(schedule, await _repaid(debtId), today ?? _today());
  }

  /// Principal and repayment rows for one debt, newest first.
  Stream<List<Transaction>> watchPayments(int debtId) =>
      (_db.select(_db.transactions)
            ..where((t) => t.debtId.equals(debtId))
            ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))
          .watch();
}
