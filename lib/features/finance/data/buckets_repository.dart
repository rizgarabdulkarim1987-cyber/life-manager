import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/money/conversion.dart';
import '../../../core/money/money.dart';
import '../domain/buckets_math.dart';
import 'rates_repository.dart';

final class MissingRate implements Exception {
  const MissingRate(this.from, this.to);
  final String from;
  final String to;

  @override
  String toString() => 'MissingRate($from→$to)';
}

/// Calendar month containing [month], in local time, as a UTC range.
(DateTime, DateTime) monthRange(DateTime month) {
  final start = DateTime(month.year, month.month);
  final end = DateTime(month.year, month.month + 1);
  return (start.toUtc(), end.toUtc());
}

class BucketsRepository {
  BucketsRepository(this._db, this._rates);

  final AppDatabase _db;
  final RatesRepository _rates;

  Stream<List<Bucket>> watch() => (_db.select(_db.buckets)..orderBy([(b) => OrderingTerm.asc(b.sortOrder)])).watch();

  Future<String> _base() async => (await _db.select(_db.appSettingsTable).getSingle()).baseCurrency;

  /// The owner's percentages; they apply only to income allocated afterwards.
  Future<void> setPercents(Map<int, int> bpByBucket) async {
    final sum = bpByBucket.values.fold<int>(0, (s, x) => s + x);
    if (sum != 10000 || bpByBucket.values.any((v) => v < 0)) {
      throw ArgumentError.value(sum, 'bpByBucket', 'must sum to 10000');
    }
    await _db.transaction(() async {
      for (final e in bpByBucket.entries) {
        await (_db.update(
          _db.buckets,
        )..where((b) => b.id.equals(e.key))).write(BucketsCompanion(percentBp: Value(e.value)));
      }
    });
  }

  Future<void> setTarget(int bucketId, int? targetMinor) => (_db.update(
    _db.buckets,
  )..where((b) => b.id.equals(bucketId))).write(BucketsCompanion(targetMinor: Value(targetMinor)));

  Future<Transaction> _income(int txId) async {
    final t = await (_db.select(_db.transactions)..where((x) => x.id.equals(txId))).getSingleOrNull();
    if (t == null || t.type != 'income') throw StateError('only an income can be allocated');
    return t;
  }

  /// The income converted to the base currency at its own date's rate.
  Future<int> incomeInBase(int incomeTxId) async => (await _incomeInBase(await _income(incomeTxId))).$1;

  Future<(int, int?)> _incomeInBase(Transaction t) async {
    final base = await _base();
    if (t.currencyCode == base) return (t.amountMinor, null);
    final r = await _rates.rateOn(t.currencyCode, base, t.occurredAt);
    if (r == null) throw MissingRate(t.currencyCode, base);
    return (convert(Money(t.amountMinor, t.currencyCode), base, r).minor, r.rateE6);
  }

  Future<void> allocate(int incomeTxId, Map<int, int> amountBaseMinorByBucket) => _db.transaction(() async {
    final t = await _income(incomeTxId);
    final existing =
        await (_db.select(_db.bucketAllocations)
              ..where((a) => a.transactionId.equals(incomeTxId))
              ..limit(1))
            .get();
    if (existing.isNotEmpty) throw StateError('income is already allocated');
    final (total, rate) = await _incomeInBase(t);
    final parts = amountBaseMinorByBucket.entries.where((e) => e.value != 0).toList();
    if (parts.any((e) => e.value < 0)) throw ArgumentError('allocations must be positive');
    final sum = parts.fold<int>(0, (s, e) => s + e.value);
    if (sum > total) throw ArgumentError.value(sum, 'allocation', 'exceeds the income');
    final base = await _base();
    final now = DateTime.now().toUtc();
    for (final e in parts) {
      await _db
          .into(_db.bucketAllocations)
          .insert(
            BucketAllocationsCompanion.insert(
              transactionId: incomeTxId,
              bucketId: e.key,
              amountBaseMinor: e.value,
              baseCurrency: base,
              rateE6Used: Value(rate),
              createdAt: now,
            ),
          );
    }
  });

  Future<int> unallocatedIncomeCount(DateTime month) async {
    final (from, to) = monthRange(month);
    final rows = await _db
        .customSelect(
          'SELECT COUNT(*) AS n FROM transactions t WHERE t.type = \'income\' AND t.occurred_at >= ?1 '
          'AND t.occurred_at < ?2 AND NOT EXISTS (SELECT 1 FROM bucket_allocations a WHERE a.transaction_id = t.id)',
          variables: [Variable<DateTime>(from), Variable<DateTime>(to)],
          readsFrom: {_db.transactions, _db.bucketAllocations},
        )
        .getSingle();
    return rows.read<int>('n');
  }

  /// Expenses: allocated and spent within [month] (spending counts untagged
  /// expenses minus refunds in workspaces flagged `countsInBuckets`).
  /// Emergency and Investment: all-time allocations minus tagged spending.
  Future<List<BucketStatus>> status(DateTime month) async {
    final base = await _base();
    final book = await _rates.book();
    final (from, to) = monthRange(month);
    final all = await (_db.select(_db.buckets)..orderBy([(b) => OrderingTerm.asc(b.sortOrder)])).get();

    final allocations = await (_db.select(_db.bucketAllocations).join([
      innerJoin(_db.transactions, _db.transactions.id.equalsExp(_db.bucketAllocations.transactionId)),
    ])).get();

    final counting = (await (_db.select(
      _db.workspaces,
    )..where((w) => w.countsInBuckets.equals(true))).get()).map((w) => w.id).toSet();
    final spending = await (_db.select(_db.transactions)..where((t) => t.type.isIn(const ['expense', 'refund']))).get();

    int inBase(Transaction t) => book.convertOn(Money(t.amountMinor, t.currencyCode), base, t.occurredAt)?.minor ?? 0;
    bool inMonth(DateTime d) => !d.isBefore(from) && d.isBefore(to);

    return [
      for (final b in all)
        () {
          final monthly = b.systemKey == 'expenses';
          var allocated = 0;
          for (final row in allocations) {
            final a = row.readTable(_db.bucketAllocations);
            if (a.bucketId != b.id) continue;
            if (monthly && !inMonth(row.readTable(_db.transactions).occurredAt)) continue;
            allocated += a.amountBaseMinor;
          }
          var spent = 0;
          for (final t in spending) {
            if (monthly) {
              if (t.bucketTag != null || !counting.contains(t.workspaceId) || !inMonth(t.occurredAt)) continue;
              spent += t.type == 'refund' ? -inBase(t) : inBase(t);
            } else if (t.bucketTag == b.systemKey) {
              spent += inBase(t);
            }
          }
          return BucketStatus(
            bucket: b,
            allocatedMinor: allocated,
            spentMinor: spent,
            availableMinor: allocated - spent,
            targetMinor: b.targetMinor,
          );
        }(),
    ];
  }
}

/// [totalBaseMinor] split by each bucket's percentage, summing exactly to the
/// total: what rounding leaves over goes to the bucket with the largest share.
Map<int, int> splitByPercents(int totalBaseMinor, List<Bucket> buckets) {
  if (buckets.isEmpty) return const {};
  final out = {for (final b in buckets) b.id: totalBaseMinor * b.percentBp ~/ 10000};
  final left = totalBaseMinor - out.values.fold<int>(0, (s, v) => s + v);
  final largest = buckets.reduce((a, b) => b.percentBp > a.percentBp ? b : a);
  out[largest.id] = out[largest.id]! + left;
  return out;
}
