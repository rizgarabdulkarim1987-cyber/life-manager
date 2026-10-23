import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/logging/app_logger.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../data/tasks_providers.dart';
import 'local_notifications_port.dart';
import 'reminder_scheduler.dart';

final notificationPortProvider = Provider<NotificationPort>(
  (ref) => notificationsSupported ? LocalNotificationsPort() : NoNotificationsPort(),
);

/// False when the phone refuses exact alarms: reminders then fire a little late (Tasks shows a banner).
final exactAlarmsAllowedProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(notificationPortProvider).canScheduleExact(),
);

/// Keeps the phone's scheduled notifications in step with the open tasks: on app start, on every task
/// change, and when a notification button is pressed.
class ReminderService {
  ReminderService(this._ref);

  final Ref _ref;
  var _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    final port = _ref.read(notificationPortProvider);
    try {
      if (port is LocalNotificationsPort) {
        await port.init(_onResponse);
        await port.ensurePermissions();
      }
    } on Object catch (e) {
      AppLogger.warn('notifications could not start', e.runtimeType);
      return;
    }
    _ref.listen(openTasksProvider, (_, next) {
      final open = next.value;
      if (open != null) unawaited(_sync(port, open));
    }, fireImmediately: true);
  }

  Future<void> _sync(NotificationPort port, List<Task> open) async {
    try {
      if (port is LocalNotificationsPort) {
        final code = _ref.read(settingsProvider).value?.localeCode ?? 'ar';
        final l = lookupAppLocalizations(Locale(code));
        port.labels = NotificationLabels(
          channelName: l.notifChannelName,
          channelDescription: l.notifChannelDesc,
          done: l.notifDone,
          snooze1h: l.notifSnooze1h,
          tomorrow: l.notifTomorrow,
        );
      }
      await ReminderScheduler(port).sync(open, DateTime.now());
    } on Object catch (e) {
      AppLogger.warn('reminder sync failed', e.runtimeType);
    }
  }

  Future<void> _onResponse(String? actionId, int? taskId) async {
    final action = reminderActionOf(actionId);
    if (action == null || taskId == null) return;
    await ReminderActions(_ref.read(tasksRepositoryProvider)).handle(action, taskId, DateTime.now());
  }
}

final reminderServiceProvider = Provider<ReminderService>(ReminderService.new);
