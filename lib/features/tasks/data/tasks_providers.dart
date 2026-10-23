import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../platform/reminder_scheduler.dart';
import 'task_reminder_sync.dart';
import 'tasks_repository.dart';

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) => const PlatformReminderScheduler());

final Provider<TaskReminderSync> taskReminderSyncProvider = Provider<TaskReminderSync>(
  (ref) => TaskReminderSync(
    tasks: () => ref.read(tasksRepositoryProvider),
    scheduler: ref.watch(reminderSchedulerProvider),
    texts: () async {
      final s = await ref.read(settingsRepositoryProvider).get();
      final l = lookupAppLocalizations(Locale(s.localeCode));
      return ReminderTexts(
        done: l.tskNotifDone,
        snooze10: l.tskNotifSnooze10,
        snooze1h: l.tskNotifSnooze1h,
        channel: l.tskNotifChannel,
      );
    },
  ),
);

final Provider<TasksRepository> tasksRepositoryProvider = Provider<TasksRepository>(
  (ref) =>
      TasksRepository(ref.watch(appDatabaseProvider), onChanged: (ids) => ref.read(taskReminderSyncProvider).sync(ids)),
);

final meetingNotesRepositoryProvider = Provider<MeetingNotesRepository>(
  (ref) => MeetingNotesRepository(ref.watch(appDatabaseProvider)),
);

/// Every top-level task, finished or not; the screens filter.
final tasksProvider = StreamProvider<List<Task>>((ref) => ref.watch(tasksRepositoryProvider).watchTop());

final taskProvider = StreamProvider.family<Task?, int>((ref, id) => ref.watch(tasksRepositoryProvider).watchOne(id));

final taskStepsProvider = StreamProvider.family<List<Task>, int>(
  (ref, id) => ref.watch(tasksRepositoryProvider).watchSteps(id),
);

final meetingNotesProvider = StreamProvider<List<MeetingNote>>(
  (ref) => ref.watch(meetingNotesRepositoryProvider).watchAll(),
);

final reminderStatusProvider = FutureProvider<ReminderStatus>((ref) => ref.watch(reminderSchedulerProvider).status());
