import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/lock/lock_controller.dart';
import 'package:life_manager/features/tasks/reminders/reminder_service.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/fakes.dart';

void main() {
  testWidgets('notifications start only after the unlock, not while the lock prompt is up', (t) async {
    final c = await pumpApp(t, locale: 'en', startLocked: true, bio: FakeBiometric(result: false));
    expect(c.read(reminderServiceProvider).started, isFalse);
    c.read(lockControllerProvider.notifier).unlock();
    await t.pumpAndSettle();
    expect(c.read(reminderServiceProvider).started, isTrue);
  });
}
