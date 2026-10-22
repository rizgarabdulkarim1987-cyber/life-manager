import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/core/db/finance_seed.dart';
import 'package:life_manager/core/db/seed.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import 'seed_test.dart' show names;

void main() {
  late AppDatabase db;
  late int accountId;
  late int usdAccountId;
  late int wsId;
  final now = DateTime.utc(2026, 10, 23);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await seedInitialData(db, names);
    final accounts = await db.select(db.accounts).get();
    accountId = accounts.firstWhere((a) => a.currencyCode == 'IQD').id;
    usdAccountId = accounts.firstWhere((a) => a.currencyCode == 'USD').id;
    wsId = accounts.first.workspaceId;
  });
  tearDown(() => db.close());

  Future<int> insertTx({
    String type = 'expense',
    int amountMinor = 1000,
    int? toAccountId,
    int? toAmountMinor,
    String? transferKind,
    String? bucketTag,
    int? debtId,
    String? debtLeg,
  }) => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          type: type,
          accountId: accountId,
          workspaceId: wsId,
          amountMinor: amountMinor,
          currencyCode: 'IQD',
          toAccountId: Value(toAccountId),
          toAmountMinor: Value(toAmountMinor),
          transferKind: Value(transferKind),
          bucketTag: Value(bucketTag),
          debtId: Value(debtId),
          debtLeg: Value(debtLeg),
          occurredAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

  test('fresh v2 db seeds 16 categories and 3 buckets summing to 10000', () async {
    expect(await db.select(db.categories).get(), hasLength(16));
    final buckets = await db.select(db.buckets).get();
    expect(buckets.map((b) => b.systemKey), ['expenses', 'emergency', 'investment']);
    expect(buckets.fold<int>(0, (s, b) => s + b.percentBp), 10000);
  });

  test('seed is idempotent', () async {
    await seedFinanceDefaults(db);
    await seedFinanceDefaults(db);
    expect(await db.select(db.categories).get(), hasLength(16));
    expect(await db.select(db.buckets).get(), hasLength(3));
  });

  test('Personal counts in buckets, others do not', () async {
    final ws = await (db.select(db.workspaces)..orderBy([(w) => OrderingTerm.asc(w.sortOrder)])).get();
    expect(ws.map((w) => w.countsInBuckets), [true, false, false, false]);
  });

  test('transfer row without toAccountId is rejected', () async {
    await expectLater(insertTx(type: 'transfer', transferKind: 'transfer'), throwsA(isA<SqliteException>()));
  });

  test('a valid transfer is accepted', () async {
    await insertTx(type: 'transfer', toAccountId: usdAccountId, toAmountMinor: 1, transferKind: 'transfer');
  });

  test('expense with amount 0 or negative is rejected; adjustment −500 is accepted', () async {
    await expectLater(insertTx(amountMinor: 0), throwsA(isA<SqliteException>()));
    await expectLater(insertTx(amountMinor: -5), throwsA(isA<SqliteException>()));
    await expectLater(insertTx(type: 'adjustment', amountMinor: 0), throwsA(isA<SqliteException>()));
    await insertTx(type: 'adjustment', amountMinor: -500);
  });

  test('bucketTag on an income is rejected', () async {
    await expectLater(insertTx(type: 'income', bucketTag: 'emergency'), throwsA(isA<SqliteException>()));
    await insertTx(bucketTag: 'emergency');
  });

  test('debt_payment needs a debt and a leg', () async {
    await expectLater(insertTx(type: 'debt_payment'), throwsA(isA<SqliteException>()));
  });

  test('deleting a transaction cascades its allocations', () async {
    final tx = await insertTx(type: 'income');
    final bucket = (await db.select(db.buckets).get()).first;
    await db
        .into(db.bucketAllocations)
        .insert(
          BucketAllocationsCompanion.insert(
            transactionId: tx,
            bucketId: bucket.id,
            amountBaseMinor: 700,
            baseCurrency: 'IQD',
            createdAt: now,
          ),
        );
    await (db.delete(db.transactions)..where((t) => t.id.equals(tx))).go();
    expect(await db.select(db.bucketAllocations).get(), isEmpty);
  });

  test('settings carry the phase 2 defaults', () async {
    final s = await db.select(db.appSettingsTable).getSingle();
    expect(s.aiOnlineEnabled, isTrue);
    expect(s.aiVoiceConsent, isNull);
    expect(s.groqSttModel, 'whisper-large-v3-turbo');
    expect(s.groqLlmModel, 'llama-3.3-70b-versatile');
    expect(s.localWhisperModel, 'small');
    expect(s.unallocatedIncomeAlert, isFalse);
    expect(s.bucketsConfirmed, isFalse);
  });

  test('category needs a systemKey or a name', () async {
    await expectLater(
      db
          .into(db.categories)
          .insert(CategoriesCompanion.insert(kind: 'expense', iconKey: 'tag', colorArgb: 0, sortOrder: 99)),
      throwsA(isA<SqliteException>()),
    );
  });
}
