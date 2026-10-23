import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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

class FakeRecorder implements AudioRecorderPort {
  FakeRecorder({this.allowed = true});

  final bool allowed;
  final levels = StreamController<double>.broadcast();
  int starts = 0;
  int stops = 0;
  int cancels = 0;

  @override
  Future<bool> ensurePermission() async => allowed;

  @override
  Future<void> start() async => starts++;

  @override
  Stream<double> get level => levels.stream;

  @override
  Future<Uint8List> stop() async {
    stops++;
    return Uint8List.fromList(List.filled(32, 1));
  }

  @override
  Future<void> cancel() async => cancels++;
}

void main() {
  late Directory dir;
  late InMemorySecureStore store;
  late FakeHttpPort http;
  late FakeRecorder rec;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sheet');
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

  testWidgets('fab long-press opens the text sheet; send runs fromText', (t) async {
    final c = await open(t);
    await t.longPress(find.byKey(const ValueKey('mic-fab')));
    await settle(t);
    expect(find.byKey(const ValueKey('cap-text-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('cap-manual-expense')), findsOneWidget);
    expect(t.widget<ActionChip>(find.byKey(const ValueKey('cap-manual-task'))).onPressed, isNull);

    await t.enterText(find.byKey(const ValueKey('cap-text-field')), 'دفعت 40 الف تكسي');
    await settle(t);
    await t.tap(find.byKey(const ValueKey('cap-send')));
    await settle(t);

    expect(find.byKey(const ValueKey('capture-review')), findsOneWidget);
    final pending = await t.runAsync(() => CaptureRepository(dbOf(c)).watchPending().first);
    expect(pending!.single.source, 'text');
    expect(http.requests, isEmpty);
  });

  testWidgets('first voice use shows the consent sheet before recording uploads', (t) async {
    final c = await open(t);
    await t.runAsync(() => GroqKeyStore(store).write(const Sensitive('gsk_1234')));
    c.invalidate(groqKeySavedProvider);
    await settle(t);

    await t.tap(find.byKey(const ValueKey('mic-fab')));
    await settle(t);
    expect(find.byKey(const ValueKey('consent-sheet')), findsOneWidget);
    expect(rec.starts, 0);

    await t.tap(find.byKey(const ValueKey('consent-allow')));
    await settle(t);
    // The same capture is then read online too, so the parse question follows.
    expect(find.byKey(const ValueKey('consent-sheet')), findsOneWidget);
    expect(rec.starts, 0);
    await t.tap(find.byKey(const ValueKey('consent-allow')));
    for (var i = 0; i < 5; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(find.byKey(const ValueKey('cap-voice-sheet')), findsOneWidget);
    expect(rec.starts, 1);
    final s = await t.runAsync(() => c.read(settingsRepositoryProvider).get());
    expect(s!.aiVoiceConsent, 'granted');

    await t.tap(find.byKey(const ValueKey('cap-cancel')));
    for (var i = 0; i < 5; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(rec.cancels, 1);
    expect(find.byKey(const ValueKey('cap-voice-sheet')), findsNothing);
  });

  testWidgets('voice with no engine: stop → saved to Inbox snackbar, audio kept', (t) async {
    final c = await open(t);
    await t.tap(find.byKey(const ValueKey('mic-fab')));
    for (var i = 0; i < 3; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(find.byKey(const ValueKey('cap-voice-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('cap-elapsed')), findsOneWidget);
    rec.levels.add(0.8);
    await t.pump(const Duration(seconds: 1));

    await t.tap(find.byKey(const ValueKey('cap-stop')));
    for (var i = 0; i < 8; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(rec.stops, 1);
    expect(find.byKey(const ValueKey('cap-voice-sheet')), findsNothing);
    expect(find.byKey(const ValueKey('cap-inbox-snack')), findsOneWidget);
    final pending = await t.runAsync(() => CaptureRepository(dbOf(c)).watchPending().first);
    expect(pending!.single.audio, isNotNull);
    expect(pending.single.failureType, 'SpeechUnavailable');
  });
}
