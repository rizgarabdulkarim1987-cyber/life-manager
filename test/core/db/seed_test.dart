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

  test('seed creates 4 workspaces in spec order', () async {
    await seedInitialData(db, names);
    final ws = await (db.select(db.workspaces)..orderBy([(w) => OrderingTerm.asc(w.sortOrder)])).get();
    expect(ws.map((w) => w.name), ['Personal', 'Buzzify', 'Related / EO', 'Other Projects']);
  });

  test('seed creates 6 cash accounts, IQD+USD per Personal/Buzzify/EO', () async {
    await seedInitialData(db, names);
    final acc = await db.select(db.accounts).get();
    expect(acc, hasLength(6));
    expect(acc.where((a) => a.currencyCode == 'IQD'), hasLength(3));
    expect(acc.where((a) => a.currencyCode == 'USD'), hasLength(3));
    expect(acc.every((a) => a.kind == 'cash' && a.openingBalanceMinor == 0), isTrue);
    expect(acc.map((a) => a.name), contains('Buzzify · Cash USD'));

    final other = (await db.select(db.workspaces).get()).firstWhere((w) => w.name == 'Other Projects');
    expect(acc.where((a) => a.workspaceId == other.id), isEmpty);
  });

  test('seed is idempotent', () async {
    await seedInitialData(db, names);
    await seedInitialData(db, names);
    expect(await db.select(db.accounts).get(), hasLength(6));
    expect(await db.select(db.workspaces).get(), hasLength(4));
  });

  test('isSetupCompleted reads the settings flag', () async {
    expect(await isSetupCompleted(db), isFalse);
    await db.update(db.appSettingsTable).write(const AppSettingsTableCompanion(setupCompleted: Value(true)));
    expect(await isSetupCompleted(db), isTrue);
  });
}
