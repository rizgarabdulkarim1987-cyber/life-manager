import 'package:drift/drift.dart' show OrderingTerm, TableUpdateQuery;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/db/app_database.dart';
import '../../core/l10n/ckb_fallback_localizations.dart';
import '../../core/theme/tokens.dart';
import '../capture/data/capture_providers.dart';
import '../capture/ui/composer.dart';
import '../finance/data/categories_repository.dart' show categoryLabel;
import '../finance/data/finance_providers.dart';
import '../finance/ui/widgets/undo_snack.dart';
import '../projects/data/projects_providers.dart';
import '../tasks/data/tasks_providers.dart';
import '../tasks/data/tasks_repository.dart' show TaskView;
import '../tasks/ui/tasks_screen.dart' show TaskTile;
import 'tips.dart';

/// Recomputed whenever a transaction changes.
final homeTipsProvider = StreamProvider<List<Tip>>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  yield await computeTips(db, DateTime.now());
  final changes = db.tableUpdates(
    TableUpdateQuery.onAllTables([db.transactions, db.tasks, db.projectSteps, db.projects, db.budgets, db.buckets]),
  );
  await for (final _ in changes) {
    yield await computeTips(db, DateTime.now());
  }
});

/// The last five incomes and expenses, newest recorded first.
final recentEntriesProvider = StreamProvider<List<Transaction>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.transactions)
        ..where((t) => t.type.isIn(const ['expense', 'income', 'refund']))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt), (t) => OrderingTerm.desc(t.id)])
        ..limit(5))
      .watch();
});

/// Home (redesign §9.4): the big composer, one tip, today, recent entries and
/// projects. No amounts here at all: money lives behind Finance's lock.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final waiting = ref.watch(pendingCapturesProvider).value?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.homeGreeting),
        actions: [
          IconButton(
            key: const ValueKey('open-inbox'),
            tooltip: l.capInbox,
            icon: Badge(isLabelVisible: waiting > 0, label: Text('$waiting'), child: const Icon(Icons.inbox_outlined)),
            onPressed: () => context.push('/inbox'),
          ),
          IconButton(
            key: const ValueKey('open-settings'),
            tooltip: l.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const Composer(large: true),
          const SizedBox(height: 16),
          const _TipCard(),
          _Section(key: const ValueKey('home-today'), title: l.homeToday, child: const _TodayList()),
          const _RecentCard(),
          _Section(key: const ValueKey('home-projects'), title: l.homeProjects, child: const _ProjectsList()),
        ],
      ),
    );
  }
}

class _TipCard extends ConsumerWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.tokens;
    final tip = ref.watch(homeTipsProvider).value?.firstOrNull ?? const Tip(TipKind.allClear);
    final calm = tip.kind == TipKind.allClear;
    final color = calm ? k.success : k.warning;
    return Container(
      key: const ValueKey('home-tip'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(calm ? Icons.wb_sunny_outlined : Icons.lightbulb_outline_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(tipText(tip, context.l10n), style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    // Material, not a decorated box, so the rows' ink shows.
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: k.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.tokens.textMuted)),
  );
}

class _RecentCard extends ConsumerStatefulWidget {
  const _RecentCard();

  @override
  ConsumerState<_RecentCard> createState() => _RecentCardState();
}

class _RecentCardState extends ConsumerState<_RecentCard> {
  final _hidden = <int>{};

  Future<void> _delete(Transaction t) async {
    final repo = ref.read(transactionsRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    setState(() => _hidden.add(t.id));
    final allocations = await repo.delete(t.id);
    showUndoSnack(
      messenger,
      l,
      message: l.finDeleted,
      onUndo: () async {
        await repo.restore(t, allocations);
        if (mounted) setState(() => _hidden.remove(t.id));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final rows = [
      for (final t in ref.watch(recentEntriesProvider).value ?? const <Transaction>[])
        if (!_hidden.contains(t.id)) t,
    ];
    final categories = {for (final c in ref.watch(categoriesProvider).value ?? const <Category>[]) c.id: c};
    return _Section(
      key: const ValueKey('home-recent'),
      title: l.homeRecent,
      child: rows.isEmpty
          ? _Empty(l.homeRecentEmpty)
          : Column(
              children: [
                for (final t in rows)
                  Dismissible(
                    key: ValueKey('recent-${t.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: AlignmentDirectional.centerEnd,
                      padding: const EdgeInsetsDirectional.only(end: 16),
                      decoration: BoxDecoration(
                        color: k.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.delete_outline_rounded, color: k.danger),
                    ),
                    onDismissed: (_) => _delete(t),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => context.push('/finance/tx/${t.id}'),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: k.surfaceHigh,
                        child: Icon(
                          t.type == 'income' ? Icons.south_west_rounded : Icons.north_east_rounded,
                          size: 18,
                          color: t.type == 'income' ? k.success : k.textMuted,
                        ),
                      ),
                      title: Text(
                        (t.description ?? '').trim().isNotEmpty
                            ? t.description!.trim()
                            : categories[t.categoryId] == null
                            ? (t.type == 'income' ? l.homeIncome : l.homeExpense)
                            : categoryLabel(categories[t.categoryId]!, l),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyLarge,
                      ),
                      subtitle: Text(
                        '${t.occurredAt.toLocal().day}/${t.occurredAt.toLocal().month}',
                        style: text.bodySmall?.copyWith(color: k.textMuted),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Overdue and due-today tasks, at most five.
class _TodayList extends ConsumerWidget {
  const _TodayList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdue = ref.watch(taskViewProvider(TaskView.overdue)).value ?? const <Task>[];
    final today = ref.watch(taskViewProvider(TaskView.today)).value ?? const <Task>[];
    final rows = [...overdue, ...today].take(5).toList();
    if (rows.isEmpty) return _Empty(context.l10n.homeTodayEmpty);
    return Column(children: [for (final t in rows) TaskTile(task: t)]);
  }
}

/// Projects still in play, with how far along each is; at most three.
class _ProjectsList extends ConsumerWidget {
  const _ProjectsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final open = [
      for (final p in ref.watch(projectsProvider).value ?? const <Project>[])
        if (p.status != 'done' && p.status != 'dropped') p,
    ].take(3).toList();
    if (open.isEmpty) return _Empty(l.homeProjectsEmpty);
    return Column(
      children: [
        for (final p in open)
          Consumer(
            builder: (context, ref, _) {
              final steps = ref.watch(projectStepsProvider(p.id)).value ?? const <ProjectStep>[];
              final done = steps.where((s) => s.done).length;
              return ListTile(
                key: ValueKey('home-project-${p.id}'),
                contentPadding: EdgeInsets.zero,
                onTap: () => context.push('/projects/${p.id}'),
                title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: steps.isEmpty
                    ? null
                    : Text(l.projectProgress(done, steps.length), style: TextStyle(color: k.textMuted)),
                trailing: const Icon(Icons.chevron_right_rounded),
              );
            },
          ),
      ],
    );
  }
}
