import 'package:flutter/material.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../domain/task_views.dart';
import 'task_format.dart';

/// One row of a task list. The circle completes (or reopens) the task.
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.workspaceName,
    required this.onTap,
    required this.onToggle,
  });

  final Task task;
  final String? workspaceName;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final done = isDone(task);
    final due = dueLocal(task);
    final overdue = isOverdue(task, DateTime.now());
    final tags = task.tags.split(',').where((t) => t.isNotEmpty).take(2);
    final small = text.bodySmall?.copyWith(color: k.textMuted);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 16, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                key: ValueKey('task-toggle-${task.id}'),
                tooltip: done ? l.tskReopen : l.tskMarkDone,
                onPressed: onToggle,
                icon: Icon(
                  done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: done ? k.success : priorityColor(k, task.priority),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyLarge?.copyWith(
                          color: done ? k.textMuted : k.text,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (due != null)
                            Text(
                              formatDateTime(context, due, allDay: task.dueAllDay),
                              style: small?.copyWith(color: overdue ? k.danger : k.textMuted),
                            ),
                          if (task.priority == 'high' || task.priority == 'urgent')
                            Text(
                              priorityLabel(l, task.priority),
                              style: small?.copyWith(color: priorityColor(k, task.priority)),
                            ),
                          if (task.recurrence != null) Icon(Icons.repeat_rounded, size: 14, color: k.textMuted),
                          if (task.remindAt != null && !done)
                            Icon(Icons.notifications_none_rounded, size: 14, color: k.textMuted),
                          if (workspaceName != null) Text(workspaceName!, style: small),
                          for (final t in tags) Text('#$t', style: small),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
