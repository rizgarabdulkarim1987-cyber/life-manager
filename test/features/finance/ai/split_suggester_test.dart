import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/net/http_port.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/core/storage/secure_store.dart';
import 'package:life_manager/features/capture/ai/ai_config.dart';
import 'package:life_manager/features/capture/ai/groq_client.dart';
import 'package:life_manager/features/capture/domain/intent_validator.dart' show InvalidAiOutput;
import 'package:life_manager/features/finance/ai/split_suggester.dart';
import 'package:life_manager/features/settings/settings_repository.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/finance_ui.dart';

HttpReply _reply(Object content) => HttpReply(
  200,
  jsonEncode({
    'choices': [
      {
        'message': {'content': content is String ? content : jsonEncode(content)},
      },
    ],
  }),
);

void main() {
  late FakeHttpPort http;
  late GroqClient client;
  late GroqKeyStore keys;

  setUp(() async {
    keys = GroqKeyStore(InMemorySecureStore());
    await keys.write(const Sensitive('gsk_test'));
    http = FakeHttpPort((_) => _reply({'expenses': 6000, 'emergency': 2000, 'investment': 2000}));
    client = GroqClient(http, keys);
  });

  test('the payload carries only the goal, never amounts', () async {
    final split = await suggestSplit(client, 'm', 'save for a car in two years');
    expect(split, {'expenses': 6000, 'emergency': 2000, 'investment': 2000});
    final body = jsonDecode(http.requests.single.body!) as Map<String, Object?>;
    final user = ((body['messages'] as List).last as Map)['content'] as String;
    expect(jsonDecode(user), {'goal': 'save for a car in two years'});
  });

  test('a bad sum is rejected', () async {
    http.reply = (_) => _reply({'expenses': 6000, 'emergency': 2000, 'investment': 1000});
    expect(() => suggestSplit(client, 'm', 'x'), throwsA(isA<InvalidAiOutput>()));
  });

  test('a missing bucket or a value out of range is rejected', () async {
    http.reply = (_) => _reply({'expenses': 12000, 'emergency': -2000});
    expect(() => suggestSplit(client, 'm', 'x'), throwsA(isA<InvalidAiOutput>()));
    http.reply = (_) => _reply('not json');
    expect(() => suggestSplit(client, 'm', 'x'), throwsA(isA<InvalidAiOutput>()));
  });

  testWidgets('applying a suggestion fills the editor without saving until Save', (t) async {
    final c = await pumpApp(
      t,
      locale: 'en',
      overrides: [groqClientProvider.overrideWithValue(client), groqKeyStoreProvider.overrideWithValue(keys)],
    );
    await SettingsRepository(dbOf(c)).setAiOnlineEnabled(true);
    await SettingsRepository(dbOf(c)).setConsent(AiFeature.parse, ConsentState.granted);
    await settle(t);
    final db = dbOf(c);
    final before = {for (final b in await t.runAsync(() => db.select(db.buckets).get()) ?? []) b.id: b.percentBp};
    await pushRoute(t, c, '/finance/buckets');
    await t.tap(find.byKey(const ValueKey('edit-percentages')));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('suggest-goal')), 'a car');
    await t.tap(find.byKey(const ValueKey('suggest-split')));
    await settle(t);
    final buckets = await t.runAsync(() => db.select(db.buckets).get()) ?? [];
    final investment = buckets.firstWhere((b) => b.systemKey == 'investment');
    expect(t.widget<TextField>(find.byKey(ValueKey('pct-${investment.id}'))).controller!.text, '20');
    expect({for (final b in buckets) b.id: b.percentBp}, before, reason: 'nothing saved yet');
    expect(saveEnabled(t, 'pct-save'), isTrue);
  });
}
