import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/restart_scope.dart';
import 'package:life_manager/app/startup_error.dart';

void main() {
  testWidgets('a failed start shows an error with retry instead of a blank screen', (t) async {
    var attempts = 0;
    await t.pumpWidget(
      RestartScope(
        loading: const SizedBox(),
        failed: (retry) => StartupErrorScreen(onRetry: retry),
        build: () async {
          attempts++;
          if (attempts == 1) throw StateError('db locked');
          return const Directionality(textDirection: TextDirection.ltr, child: Text('opened'));
        },
      ),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('startup-retry')), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('startup-retry')));
    await t.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('opened'), findsOneWidget);
  });
}
