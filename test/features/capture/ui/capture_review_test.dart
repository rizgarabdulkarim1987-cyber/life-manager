import 'package:life_manager/app/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/storage/secure_store.dart';
import 'package:life_manager/features/capture/data/capture_repository.dart';
import 'package:life_manager/features/capture/domain/proposal.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/finance_ui.dart';

Future<void> _reveal(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(
    f,
    200,
    scrollable: find.descendant(of: find.byKey(const ValueKey('cap-list')), matching: find.byType(Scrollable)).first,
  );
  await settle(t);
}

Future<ProviderContainer> _open(WidgetTester t) =>
    pumpApp(t, locale: 'en', overrides: [secureStoreProvider.overrideWithValue(InMemorySecureStore())]);

void main() {
  testWidgets('review: two proposals, drop one, save → one transaction with captureId; capture done', (t) async {
    final c = await _open(t);
    final cash = await accountId(c, 'Personal', 'IQD');
    final repo = CaptureRepository(dbOf(c));
    late int id;
    id = await dbWrite(t, () => repo.createText('دفعت 40 الف تكسي وبعدين 15 الف غدا'));
    await dbWrite(
      t,
      () => repo.setParsed(id, [
        MoneyProposal(type: IntentType.expense, confidence: 90, amountMinor: 40000, currency: 'IQD', accountId: cash),
        MoneyProposal(type: IntentType.expense, confidence: 90, amountMinor: 15000, currency: 'IQD', accountId: cash),
      ], by: 'rules'),
    );
    await pushRoute(t, c, '/capture/$id');

    expect(find.byKey(const ValueKey('capture-review')), findsOneWidget);
    expect(find.byKey(const ValueKey('cap-badge-rules')), findsOneWidget);
    expect(find.byKey(const ValueKey('cap-card-0')), findsOneWidget);
    await _reveal(t, find.byKey(const ValueKey('cap-keep-1')));
    await t.tap(find.byKey(const ValueKey('cap-keep-1')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('cap-save')));
    await settle(t);

    final db = dbOf(c);
    final txs = await t.runAsync(() => (db.select(db.transactions)..where((x) => x.captureId.equals(id))).get());
    expect(txs, hasLength(1));
    expect(txs!.single.amountMinor, 40000);
    expect((await t.runAsync(() => repo.get(id)))!.status, 'done');
    expect(find.byKey(const ValueKey('capture-review')), findsNothing);
  });

  testWidgets('review: missing account blocks Save', (t) async {
    final c = await _open(t);
    final cash = await accountId(c, 'Personal', 'IQD');
    final repo = CaptureRepository(dbOf(c));
    late int id;
    id = await dbWrite(t, () => repo.createText('40 الف'));
    await dbWrite(
      t,
      () => repo.setParsed(id, [
        const MoneyProposal(type: IntentType.expense, confidence: 50, amountMinor: 40000, currency: 'IQD'),
      ], by: 'rules'),
    );
    await pushRoute(t, c, '/capture/$id');

    expect(saveEnabled(t, 'cap-save'), isFalse);
    expect(find.byKey(const ValueKey('cap-missing-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('cap-check-0')), findsOneWidget, reason: 'confidence below 60');
    await pickAccount(t, 'cap-account-0', cash);
    expect(saveEnabled(t, 'cap-save'), isTrue);
    expect(find.byKey(const ValueKey('cap-missing-0')), findsNothing);
  });

  testWidgets('review: editing transcript and parse again replaces the cards', (t) async {
    final c = await _open(t);
    final repo = CaptureRepository(dbOf(c));
    late int id;
    id = await dbWrite(t, () => repo.createText('دفعت 40 الف تكسي'));
    await dbWrite(
      t,
      () => repo.setParsed(id, [
        const MoneyProposal(type: IntentType.expense, confidence: 90, amountMinor: 40000, currency: 'IQD'),
      ], by: 'rules'),
    );
    await pushRoute(t, c, '/capture/$id');
    expect(find.byKey(const ValueKey('cap-card-1')), findsNothing);

    await t.enterText(find.byKey(const ValueKey('cap-transcript')), 'دفعت 25 الف غدا. استلمت 500 دولار');
    await settle(t);
    await t.tap(find.byKey(const ValueKey('cap-reparse')));
    await settle(t);

    await _reveal(t, find.byKey(const ValueKey('cap-card-1')));
    expect(find.byKey(const ValueKey('cap-card-1')), findsOneWidget);
    final row = (await t.runAsync(() => repo.get(id)))!;
    expect(row.transcript, 'دفعت 25 الف غدا. استلمت 500 دولار');
    final ps = decodeProposals(row.parsedJson!);
    expect((ps[0] as MoneyProposal).amountMinor, 25000);
    expect((ps[1] as MoneyProposal).type, IntentType.income);
    expect(row.status, 'pending');
  });

  testWidgets('review: save moves a task to a new pending capture and shows the AI badge', (t) async {
    final c = await _open(t);
    final cash = await accountId(c, 'Personal', 'IQD');
    final repo = CaptureRepository(dbOf(c));
    late int id;
    id = await dbWrite(t, () => repo.createText('x'));
    await dbWrite(
      t,
      () => repo.setParsed(id, [
        const TaskProposal(title: 'اتصل بأحمد', confidence: 100),
        MoneyProposal(type: IntentType.expense, confidence: 90, amountMinor: 40000, currency: 'IQD', accountId: cash),
      ], by: 'ai'),
    );
    await pushRoute(t, c, '/capture/$id');
    expect(find.byKey(const ValueKey('cap-badge-ai')), findsOneWidget);
    expect(find.byKey(const ValueKey('cap-later-0')), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('cap-save')));
    await settle(t);
    final db = dbOf(c);
    final pending = await t.runAsync(() => (db.select(db.captures)..where((x) => x.status.equals('pending'))).get());
    expect(pending, hasLength(1), reason: 'the task moved to a new pending capture');
    expect(decodeProposals(pending!.single.parsedJson!).single, isA<TaskProposal>());
    expect((await t.runAsync(() => repo.get(id)))!.status, 'done');
  });

  testWidgets('review: keep in Inbox stores the edits and leaves the capture pending', (t) async {
    final c = await _open(t);
    final cash = await accountId(c, 'Personal', 'IQD');
    final repo = CaptureRepository(dbOf(c));
    late int id;
    id = await dbWrite(t, () => repo.createText('40 الف'));
    await dbWrite(
      t,
      () => repo.setParsed(id, [
        const MoneyProposal(type: IntentType.expense, confidence: 50, amountMinor: 40000, currency: 'IQD'),
      ], by: 'rules'),
    );
    await pushRoute(t, c, '/capture/$id');
    await pickAccount(t, 'cap-account-0', cash);
    await t.tap(find.byKey(const ValueKey('cap-keep-inbox')));
    await settle(t);
    expect(find.byKey(const ValueKey('capture-review')), findsNothing);
    final row = (await t.runAsync(() => repo.get(id)))!;
    expect(row.status, 'pending');
    expect((decodeProposals(row.parsedJson!).single as MoneyProposal).accountId, cash);
  });
}
