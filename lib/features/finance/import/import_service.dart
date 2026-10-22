import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../data/transactions_repository.dart';
import 'import_mapping.dart';

/// Stores planned rows as one batch, and takes a batch back out.
class ImportService {
  ImportService(this._db, this._tx);

  final AppDatabase _db;
  final TransactionsRepository _tx;

  /// Duplicate keys of what is already booked between [from] and [to] (local, inclusive).
  Future<Set<String>> existingKeys(DateTime from, DateTime to) async {
    final start = DateTime(from.year, from.month, from.day).toUtc();
    final end = DateTime(to.year, to.month, to.day + 1).toUtc();
    final rows = await (_db.select(
      _db.transactions,
    )..where((t) => t.occurredAt.isBiggerOrEqualValue(start) & t.occurredAt.isSmallerThanValue(end))).get();
    return {for (final t in rows) importKey(t.occurredAt.toLocal(), t.accountId, t.amountMinor, t.description)};
  }

  /// Inserts the batch and its rows in one database transaction. Rows with a
  /// problem are never stored; duplicates are left out unless asked for.
  Future<int> commit(String fileName, List<ImportRow> rows, {bool skipDuplicates = true}) {
    final keep = rows.where((r) => r.problem == null && !(skipDuplicates && r.duplicate)).toList();
    return _db.transaction(() async {
      final id = await _db
          .into(_db.importBatches)
          .insert(
            ImportBatchesCompanion.insert(fileName: fileName, rowCount: keep.length, createdAt: DateTime.now().toUtc()),
          );
      for (final r in keep) {
        await _tx.addSimple(
          type: r.type,
          accountId: r.accountId,
          amountMinor: r.amountMinor,
          occurredAt: r.occurredAt.toUtc(),
          categoryId: r.categoryId,
          description: r.description,
          importBatchId: id,
        );
      }
      return id;
    });
  }

  /// Deletes the batch's transactions (their allocations go with them).
  Future<void> undo(int batchId) => _db.transaction(() async {
    await (_db.delete(_db.transactions)..where((t) => t.importBatchId.equals(batchId))).go();
    await (_db.update(
      _db.importBatches,
    )..where((b) => b.id.equals(batchId))).write(ImportBatchesCompanion(undoneAt: Value(DateTime.now().toUtc())));
  });

  Stream<List<ImportBatche>> watchBatches() => (_db.select(
    _db.importBatches,
  )..orderBy([(b) => OrderingTerm.desc(b.createdAt), (b) => OrderingTerm.desc(b.id)])).watch();
}
