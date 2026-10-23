import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';

class NotesRepository {
  NotesRepository(this._db);

  final AppDatabase _db;

  DateTime get _now => DateTime.now().toUtc();

  String _clean(String body) {
    final b = body.trim();
    if (b.isEmpty) throw ArgumentError.value(body, 'body');
    return b;
  }

  Future<int> add(String body, {int? projectId, int? captureId}) => _db
      .into(_db.notes)
      .insert(
        NotesCompanion.insert(
          body: _clean(body),
          projectId: Value(projectId),
          captureId: Value(captureId),
          createdAt: _now,
          updatedAt: _now,
        ),
      );

  Future<Note?> get(int id) => (_db.select(_db.notes)..where((n) => n.id.equals(id))).getSingleOrNull();

  Future<void> update(int id, String body) => (_db.update(
    _db.notes,
  )..where((n) => n.id.equals(id))).write(NotesCompanion(body: Value(_clean(body)), updatedAt: Value(_now)));

  /// Deletes and returns the row, so Undo can [restore] it.
  Future<Note?> delete(int id) async {
    final n = await get(id);
    if (n != null) await (_db.delete(_db.notes)..where((x) => x.id.equals(id))).go();
    return n;
  }

  Future<void> restore(Note n) => _db.into(_db.notes).insert(n, mode: InsertMode.insertOrReplace);

  Stream<List<Note>> watchAll({int? projectId}) {
    final q = _db.select(_db.notes)..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]);
    if (projectId != null) q.where((n) => n.projectId.equals(projectId));
    return q.watch();
  }
}
