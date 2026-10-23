import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../l10n/gen/app_localizations.dart';

List<String> extraKeywords(Category c) =>
    c.extraKeywords.split(',').map((w) => w.trim()).where((w) => w.isNotEmpty).toList();

String? systemLabel(String key, AppLocalizations l) => switch (key) {
  'food' => l.cat_food,
  'transport' => l.cat_transport,
  'rent' => l.cat_rent,
  'bills' => l.cat_bills,
  'family' => l.cat_family,
  'shopping' => l.cat_shopping,
  'health' => l.cat_health,
  'business' => l.cat_business,
  'marketing' => l.cat_marketing,
  'subscriptions' => l.cat_subscriptions,
  'other_expense' => l.cat_other_expense,
  'salary' => l.cat_salary,
  'business_income' => l.cat_business_income,
  'freelance' => l.cat_freelance,
  'client_payment' => l.cat_client_payment,
  'other_income' => l.cat_other_income,
  'expenses' => l.bucket_expenses,
  'emergency' => l.bucket_emergency,
  'investment' => l.bucket_investment,
  _ => null,
};

/// The owner's name if renamed, else the localized seeded name.
String categoryLabel(Category c, AppLocalizations l) => c.name ?? systemLabel(c.systemKey ?? '', l) ?? '?';

String bucketLabel(Bucket b, AppLocalizations l) => b.name ?? systemLabel(b.systemKey ?? '', l) ?? '?';

class CategoriesRepository {
  CategoriesRepository(this._db);

  final AppDatabase _db;

  Stream<List<Category>> watch({String? kind, bool includeArchived = false}) {
    final q = _db.select(_db.categories)
      ..orderBy([(c) => OrderingTerm.asc(c.sortOrder), (c) => OrderingTerm.asc(c.id)]);
    q.where((c) {
      Expression<bool> e = const Constant(true);
      if (kind != null) e = e & c.kind.equals(kind);
      if (!includeArchived) e = e & c.isArchived.equals(false);
      return e;
    });
    return q.watch();
  }

  Future<int> create({
    required String kind,
    required String name,
    String iconKey = 'tag',
    int? colorArgb,
    int? workspaceId,
  }) async {
    final last =
        await (_db.select(_db.categories)
              ..orderBy([(c) => OrderingTerm.desc(c.sortOrder)])
              ..limit(1))
            .getSingleOrNull();
    return _db
        .into(_db.categories)
        .insert(
          CategoriesCompanion.insert(
            kind: kind,
            name: Value(name.trim()),
            iconKey: iconKey,
            colorArgb: colorArgb ?? 0xFFA3ADC2,
            workspaceId: Value(workspaceId),
            sortOrder: (last?.sortOrder ?? -1) + 1,
          ),
        );
  }

  Future<void> rename(int id, String name) =>
      (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(CategoriesCompanion(name: Value(name.trim())));

  Future<void> setExtraKeywords(int id, List<String> words) {
    final clean = words.map((w) => w.trim().replaceAll(',', ' ')).where((w) => w.isNotEmpty).toSet().join(',');
    return (_db.update(
      _db.categories,
    )..where((c) => c.id.equals(id))).write(CategoriesCompanion(extraKeywords: Value(clean)));
  }

  Future<void> archive(int id) => (_db.update(
    _db.categories,
  )..where((c) => c.id.equals(id))).write(const CategoriesCompanion(isArchived: Value(true)));
}
