import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../finance/data/finance_providers.dart' show workspacesProvider;
import '../data/tasks_providers.dart';
import '../domain/task_views.dart';
import 'task_format.dart';

/// One task: its facts, its steps, and the quick actions (done, start, snooze).
class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final int taskId;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  final _step = TextEditingController();

  @override
  void dispose() {
    _step.dispose();
    super.dispose();
  }

  Future<void> _addStep() async {
    final t = _step.text.trim();
    if (t.isEmpty) return;
    await ref.read(tasksRepositoryProvider).addStep(widget.taskId, t);
    _step.clear();
  }

  Future<void> _delete(Task task) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.tskDeleteTitle),
        content: Text(l.tskDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text(l.cancel)),
          FilledButton(
            key: const ValueKey('task-delete-confirm'),
            style: FilledButton.styleFrom(backgroundColor: c.tokens.danger, foregroundColor: c.tokens.onAccent),
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(l.tskDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(tasksRepositoryProvider).delete(task.id);
    if (mounted) context.pop();
  }

  Future<void> _snoozeTomorrow() async {
    final n = DateTime.now();
    await ref.read(tasksRepositoryProvider).setReminder(widget.taskId, DateTime(n.year, n.month, n.day + 1, 9));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.tskSnoozedTomorrow)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final task = ref.watch(taskProvider(widget.taskId)).value;
    if (task == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.tskNotFound)),
      );
    }
    final steps = ref.watch(taskStepsProvider(task.id)).value ?? const <Task>[];
    final workspaces = ref.watch(workspacesProvider).value ?? const <Workspace>[];
    final workspace = workspaces.where((w) => w.id == task.workspaceId).firstOrNull;
    final repo = ref.read(tasksRepositoryProvider);
    final due = dueLocal(task);
    final remind = task.remindAt?.toLocal();
    final done = isDone(task);
    final tags = task.tags.split(',').where((t) => t.isNotEmpty);

    Widget fact(IconData icon, String label, {Color? color, Key? key}) => Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color ?? k.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: text.bodyLarge?.copyWith(color: color ?? k.text)),
          ),
        ],
      ),
    );

    return Scaffold(
      key: const ValueKey('task-detail'),
      appBar: AppBar(
        actions: [
          IconButton(
            key: const ValueKey('task-edit'),
            tooltip: l.tskEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/tasks/${task.id}/edit'),
          ),
          IconButton(
            key: const ValueKey('task-delete'),
            tooltip: l.tskDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _delete(task),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Text(
            task.title,
            key: const ValueKey('task-detail-title'),
            style: text.headlineSmall?.copyWith(
              color: done ? k.textMuted : k.text,
              decoration: done ? TextDecoration.lineThrough : null,
            ),
          ),
          const SizedBox(height: 12),
          fact(
            done ? Icons.check_circle_rounded : Icons.flag_outlined,
            '${switch (task.status) {
              'done' => l.tskStatusDone,
              'doing' => l.tskStatusDoing,
              _ => l.tskStatusTodo,
            }} · ${priorityLabel(l, task.priority)}',
            color: done ? k.success : priorityColor(k, task.priority),
          ),
          if (due != null)
            fact(
              Icons.event_rounded,
              formatDateTime(context, due, allDay: task.dueAllDay),
              color: isOverdue(task, DateTime.now()) ? k.danger : null,
              key: const ValueKey('task-detail-due'),
            ),
          if (remind != null)
            fact(
              Icons.notifications_none_rounded,
              formatDateTime(context, remind, allDay: false),
              key: const ValueKey('task-detail-remind'),
            ),
          if (task.recurrence != null)
            fact(Icons.repeat_rounded, recurrenceLabel(l, task.recurrence!, task.recurrenceInterval)),
          if (workspace != null) fact(Icons.folder_outlined, workspace.name),
          if (tags.isNotEmpty) fact(Icons.sell_outlined, tags.map((t) => '#$t').join('  ')),
          if (task.notes != null) ...[
            const SizedBox(height: 8),
            Text(task.notes!, style: text.bodyLarge?.copyWith(color: k.text, height: 1.5)),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const ValueKey('task-done'),
                onPressed: () => done ? repo.setStatus(task.id, 'todo') : repo.complete(task.id),
                icon: Icon(done ? Icons.undo_rounded : Icons.check_rounded),
                label: Text(done ? l.tskReopen : l.tskMarkDone),
              ),
              if (!done && task.status != 'doing')
                OutlinedButton.icon(
                  key: const ValueKey('task-start'),
                  onPressed: () => repo.setStatus(task.id, 'doing'),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(l.tskStart),
                ),
              if (!done && task.remindAt != null)
                OutlinedButton.icon(
                  key: const ValueKey('task-snooze'),
                  onPressed: _snoozeTomorrow,
                  icon: const Icon(Icons.snooze_rounded),
                  label: Text(l.tskSnoozeTomorrow),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            steps.isEmpty ? l.tskSteps : '${l.tskSteps} · ${steps.where(isDone).length}/${steps.length}',
            style: text.titleMedium?.copyWith(color: k.text),
          ),
          for (final s in steps)
            Row(
              key: ValueKey('step-${s.id}'),
              children: [
                IconButton(
                  key: ValueKey('step-toggle-${s.id}'),
                  onPressed: () => isDone(s) ? repo.setStatus(s.id, 'todo') : repo.complete(s.id),
                  icon: Icon(
                    isDone(s) ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                    color: isDone(s) ? k.success : k.textMuted,
                  ),
                ),
                Expanded(
                  child: Text(
                    s.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyLarge?.copyWith(
                      color: isDone(s) ? k.textMuted : k.text,
                      decoration: isDone(s) ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                IconButton(
                  key: ValueKey('step-delete-${s.id}'),
                  tooltip: l.tskDelete,
                  onPressed: () => repo.delete(s.id),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('step-add'),
            controller: _step,
            maxLength: 200,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: l.tskAddStep,
              counterText: '',
              suffixIcon: IconButton(
                key: const ValueKey('step-add-button'),
                tooltip: l.tskAddStep,
                icon: const Icon(Icons.add_rounded),
                onPressed: _addStep,
              ),
            ),
            onSubmitted: (_) => _addStep(),
          ),
        ],
      ),
    );
  }
}
