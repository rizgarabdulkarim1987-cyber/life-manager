import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/theme/tokens.dart';
import '../../finance/data/finance_providers.dart' show workspacesProvider;
import '../data/tasks_providers.dart';
import '../platform/reminder_scheduler.dart' show ReminderStatus;
import '../data/tasks_repository.dart';
import '../domain/task_views.dart';
import 'task_format.dart';
import 'task_tile.dart';

/// The Tasks tab: quick add, the view chips of spec §11, a workspace filter and a sort.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> with WidgetsBindingObserver {
  final _quick = TextEditingController();
  TaskView _view = TaskView.today;
  TaskSort _sort = TaskSort.due;
  int? _workspaceId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _quick.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from Android's settings: the permission may have changed.
    if (state == AppLifecycleState.resumed) ref.invalidate(reminderStatusProvider);
  }

  Future<void> _quickAdd() async {
    final title = _quick.text.trim();
    if (title.isEmpty) return;
    final today = dayOf(DateTime.now());
    final due = switch (_view) {
      TaskView.today => today,
      TaskView.tomorrow => DateTime(today.year, today.month, today.day + 1),
      _ => null,
    };
    try {
      await ref
          .read(tasksRepositoryProvider)
          .create(TaskInput(title: title, dueAt: due, dueAllDay: due != null, workspaceId: _workspaceId));
      _quick.clear();
    } on ArgumentError catch (e) {
      AppLogger.warn('quick add refused', e);
    }
  }

  Future<void> _toggle(Task t) async {
    final repo = ref.read(tasksRepositoryProvider);
    if (isDone(t)) {
      await repo.setStatus(t.id, 'todo');
      return;
    }
    final next = await repo.complete(t.id);
    if (next != null && mounted) {
      final n = await repo.get(next);
      if (n != null && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(context.l10n.tskNextCreated(formatDateTime(context, dueLocal(n)!, allDay: n.dueAllDay))),
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final all = ref.watch(tasksProvider).value ?? const <Task>[];
    final workspaces = ref.watch(workspacesProvider).value ?? const <Workspace>[];
    final names = {for (final w in workspaces) w.id: w.name};
    final now = DateTime.now();
    final scoped = _workspaceId == null ? all : all.where((t) => t.workspaceId == _workspaceId).toList();
    final shown = scoped.where((t) => taskInView(t, _view, now)).toList()..sort(taskComparator(_sort));
    final status = ref.watch(reminderStatusProvider).value;
    final hasReminders = all.any((t) => !isDone(t) && t.remindAt != null);
    return Scaffold(
      key: const ValueKey('tasks-screen'),
      appBar: AppBar(
        title: Text(l.navTasks),
        actions: [
          IconButton(
            key: const ValueKey('tasks-calendar'),
            tooltip: l.tskCalendar,
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => context.push('/tasks/calendar'),
          ),
          IconButton(
            key: const ValueKey('tasks-meetings'),
            tooltip: l.tskMeetings,
            icon: const Icon(Icons.groups_2_outlined),
            onPressed: () => context.push('/tasks/meetings'),
          ),
          IconButton(
            key: const ValueKey('task-add'),
            tooltip: l.tskAdd,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push('/tasks/new'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (hasReminders && status != null && (!status.notifications || !status.exactAlarms))
            _ReminderBanner(status: status),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              key: const ValueKey('task-quick'),
              controller: _quick,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: l.tskQuickHint,
                suffixIcon: IconButton(
                  key: const ValueKey('task-quick-add'),
                  tooltip: l.tskAdd,
                  icon: const Icon(Icons.keyboard_return_rounded),
                  onPressed: _quickAdd,
                ),
              ),
              onSubmitted: (_) => _quickAdd(),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                for (final v in TaskView.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      key: ValueKey('tasks-view-${v.name}'),
                      label: Text(
                        '${viewLabel(l, v)} ${scoped.where((t) => taskInView(t, v, now)).length}',
                        maxLines: 1,
                      ),
                      selected: _view == v,
                      onSelected: (_) => setState(() => _view = v),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      key: const ValueKey('tasks-workspace'),
                      isExpanded: true,
                      value: names.containsKey(_workspaceId) ? _workspaceId : null,
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(l.tskAllWorkspaces, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        for (final w in workspaces)
                          DropdownMenuItem<int?>(
                            value: w.id,
                            child: Text(w.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) => setState(() => _workspaceId = v),
                    ),
                  ),
                ),
                PopupMenuButton<TaskSort>(
                  key: const ValueKey('tasks-sort'),
                  tooltip: l.tskSort,
                  icon: const Icon(Icons.sort_rounded),
                  initialValue: _sort,
                  onSelected: (s) => setState(() => _sort = s),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: TaskSort.due, child: Text(l.tskSortDue)),
                    PopupMenuItem(value: TaskSort.priority, child: Text(l.tskSortPriority)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l.tskEmpty,
                        key: const ValueKey('tasks-empty'),
                        textAlign: TextAlign.center,
                        style: text.bodyLarge?.copyWith(color: k.textMuted),
                      ),
                    ),
                  )
                : ListView.separated(
                    key: const ValueKey('tasks-list'),
                    padding: const EdgeInsets.only(bottom: 112),
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => Divider(color: k.border, height: 1, indent: 20, endIndent: 20),
                    itemBuilder: (context, i) {
                      final t = shown[i];
                      return TaskTile(
                        key: ValueKey('task-${t.id}'),
                        task: t,
                        workspaceName: names[t.workspaceId],
                        onTap: () => context.push('/tasks/${t.id}'),
                        onToggle: () => _toggle(t),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReminderBanner extends ConsumerWidget {
  const _ReminderBanner({required this.status});

  final ReminderStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final scheduler = ref.read(reminderSchedulerProvider);
    final needNotifications = !status.notifications;
    return Container(
      key: const ValueKey('reminder-banner'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: k.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            needNotifications ? l.tskWarnNotifications : l.tskWarnExact,
            style: text.bodyMedium?.copyWith(color: k.text),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: const ValueKey('reminder-banner-action'),
              onPressed: () async {
                if (needNotifications) {
                  await scheduler.requestNotifications();
                } else {
                  await scheduler.openExactAlarmSettings();
                }
                ref.invalidate(reminderStatusProvider);
              },
              child: Text(needNotifications ? l.tskAllow : l.tskOpenSettings),
            ),
          ),
        ],
      ),
    );
  }
}
