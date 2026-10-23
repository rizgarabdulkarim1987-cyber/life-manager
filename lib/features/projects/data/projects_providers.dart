import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/money/money.dart';
import '../../finance/data/finance_providers.dart';
import '../../finance/data/rates_repository.dart';
import '../domain/affordability.dart';
import 'projects_repository.dart';

final projectsRepositoryProvider = Provider<ProjectsRepository>(
  (ref) => ProjectsRepository(ref.watch(appDatabaseProvider)),
);

final projectsProvider = StreamProvider.autoDispose<List<Project>>(
  (ref) => ref.watch(projectsRepositoryProvider).watchAll(),
);

final projectProvider = StreamProvider.autoDispose.family<Project?, int>(
  (ref, id) => ref.watch(projectsRepositoryProvider).watch(id),
);

final projectStepsProvider = StreamProvider.autoDispose.family<List<ProjectStep>, int>(
  (ref, id) => ref.watch(projectsRepositoryProvider).watchSteps(id),
);

final projectMessagesProvider = StreamProvider.autoDispose.family<List<ProjectMessage>, int>(
  (ref, id) => ref.watch(projectsRepositoryProvider).watchMessages(id),
);

/// What the Investment bucket got on average in each of the last 3 full months, in base minor units.
Future<int> investmentMonthlyAverage(AppDatabase db, DateTime now) async {
  final bucket = await (db.select(db.buckets)..where((b) => b.systemKey.equals('investment'))).getSingleOrNull();
  if (bucket == null) return 0;
  final to = DateTime(now.year, now.month);
  final from = DateTime(now.year, now.month - 3);
  final rows = await (db.select(db.bucketAllocations).join([
    innerJoin(db.transactions, db.transactions.id.equalsExp(db.bucketAllocations.transactionId)),
  ])..where(db.bucketAllocations.bucketId.equals(bucket.id))).get();
  var total = 0;
  for (final r in rows) {
    final at = r.readTable(db.transactions).occurredAt.toLocal();
    if (!at.isBefore(from) && at.isBefore(to)) total += r.readTable(db.bucketAllocations).amountBaseMinor;
  }
  return total ~/ 3;
}

/// Where a project's cost stands against the Investment bucket; null until the project has a cost
/// that can be worth in the base currency.
class ProjectAffordability {
  const ProjectAffordability({
    required this.cost,
    required this.costBase,
    required this.available,
    required this.average,
    required this.result,
  });

  final Money cost;
  final Money costBase;
  final Money available;
  final Money average;
  final Affordability result;
}

final projectAffordabilityProvider = FutureProvider.autoDispose.family<ProjectAffordability?, int>((ref, id) async {
  final project = await ref.watch(projectProvider(id).future);
  final minor = project?.estCostMinor;
  final code = project?.currencyCode;
  if (minor == null || code == null) return null;
  final db = ref.watch(appDatabaseProvider);
  final base = (await ref.watch(settingsProvider.future)).baseCurrency;
  final book = await ref.watch(ratesRepositoryProvider).book();
  final cost = Money(minor, code);
  final inBase = book.convertOn(cost, base, DateTime.now());
  if (inBase == null) return null;
  final buckets = await ref.watch(bucketStatusProvider.future);
  final invest = buckets.where((b) => b.bucket.systemKey == 'investment').firstOrNull;
  final available = invest?.availableMinor ?? 0;
  final average = await investmentMonthlyAverage(db, DateTime.now());
  return ProjectAffordability(
    cost: cost,
    costBase: inBase,
    available: Money(available, base),
    average: Money(average, base),
    result: computeAffordability(
      costBaseMinor: inBase.minor,
      investmentAvailableMinor: available,
      avgMonthlyAllocationMinor: average,
    ),
  );
});
