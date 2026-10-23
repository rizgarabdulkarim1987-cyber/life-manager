import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/capture/data/capture_committer.dart';
import 'package:life_manager/features/capture/data/capture_repository.dart';
import 'package:life_manager/features/capture/domain/proposal.dart';
import 'package:life_manager/features/finance/data/debts_repository.dart';

import '../../../helpers/finance_fixtures.dart';

void main() {
  late FinanceFixture f;
  late CaptureRepository repo;
  late CaptureCommitter committer;
  final at = DateTime(2026, 10, 22, 15, 40);

  setUp(() async {
    f = await financeFixture();
    repo = CaptureRepository(f.db);
    committer = CaptureCommitter(f.db);
  });
  tearDown(() => f.db.close());

  MoneyProposal expense({int? amount = 40000, int? account}) => MoneyProposal(
    type: IntentType.expense,
    confidence: 100,
    amountMinor: amount,
    accountId: account ?? f.buzzIqd,
    categoryId: f.cat('transport'),
    occurredAt: at,
    description: 'تكسي',
  );

  Future<int> voiceCapture() async {
    final id = await repo.createVoice(Uint8List(16));
    await repo.setTranscript(id, 'دفعت 40 الف تكسي وبعدين حولت');
    return id;
  }

  test('commit writes expense and transfer atomically and marks done; audio removed', () async {
    final id = await voiceCapture();
    await committer.commit(id, [
      MoneyCommit(expense(), null),
      TransferCommit(
        TransferProposal(
          confidence: 100,
          fromAccountId: f.personalUsd,
          toAccountId: f.personalIqd,
          amountMinor: 10000,
          toAmountMinor: 131000,
          rateE6: 1310000000,
          transferKind: 'transfer',
          occurredAt: at,
        ),
      ),
    ]);
    final txs = await f.db.select(f.db.transactions).get();
    expect(txs.map((t) => (t.type, t.accountId, t.amountMinor, t.captureId)), [
      ('expense', f.buzzIqd, 40000, id),
      ('transfer', f.personalUsd, 10000, id),
    ]);
    final c = (await repo.get(id))!;
    expect((c.status, c.audio), ('done', null));
  });

  test('commit failure in the second item leaves nothing written and capture pending', () async {
    final id = await voiceCapture();
    // USD → IQD with no received amount or rate: the transactions repository refuses it.
    final bad = TransferProposal(
      confidence: 100,
      fromAccountId: f.personalUsd,
      toAccountId: f.personalIqd,
      amountMinor: 10000,
      occurredAt: at,
    );
    await expectLater(committer.commit(id, [MoneyCommit(expense(), null), TransferCommit(bad)]), throwsArgumentError);
    expect(await f.db.select(f.db.transactions).get(), isEmpty);
    final c = (await repo.get(id))!;
    expect(c.status, 'pending');
    expect(c.audio, isNotNull);
  });

  test('incomplete money item → ArgumentError before anything is written', () async {
    final id = await voiceCapture();
    await expectLater(
      committer.commit(id, [MoneyCommit(expense(), null), MoneyCommit(expense(amount: null), null)]),
      throwsArgumentError,
    );
    expect(await f.db.select(f.db.transactions).get(), isEmpty);
    expect((await repo.get(id))!.status, 'pending');
  });

  test('task proposal is kept as a new pending capture', () async {
    final id = await voiceCapture();
    const task = TaskProposal(title: 'اتصل بالعميل', confidence: 100);
    await committer.commit(id, [MoneyCommit(expense(), null), const KeepInInbox(task)]);
    expect((await repo.get(id))!.status, 'done');
    final pending = await repo.watchPending().first;
    expect(pending, hasLength(1));
    final kept = pending.single;
    expect((kept.source, kept.transcript, kept.audio), ('text', 'دفعت 40 الف تكسي وبعدين حولت', null));
    expect((decodeProposals(kept.parsedJson!).single as TaskProposal).title, 'اتصل بالعميل');
  });

  test('income with an allocation splits into buckets in the same commit', () async {
    final id = await repo.createText('استلمت مليون');
    final buckets = await f.db.select(f.db.buckets).get();
    final income = MoneyProposal(
      type: IntentType.income,
      confidence: 100,
      amountMinor: 1000000,
      accountId: f.personalIqd,
      categoryId: f.cat('salary'),
      occurredAt: at,
    );
    await committer.commit(id, [
      MoneyCommit(income, {buckets[0].id: 600000, buckets[1].id: 400000}),
    ]);
    final allocs = await f.db.select(f.db.bucketAllocations).get();
    expect(allocs.map((a) => a.amountBaseMinor), [600000, 400000]);
  });

  test('debt: repayment on an existing debt, or a new debt with its principal', () async {
    final debts = DebtsRepository(f.db);
    final debtId = await debts.create(
      direction: 'owed_to_me',
      counterparty: 'احمد',
      workspaceId: f.personalWs,
      principalMinor: 100000,
      currencyCode: 'IQD',
      startDate: DateTime(2026, 9, 1),
    );
    final id = await repo.createText('رجعلي احمد 50 الف وتسلفت من علي 20 الف');
    await committer.commit(id, [
      DebtCommit(
        DebtProposal(
          confidence: 100,
          counterparty: 'احمد',
          direction: 'owed_to_me',
          leg: 'repayment',
          amountMinor: 50000,
          currency: 'IQD',
          accountId: f.personalIqd,
          occurredAt: at,
        ),
        debtId,
      ),
      DebtCommit(
        DebtProposal(
          confidence: 100,
          counterparty: 'علي',
          direction: 'owed_by_me',
          leg: 'principal',
          amountMinor: 20000,
          currency: 'IQD',
          accountId: f.personalIqd,
          occurredAt: at,
        ),
        null,
      ),
    ]);
    final all = await f.db.select(f.db.debts).get();
    expect(all.map((d) => (d.counterparty, d.direction, d.principalMinor)), [
      ('احمد', 'owed_to_me', 100000),
      ('علي', 'owed_by_me', 20000),
    ]);
    final legs = await f.db.select(f.db.transactions).get();
    expect(legs.map((t) => (t.debtId, t.debtLeg, t.amountMinor)), [
      (debtId, 'repayment', 50000),
      (all[1].id, 'principal', 20000),
    ]);
  });

  test('a second commit, or a commit after discard, writes nothing', () async {
    final id = await voiceCapture();
    await committer.commit(id, [MoneyCommit(expense(), null)]);
    await expectLater(committer.commit(id, [MoneyCommit(expense(), null)]), throwsA(isA<CaptureAlreadyHandled>()));
    expect(await f.db.select(f.db.transactions).get(), hasLength(1));

    final other = await voiceCapture();
    await repo.discard(other);
    await expectLater(committer.commit(other, [MoneyCommit(expense(), null)]), throwsA(isA<CaptureAlreadyHandled>()));
    expect(await f.db.select(f.db.transactions).get(), hasLength(1));
    expect((await repo.get(other))!.status, 'discarded');
  });

  test('undo removes everything one capture wrote, including a new debt, and discards it', () async {
    final id = await voiceCapture();
    await committer.commit(id, [
      MoneyCommit(expense(), null),
      DebtCommit(
        DebtProposal(
          confidence: 100,
          counterparty: 'Ahmed',
          direction: 'owed_to_me',
          leg: 'principal',
          amountMinor: 50000,
          accountId: f.personalIqd,
          occurredAt: at,
        ),
        null,
      ),
    ]);
    expect(await f.db.select(f.db.transactions).get(), hasLength(2));
    expect(await f.db.select(f.db.debts).get(), hasLength(1));
    await committer.undo(id);
    expect(await f.db.select(f.db.transactions).get(), isEmpty);
    expect(await f.db.select(f.db.debts).get(), isEmpty);
    expect((await repo.get(id))!.status, 'discarded');
  });

  test('undo of a repayment that closed a debt opens it again', () async {
    final debts = DebtsRepository(f.db);
    final debtId = await debts.create(
      direction: 'owed_by_me',
      counterparty: 'Sara',
      workspaceId: f.personalWs,
      principalMinor: 20000,
      currencyCode: 'IQD',
      startDate: at.toUtc(),
    );
    final id = await voiceCapture();
    await committer.commit(id, [
      DebtCommit(
        DebtProposal(confidence: 100, leg: 'repayment', amountMinor: 20000, accountId: f.personalIqd, occurredAt: at),
        debtId,
      ),
    ]);
    expect((await (f.db.select(f.db.debts)..where((d) => d.id.equals(debtId))).getSingle()).closedAt, isNotNull);
    await committer.undo(id);
    final d = await (f.db.select(f.db.debts)..where((d) => d.id.equals(debtId))).getSingle();
    expect(d.closedAt, isNull);
    expect(await f.db.select(f.db.transactions).get(), isEmpty);
  });

  test('undo twice is harmless', () async {
    final id = await voiceCapture();
    await committer.commit(id, [MoneyCommit(expense(), null)]);
    await committer.undo(id);
    await committer.undo(id);
    expect(await f.db.select(f.db.transactions).get(), isEmpty);
  });

  test('commit deletes, undo restores', () async {
    final first = await repo.createText('دفعت 40 الف تكسي');
    await committer.commit(first, [MoneyCommit(expense(), null)]);
    final tx = (await f.db.select(f.db.transactions).get()).single;

    final id = await repo.createText('احذف آخر مصروف');
    await committer.commit(id, [DeleteCommit(DeleteProposal(confidence: 100, target: 'last_expense', txId: tx.id))]);
    expect(await f.db.select(f.db.transactions).get(), isEmpty);

    await committer.undo(id);
    final back = (await f.db.select(f.db.transactions).get()).single;
    expect((back.id, back.amountMinor, back.description), (tx.id, 40000, 'تكسي'));
  });

  test('commit edits, undo puts the old amount back', () async {
    final first = await repo.createText('دفعت 40 الف تكسي');
    await committer.commit(first, [MoneyCommit(expense(), null)]);
    final tx = (await f.db.select(f.db.transactions).get()).single;

    final id = await repo.createText('غير المبلغ لـ 30 الف');
    await committer.commit(id, [
      EditCommit(EditProposal(confidence: 100, target: 'last', txId: tx.id, newAmountMinor: 30000)),
    ]);
    expect((await f.db.select(f.db.transactions).get()).single.amountMinor, 30000);

    await committer.undo(id);
    expect((await f.db.select(f.db.transactions).get()).single.amountMinor, 40000);
  });
}
