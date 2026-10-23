import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/capture/data/capture_repository.dart';
import 'package:life_manager/features/capture/domain/proposal.dart';

import '../../../helpers/finance_fixtures.dart';

void main() {
  late FinanceFixture f;
  late CaptureRepository repo;

  setUp(() async {
    f = await financeFixture();
    repo = CaptureRepository(f.db);
  });
  tearDown(() => f.db.close());

  test('voice and text captures start pending', () async {
    final v = await repo.createVoice(Uint8List.fromList([1, 2, 3]));
    final t = await repo.createText('دفعت 40 الف');
    final cv = (await repo.get(v))!, ct = (await repo.get(t))!;
    expect((cv.source, cv.status, cv.transcript), ('voice', 'pending', null));
    expect(cv.audio, [1, 2, 3]);
    expect((ct.source, ct.status, ct.audio, ct.transcript), ('text', 'pending', null, 'دفعت 40 الف'));
    expect(await repo.pendingCount(), 2);
    expect((await repo.watchPending().first).map((c) => c.id), containsAll([v, t]));
  });

  test('transcript, parse and failure are recorded', () async {
    final id = await repo.createVoice(Uint8List(4));
    await repo.setTranscript(id, 'غدا 12 دولار');
    await repo.setFailure(id, 'SocketException');
    expect((await repo.get(id))!.failureType, 'SocketException');
    await repo.setParsed(id, [const TaskProposal(title: 'x', confidence: 70)], by: 'rules');
    final c = (await repo.get(id))!;
    expect((c.transcript, c.parsedBy, c.failureType), ('غدا 12 دولار', 'rules', null));
    expect(decodeProposals(c.parsedJson!).single, isA<TaskProposal>());
  });

  test('setFailure stores only the type name', () async {
    final id = await repo.createText('x');
    await repo.setFailure(id, 'SocketException');
    expect((await repo.get(id))!.failureType, 'SocketException');
    expect(() => repo.setFailure(id, 'SocketException: host api.groq.com'), throwsArgumentError);
  });

  test('markDone and discard drop the audio and leave the pending list', () async {
    final a = await repo.createVoice(Uint8List(8));
    final b = await repo.createVoice(Uint8List(8));
    await repo.markDone(a);
    await repo.discard(b);
    final ca = (await repo.get(a))!, cb = (await repo.get(b))!;
    expect((ca.status, ca.audio, cb.status, cb.audio), ('done', null, 'discarded', null));
    expect(await repo.pendingCount(), 0);
  });

  test('proposals json round-trip', () {
    final ps = <Proposal>[
      MoneyProposal(
        type: IntentType.expense,
        confidence: 80,
        amountMinor: 40000,
        currency: 'IQD',
        accountId: 3,
        workspaceId: 2,
        categoryId: 7,
        occurredAt: DateTime(2026, 10, 22, 15, 40),
        description: 'تكسي "بزفاي"',
        bucketTag: 'emergency',
      ),
      const MoneyProposal(type: IntentType.income, confidence: 40),
      TransferProposal(
        confidence: 100,
        fromAccountId: 1,
        toAccountId: 2,
        amountMinor: 10000,
        toAmountMinor: 131000,
        rateE6: 1310000000,
        transferKind: 'transfer',
        occurredAt: DateTime.utc(2026, 10, 23),
      ),
      const DebtProposal(
        confidence: 60,
        counterparty: 'احمد',
        direction: 'owed_to_me',
        leg: 'repayment',
        amountMinor: 50000,
        currency: 'IQD',
        accountId: 1,
      ),
      TaskProposal(title: 'اتصل', confidence: 100, due: DateTime(2026, 10, 24, 11), workspaceId: 2),
      const NoteProposal(text: 'سطر\nثاني', workspaceId: 1),
    ];
    final json = encodeProposals(ps);
    final back = decodeProposals(json);
    expect(encodeProposals(back), json);
    expect(back.map((p) => p.runtimeType), ps.map((p) => p.runtimeType));
    final m = back[0] as MoneyProposal;
    expect(
      (m.amountMinor, m.occurredAt, m.description, m.bucketTag),
      (40000, DateTime(2026, 10, 22, 15, 40), 'تكسي "بزفاي"', 'emergency'),
    );
    expect((back[2] as TransferProposal).occurredAt, DateTime.utc(2026, 10, 23));
  });
}
