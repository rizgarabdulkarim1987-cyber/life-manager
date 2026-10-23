import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/providers.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/core/l10n/ckb_fallback_localizations.dart';
import 'package:life_manager/core/theme/app_theme.dart';
import 'package:life_manager/features/lock/lock_controller.dart';
import 'package:life_manager/features/setup/setup_flow.dart';
import 'package:life_manager/features/setup/splash_screen.dart';

import '../../helpers/fakes.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late int doneCalls;

  Future<void> pump(WidgetTester t, Widget home, {required FakeBiometric bio}) async {
    db = AppDatabase(NativeDatabase.memory());
    doneCalls = 0;
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db), biometricAuthenticatorProvider.overrideWithValue(bio)],
    );
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: buildAppTheme(Brightness.dark),
            // Follows the stored setting so the language step switches live.
            locale: Locale(ref.watch(settingsProvider).value?.localeCode ?? 'ar'),
            supportedLocales: kSupportedLocales,
            localizationsDelegates: appLocalizationDelegates,
            home: home,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Widget flow() => SetupFlow(onDone: () => doneCalls++);

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> tapKey(WidgetTester t, String key) async {
    await t.tap(find.byKey(ValueKey(key)));
    await t.pumpAndSettle();
  }

  Future<void> finish(WidgetTester t) async {
    await tapKey(t, 'ack-checkbox');
    // The button shows a spinner while finishing, so pump frames instead of settling.
    await t.tap(find.byKey(const ValueKey('setup-finish')));
    for (var i = 0; i < 50 && doneCalls == 0; i++) {
      await t.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('completes setup and seeds without any PIN', (t) async {
    await pump(t, flow(), bio: FakeBiometric());
    await tapKey(t, 'lang-en');
    expect(find.text('Choose your language'), findsOneWidget);
    await tapKey(t, 'setup-next');
    expect(find.byKey(const ValueKey('pin-key-1')), findsNothing);
    expect(find.byKey(const ValueKey('step-warning')), findsOneWidget);
    await finish(t);

    final s = await db.select(db.appSettingsTable).getSingle();
    expect(s.setupCompleted, isTrue);
    expect(s.localeCode, 'en');
    expect(await db.select(db.accounts).get(), hasLength(6));
    expect(container.read(lockControllerProvider), LockStatus.unlocked);
    expect(doneCalls, 1);
  });

  testWidgets('cannot finish without acknowledging backup warning', (t) async {
    await pump(t, flow(), bio: FakeBiometric());
    await tapKey(t, 'setup-next');
    final finish = t.widget<FilledButton>(find.byKey(const ValueKey('setup-finish')));
    expect(finish.onPressed, isNull);
    expect(doneCalls, 0);
  });

  testWidgets('setup fits a small phone in Kurdish', (t) async {
    t.view.physicalSize = const Size(320 * 3, 568 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await pump(t, flow(), bio: FakeBiometric());
    await tapKey(t, 'lang-ckb');
    expect(t.takeException(), isNull);
    await tapKey(t, 'setup-next');
    expect(t.takeException(), isNull);
  });

  testWidgets('splash reports whether setup is done', (t) async {
    bool? result;
    await pump(t, SplashScreen(onResolved: (v) => result = v), bio: FakeBiometric());
    expect(result, isFalse);
  });
}
