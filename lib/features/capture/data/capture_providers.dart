import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import 'capture_repository.dart';

final captureRepositoryProvider = Provider<CaptureRepository>(
  (ref) => CaptureRepository(ref.watch(appDatabaseProvider)),
);

/// Captures waiting in the Inbox, newest first.
final pendingCapturesProvider = StreamProvider<List<Capture>>(
  (ref) => ref.watch(captureRepositoryProvider).watchPending(),
);
