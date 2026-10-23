import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';

List<String> workspaceAliases(Workspace w) =>
    w.aliases.split(',').map((a) => a.trim()).where((a) => a.isNotEmpty).toList();

class WorkspacesRepository {
  WorkspacesRepository(this._db);

  final AppDatabase _db;

  Stream<List<Workspace>> watchAll({bool includeArchived = false}) {
    final q = _db.select(_db.workspaces)..orderBy([(w) => OrderingTerm.asc(w.sortOrder)]);
    if (!includeArchived) q.where((w) => w.isArchived.equals(false));
    return q.watch();
  }

  Future<int> create({required String name, required String iconKey, required int colorArgb}) async {
    final last =
        await (_db.select(_db.workspaces)
              ..orderBy([(w) => OrderingTerm.desc(w.sortOrder)])
              ..limit(1))
            .getSingleOrNull();
    return _db
        .into(_db.workspaces)
        .insert(
          WorkspacesCompanion.insert(
            name: name.trim(),
            iconKey: iconKey,
            colorArgb: colorArgb,
            sortOrder: (last?.sortOrder ?? -1) + 1,
            createdAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<void> update(Workspace w) => _db.update(_db.workspaces).replace(w);

  Future<void> setAliases(int id, List<String> aliases) {
    final clean = aliases.map((a) => a.trim().replaceAll(',', ' ')).where((a) => a.isNotEmpty).toSet().join(',');
    return (_db.update(
      _db.workspaces,
    )..where((w) => w.id.equals(id))).write(WorkspacesCompanion(aliases: Value(clean)));
  }

  Future<void> setCountsInBuckets(int id, bool v) =>
      (_db.update(_db.workspaces)..where((w) => w.id.equals(id))).write(WorkspacesCompanion(countsInBuckets: Value(v)));

  Future<bool> hasActiveAccounts(int id) async =>
      (await (_db.select(_db.accounts)
                ..where((a) => a.workspaceId.equals(id) & a.isArchived.equals(false))
                ..limit(1))
              .get())
          .isNotEmpty;

  /// Refuses while the workspace still has accounts in use.
  Future<void> archive(int id) => _db.transaction(() async {
    if (await hasActiveAccounts(id)) throw StateError('workspace has active accounts');
    await (_db.update(
      _db.workspaces,
    )..where((w) => w.id.equals(id))).write(const WorkspacesCompanion(isArchived: Value(true)));
  });
}
