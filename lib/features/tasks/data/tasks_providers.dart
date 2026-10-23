import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import 'notes_repository.dart';
import 'tasks_repository.dart';

final tasksRepositoryProvider = Provider<TasksRepository>((ref) => TasksRepository(ref.watch(appDatabaseProvider)));

final notesRepositoryProvider = Provider<NotesRepository>((ref) => NotesRepository(ref.watch(appDatabaseProvider)));
