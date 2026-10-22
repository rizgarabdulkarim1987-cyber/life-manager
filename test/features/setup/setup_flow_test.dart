import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/providers.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/core/l10n/ckb_fallback_localizations.dart';
import 'package:life_manager/core/storage/secure_store.dart';
import 'package:life_manager/core/theme/app_theme.dart';
import 'package:life_manager/features/lock/lock_controller.dart';
import 'package:life_manager/features/lock/pin_service.dart';
import 'package:life_manager/features/setup/setup_flow.dart';
import 'package:life_manager/features/setup/splash_screen.dart';

import '../../helpers/fakes.dart';

void main() {
  late AppDatabase db;
  late PinService pins;
  late ProviderContainer container;
  late int doneCalls;

  Future<void> pump(WidgetTester t, Widget home, {required FakeBiometric bio}) async {
    db = AppDatabase(NativeDatabase.memory());
    pins = PinService(InMemorySecureStore(), FakeKdf());
    doneCalls = 0;
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        pinServiceProvider.overrideWithValue(pins),
        biometricAuthenticatorProvider.overrideWithValue(bio),
      ],
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

  Future<void> enterPin(WidgetTester t, String digits) async {
    for (final d in digits.split('')) {
      await t.tap(find.byKey(ValueKey('pin-key-$d')));
      await t.pump();
    }
    await t.pumpAndSettle();
  }

  testWidgets('completes setup and seeds', (t) async {
    final bio = FakeBiometric(available: true, result: true);
    await pump(t, flow(), bio: bio);

    await tapKey(t, 'lang-en');
    expect(find.text('Choose your language'), findsOneWidget);
    await tapKey(t, 'setup-next');

    await enterPin(t, '123456');
    expect(find.text('Enter the PIN again'), findsOneWidget);
    await enterPin(t, '123456');

    expect(find.byKey(const ValueKey('step-bio')), findsOneWidget);
    await tapKey(t, 'bio-enable');

    expect(find.byKey(const ValueKey('step-warning')), findsOneWidget);
    await tapKey(t, 'ack-checkbox');
    // The button shows a spinner while finishing, so pump frames instead of settling.
    await t.tap(find.byKey(const ValueKey('setup-finish')));
    for (var i = 0; i < 50 && doneCalls == 0; i++) {
      await t.pump(const Duration(milliseconds: 20));
    }

    final s = await db.select(db.appSettingsTable).getSingle();
    expect(s.setupCompleted, isTrue);
    expect(s.localeCode, 'en');
    expect(s.biometricEnabled, isTrue);
    expect(await db.select(db.accounts).get(), hasLength(6));
    expect(await pins.verify('123456'), isA<PinOk>());
    expect(container.read(lockControllerProvider), LockStatus.unlocked);
    expect(doneCalls, 1);
  });

  testWidgets('skips biometric step when unavailable', (t) async {
    await pump(t, flow(), bio: FakeBiometric(available: false, result: false));
    await tapKey(t, 'setup-next');
    await enterPin(t, '123456');
    await enterPin(t, '123456');
    expect(find.byKey(const ValueKey('step-bio')), findsNothing);
    expect(find.byKey(const ValueKey('step-warning')), findsOneWidget);
  });

  testWidgets('PIN confirmation mismatch stays on PIN step', (t) async {
    await pump(t, flow(), bio: FakeBiometric(available: false, result: false));
    await tapKey(t, 'lang-en');
    await tapKey(t, 'setup-next');
    await enterPin(t, '123456');
    await enterPin(t, '654321');
    expect(find.byKey(const ValueKey('step-pin')), findsOneWidget);
    expect(find.text("The PINs don't match. Start again."), findsOneWidget);
    expect(find.text('Create a 6-digit PIN'), findsOneWidget);
  });

  testWidgets('cannot finish without acknowledging backup warning', (t) async {
    await pump(t, flow(), bio: FakeBiometric(available: false, result: false));
    await tapKey(t, 'setup-next');
    await enterPin(t, '123456');
    await enterPin(t, '123456');
    final finish = t.widget<FilledButton>(find.byKey(const ValueKey('setup-finish')));
    expect(finish.onPressed, isNull);
    expect(doneCalls, 0);
  });

  testWidgets('setup fits a small phone in Kurdish', (t) async {
    t.view.physicalSize = const Size(320 * 3, 568 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await pump(t, flow(), bio: FakeBiometric(available: false, result: false));
    await tapKey(t, 'lang-ckb');
    expect(t.takeException(), isNull);
    await tapKey(t, 'setup-next');
    await enterPin(t, '123456');
    await enterPin(t, '123456');
    expect(t.takeException(), isNull);
  });

  testWidgets('splash reports whether setup is done', (t) async {
    bool? result;
    await pump(t, SplashScreen(onResolved: (v) => result = v), bio: FakeBiometric(available: false, result: false));
    expect(result, isFalse);
  });
}
