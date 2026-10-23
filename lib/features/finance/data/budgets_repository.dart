import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/money/money.dart';
import '../domain/budgets_math.dart';
import 'buckets_repository.dart' show monthRange;
import 'rates_repository.dart';

class BudgetsRepository {
  BudgetsRepository(this._db, this._rates);

  final AppDatabase _db;
  final RatesRepository _rates;

  Stream<List<Budget>> watch() =>
      (_db.select(_db.budgets)
            ..where((b) => b.isArchived.equals(false))
            ..orderBy([(b) => OrderingTerm.asc(b.createdAt)]))
          .watch();

  Future<int> create({
    int? categoryId,
    int? workspaceId,
    required int amountMinor,
    required String currencyCode,
  }) async {
    if (categoryId == null && workspaceId == null) throw ArgumentError('a budget needs a category or a workspace');
    if (amountMinor <= 0) throw ArgumentError.value(amountMinor, 'amountMinor');
    return _db
        .into(_db.budgets)
        .insert(
          BudgetsCompanion.insert(
            categoryId: Value(categoryId),
            workspaceId: Value(workspaceId),
            amountMinor: amountMinor,
            currencyCode: currencyCode,
            createdAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<void> update(Budget b) async {
    if (b.amountMinor <= 0) throw ArgumentError.value(b.amountMinor, 'amountMinor');
    await _db.update(_db.budgets).replace(b);
  }

  Future<void> archive(int id) =>
      (_db.update(_db.budgets)..where((b) => b.id.equals(id))).write(const BudgetsCompanion(isArchived: Value(true)));

  /// Expenses minus refunds in [month] matching each budget, converted to the
  /// budget's currency at each transaction's own date.
  Future<List<BudgetProgress>> progress(DateTime month) async {
    final budgets = await (_db.select(_db.budgets)..where((b) => b.isArchived.equals(false))).get();
    if (budgets.isEmpty) return const [];
    final (from, to) = monthRange(month);
    final rows =
        await (_db.select(_db.transactions)..where(
              (t) =>
                  t.type.isIn(const ['expense', 'refund']) &
                  t.occurredAt.isBiggerOrEqualValue(from) &
                  t.occurredAt.isSmallerThanValue(to),
            ))
            .get();
    final book = await _rates.book();
    return [
      for (final b in budgets)
        () {
          var actual = 0;
          final missing = <String>{};
          for (final t in rows) {
            if (b.categoryId != null && t.categoryId != b.categoryId) continue;
            if (b.workspaceId != null && t.workspaceId != b.workspaceId) continue;
            final m = book.convertOn(Money(t.amountMinor, t.currencyCode), b.currencyCode, t.occurredAt);
            if (m == null) {
              missing.add(t.currencyCode);
              continue;
            }
            actual += t.type == 'refund' ? -m.minor : m.minor;
          }
          return BudgetProgress(
            budget: b,
            actualMinor: actual,
            remainingMinor: b.amountMinor - actual,
            percentBp: actual * 10000 ~/ b.amountMinor,
            missingRates: missing.toList()..sort(),
          );
        }(),
    ];
  }
}
