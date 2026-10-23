import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/capture/domain/intent_validator.dart';
import 'package:life_manager/features/capture/domain/lexicon.dart';
import 'package:life_manager/features/capture/domain/proposal.dart';
import 'package:life_manager/l10n/gen/app_localizations.dart';

import '../../../helpers/finance_fixtures.dart';

Map<String, Object?> intent(Map<String, Object?> fields) => {'type': 'expense', ...fields};
Map<String, Object?> root(List<Object?> intents) => {'intents': intents};

void main() {
  late FinanceFixture f;
  late Lexicon lex;
  final now = DateTime(2026, 10, 23, 15, 40);

  setUp(() async {
    f = await financeFixture();
    lex = await loadLexicon(f.db, lookupAppLocalizations(const Locale('ar')));
  });
  tearDown(() => f.db.close());

  test('valid AI json → proposals with resolved ids', () {
    final ps = validateIntents(
      root([
        intent({
          'amount': '40000',
          'currency': 'IQD',
          'workspace': 'Buzzify',
          'category': 'مواصلات',
          'date': '2026-10-22',
          'time': '09:30',
          'description': 'تكسي',
        }),
        {'type': 'income', 'amount': '500', 'currency': 'USD', 'category': 'العميل'},
        {'type': 'transfer', 'amount': '100', 'currency': 'USD', 'to_amount': '131000', 'to_currency': 'IQD'},
        {'type': 'task', 'title': 'اتصل بالعميل', 'date': '2026-10-24', 'time': '11:00'},
        {
          'type': 'debt_payment',
          'amount': '50000',
          'counterparty': 'احمد',
          'debt_direction': 'owed_to_me',
          'debt_leg': 'repayment',
        },
        {'type': 'note', 'description': 'رقم الكراج'},
      ]),
      lex,
      now,
    );
    final e = ps[0] as MoneyProposal;
    expect(
      (e.type, e.amountMinor, e.workspaceId, e.accountId, e.categoryId, e.occurredAt, e.description),
      (IntentType.expense, 40000, f.buzzWs, f.buzzIqd, f.cat('transport'), DateTime(2026, 10, 22, 9, 30), 'تكسي'),
    );
    final i = ps[1] as MoneyProposal;
    expect(
      (i.type, i.accountId, i.amountMinor, i.categoryId),
      (IntentType.income, f.personalUsd, 50000, f.cat('client_payment')),
    );
    final t = ps[2] as TransferProposal;
    expect(
      (t.fromAccountId, t.toAccountId, t.amountMinor, t.toAmountMinor, t.rateE6),
      (f.personalUsd, f.personalIqd, 10000, 131000, 1310000000),
    );
    final task = ps[3] as TaskProposal;
    expect((task.title, task.due), ('اتصل بالعميل', DateTime(2026, 10, 24, 11)));
    final d = ps[4] as DebtProposal;
    expect(
      (d.counterparty, d.direction, d.leg, d.amountMinor, d.accountId),
      ('احمد', 'owed_to_me', 'repayment', 50000, f.personalIqd),
    );
    expect((ps[5] as NoteProposal).text, 'رقم الكراج');
  });

  test('amount 25000.5 for IQD rounds half-even to 25000 and keeps the proposal', () {
    final p = validateIntents(
      root([
        intent({'amount': '25000.5', 'currency': 'IQD'}),
      ]),
      lex,
      now,
    ).single;
    expect((p as MoneyProposal).amountMinor, 25000);
  });

  test('amount as a number (not string) → InvalidAiOutput', () {
    expect(
      () => validateIntents(
        root([
          intent({'amount': 25000}),
        ]),
        lex,
        now,
      ),
      throwsA(isA<InvalidAiOutput>()),
    );
  });

  test('unknown key → InvalidAiOutput', () {
    expect(
      () => validateIntents(
        root([
          intent({'iban': 'x'}),
        ]),
        lex,
        now,
      ),
      throwsA(isA<InvalidAiOutput>()),
    );
    expect(() => validateIntents({'intents': [], 'extra': 1}, lex, now), throwsA(isA<InvalidAiOutput>()));
  });

  test('other schema breaks → InvalidAiOutput', () {
    for (final bad in <Object?>[
      null,
      [],
      {'intents': 'x'},
      root([
        intent({'type': 'refund'}),
      ]),
      root([
        intent({'amount': '1e5'}),
      ]),
      root([
        intent({'amount': '-5'}),
      ]),
      root([
        intent({'currency': 'EUR'}),
      ]),
      root([
        intent({'date': '23/10/2026'}),
      ]),
      root([
        intent({'date': '2026-02-30'}),
      ]),
      root([
        intent({'time': '25:00'}),
      ]),
      root([
        intent({'description': 'x' * 301}),
      ]),
      root([
        intent({'debt_leg': 'interest'}),
      ]),
      root(['expense']),
    ]) {
      expect(() => validateIntents(bad, lex, now), throwsA(isA<InvalidAiOutput>()), reason: '$bad');
    }
  });

  test('unknown category name → categoryId null, not a failure', () {
    final p = validateIntents(
      root([
        intent({'amount': '5000', 'category': 'رحلات فضائية'}),
      ]),
      lex,
      now,
    ).single;
    expect((p as MoneyProposal).categoryId, isNull);
    expect(p.amountMinor, 5000);
  });

  test('an unknown workspace name leaves the workspace and account for review', () {
    final p = validateIntents(
      root([
        intent({'amount': '5000', 'workspace': 'Nowhere'}),
      ]),
      lex,
      now,
    ).single;
    expect(((p as MoneyProposal).workspaceId, p.accountId), (null, null));
  });

  test('11 intents → InvalidAiOutput', () {
    final many = root([
      for (var i = 0; i < 11; i++) intent({'amount': '1'}),
    ]);
    expect(() => validateIntents(many, lex, now), throwsA(isA<InvalidAiOutput>()));
    expect(
      validateIntents(
        root([
          for (var i = 0; i < 10; i++) intent({'amount': '1'}),
        ]),
        lex,
        now,
      ),
      hasLength(10),
    );
  });

  test('InvalidAiOutput carries no model text', () {
    try {
      validateIntents(
        root([
          intent({'description': 'secret' * 100}),
        ]),
        lex,
        now,
      );
      fail('should throw');
    } on InvalidAiOutput catch (e) {
      expect(e.toString(), isNot(contains('secret')));
    }
  });

  test('edit and delete carry their target', () {
    final ps = validateIntents(
      root([
        {'type': 'delete', 'target': 'last_expense'},
        {'type': 'edit', 'target': 'last', 'amount': '30000', 'currency': 'IQD'},
      ]),
      lex,
      now,
    );
    expect((ps[0] as DeleteProposal).target, 'last_expense');
    final e = ps[1] as EditProposal;
    expect((e.target, e.newAmountMinor), ('last', 30000));
  });

  test('an unknown category name is kept for the chat to offer', () {
    final p =
        validateIntents(
              root([
                intent({'amount': '5000', 'currency': 'IQD', 'category': 'Gym'}),
              ]),
              lex,
              now,
            ).single
            as MoneyProposal;
    expect((p.categoryId, p.newCategoryName), (null, 'Gym'));
  });

  test('reminder, appointment with a place, and a project idea are accepted', () {
    final ps = validateIntents(
      root([
        {'type': 'reminder', 'title': 'اخابر احمد', 'date': '2026-10-24', 'time': '17:00'},
        {'type': 'appointment', 'title': 'طبيب', 'date': '2026-10-29', 'place': 'المنصور'},
        {'type': 'project_idea', 'title': 'محل قهوة', 'description': 'محل قهوة صغير بالكرادة'},
      ]),
      lex,
      now,
    );
    final reminder = ps[0] as TaskProposal, visit = ps[1] as TaskProposal, idea = ps[2] as ProjectIdeaProposal;
    expect((reminder.kind, reminder.due, reminder.hasTime), ('reminder', DateTime(2026, 10, 24, 17), true));
    expect(
      (visit.kind, visit.place, visit.hasTime, visit.due),
      ('appointment', 'المنصور', false, DateTime(2026, 10, 29)),
    );
    expect((idea.title, idea.description), ('محل قهوة', 'محل قهوة صغير بالكرادة'));
  });

  test('an unknown type is still refused', () {
    expect(
      () => validateIntents(
        root([
          {'type': 'lottery'},
        ]),
        lex,
        now,
      ),
      throwsA(isA<InvalidAiOutput>()),
    );
  });
}
