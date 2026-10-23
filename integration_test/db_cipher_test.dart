import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:path_provider/path_provider.dart';

/// Runs on a phone: `flutter test integration_test/db_cipher_test.dart -d <id>`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SQLCipher is active and encrypts the file on device', (t) async {
    final dir = await (await getTemporaryDirectory()).createTemp('cipher');
    final file = appDatabaseFile(dir);
    const key = Sensitive('00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff');

    final db = await openAppDatabase(file: file, hexKey: key);
    final v = await db.customSelect('PRAGMA cipher_version').getSingle();
    expect('${v.data.values.first}', isNotEmpty);
    await db.into(db.workspaces).insert(WorkspacesCompanion.insert(
        name: 'Device secret', iconKey: 'person', colorArgb: 0, sortOrder: 0, createdAt: DateTime.utc(2026)));
    await db.close();

    expect(String.fromCharCodes(file.readAsBytesSync().sublist(0, 16)), isNot(startsWith('SQLite format 3')));

    final again = await openAppDatabase(file: file, hexKey: key);
    expect(await again.select(again.workspaces).get(), hasLength(1));
    await again.close();

    final wrong = await openAppDatabase(
        file: file, hexKey: const Sensitive('ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'));
    await expectLater(wrong.select(wrong.workspaces).get(), throwsA(anything));
    await wrong.close();
    await dir.delete(recursive: true);
    expect(File(file.path).existsSync(), isFalse);
  });
}
