import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/providers.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/core/l10n/ckb_fallback_localizations.dart';
import 'package:life_manager/core/theme/app_theme.dart';
import 'package:life_manager/features/lock/lock_controller.dart';
import 'package:life_manager/features/lock/lock_screen.dart';

import '../../helpers/fakes.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  Future<void> pump(WidgetTester t, {required FakeBiometric bio, Locale locale = const Locale('en')}) async {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db), biometricAuthenticatorProvider.overrideWithValue(bio)],
    );
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          locale: locale,
          supportedLocales: kSupportedLocales,
          localizationsDelegates: appLocalizationDelegates,
          home: const LockScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  testWidgets('prompts face or fingerprint at once and unlocks on success', (t) async {
    final bio = FakeBiometric(deviceSupported: true, result: true);
    await pump(t, bio: bio);
    expect(bio.prompts, 1);
    expect(container.read(lockControllerProvider), LockStatus.unlocked);
    expect(container.read(lockControllerProvider.notifier).lastAuthAt, isNotNull);
  });

  testWidgets('a failed prompt stays locked and offers to try again', (t) async {
    final bio = FakeBiometric(deviceSupported: true, result: false);
    await pump(t, bio: bio);
    expect(container.read(lockControllerProvider), LockStatus.locked);
    expect(find.byKey(const ValueKey('unlock-retry')), findsOneWidget);
    expect(find.byKey(const ValueKey('pin-key-1')), findsNothing);
    await t.tap(find.byKey(const ValueKey('unlock-retry')));
    await t.pumpAndSettle();
    expect(bio.prompts, 2);
  });

  testWidgets('no screen lock explains why and opens security settings', (t) async {
    final calls = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('life_manager/intents'), (c) async {
      calls.add(c.method);
      return null;
    });
    final bio = FakeBiometric(deviceSupported: false, result: false);
    await pump(t, bio: bio);
    expect(bio.prompts, 0);
    expect(find.byKey(const ValueKey('no-screen-lock')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('open-security-settings')));
    await t.pumpAndSettle();
    expect(calls, ['openSecuritySettings']);
  });

  testWidgets('small phone does not overflow', (t) async {
    t.view.physicalSize = const Size(320 * 3, 568 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await pump(t, bio: FakeBiometric(deviceSupported: false, result: false), locale: const Locale('ckb'));
    expect(t.takeException(), isNull);
  });
}
