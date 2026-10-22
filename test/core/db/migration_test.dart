import 'package:drift_dev/api/migrations_native.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/db/app_database.dart';

import 'generated/schema.dart';

void main() {
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('schema v1 matches drift_schemas/drift_schema_v1.json', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    await verifier.migrateAndValidate(db, 1);
    await db.close();
  });

  test('current schemaVersion has a dumped schema', () async {
    final db = AppDatabase(NativeDatabase.memory());
    expect(GeneratedHelper.versions, contains(db.schemaVersion));
    await db.close();
  });
}
