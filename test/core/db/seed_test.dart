import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/core/db/seed.dart';

const names = SeedNames(
  personal: 'Personal',
  buzzify: 'Buzzify',
  eo: 'Related / EO',
  otherProjects: 'Other Projects',
  cashIqd: 'Cash IQD',
  cashUsd: 'Cash USD',
);

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('fresh install has no categories and no accounts until setup', () async {
    expect(await db.select(db.categories).get(), isEmpty);
    expect(await db.select(db.accounts).get(), isEmpty);
    expect(await db.select(db.buckets).get(), hasLength(3));
    await seedInitialData(db, names);
    expect((await db.select(db.workspaces).get()).map((w) => (w.name, w.countsInBuckets)), [('Personal', true)]);
    expect(await db.select(db.accounts).get(), isEmpty);
    expect(await db.select(db.categories).get(), isEmpty);
  });

  test('seed is idempotent', () async {
    await seedInitialData(db, names);
    await seedInitialData(db, names);
    expect(await db.select(db.workspaces).get(), hasLength(1));
  });

  test('the demo seed (tests, screenshots) adds the four workspaces, six accounts and the categories', () async {
    await seedInitialData(db, names);
    await seedDemoData(db, names);
    final ws = await (db.select(db.workspaces)..orderBy([(w) => OrderingTerm.asc(w.sortOrder)])).get();
    expect(ws.map((w) => w.name), ['Personal', 'Buzzify', 'Related / EO', 'Other Projects']);
    final acc = await db.select(db.accounts).get();
    expect(acc, hasLength(6));
    expect(acc.map((a) => a.name), contains('Buzzify · Cash USD'));
    expect(await db.select(db.categories).get(), hasLength(16));
  });

  test('isSetupCompleted reads the settings flag', () async {
    expect(await isSetupCompleted(db), isFalse);
    await db.update(db.appSettingsTable).write(const AppSettingsTableCompanion(setupCompleted: Value(true)));
    expect(await isSetupCompleted(db), isTrue);
  });
}
