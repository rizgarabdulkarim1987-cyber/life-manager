import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/providers.dart';
import 'package:life_manager/core/net/http_port.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/core/storage/secure_store.dart';
import 'package:life_manager/features/capture/ai/ai_config.dart';
import 'package:life_manager/features/capture/data/capture_repository.dart';
import 'package:life_manager/features/capture/speech/model_manager.dart';
import 'package:life_manager/features/capture/speech/recorder.dart';
import 'package:life_manager/features/capture/speech/speech_to_text.dart' show modelManagerProvider;

import '../../../helpers/app_harness.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/finance_ui.dart';

void main() {
  late Directory dir;
  late InMemorySecureStore store;
  late FakeHttpPort http;
  late FakeRecorder rec;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('composer');
    store = InMemorySecureStore();
    http = FakeHttpPort((_) => const HttpReply(500, 'down'));
    rec = FakeRecorder();
  });
  tearDown(() => dir.delete(recursive: true));

  Future<ProviderContainer> open(WidgetTester t) => pumpApp(
    t,
    locale: 'en',
    overrides: [
      secureStoreProvider.overrideWithValue(store),
      httpPortProvider.overrideWithValue(http),
      modelManagerProvider.overrideWithValue(ModelManager(http, () async => dir)),
      audioRecorderProvider.overrideWithValue(rec),
    ],
  );

  Future<void> spin(WidgetTester t, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await t.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('composer is on every tab', (t) async {
    await open(t);
    for (final i in [1, 2, 3, 0]) {
      await t.tap(find.byKey(ValueKey('nav-$i')));
      await settle(t);
      expect(find.byKey(const ValueKey('composer-field')), findsWidgets, reason: 'tab $i');
    }
  });

  testWidgets('typing and send opens chat with reply', (t) async {
    final c = await open(t);
    await t.tap(find.byKey(const ValueKey('nav-2')));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('composer-field')).first, 'دفعت 40 الف تكسي');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('composer-send')).first);
    await spin(t);
    expect(find.byKey(const ValueKey('chat-sheet')), findsOneWidget);
    expect(find.textContaining('40,000'), findsWidgets);
    final ok = find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('card-ok-'),
    );
    expect(ok, findsOneWidget);
    await t.tap(ok);
    await spin(t);
    final txs = await t.runAsync(() => dbOf(c).select(dbOf(c).transactions).get());
    expect(txs!.single.amountMinor, 40000);
    expect(
      find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('undo-'),
      ),
      findsOneWidget,
    );
    expect(http.requests, isEmpty, reason: 'online AI is off');
  });

  testWidgets('a saved card in the chat hides its amount again, while the open one shows what was typed', (t) async {
    await pumpApp(
      t,
      locale: 'en',
      revealMoney: false,
      overrides: [
        secureStoreProvider.overrideWithValue(store),
        httpPortProvider.overrideWithValue(http),
        modelManagerProvider.overrideWithValue(ModelManager(http, () async => dir)),
      ],
    );
    await t.tap(find.byKey(const ValueKey('nav-2')));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('composer-field')).first, 'دفعت 40 الف تكسي');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('composer-send')).first);
    await spin(t);
    expect(find.textContaining('40,000'), findsWidgets, reason: 'the owner just typed it');
    await t.tap(
      find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('card-ok-'),
      ),
    );
    await spin(t);
    expect(find.textContaining('40,000'), findsNothing, reason: 'after saving, the figure is masked again');
    expect(find.textContaining('•••••'), findsWidgets);
  });

  testWidgets('hold mic records and release sends', (t) async {
    final c = await open(t);
    final g = await t.startGesture(t.getCenter(find.byKey(const ValueKey('composer-mic')).first));
    await t.pump(const Duration(milliseconds: 700));
    await spin(t, 3);
    expect(rec.starts, 1);
    await g.up();
    await spin(t);
    expect(rec.stops, 1);
    expect(find.byKey(const ValueKey('chat-sheet')), findsOneWidget);
    final pending = await t.runAsync(() => CaptureRepository(dbOf(c)).watchPending().first);
    expect(pending!.single.audio, isNotNull, reason: 'no speech engine: the audio waits in the Inbox');
  });

  testWidgets('tap mic toggles recording', (t) async {
    await open(t);
    await t.tap(find.byKey(const ValueKey('composer-mic')).first);
    await spin(t, 3);
    expect(rec.starts, 1);
    expect(find.byKey(const ValueKey('composer-recording')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('composer-mic')).first);
    await spin(t);
    expect(rec.stops, 1);
  });

  testWidgets('first voice use asks consent before recording', (t) async {
    final c = await open(t);
    await t.runAsync(() => GroqKeyStore(store).write(const Sensitive('gsk_1234')));
    c.invalidate(groqKeySavedProvider);
    await settle(t);
    await t.tap(find.byKey(const ValueKey('composer-mic')).first);
    await settle(t);
    expect(find.byKey(const ValueKey('consent-sheet')), findsOneWidget);
    expect(rec.starts, 0);
  });

  testWidgets('nav has Home, Finance, Tasks, Projects', (t) async {
    await open(t);
    for (final label in ['Home', 'Finance', 'Tasks', 'Projects']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.byKey(const ValueKey('mic-fab')), findsNothing);
  });
}
