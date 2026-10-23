import 'package:life_manager/features/tasks/reminders/reminder_scheduler.dart';

class FakeNotificationPort implements NotificationPort {
  final scheduled = <int, PlannedReminder>{};
  final cancelled = <int>[];
  var exact = true;

  @override
  Future<void> schedule(int id, String title, DateTime at) async => scheduled[id] = PlannedReminder(title, at);

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }

  @override
  Future<bool> ensurePermissions() async => true;

  @override
  Future<List<int>> pendingIds() async => scheduled.keys.toList();

  @override
  Future<bool> canScheduleExact() async => exact;

  @override
  Future<void> requestExact() async => exact = true;
}
