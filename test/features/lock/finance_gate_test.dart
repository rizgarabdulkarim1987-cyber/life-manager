import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/lock/lock_controller.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fakes.dart';
import '../../helpers/finance_ui.dart';

void main() {
  for (final route in [
    '/finance/reports',
    '/finance/buckets',
    '/finance/budgets',
    '/finance/debts',
    '/finance/history',
  ]) {
    testWidgets('$route asks again when the last unlock is older than a minute', (t) async {
      final c = await pumpApp(t, locale: 'en', bio: FakeBiometric(result: false));
      c.read(lockControllerProvider.notifier).lastAuthAt = DateTime.now().subtract(const Duration(minutes: 5));
      await pushRoute(t, c, route);
      expect(find.byKey(const ValueKey('sensitive-unlock')), findsOneWidget);
    });
  }
}
