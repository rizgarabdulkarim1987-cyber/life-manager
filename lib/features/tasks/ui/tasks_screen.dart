import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../finance/ui/ui_format.dart';
import '../../finance/ui/widgets/undo_snack.dart';
import '../data/tasks_providers.dart';
import '../reminders/reminder_service.dart';
import '../data/tasks_repository.dart';
import 'calendar_view.dart';
import 'notes_screen.dart';

enum _Segment { today, upcoming, overdue, noDate, done, calendar, notes }

TaskView? _viewOf(_Segment s) => switch (s) {
  _Segment.today => TaskView.today,
  _Segment.upcoming => TaskView.upcoming,
  _Segment.overdue => TaskView.overdue,
  _Segment.noDate => TaskView.inbox,
  _Segment.done => TaskView.done,
  _ => null,
};

String _segmentLabel(AppLocalizations l, _Segment s) => switch (s) {
  _Segment.today => l.tasksToday,
  _Segment.upcoming => l.tasksUpcoming,
  _Segment.overdue => l.tasksOverdue,
  _Segment.noDate => l.tasksNoDate,
  _Segment.done => l.tasksDone,
  _Segment.calendar => l.tasksCalendar,
  _Segment.notes => l.tasksNotes,
};

/// The Tasks tab: tasks by when they are due, a month calendar and notes (redesign §9.2).
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  var _segment = _Segment.today;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final view = _viewOf(_segment);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navTasks),
        actions: [
          IconButton(
            key: const ValueKey('tasks-add'),
            tooltip: _segment == _Segment.notes ? l.noteNew : l.tasksAdd,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _segment == _Segment.notes ? editNote(context, ref) : context.push('/tasks/new'),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  for (final s in _Segment.values)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        key: ValueKey('segment-${s.name}'),
                        label: Text(_segmentLabel(l, s)),
                        selected: _segment == s,
                        selectedColor: k.accent.withValues(alpha: 0.16),
                        onSelected: (_) => setState(() => _segment = s),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (ref.watch(exactAlarmsAllowedProvider).value == false)
            Container(
              key: const ValueKey('exact-alarm-warning'),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 6, 6),
              decoration: BoxDecoration(
                color: k.warning.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(l.exactAlarmWarning, style: Theme.of(context).textTheme.bodySmall)),
                  TextButton(
                    key: const ValueKey('exact-alarm-allow'),
                    onPressed: () async {
                      await ref.read(notificationPortProvider).requestExact();
                      ref.invalidate(exactAlarmsAllowedProvider);
                    },
                    child: Text(l.exactAlarmAllow),
                  ),
                ],
              ),
            ),
          Expanded(
            child: switch (_segment) {
              _Segment.calendar => const CalendarView(),
              _Segment.notes => const NotesView(),
              _ => TaskList(view: view!),
            },
          ),
        ],
      ),
    );
  }
}

/// Completes a task and offers to take it back (a repeating one also drops its new copy).
Future<void> completeTask(BuildContext context, WidgetRef ref, Task t) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(tasksRepositoryProvider);
  final spawned = await repo.complete(t.id);
  showUndoSnack(
    messenger,
    l,
    message: l.taskCompleted,
    onUndo: () async {
      await repo.reopen(t.id);
      if (spawned != null) await repo.delete(spawned);
    },
  );
}

Future<void> deleteTask(BuildContext context, WidgetRef ref, Task t) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(tasksRepositoryProvider);
  final gone = await repo.delete(t.id);
  if (gone == null) return;
  showUndoSnack(messenger, l, message: l.taskDeleted, onUndo: () => repo.restore(gone));
}

class TaskList extends ConsumerWidget {
  const TaskList({super.key, required this.view});

  final TaskView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskViewProvider(view)).value;
    if (tasks == null) return const SizedBox.shrink();
    return TaskRows(tasks: tasks);
  }
}

/// The rows of [tasks] with the empty state; also used under the calendar.
class TaskRows extends ConsumerWidget {
  const TaskRows({super.key, required this.tasks, this.shrinkWrap = false});

  final List<Task> tasks;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l.tasksEmpty,
            key: const ValueKey('tasks-empty'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: k.textMuted),
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: tasks.length,
      itemBuilder: (context, i) {
        final t = tasks[i];
        return Dismissible(
          key: ValueKey('task-row-${t.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            color: k.danger.withValues(alpha: 0.16),
            alignment: AlignmentDirectional.centerEnd,
            padding: const EdgeInsetsDirectional.only(end: 24),
            child: Icon(Icons.delete_outline_rounded, color: k.danger),
          ),
          onDismissed: (_) => deleteTask(context, ref, t),
          child: TaskTile(task: t),
        );
      },
    );
  }
}

String taskWhen(BuildContext context, Task t) {
  final due = t.dueAt?.toLocal();
  if (due == null) return '';
  final date = formatDate(context, due);
  return t.hasTime ? '$date · ${DateFormat.Hm('en').format(due)}' : date;
}

class TaskTile extends ConsumerWidget {
  const TaskTile({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final t = task;
    final done = t.status == 'done';
    final when = taskWhen(context, t);
    final meta = [if (when.isNotEmpty) when, if (t.place != null && t.place!.isNotEmpty) t.place!].join(' · ');
    return ListTile(
      key: ValueKey('task-${t.id}'),
      onTap: () => context.push('/tasks/${t.id}'),
      leading: Checkbox(
        key: ValueKey('task-check-${t.id}'),
        value: done,
        onChanged: (v) => v == true ? completeTask(context, ref, t) : ref.read(tasksRepositoryProvider).reopen(t.id),
      ),
      title: Text(
        t.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: text.bodyLarge?.copyWith(
          color: done ? k.textMuted : k.text,
          decoration: done ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: meta.isEmpty ? null : Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: switch (t.kind) {
        'appointment' => Icon(Icons.event_rounded, color: k.textMuted),
        'reminder' => Icon(Icons.notifications_none_rounded, color: k.textMuted),
        _ => t.priority == 2 ? Icon(Icons.priority_high_rounded, color: k.danger) : null,
      },
    );
  }
}
