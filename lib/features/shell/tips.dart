import 'dart:ui';

import '../../core/db/app_database.dart';
import '../../l10n/gen/app_localizations.dart';
import '../finance/data/budgets_repository.dart';
import '../finance/data/categories_repository.dart' show categoryLabel;
import '../finance/data/buckets_repository.dart';
import '../finance/data/rates_repository.dart';

/// Most urgent first (redesign §9.4).
enum TipKind { overdueTasks, budgetNear, projectStepSoon, emergencyLow, allClear }

/// One line for Home. [args] are names and counts, never amounts.
class Tip {
  const Tip(this.kind, [this.args = const []]);

  final TipKind kind;
  final List<String> args;
}

/// Extra tips from other parts of the app (tasks, projects), merged by priority.
typedef TipSource = Future<List<Tip>> Function(AppDatabase db, DateTime now);

final tipSources = <TipSource>[];

/// Every tip that applies now, most urgent first; always ends with [TipKind.allClear]
/// when nothing else applies. Computed on the phone: nothing is sent anywhere.
Future<List<Tip>> computeTips(AppDatabase db, DateTime now) async {
  final rates = RatesRepository(db);
  final tips = <Tip>[];
  for (final source in tipSources) {
    tips.addAll(await source(db, now));
  }

  final settings = await db.select(db.appSettingsTable).getSingleOrNull();
  final l = lookupAppLocalizations(Locale(settings?.localeCode ?? 'ar'));
  final categories = {for (final c in await db.select(db.categories).get()) c.id: categoryLabel(c, l)};
  final workspaces = {for (final w in await db.select(db.workspaces).get()) w.id: w.name};
  for (final b in await BudgetsRepository(db, rates).progress(now)) {
    if (b.percentBp < 8000) continue;
    final name = categories[b.budget.categoryId] ?? workspaces[b.budget.workspaceId] ?? '';
    tips.add(Tip(TipKind.budgetNear, [name]));
  }

  for (final s in await BucketsRepository(db, rates).status(now)) {
    final target = s.targetMinor;
    if (s.bucket.systemKey == 'emergency' && target != null && s.availableMinor < target) {
      tips.add(const Tip(TipKind.emergencyLow));
    }
  }

  if (tips.isEmpty) return const [Tip(TipKind.allClear)];
  tips.sort((a, b) => a.kind.index.compareTo(b.kind.index));
  return tips;
}

String tipText(Tip t, AppLocalizations l) => switch (t.kind) {
  TipKind.overdueTasks => l.tipOverdue(int.tryParse(t.args.firstOrNull ?? '') ?? 1),
  TipKind.budgetNear => l.tipBudgetNear(t.args.firstOrNull ?? ''),
  TipKind.projectStepSoon => l.tipProjectStepSoon(t.args.firstOrNull ?? '', t.args.elementAtOrNull(1) ?? ''),
  TipKind.emergencyLow => l.tipEmergencyLow,
  TipKind.allClear => l.tipAllClear,
};
