import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/core/db/seed.dart';

const fixtureNames = SeedNames(
  personal: 'Personal',
  buzzify: 'Buzzify',
  eo: 'Related / EO',
  otherProjects: 'Other Projects',
  cashIqd: 'Cash IQD',
  cashUsd: 'Cash USD',
);

/// An in-memory database with the Phase 1 seed and the finance defaults.
class FinanceFixture {
  FinanceFixture._(this.db, this._accounts, this._workspaces, this._categories);

  final AppDatabase db;
  final List<Account> _accounts;
  final List<Workspace> _workspaces;
  final List<Category> _categories;

  int _acc(int wsIndex, String currency) =>
      _accounts.firstWhere((a) => a.workspaceId == _workspaces[wsIndex].id && a.currencyCode == currency).id;

  int get personalWs => _workspaces[0].id;
  int get buzzWs => _workspaces[1].id;
  int get eoWs => _workspaces[2].id;
  int get otherWs => _workspaces[3].id;
  int get personalIqd => _acc(0, 'IQD');
  int get personalUsd => _acc(0, 'USD');
  int get buzzIqd => _acc(1, 'IQD');
  int get buzzUsd => _acc(1, 'USD');
  int get eoIqd => _acc(2, 'IQD');
  int get eoUsd => _acc(2, 'USD');

  int cat(String systemKey) => _categories.firstWhere((c) => c.systemKey == systemKey).id;

  Future<void> setOpening(int accountId, int minor) =>
      (db.update(db.accounts)..where((a) => a.id.equals(accountId))).write(
        AccountsCompanion(openingBalanceMinor: Value(minor)),
      );
}

Future<FinanceFixture> financeFixture() async {
  final db = AppDatabase(NativeDatabase.memory());
  await seedInitialData(db, fixtureNames);
  final ws = await (db.select(db.workspaces)..orderBy([(w) => OrderingTerm.asc(w.sortOrder)])).get();
  return FinanceFixture._(db, await db.select(db.accounts).get(), ws, await db.select(db.categories).get());
}
