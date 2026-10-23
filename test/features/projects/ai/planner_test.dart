import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/core/net/http_port.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/core/storage/secure_store.dart';
import 'package:life_manager/features/capture/ai/ai_config.dart';
import 'package:life_manager/features/capture/ai/ai_payload.dart';
import 'package:life_manager/features/capture/ai/groq_client.dart';
import 'package:life_manager/features/capture/domain/intent_validator.dart' show InvalidAiOutput;
import 'package:life_manager/features/capture/domain/lexicon.dart';
import 'package:life_manager/features/projects/ai/planner.dart';
import 'package:life_manager/features/projects/data/projects_repository.dart';
import 'package:life_manager/l10n/gen/app_localizations.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/finance_fixtures.dart';

HttpReply _reply(Object content) => HttpReply(
  200,
  jsonEncode({
    'choices': [
      {
        'message': {'content': jsonEncode(content)},
      },
    ],
  }),
);

const _plan = {
  'reply': 'Here is a plan.',
  'question': false,
  'plan': {
    'phases': [
      {
        'name': 'Prepare',
        'steps': [
          {'title': 'Find a shop', 'due': '2026-11-01'},
          {'title': 'Buy a machine', 'due': null},
        ],
      },
      {
        'name': 'Launch',
        'steps': [
          {'title': 'Open the doors', 'due': '2026-12-15'},
        ],
      },
    ],
    'est_cost': '12500.50',
    'currency': 'USD',
  },
  'step_updates': [],
};

