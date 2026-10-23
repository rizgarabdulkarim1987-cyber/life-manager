import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import 'notes_repository.dart';
import 'tasks_repository.dart';

final tasksRepositoryProvider = Provider<TasksRepository>((ref) => TasksRepository(ref.watch(appDatabaseProvider)));

final notesRepositoryProvider = Provider<NotesRepository>((ref) => NotesRepository(ref.watch(appDatabaseProvider)));

/// The list for one segment of the Tasks tab, measured from the moment it is first watched.
final taskViewProvider = StreamProvider.autoDispose.family<List<Task>, TaskView>(
  (ref, v) => ref.watch(tasksRepositoryProvider).watchView(v, DateTime.now()),
);

final taskMonthProvider = StreamProvider.autoDispose.family<List<Task>, DateTime>(
  (ref, month) => ref.watch(tasksRepositoryProvider).watchMonth(month),
);

final notesProvider = StreamProvider.autoDispose<List<Note>>((ref) => ref.watch(notesRepositoryProvider).watchAll());

final openTasksProvider = StreamProvider.autoDispose<List<Task>>(
  (ref) => ref.watch(tasksRepositoryProvider).watchOpen(),
);
