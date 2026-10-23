import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../finance/data/finance_providers.dart' show workspacesProvider;
import '../../finance/ui/ui_format.dart';
import '../data/tasks_providers.dart';
import '../domain/task_views.dart';
import 'task_tile.dart';

/// A month grid of open tasks per day; tapping a day lists that day's tasks.
class TasksCalendarScreen extends ConsumerStatefulWidget {
  const TasksCalendarScreen({super.key});

  @override
  ConsumerState<TasksCalendarScreen> createState() => _TasksCalendarScreenState();
}

class _TasksCalendarScreenState extends ConsumerState<TasksCalendarScreen> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
    _selected = dayOf(n);
  }

  void _shift(int by) => setState(() => _month = DateTime(_month.year, _month.month + by));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final loc = MaterialLocalizations.of(context);
    final all = ref.watch(tasksProvider).value ?? const <Task>[];
    final names = {for (final w in ref.watch(workspacesProvider).value ?? const <Workspace>[]) w.id: w.name};
    final counts = countByDay(all, _month);
    final first = loc.firstDayOfWeekIndex;
    final lead = (DateTime(_month.year, _month.month).weekday % 7 - first + 7) % 7;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = lead + days;
    final rows = (cells / 7).ceil();
    final today = dayOf(DateTime.now());
    final dayTasks = all.where((t) {
      final d = dueLocal(t);
      return d != null && dayOf(d) == _selected;
    }).toList()..sort(taskComparator(TaskSort.due));
    final title = DateFormat.yMMMM(dateLocaleOf(context)).format(_month);

    return Scaffold(
      key: const ValueKey('tasks-calendar-screen'),
      appBar: AppBar(title: Text(l.tskCalendar)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Row(
            children: [
              IconButton(
                key: const ValueKey('cal-prev'),
                tooltip: loc.previousMonthTooltip,
                onPressed: () => _shift(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  title,
                  key: const ValueKey('cal-title'),
                  textAlign: TextAlign.center,
                  style: text.titleMedium?.copyWith(color: k.text),
                ),
              ),
              IconButton(
                key: const ValueKey('cal-next'),
                tooltip: loc.nextMonthTooltip,
                onPressed: () => _shift(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        loc.narrowWeekdays[(first + i) % 7],
                        style: text.labelMedium?.copyWith(color: k.textMuted),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Column(
              children: [
                for (var r = 0; r < rows; r++)
                  Row(
                    children: [
                      for (var c = 0; c < 7; c++)
                        Expanded(
                          child: _Cell(
                            day: r * 7 + c - lead + 1,
                            days: days,
                            month: _month,
                            count: counts[r * 7 + c - lead + 1] ?? 0,
                            today: today,
                            selected: _selected,
                            onTap: (d) => setState(() => _selected = d),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          Divider(color: k.border, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(formatDate(context, _selected), style: text.titleSmall?.copyWith(color: k.textMuted)),
          ),
          if (dayTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                l.tskCalendarEmpty,
                key: const ValueKey('cal-empty'),
                style: text.bodyMedium?.copyWith(color: k.textMuted),
              ),
            ),
          for (final t in dayTasks)
            TaskTile(
              key: ValueKey('cal-task-${t.id}'),
              task: t,
              workspaceName: names[t.workspaceId],
              onTap: () => context.push('/tasks/${t.id}'),
              onToggle: () {
                final repo = ref.read(tasksRepositoryProvider);
                isDone(t) ? repo.setStatus(t.id, 'todo') : repo.complete(t.id);
              },
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey('cal-add'),
                onPressed: () => context.push('/tasks/new?due=${_selected.toIso8601String()}'),
                icon: const Icon(Icons.add_rounded),
                label: Text(l.tskAdd),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.day,
    required this.days,
    required this.month,
    required this.count,
    required this.today,
    required this.selected,
    required this.onTap,
  });

  final int day;
  final int days;
  final DateTime month;
  final int count;
  final DateTime today;
  final DateTime selected;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    if (day < 1 || day > days) return const SizedBox(height: 52);
    final k = context.tokens;
    final date = DateTime(month.year, month.month, day);
    final isSel = date == selected;
    final isToday = date == today;
    return InkWell(
      key: ValueKey('cal-day-$day'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => onTap(date),
      child: Container(
        height: 52,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: isSel ? k.accent : null,
          border: isToday && !isSel ? Border.all(color: k.accent) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$day', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isSel ? k.onAccent : k.text)),
              Text(
                count == 0 ? ' ' : '● $count',
                key: count == 0 ? null : ValueKey('cal-count-$day'),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isSel ? k.onAccent : k.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