void main() {
  late AppDatabase db;
  late ProjectsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProjectsRepository(db);
  });
  tearDown(() => db.close());

  group('reply validation', () {
    test('a question reply without a plan is valid', () {
      final r = parsePlannerReply({'reply': 'What is your budget?', 'question': true, 'plan': null});
      expect((r.reply, r.question, r.plan), ('What is your budget?', true, null));
      expect(r.stepUpdates, isEmpty);
    });

    test('a plan is read with its phases, dates and cost', () {
      final r = parsePlannerReply(_plan);
      final plan = r.plan!;
      expect(plan.phases.map((p) => p.name), ['Prepare', 'Launch']);
      expect(plan.stepCount, 3);
      expect(plan.phases.first.steps.first.due, DateTime(2026, 11, 1));
      expect((plan.estCostMinor, plan.currency), (1250050, 'USD'));
    });

    test('invalid plans are rejected', () {
      void bad(Object? json) => expect(() => parsePlannerReply(json), throwsA(isA<InvalidAiOutput>()), reason: '$json');
      bad('text');
      bad({'reply': ''});
      bad({'reply': 'x', 'extra': 1});
      bad({'reply': 'x', 'question': 'yes'});
      bad({
        'reply': 'x',
        'plan': {'phases': []},
      });
      bad({
        'reply': 'x',
        'plan': {
          'phases': [
            {'name': 'A', 'steps': []},
          ],
        },
      });
      bad({
        'reply': 'x',
        'plan': {
          'phases': [
            {
              'name': 'A',
              'steps': [
                {'title': 'a', 'due': '2026-02-30'},
              ],
            },
          ],
        },
      });
      bad({
        'reply': 'x',
        'plan': {
          'phases': [
            {
              'name': 'A',
              'steps': [
                {'title': 'a', 'due': 'soon'},
              ],
            },
          ],
        },
      });
      bad({
        'reply': 'x',
        'plan': {
          'phases': [
            {
              'name': 'A',
              'steps': [
                {'title': 'a'},
              ],
            },
          ],
          'est_cost': '-5',
          'currency': 'IQD',
        },
      });
      bad({
        'reply': 'x',
        'plan': {
          'phases': [
            {
              'name': 'A',
              'steps': [
                {'title': 'a'},
              ],
            },
          ],
          'est_cost': '5',
        },
      });
      bad({
        'reply': 'x',
        'plan': {
          'phases': [
            {
              'name': 'A',
              'steps': [
                {'title': 'a'},
              ],
            },
          ],
          'currency': 'EUR',
        },
      });
      bad({
        'reply': 'x',
        'step_updates': [
          {'seq': 'one', 'done': true},
        ],
      });
      bad({
        'reply': 'x',
        'plan': {
          'phases': [
            for (var i = 0; i < 5; i++)
              {
                'name': 'P$i',
                'steps': [
                  for (var k = 0; k < 15; k++) {'title': 's$k'},
                ],
              },
          ],
        },
      });
    });
  });

  test('plan saved replaces steps on OK, keeps done marks by title and moves an idea to planning', () async {
    final id = await repo.create(title: 'Coffee shop');
    await repo.applyPlan(
      id,
      parsePlannerReply({
        'reply': 'x',
        'plan': {
          'phases': [
            {
              'name': 'Old',
              'steps': [
                {'title': 'Find a shop'},
                {'title': 'Dropped step'},
              ],
            },
          ],
        },
      }).plan!,
    );
    await repo.setStepDone((await repo.stepsOf(id)).first.id, true);

    await repo.applyPlan(id, parsePlannerReply(_plan).plan!);
    final steps = await repo.stepsOf(id);
    expect(steps.map((s) => (s.seq, s.title, s.phase, s.done)), [
      (1, 'Find a shop', 'Prepare', true),
      (2, 'Buy a machine', 'Prepare', false),
      (3, 'Open the doors', 'Launch', false),
    ]);
    final project = (await repo.get(id))!;
    expect((project.status, project.estCostMinor, project.currencyCode), ('planning', 1250050, 'USD'));
  });

  test('a plan with no cost keeps the owner\'s estimate', () async {
    final id = await repo.create(title: 'x');
    await repo.setEstimate(id, costMinor: 5000000, currency: 'IQD');
    await repo.applyPlan(
      id,
      parsePlannerReply({
        'reply': 'x',
        'plan': {
          'phases': [
            {
              'name': 'A',
              'steps': [
                {'title': 'a'},
              ],
            },
          ],
        },
      }).plan!,
    );
    expect((await repo.get(id))!.estCostMinor, 5000000);
  });

  test('step_updates mark done by number', () async {
    final id = await repo.create(title: 'x');
    await repo.applyPlan(id, parsePlannerReply(_plan).plan!);
    final reply = parsePlannerReply({
      'reply': 'Nice.',
      'step_updates': [
        {'seq': 1, 'done': true},
        {'seq': 3, 'done': true},
        {'seq': 99, 'done': true},
      ],
    });
    await repo.applyStepUpdates(id, reply.stepUpdates);
    expect((await repo.stepsOf(id)).map((s) => s.done), [true, false, true]);
  });

  test('deleting a project removes steps and chat but leaves its tasks as plain tasks', () async {
    final id = await repo.create(title: 'x');
    await repo.applyPlan(id, parsePlannerReply(_plan).plan!);
    await repo.addMessage(id, 'user', 'hello');
    final stepId = (await repo.stepsOf(id)).first.id;
    final taskId = await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            title: 't',
            createdAt: DateTime.now().toUtc(),
            projectId: Value(id),
            projectStepId: Value(stepId),
          ),
        );
    await repo.delete(id);
    expect(await repo.get(id), isNull);
    expect(await db.select(db.projectSteps).get(), isEmpty);
    expect(await db.select(db.projectMessages).get(), isEmpty);
    final task = await (db.select(db.tasks)..where((t) => t.id.equals(taskId))).getSingle();
    expect((task.projectId, task.projectStepId), (null, null));
  });

  test('payload has no bucket amounts, balances or cost: only the words and the steps', () async {
    final id = await repo.create(title: 'Coffee shop', description: 'near the university');
    await repo.setEstimate(id, costMinor: 987654321, currency: 'IQD');
    await repo.applyPlan(id, parsePlannerReply(_plan).plan!);
    await repo.addMessage(id, 'user', 'my budget is 10 million');
    await repo.addMessage(id, 'assistant', 'Noted.');
    final payload = buildPlannerPayload(
      (await repo.get(id))!,
      await repo.messagesOf(id),
      await repo.stepsOf(id),
      DateTime(2026, 10, 23),
    );
    expect(payload.keys, unorderedEquals(['today', 'title', 'description', 'messages', 'steps']));
    final text = jsonEncode(payload);
    expect(text, isNot(contains('987654321')));
    expect(text, isNot(contains('1250050')));
    expect(text, contains('my budget is 10 million'), reason: 'the owner\'s own words go');
    expect(payload['steps'], hasLength(3));
  });

  test('Planner.reply sends that payload and returns the validated reply', () async {
    final keys = GroqKeyStore(InMemorySecureStore());
    await keys.write(const Sensitive('gsk_test'));
    final http = FakeHttpPort((_) => _reply(_plan));
    final id = await repo.create(title: 'Coffee shop');
    final project = (await repo.get(id))!;
    final out = await Planner(GroqClient(http, keys), () => 'm').reply(project, const [], const []);
    expect(out.plan!.stepCount, 3);
    final body = jsonDecode(http.requests.single.body!) as Map<String, Object?>;
    final user = jsonDecode(((body['messages'] as List).last as Map)['content'] as String) as Map;
    expect(user['title'], 'Coffee shop');
    http.reply = (_) => _reply({
      'reply': 'x',
      'plan': {'phases': []},
    });
    expect(
      () => Planner(GroqClient(http, keys), () => 'm').reply(project, const [], const []),
      throwsA(isA<InvalidAiOutput>()),
    );
  });

  test('the parse payload carries project titles, the receipt payload does not', () async {
    final f = await financeFixture();
    addTearDown(f.db.close);
    await ProjectsRepository(f.db).create(title: 'Coffee shop');
    final done = await ProjectsRepository(f.db).create(title: 'Old thing');
    await ProjectsRepository(f.db).setStatus(done, 'done');
    final lex = await loadLexicon(f.db, lookupAppLocalizations(const Locale('en')));
    expect(buildParsePayload('x', lex, DateTime(2026, 10, 23))['projects'], ['Coffee shop']);
    expect(buildReceiptPayload(lex, DateTime(2026, 10, 23)).containsKey('projects'), isFalse);
  });
}
