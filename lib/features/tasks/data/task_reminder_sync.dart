import '../../../core/logging/app_logger.dart';
import '../platform/reminder_scheduler.dart';
import 'tasks_repository.dart';

/// Keeps the phone's alarms in step with the tasks (spec §11): one alarm per
/// open top-level task that has a reminder time in the future. A reminder that
/// already fired is left to the native side, which repeats it every hour until
/// the task is done or snoozed.
class TaskReminderSync {
  TaskReminderSync({required this.tasks, required this.scheduler, required this.texts, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final TasksRepository Function() tasks;
  final ReminderScheduler scheduler;
  final Future<ReminderTexts> Function() texts;
  final DateTime Function() _now;

  Future<void> sync(Iterable<int> ids) async {
    for (final id in ids.toSet()) {
      try {
        await _one(id);
      } catch (e) {
        AppLogger.warn('reminder sync failed', e);
      }
    }
  }

  Future<void> _one(int id) async {
    final t = await tasks().get(id);
    final at = t?.remindAt;
    if (t == null || t.status == 'done' || t.parentId != null || at == null || !at.isAfter(_now())) {
      await scheduler.cancel(id);
      return;
    }
    await scheduler.schedule(ReminderRequest(taskId: id, at: at, title: t.title, texts: await texts()));
  }

  /// At start-up: schedules every open future reminder and drops native ones
  /// whose task is gone, done or no longer has a reminder.
  Future<void> syncAll() async {
    try {
      final open = await tasks().openWithReminder();
      final keep = {
        for (final t in open)
          if (t.parentId == null) t.id,
      };
      for (final id in await scheduler.scheduledIds()) {
        if (!keep.contains(id)) await scheduler.cancel(id);
      }
      final now = _now();
      for (final t in open) {
        final at = t.remindAt;
        if (t.parentId != null || at == null || !at.isAfter(now)) continue;
        await scheduler.schedule(ReminderRequest(taskId: t.id, at: at, title: t.title, texts: await texts()));
      }
    } catch (e) {
      AppLogger.warn('reminder resync failed', e);
    }
  }
}

/// What the notifications and the share sheet left for the app to pick up.
class TaskIntake {
  const TaskIntake({this.openTaskId, this.sharedText});

  final int? openTaskId;
  final String? sharedText;
}

/// Applies Done taps made on notifications while the app was closed, then
/// hands back the task to open and any shared text.
Future<TaskIntake> takeIntake(ReminderScheduler scheduler, TasksRepository tasks) async {
  for (final id in await scheduler.takeDoneActions()) {
    try {
      await tasks.complete(id);
    } catch (e) {
      AppLogger.warn('notification done failed', e);
    }
  }
  final open = await scheduler.takeOpenTask();
  final shared = (await scheduler.takeSharedText())?.trim();
  return TaskIntake(openTaskId: open, sharedText: shared == null || shared.isEmpty ? null : shared);
}
