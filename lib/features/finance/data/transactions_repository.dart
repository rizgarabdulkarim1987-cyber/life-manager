import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/text/digits.dart';

const kSimpleTypes = {'income', 'expense', 'refund', 'adjustment'};

/// Changing the money of an income that already has bucket allocations would
/// silently break them; the UI asks the owner to clear them first.
final class AllocationsLocked implements Exception {
  const AllocationsLocked();
}

class TxFilter {
  const TxFilter({this.from, this.to, this.accountIds, this.workspaceIds, this.categoryIds, this.types, this.text});

  final DateTime? from;
  final DateTime? to;
  final Set<int>? accountIds;
  final Set<int>? workspaceIds;
  final Set<int>? categoryIds;
  final Set<String>? types;

  /// Matches the description, ignoring diacritics and letter variants.
  final String? text;
}

class TransactionsRepository {
  TransactionsRepository(this._db);

  final AppDatabase _db;

  Future<Transaction?> get(int id) => (_db.select(_db.transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> addSimple({
    required String type,
    required int accountId,
    required int amountMinor,
    required DateTime occurredAt,
    int? categoryId,
    String? description,
    String? bucketTag,
    String paymentStatus = 'paid',
    int? importBatchId,
    int? captureId,
  }) {
    if (!kSimpleTypes.contains(type)) throw ArgumentError.value(type, 'type');
    final now = DateTime.now().toUtc();
    return _insert(
      TransactionsCompanion.insert(
        type: type,
        accountId: accountId,
        workspaceId: 0,
        amountMinor: amountMinor,
        currencyCode: '',
        occurredAt: occurredAt,
        categoryId: Value(categoryId),
        description: Value(_clean(description)),
        bucketTag: Value(bucketTag),
        paymentStatus: Value(paymentStatus),
        importBatchId: Value(importBatchId),
        captureId: Value(captureId),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Same currency: the amount is copied and no rate stored. Different
  /// currencies: both amounts and the rate used are required (spec §10.2).
  Future<int> addTransfer({
    required int fromAccountId,
    required int toAccountId,
    required int amountMinor,
    required DateTime occurredAt,
    int? toAmountMinor,
    int? rateE6,
    String transferKind = 'transfer',
    String? description,
    int? captureId,
  }) {
    final now = DateTime.now().toUtc();
    return _insert(
      TransactionsCompanion.insert(
        type: 'transfer',
        accountId: fromAccountId,
        workspaceId: 0,
        amountMinor: amountMinor,
        currencyCode: '',
        occurredAt: occurredAt,
        toAccountId: Value(toAccountId),
        toAmountMinor: Value(toAmountMinor),
        rateE6: Value(rateE6),
        transferKind: Value(transferKind),
        description: Value(_clean(description)),
        captureId: Value(captureId),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Inserts a fully formed row (debts and imports build their own).
  Future<int> insertRaw(TransactionsCompanion c) => _insert(c);

  Future<int> _insert(TransactionsCompanion c) => _db.transaction(() async {
    final row = await _normalize(c);
    return _db.into(_db.transactions).insert(row);
  });

  Future<void> update(int id, TransactionsCompanion changes, {bool clearAllocations = false}) =>
      _db.transaction(() async {
        final old = await get(id);
        if (old == null) throw StateError('transaction not found');
        final merged = old.copyWithCompanion(changes).toCompanion(true);
        final row = await _normalize(merged);
        final moneyChanged =
            row.amountMinor.value != old.amountMinor ||
            row.accountId.value != old.accountId ||
            row.occurredAt.value != old.occurredAt ||
            row.type.value != old.type ||
            row.paymentStatus.value != old.paymentStatus;
        if (moneyChanged) {
          final allocations = _db.bucketAllocations;
          final has = await (_db.select(allocations)
                ..where((a) => a.transactionId.equals(id))
                ..limit(1))
              .get();
          if (has.isNotEmpty) {
            if (!clearAllocations) throw const AllocationsLocked();
            await (_db.delete(allocations)..where((a) => a.transactionId.equals(id))).go();
          }
        }
        await _db.update(_db.transactions).replace(row.copyWith(id: Value(id), updatedAt: Value(DateTime.now().toUtc())));
      });

  Future<void> delete(int id) => (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();

  /// Re-inserts a row exactly as it was (undo after delete).
  Future<void> restore(Transaction t) => _db.into(_db.transactions).insert(t);

  Stream<List<Transaction>> watch(TxFilter f) {
    final q = _db.select(_db.transactions)
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt), (t) => OrderingTerm.desc(t.id)]);
    q.where((t) {
      Expression<bool> e = const Constant(true);
      if (f.from != null) e = e & t.occurredAt.isBiggerOrEqualValue(f.from!);
      if (f.to != null) e = e & t.occurredAt.isSmallerThanValue(f.to!);
      if (f.accountIds != null) e = e & (t.accountId.isIn(f.accountIds!) | t.toAccountId.isIn(f.accountIds!));
      if (f.workspaceIds != null) e = e & t.workspaceId.isIn(f.workspaceIds!);
      if (f.categoryIds != null) e = e & t.categoryId.isIn(f.categoryIds!);
      if (f.types != null) e = e & t.type.isIn(f.types!);
      return e;
    });
    final needle = f.text == null ? '' : normalizeForMatch(f.text!.trim());
    if (needle.isEmpty) return q.watch();
    return q.watch().map(
      (rows) => rows.where((r) => r.description != null && normalizeForMatch(r.description!).contains(needle)).toList(),
    );
  }

  /// Derives workspace and currency from the account and checks the rules
  /// the table constraints can't see (other rows).
  Future<TransactionsCompanion> _normalize(TransactionsCompanion c) async {
    final account = await (_db.select(_db.accounts)..where((a) => a.id.equals(c.accountId.value))).getSingleOrNull();
    if (account == null) throw ArgumentError.value(c.accountId.value, 'accountId', 'unknown account');
    var row = c.copyWith(workspaceId: Value(account.workspaceId), currencyCode: Value(account.currencyCode));

    final categoryId = c.categoryId.present ? c.categoryId.value : null;
    if (categoryId != null) {
      final cat = await (_db.select(_db.categories)..where((x) => x.id.equals(categoryId))).getSingleOrNull();
      final want = switch (c.type.value) {
        'income' => 'income',
        'expense' || 'refund' => 'expense',
        _ => null,
      };
      if (cat == null || (want != null && cat.kind != want)) {
        throw ArgumentError.value(categoryId, 'categoryId', 'category does not fit this type');
      }
    }

    if (c.type.value == 'transfer') {
      final toId = c.toAccountId.value;
      if (toId == null || toId == account.id) throw ArgumentError.value(toId, 'toAccountId', 'needs another account');
      final to = await (_db.select(_db.accounts)..where((a) => a.id.equals(toId))).getSingleOrNull();
      if (to == null) throw ArgumentError.value(toId, 'toAccountId', 'unknown account');
      if (to.currencyCode == account.currencyCode) {
        row = row.copyWith(toAmountMinor: Value(c.amountMinor.value), rateE6: const Value(null));
      } else {
        final toAmount = c.toAmountMinor.present ? c.toAmountMinor.value : null;
        final rate = c.rateE6.present ? c.rateE6.value : null;
        if (toAmount == null || rate == null) {
          throw ArgumentError('a cross-currency transfer needs the received amount and the rate');
        }
      }
    }
    return row;
  }

  static String? _clean(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}
