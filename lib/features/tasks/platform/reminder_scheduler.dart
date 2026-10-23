import 'package:flutter/services.dart';

import '../../../core/logging/app_logger.dart';

/// Words on the notification, in the app language at the time it was scheduled.
class ReminderTexts {
  const ReminderTexts({required this.done, required this.snooze10, required this.snooze1h, required this.channel});

  final String done;
  final String snooze10;
  final String snooze1h;

  /// Name of the notification channel in Android's settings.
  final String channel;
}

class ReminderRequest {
  const ReminderRequest({required this.taskId, required this.at, required this.title, this.body, required this.texts});

  final int taskId;
  final DateTime at;
  final String title;
  final String? body;
  final ReminderTexts texts;
}

class ReminderStatus {
  const ReminderStatus({required this.notifications, required this.exactAlarms});

  /// The notification permission (Android 13+) is granted.
  final bool notifications;

  /// Exact alarms are allowed; otherwise reminders may arrive a few minutes late.
  final bool exactAlarms;

  static const unknown = ReminderStatus(notifications: true, exactAlarms: true);
}

/// Everything Android-specific about reminders, intents and sharing. The real
/// one talks to `ReminderChannel.kt`; tests use a fake.
abstract interface class ReminderScheduler {
  Future<ReminderStatus> status();

  /// Asks for the notification permission; true when granted.
  Future<bool> requestNotifications();

  Future<void> openExactAlarmSettings();

  Future<void> schedule(ReminderRequest r);

  Future<void> cancel(int taskId);

  /// Ids of the reminders the native side still holds (waiting, or nagging).
  Future<List<int>> scheduledIds();

  /// Tasks marked Done from a notification while the app was closed.
  Future<List<int>> takeDoneActions();

  /// The task a tapped notification wants opened, once.
  Future<int?> takeOpenTask();

  /// Text shared into the app from another app, once.
  Future<String?> takeSharedText();
}

/// Talks to `ReminderChannel.kt`. The native side answers with codes only.
final class PlatformReminderScheduler implements ReminderScheduler {
  const PlatformReminderScheduler([this._channel = channel]);

  static const channel = MethodChannel('com.personal.lifemanager/reminders');

  final MethodChannel _channel;

  Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      AppLogger.warn('reminder call failed', e);
      return null;
    }
  }

  @override
  Future<ReminderStatus> status() async {
    final m = await _call<Map<Object?, Object?>>('status');
    if (m == null) return ReminderStatus.unknown;
    return ReminderStatus(notifications: m['notifications'] != false, exactAlarms: m['exact'] != false);
  }

  @override
  Future<bool> requestNotifications() async => await _call<bool>('requestNotifications') ?? false;

  @override
  Future<void> openExactAlarmSettings() => _call<void>('openExactAlarmSettings');

  @override
  Future<void> schedule(ReminderRequest r) => _call<void>('schedule', {
    'id': r.taskId,
    'at': r.at.toUtc().millisecondsSinceEpoch,
    'title': r.title,
    'body': r.body,
    'done': r.texts.done,
    'snooze10': r.texts.snooze10,
    'snooze1h': r.texts.snooze1h,
    'channel': r.texts.channel,
  });

  @override
  Future<void> cancel(int taskId) => _call<void>('cancel', {'id': taskId});

  @override
  Future<List<int>> scheduledIds() async => [...?await _call<List<Object?>>('scheduledIds')].whereType<int>().toList();

  @override
  Future<List<int>> takeDoneActions() async =>
      [...?await _call<List<Object?>>('takeDoneActions')].whereType<int>().toList();

  @override
  Future<int?> takeOpenTask() async {
    final id = await _call<int>('takeOpenTask');
    return id == null || id < 0 ? null : id;
  }

  @override
  Future<String?> takeSharedText() => _call<String>('takeSharedText');
}
