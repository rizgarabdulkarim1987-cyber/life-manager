import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/router.dart';
import 'package:life_manager/features/capture/domain/proposal.dart';
import 'package:life_manager/features/tasks/data/tasks_providers.dart';
import 'package:life_manager/features/tasks/data/tasks_repository.dart';
import 'package:life_manager/features/tasks/ui/meetings_screen.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_reminders.dart';
import '../helpers/finance_ui.dart';

void main() {
  final long = List.filled(30, 'مهمەی درێژ').join(' ').substring(0, 190);

  for (final scale in [1.0, 2.0]) {
    group('tasks at 320 dp, Sorani, ${scale}x text', () {
      Future<ProviderContainer> open(WidgetTester t) async {
        t.view.physicalSize = const Size(320, 640);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          t.view.reset();
          t.platformDispatcher.clearTextScaleFactorTestValue();
        });
        return pumpApp(
          t,
          locale: 'ckb',
          overrides: [reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler(notifications: false))],
        );
      }

      Future<void> go(WidgetTester t, ProviderContainer c, String location) async {
        c.read(routerProvider).push(location);
        await settle(t);
        expect(t.takeException(), isNull);
      }

      Future<int> add(WidgetTester t, ProviderContainer c, TaskInput i) =>
          dbWrite(t, () => c.read(tasksRepositoryProvider).create(i));

      testWidgets('list of 200 long tasks with every view and the warning banner', (t) async {
        final c = await open(t);
        final repo = c.read(tasksRepositoryProvider);
        final now = DateTime.now();
        await t.runAsync(() async {
          for (var i = 0; i < 200; i++) {
            await repo.create(
              TaskInput(
                title: '$i $long',
                dueAt: now.add(Duration(hours: i - 100)),
                priority: i.isEven ? 'urgent' : 'low',
                tags: ['client-with-a-long-tag-$i', 'another-quite-long-tag', 'third'],
                recurrence: i % 5 == 0 ? 'daily' : null,
                remindAt: now.add(const Duration(days: 3)),
                workspaceId: null,
              ),
            );
          }
        });
        await go(t, c, '/tasks');
        await t.tap(find.byKey(const ValueKey('nav-2')));
        await settle(t);
        expect(find.byKey(const ValueKey('reminder-banner')), findsOneWidget);
        for (final v in ['all', 'overdue', 'upcoming', 'week', 'completed']) {
          await t.drag(find.byKey(const ValueKey('tasks-list')), const Offset(0, 20000));
          await t.pump(const Duration(milliseconds: 300));
          final chip = find.byKey(ValueKey('tasks-view-$v'));
          await t.ensureVisible(chip);
          await t.tap(chip);
          await settle(t);
          await t.drag(
            find.byKey(const ValueKey('tasks-list')).hitTestable(),
            const Offset(0, -4000),
            warnIfMissed: false,
          );
          await t.pump(const Duration(milliseconds: 300));
          expect(t.takeException(), isNull, reason: v);
        }
      });

      testWidgets('detail with long text, tags, 20 steps and every fact', (t) async {
        final c = await open(t);
        final id = await add(
          t,
          c,
          TaskInput(
            title: long,
            notes: List.filled(40, 'تێبینی درێژ').join('\n'),
            dueAt: DateTime.now().add(const Duration(days: 2)),
            remindAt: DateTime.now().add(const Duration(days: 1)),
            recurrence: 'monthly',
            recurrenceInterval: 12,
            priority: 'urgent',
            tags: List.generate(12, (i) => 'long-tag-number-$i'),
          ),
        );
        for (var i = 0; i < 20; i++) {
          await dbWrite(t, () => c.read(tasksRepositoryProvider).addStep(id, '$i $long'));
        }
        await go(t, c, '/tasks/$id');
        await t.drag(find.byType(Scrollable).last, const Offset(0, -5000));
        await t.pump(const Duration(milliseconds: 300));
        expect(t.takeException(), isNull);
      });

      testWidgets('form with the keyboard open, a long title and a repeating date', (t) async {
        final c = await open(t);
        await go(t, c, '/tasks/new?due=${DateTime.now().toIso8601String()}');
        t.view.viewInsets = const FakeViewPadding(bottom: 300);
        await t.pumpAndSettle();
        await t.enterText(find.byKey(const ValueKey('task-title')), long);
        FocusManager.instance.primaryFocus?.unfocus();
        await t.pump();
        final page = find
            .descendant(
              of: find.byKey(const ValueKey('task-form')),
              matching: find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical),
            )
            .first;
        await t.scrollUntilVisible(find.byKey(const ValueKey('task-repeat')), 200, scrollable: page);
        await t.tap(find.byKey(const ValueKey('task-repeat')));
        await settle(t);
        await t.tap(find.text('هەموو مانگێک').last);
        await settle(t);
        expect(find.byKey(const ValueKey('task-interval')), findsOneWidget);
        expect(t.takeException(), isNull);
        t.view.resetViewInsets();
      });

      testWidgets('calendar with many tasks on one day', (t) async {
        final c = await open(t);
        final today = DateTime.now();
        await t.runAsync(() async {
          for (var i = 0; i < 40; i++) {
            await c.read(tasksRepositoryProvider).create(TaskInput(title: '$i $long', dueAt: today));
          }
        });
        await go(t, c, '/tasks/calendar');
        await t.drag(find.byType(Scrollable).last, const Offset(0, -3000));
        await t.pump(const Duration(milliseconds: 300));
        expect(t.takeException(), isNull);
      });

      testWidgets('meeting notes list, editor and a 50-point action sheet', (t) async {
        final c = await open(t);
        final notes = c.read(meetingNotesRepositoryProvider);
        await t.runAsync(() async {
          for (var i = 0; i < 30; i++) {
            await notes.create(title: '$i $long', body: List.filled(30, 'دەق').join('\n'));
          }
        });
        await go(t, c, '/tasks/meetings');
        await t.drag(find.byType(Scrollable).last, const Offset(0, -4000));
        await t.pump(const Duration(milliseconds: 300));
        expect(t.takeException(), isNull);

        await go(t, c, '/tasks/meetings/new');
        expect(t.takeException(), isNull);

        unawaited(
          showModalBottomSheet<void>(
            context: t.element(find.byKey(const ValueKey('meeting-editor'))),
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => ActionPointsSheet(
              points: [for (var i = 0; i < 50; i++) TaskProposal(title: '$i $long', confidence: 100)],
            ),
          ),
        );
        await settle(t);
        expect(find.byKey(const ValueKey('action-points')), findsOneWidget);
        await t.drag(find.byType(Scrollable).last, const Offset(0, -6000));
        await t.pump(const Duration(milliseconds: 300));
        expect(t.takeException(), isNull);
      });
    });
  }
}
