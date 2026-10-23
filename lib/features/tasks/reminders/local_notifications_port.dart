import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/logging/app_logger.dart';
import 'reminder_scheduler.dart';

/// The words on the notification, in the owner's language.
class NotificationLabels {
  const NotificationLabels({
    required this.channelName,
    required this.channelDescription,
    required this.done,
    required this.snooze1h,
    required this.tomorrow,
  });

  final String channelName;
  final String channelDescription;
  final String done;
  final String snooze1h;
  final String tomorrow;
}

const kActionDone = 'done';
const kActionSnooze10 = 'snooze10';
const kActionSnooze60 = 'snooze60';
const kActionTomorrow = 'tomorrow';

ReminderAction? reminderActionOf(String? id) => switch (id) {
  kActionDone => ReminderAction.done,
  kActionSnooze10 => ReminderAction.snooze10,
  kActionSnooze60 => ReminderAction.snooze60,
  kActionTomorrow => ReminderAction.snoozeTomorrow,
  _ => null,
};

/// Android notifications through flutter_local_notifications. Everything stays on the phone.
class LocalNotificationsPort implements NotificationPort {
  LocalNotificationsPort({this.labels});

  NotificationLabels? labels;
  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// [onResponse] gets the action id and the task id when a button or the notification is tapped.
  Future<void> init(void Function(String? actionId, int? taskId) onResponse) async {
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } on Object catch (e) {
      AppLogger.warn('time zone unknown, using UTC', e.runtimeType);
    }
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (r) => onResponse(r.actionId, int.tryParse(r.payload ?? '')),
    );
    _ready = true;
  }

  @override
  Future<bool> ensurePermissions() async => await _android?.requestNotificationsPermission() ?? false;

  @override
  Future<bool> canScheduleExact() async => await _android?.canScheduleExactNotifications() ?? false;

  @override
  Future<void> requestExact() async {
    await _android?.requestExactAlarmsPermission();
  }

  @override
  Future<List<int>> pendingIds() async {
    if (!_ready) return const [];
    return [for (final p in await _plugin.pendingNotificationRequests()) p.id];
  }

  @override
  Future<void> cancel(int id) async {
    if (_ready) await _plugin.cancel(id: id);
  }

  @override
  Future<void> schedule(int id, String title, DateTime at) async {
    if (!_ready) return;
    final l = labels;
    final exact = await canScheduleExact();
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      payload: '$id',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          l?.channelName ?? 'Reminders',
          channelDescription: l?.channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction(kActionDone, l?.done ?? 'Done', showsUserInterface: true),
            AndroidNotificationAction(kActionSnooze60, l?.snooze1h ?? '1 h', showsUserInterface: true),
            AndroidNotificationAction(kActionTomorrow, l?.tomorrow ?? 'Tomorrow', showsUserInterface: true),
          ],
        ),
      ),
      androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}

/// Used wherever there are no Android notifications (tests, desktop): does nothing.
class NoNotificationsPort implements NotificationPort {
  @override
  Future<bool> canScheduleExact() async => true;

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<bool> ensurePermissions() async => false;

  @override
  Future<List<int>> pendingIds() async => const [];

  @override
  Future<void> requestExact() async {}

  @override
  Future<void> schedule(int id, String title, DateTime at) async {}
}

bool get notificationsSupported => !kIsWeb && Platform.isAndroid;
