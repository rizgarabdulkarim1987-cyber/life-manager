import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/l10n/ckb_fallback_localizations.dart';
import 'package:life_manager/core/theme/app_theme.dart';
import 'package:life_manager/features/lock/lock_controller.dart';
import 'package:life_manager/features/lock/sensitive_gate.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fakes.dart';
import '../../helpers/finance_ui.dart';

Future<ProviderContainer> _pump(WidgetTester t, FakeBiometric bio) async {
  final c = ProviderContainer(overrides: [biometricAuthenticatorProvider.overrideWithValue(bio)]);
  addTearDown(c.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        locale: const Locale('en'),
        supportedLocales: kSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        home: const SensitiveGate(child: Text('secret')),
      ),
    ),
  );
  return c;
}

void main() {
  test('authFresh is true for 60 s after unlocking', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(lockControllerProvider.notifier);
    expect(n.authFresh(DateTime.now()), isFalse);
    n.unlock();
    final at = n.lastAuthAt!;
    expect(n.authFresh(at.add(const Duration(seconds: 59))), isTrue);
    expect(n.authFresh(at.add(const Duration(seconds: 61))), isFalse);
  });

  testWidgets('a fresh unlock shows the section without asking', (t) async {
    final bio = FakeBiometric(result: true);
    final c = ProviderContainer(overrides: [biometricAuthenticatorProvider.overrideWithValue(bio)]);
    addTearDown(c.dispose);
    c.read(lockControllerProvider.notifier).unlock();
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          locale: const Locale('en'),
          supportedLocales: kSupportedLocales,
          localizationsDelegates: appLocalizationDelegates,
          home: const SensitiveGate(child: Text('secret')),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('secret'), findsOneWidget);
    expect(bio.prompts, 0);
  });

  testWidgets('a stale unlock asks again before showing the section', (t) async {
    final bio = FakeBiometric(result: false);
    await _pump(t, bio);
    await t.pumpAndSettle();
    expect(bio.prompts, 1);
    expect(find.text('secret'), findsNothing);
    expect(find.byKey(const ValueKey('sensitive-unlock')), findsOneWidget);
    bio.result = true;
    await t.tap(find.byKey(const ValueKey('sensitive-unlock')));
    await t.pumpAndSettle();
    expect(find.text('secret'), findsOneWidget);
  });

  testWidgets('the Finance tab asks again when the unlock is older than a minute', (t) async {
    final bio = FakeBiometric(result: false);
    final c = await pumpApp(t, locale: 'en', bio: bio);
    c.read(lockControllerProvider.notifier).lastAuthAt = DateTime.now().subtract(const Duration(minutes: 2));
    await openFinance(t);
    expect(bio.prompts, 1);
    expect(find.byKey(const ValueKey('sensitive-unlock')), findsOneWidget);
  });
}
