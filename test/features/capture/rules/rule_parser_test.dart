import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/capture/domain/lexicon.dart';
import 'package:life_manager/features/capture/domain/proposal.dart';
import 'package:life_manager/features/capture/rules/rule_parser.dart';
import 'package:life_manager/features/finance/data/workspaces_repository.dart';
import 'package:life_manager/l10n/gen/app_localizations.dart';

import '../../../helpers/finance_fixtures.dart';

void main() {
  late FinanceFixture f;
  late Lexicon lex;
  const parser = RuleParser();
  final now = DateTime(2026, 10, 23, 15, 40);

  setUp(() async {
    f = await financeFixture();
    // Spoken Arabic names the workspace in Arabic letters; the owner adds that as an alias.
    await WorkspacesRepository(f.db).setAliases(f.buzzWs, ['بزفاي']);
    lex = await loadLexicon(f.db, lookupAppLocalizations(const Locale('ar')));
  });
  tearDown(() => f.db.close());

  Future<List<Proposal>> parse(String s) => parser.parse(s, lex, now);

  test('expense, workspace and category', () async {
    final p = (await parse('دفعت 40 الف تكسي لبزفاي')).single as MoneyProposal;
    expect(
      (p.type, p.amountMinor, p.accountId, p.categoryId),
      (IntentType.expense, 40000, f.buzzIqd, f.cat('transport')),
    );
    expect(p.workspaceId, f.buzzWs);
    expect(p.description, 'دفعت تكسي لبزفاي');
    expect(p.confidence, 100);
  });

  test('no workspace → Personal; USD picks the USD account', () async {
    final p = (await parse('غدا 12 دولار')).single as MoneyProposal;
    expect(
      (p.workspaceId, p.accountId, p.currency, p.amountMinor, p.categoryId),
      (f.personalWs, f.personalUsd, 'USD', 1200, f.cat('food')),
    );
  });

  test('income cue', () async {
    final p = (await parse('استلمت 500 دولار من العميل')).single as MoneyProposal;
    expect(
      (p.type, p.accountId, p.amountMinor, p.categoryId),
      (IntentType.income, f.personalUsd, 50000, f.cat('client_payment')),
    );
  });

  test('exchange: صرفت 100 دولار ب 131 الف → transfer USD→IQD with rate 1310', () async {
    final p = (await parse('صرفت 100 دولار ب 131 الف')).single as TransferProposal;
    expect(
      (p.fromAccountId, p.toAccountId, p.amountMinor, p.toAmountMinor, p.rateE6),
      (f.personalUsd, f.personalIqd, 10000, 131000, 1310000000),
    );
    expect(p.toTransferDraft().rateE6, 1310000000);
  });

  test('two clauses → two proposals', () async {
    final ps = await parse('تغديت ب 15 الف وبعدين بانزين 20 الف');
    expect(ps.length, 2);
    final a = ps[0] as MoneyProposal, b = ps[1] as MoneyProposal;
    expect((a.amountMinor, b.amountMinor, b.categoryId), (15000, 20000, f.cat('transport')));
  });

  test('task with tomorrow at 11', () async {
    final p = (await parse('ذكرني اتصل بالعميل باجر الساعة 11')).single as TaskProposal;
    expect(p.due, DateTime(2026, 10, 24, 11));
    expect(p.title, 'اتصل بالعميل');
  });

  test('debt repayment', () async {
    final p = (await parse('رجعلي احمد 50 الف من السلفة')).single as DebtProposal;
    expect(
      (p.direction, p.leg, p.amountMinor, p.currency, p.counterparty, p.accountId),
      ('owed_to_me', 'repayment', 50000, 'IQD', 'احمد', f.personalIqd),
    );
  });

  test('no amount → task with confidence ≥ 60; expense without amount → confidence < 60', () async {
    final task = (await parse('لازم اشتري هدية لامي')).single;
    expect(task, isA<TaskProposal>());
    expect((task as TaskProposal).confidence, greaterThanOrEqualTo(kLowConfidence));
    final money = (await parse('دفعت لبزفاي')).single as MoneyProposal;
    expect(money.type, IntentType.expense);
    expect(money.amountMinor, isNull);
    expect(money.confidence, lessThan(kLowConfidence));
  });

  test('english and mixed: "lunch 15k buzzify"', () async {
    final p = (await parse('lunch 15k buzzify')).single as MoneyProposal;
    expect((p.amountMinor, p.workspaceId, p.accountId, p.categoryId), (15000, f.buzzWs, f.buzzIqd, f.cat('food')));
  });

  test('yesterday sets occurredAt to yesterday at the current time', () async {
    final p = (await parse('البارحة دفعت 10 الف بانزين')).single as MoneyProposal;
    expect(p.occurredAt, DateTime(2026, 10, 22, 15, 40));
  });

  test('a note keeps its text', () async {
    final p = (await parse('ملاحظة: رقم الكراج عند ابو علي')).single as NoteProposal;
    expect(p.text, contains('ابو علي'));
  });

  test('a decimal point does not split clauses', () async {
    final p = (await parse('قهوة 2.5 دولار')).single as MoneyProposal;
    expect(p.amountMinor, 250);
  });

  test('money proposals adapt to the transaction form draft', () async {
    final p = (await parse('دفعت 40 الف تكسي لبزفاي')).single as MoneyProposal;
    final d = p.toTransactionDraft();
    expect((d.type, d.accountId, d.amountMinor, d.categoryId), ('expense', f.buzzIqd, 40000, f.cat('transport')));
  });

  test('transfer cue: «من» marks the source, the other side is Personal', () async {
    final p = (await parse('حولت 100 الف من بزفاي')).single as TransferProposal;
    expect(
      (p.fromAccountId, p.toAccountId, p.amountMinor, p.transferKind),
      (f.buzzIqd, f.personalIqd, 100000, 'transfer'),
    );
  });

  test('«صرفت» with one amount is spending, not an exchange', () async {
    final p = (await parse('صرفت ٢٥ ألف على الغدا')).single as MoneyProposal;
    expect((p.type, p.amountMinor, p.categoryId), (IntentType.expense, 25000, f.cat('food')));
  });

  test('a time is not an amount', () async {
    final p = (await parse('دفعت 10 الف بانزين الساعة 5 العصر')).single as MoneyProposal;
    expect((p.amountMinor, p.occurredAt), (10000, DateTime(2026, 10, 23, 17)));
  });

  test('«احذف آخر مصروف» → delete the latest expense', () async {
    final d = (await parse('احذف آخر مصروف')).single as DeleteProposal;
    expect(d.target, 'last_expense');
    expect(d.txId, isNull, reason: 'the chat picks the row');
  });

  test('«غير المبلغ لـ 30 الف» → edit the last entry to 30000', () async {
    final e = (await parse('غير المبلغ لـ 30 الف')).single as EditProposal;
    expect((e.target, e.newAmountMinor), ('last', 30000));
  });

  test('«امسح التكسي» targets the entry by its words', () async {
    final d = (await parse('امسح التكسي')).single as DeleteProposal;
    expect(d.target, 'تكسي');
  });

  group('life intents', () {
    test('«ذكرني باجر الساعة 5 أخابر أحمد» is a reminder tomorrow at 17:00', () async {
      final p = (await parse('ذكرني باجر الساعة 5 اخابر احمد')).single as TaskProposal;
      expect((p.kind, p.due, p.hasTime), ('reminder', DateTime(2026, 10, 24, 17), true));
      expect(p.title, 'اخابر احمد');
    });

    test('a morning marker keeps a small hour in the morning', () async {
      final p = (await parse('ذكرني باجر الساعة 5 صباحا اصحى')).single as TaskProposal;
      expect(p.due, DateTime(2026, 10, 24, 5));
    });

    test('«موعد طبيب الخميس 10 بالمنصور» is an appointment with its place', () async {
      final p = (await parse('موعد طبيب الخميس 10 بالمنصور')).single as TaskProposal;
      expect(p.kind, 'appointment');
      expect(p.due, DateTime(2026, 10, 29, 10));
      expect(p.hasTime, isTrue);
      expect(p.place, 'المنصور');
      expect(p.title, 'موعد طبيب');
    });

    test('a task with no time is a date only', () async {
      final p = (await parse('لازم اسدد الايجار باجر')).single as TaskProposal;
      expect((p.kind, p.due, p.hasTime), ('task', DateTime(2026, 10, 24), false));
    });

    test('«عندي فكرة مشروع محل قهوة» is a project idea', () async {
      final p = (await parse('عندي فكرة مشروع محل قهوة صغير')).single as ProjectIdeaProposal;
      expect(p.title, 'محل قهوة صغير');
    });

    test('«ملاحظة …» is still a note', () async {
      final p = (await parse('ملاحظة رقم المهندس 0770')).single;
      expect(p, isA<NoteProposal>());
    });
  });
}
