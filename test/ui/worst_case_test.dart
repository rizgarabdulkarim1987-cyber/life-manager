import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app.dart';
import 'package:life_manager/app/providers.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/core/storage/secure_store.dart';
import 'package:life_manager/features/lock/lock_controller.dart';
import 'package:life_manager/features/lock/pin_service.dart';

import 'package:life_manager/features/capture/data/capture_repository.dart';
import 'package:life_manager/features/capture/domain/proposal.dart';

import '../helpers/app_harness.dart';
import '../helpers/fakes.dart';
import '../helpers/finance_ui.dart';

/// Worst realistic data at the boundary the app reads from (the database):
/// names at the 80-character schema limit, Kurdish and Latin mixed, a long
/// workspace with many accounts, at 320dp, 200% text, RTL.
const _longWs = 'بەڕێوەبەرایەتی پرۆژەکانی بازاڕکردن و دیزاین و ڤیدیۆ بۆ کڕیارانی هەولێر و دهۆک'; // 79
const _longLatin = 'Buzzify Marketing & Creative Studio — Erbil, Sulaymaniyah and Duhok Branches'; // 78

Future<void> seedWorstCase(AppDatabase db) async {
  final now = DateTime.utc(2026);
  final names = [_longWs, _longLatin, 'EO', 'J'];
  for (var w = 0; w < names.length; w++) {
    final ws = await db
        .into(db.workspaces)
        .insert(
          WorkspacesCompanion.insert(
            name: names[w],
            iconKey: 'person',
            colorArgb: 0xFF3B82FF,
            sortOrder: w,
            createdAt: now,
          ),
        );
    final count = w == 0 ? 14 : 1;
    for (var a = 0; a < count; a++) {
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              workspaceId: ws,
              name: a == 0 ? _longLatin : 'Cash ${a.isEven ? 'IQD' : 'USD'} $a',
              kind: 'cash',
              currencyCode: a.isEven ? 'IQD' : 'USD',
              sortOrder: a,
              createdAt: now,
            ),
          );
    }
  }
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  var worstOpen = false;

  Future<void> pumpWorst(WidgetTester t, {required double scale, String locale = 'ckb'}) async {
    t.view.physicalSize = const Size(320 * 3, 640 * 3);
    t.view.devicePixelRatio = 3;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(() {
      t.view.reset();
      t.platformDispatcher.clearTextScaleFactorTestValue();
    });
    worstOpen = true;
    db = AppDatabase(NativeDatabase.memory());
    await seedWorstCase(db);
    await db
        .update(db.appSettingsTable)
        .write(AppSettingsTableCompanion(setupCompleted: const Value(true), localeCode: Value(locale)));
    final pins = PinService(InMemorySecureStore(), FakeKdf());
    await pins.setPin('123456');
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        pinServiceProvider.overrideWithValue(pins),
        biometricAuthenticatorProvider.overrideWithValue(FakeBiometric(available: true, result: false)),
      ],
    );
    container.read(lockControllerProvider.notifier).unlock();
    await t.pumpWidget(UncontrolledProviderScope(container: container, child: const App()));
    await t.pumpAndSettle();
  }

  tearDown(() async {
    if (!worstOpen) return;
    worstOpen = false;
    container.dispose();
    await db.close();
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('home, nav and accounts at ${scale}x text', (t) async {
      await pumpWorst(t, scale: scale);
      await t.drag(find.byType(ListView).first, const Offset(0, -3000));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });

    testWidgets('settings at ${scale}x text', (t) async {
      await pumpWorst(t, scale: scale);
      await t.tap(find.byKey(const ValueKey('open-settings')));
      await t.pumpAndSettle();
      await t.drag(find.byType(ListView).first, const Offset(0, -3000));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });

    testWidgets('lock screen at ${scale}x text', (t) async {
      await pumpWorst(t, scale: scale);
      container.read(lockControllerProvider.notifier).lockNow();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });

    testWidgets('backup screen with keyboard open at ${scale}x text', (t) async {
      await pumpWorst(t, scale: scale);
      await t.tap(find.byKey(const ValueKey('open-settings')));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.byKey(const ValueKey('backup-link')), 100);
      await t.ensureVisible(find.byKey(const ValueKey('backup-link')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('backup-link')));
      await t.pumpAndSettle();
      // Simulate the soft keyboard taking 300dp.
      t.view.viewInsets = FakeViewPadding(bottom: 300 * 3);
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('backup-pw')),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await t.ensureVisible(find.byKey(const ValueKey('backup-pw')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('backup-pw')));
      await t.enterText(find.byKey(const ValueKey('backup-pw')), 'Correct-Horse-9');
      await t.pump();
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('restore-backup')),
        100,
        scrollable: find
            .ancestor(of: find.byKey(const ValueKey('create-backup')), matching: find.byType(Scrollable))
            .first,
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }

  group('phase 2 screens at 320 px, Sorani, 2x text', () {
    final longText = 'تێبینی درێژ ' * 6; // past 70 characters
    const huge = 999999999999;

    Future<ProviderContainer> open(WidgetTester t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        t.view.reset();
        t.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final c = await pumpApp(
        t,
        locale: 'ckb',
        overrides: [secureStoreProvider.overrideWithValue(InMemorySecureStore())],
      );
      final acc = await accountId(c, 'Personal', 'IQD');
      for (var i = 0; i < 1500; i++) {
        await txRepo(c).addSimple(
          type: i.isEven ? 'expense' : 'income',
          accountId: acc,
          amountMinor: i == 0 ? huge : 1000 + i,
          occurredAt: DateTime.now().toUtc().subtract(Duration(hours: i)),
          description: i % 7 == 0 ? longText : null,
        );
      }
      return c;
    }

    for (final route in ['/finance', '/finance/history', '/finance/tx/new?type=expense', '/finance/reports']) {
      testWidgets(route, (t) async {
        final c = await open(t);
        await pushRoute(t, c, route);
        await t.drag(find.byType(Scrollable).first, const Offset(0, -2000));
        await t.pump(const Duration(milliseconds: 300));
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('inbox with long text, voice rows and an empty transcript', (t) async {
      final c = await open(t);
      final repo = CaptureRepository(dbOf(c));
      for (var i = 0; i < 20; i++) {
        await dbWrite(t, () => repo.createText(longText));
        await dbWrite(t, () => repo.createVoice(Uint8List.fromList(List.filled(32, 3))));
      }
      await pushRoute(t, c, '/inbox');
      expect(t.takeException(), isNull);
      await t.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await t.pump(const Duration(milliseconds: 300));
      expect(t.takeException(), isNull);
    });

    testWidgets('capture review with long descriptions and a huge amount', (t) async {
      final c = await open(t);
      final acc = await accountId(c, 'Personal', 'IQD');
      final repo = CaptureRepository(dbOf(c));
      final id = await dbWrite(t, () => repo.createText(longText));
      await dbWrite(
        t,
        () => repo.setParsed(id, [
          for (var i = 0; i < 6; i++)
            MoneyProposal(
              type: IntentType.expense,
              confidence: 90,
              amountMinor: huge,
              currency: 'IQD',
              accountId: acc,
              description: longText,
            ),
          TaskProposal(title: longText, confidence: 100),
        ], by: 'ai'),
      );
      await pushRoute(t, c, '/capture/$id');
      await t.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await t.pump(const Duration(milliseconds: 300));
      expect(t.takeException(), isNull);
    });
  });
}
