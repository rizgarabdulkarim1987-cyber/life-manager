import '../../../core/db/app_database.dart';
import '../data/tasks_repository.dart';

/// Local notifications behind an interface, so the schedule can be tested without a phone.
abstract interface class NotificationPort {
  Future<void> schedule(int id, String title, DateTime at);
  Future<void> cancel(int id);

  /// Asks for the notification permission (Android 13+); true when notifications can show.
  Future<bool> ensurePermissions();

  /// Ids of the notifications waiting to fire.
  Future<List<int>> pendingIds();

  /// Whether exact alarms are allowed; without them reminders still fire, a little late.
  Future<bool> canScheduleExact();
  Future<void> requestExact();
}

/// 09:00 is when a date-only task, and an overdue nudge, fire.
const kReminderHour = 9;

class PlannedReminder {
  const PlannedReminder(this.title, this.at);

  final String title;
  final DateTime at;

  @override
  bool operator ==(Object other) => other is PlannedReminder && other.title == title && other.at.isAtSameMomentAs(at);

  @override
  int get hashCode => Object.hash(title, at.millisecondsSinceEpoch);
}

/// The next 09:00 strictly after [now].
DateTime nextNudge(DateTime now) {
  final today = DateTime(now.year, now.month, now.day, kReminderHour);
  return today.isAfter(now) ? today : DateTime(now.year, now.month, now.day + 1, kReminderHour);
}

/// One notification per open task with a date, keyed by the task id: at its time
/// (09:00 on its day when it has no time), or at the next 09:00 when that has passed.
Map<int, PlannedReminder> planReminders(List<Task> open, DateTime now) {
  final out = <int, PlannedReminder>{};
  for (final t in open) {
    final due = t.dueAt?.toLocal();
    if (t.status != 'open' || due == null) continue;
    final at = t.hasTime ? due : DateTime(due.year, due.month, due.day, kReminderHour);
    out[t.id] = PlannedReminder(t.title, at.isAfter(now) ? at : nextNudge(now));
  }
  return out;
}

class ReminderScheduler {
  ReminderScheduler(this._port);

  final NotificationPort _port;

  /// Schedules every planned reminder and cancels the ones whose task is done, gone or undated.
  Future<void> sync(List<Task> open, DateTime now) async {
    final plan = planReminders(open, now);
    for (final id in await _port.pendingIds()) {
      if (!plan.containsKey(id)) await _port.cancel(id);
    }
    for (final MapEntry(:key, :value) in plan.entries) {
      await _port.schedule(key, value.title, value.at);
    }
  }
}

/// What the notification buttons do.
enum ReminderAction { done, snooze10, snooze60, snoozeTomorrow }

class ReminderActions {
  ReminderActions(this._tasks);

  final TasksRepository _tasks;

  Future<void> handle(ReminderAction a, int taskId, DateTime now) async {
    switch (a) {
      case ReminderAction.done:
        await _tasks.complete(taskId);
      case ReminderAction.snooze10:
        await _snooze(taskId, now.add(const Duration(minutes: 10)));
      case ReminderAction.snooze60:
        await _snooze(taskId, now.add(const Duration(hours: 1)));
      case ReminderAction.snoozeTomorrow:
        await _snooze(taskId, DateTime(now.year, now.month, now.day + 1, kReminderHour));
    }
  }

  /// A snooze moves the task's own time, so the list and the next reminder agree.
  Future<void> _snooze(int taskId, DateTime to) async {
    if (await _tasks.get(taskId) == null) return;
    await _tasks.setDue(taskId, to, hasTime: true);
  }
}
