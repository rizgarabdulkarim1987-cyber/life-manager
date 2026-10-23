import 'package:life_manager/features/tasks/platform/reminder_scheduler.dart';

/// A reminder scheduler that only records what it was asked.
class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({this.notifications = true, this.exact = true});

  bool notifications;
  bool exact;
  final scheduled = <int, ReminderRequest>{};
  final cancelled = <int>[];
  final doneActions = <int>[];
  int? openTask;
  String? sharedText;
  int notificationRequests = 0;
  int exactSettingsOpened = 0;

  @override
  Future<ReminderStatus> status() async => ReminderStatus(notifications: notifications, exactAlarms: exact);

  @override
  Future<bool> requestNotifications() async {
    notificationRequests++;
    return notifications;
  }

  @override
  Future<void> openExactAlarmSettings() async => exactSettingsOpened++;

  @override
  Future<void> schedule(ReminderRequest r) async => scheduled[r.taskId] = r;

  @override
  Future<void> cancel(int taskId) async {
    cancelled.add(taskId);
    scheduled.remove(taskId);
  }

  @override
  Future<List<int>> scheduledIds() async => scheduled.keys.toList();

  @override
  Future<List<int>> takeDoneActions() async {
    final out = [...doneActions];
    doneActions.clear();
    return out;
  }

  @override
  Future<int?> takeOpenTask() async {
    final t = openTask;
    openTask = null;
    return t;
  }

  @override
  Future<String?> takeSharedText() async {
    final t = sharedText;
    sharedText = null;
    return t;
  }
}

const fakeReminderTexts = ReminderTexts(done: 'Done', snooze10: '10', snooze1h: '1h', channel: 'Tasks');
