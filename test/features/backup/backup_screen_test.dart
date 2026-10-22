import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/providers.dart';
import 'package:life_manager/core/crypto/kdf.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/core/l10n/ckb_fallback_localizations.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/core/theme/app_theme.dart';
import 'package:life_manager/features/backup/backup_format.dart';
import 'package:life_manager/features/backup/backup_screen.dart';
import 'package:life_manager/features/backup/backup_service.dart';

class FakeBackupService implements BackupService {
  String? createdWith;
  String? restoredWith;
  Exception? restoreError = const BackupWrongPasswordException();

  @override
  Future<Uint8List> createBackup(Sensitive<String> password, {KdfParams? kdf, DateTime? now}) async {
    createdWith = password.value;
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  BackupHeader inspect(Uint8List file) => BackupHeader(
    formatVersion: 1,
    schemaVersion: 1,
    appVersion: '0.9.3',
    createdAtUtc: DateTime.utc(2026, 10, 1, 10),
    kdf: const KdfParams(memoryKiB: 1024, iterations: 1),
    salt: Uint8List(16),
    nonce: Uint8List(12),
  );

  @override
  Future<void> restore(Uint8List file, Sensitive<String> password, {DateTime? now}) async {
    restoredWith = password.value;
    if (restoreError != null) throw restoreError!;
  }
}

class FakeFiles implements BackupFiles {
  String? savedName;
  @override
  Future<bool> save(String fileName, Uint8List bytes) async {
    savedName = fileName;
    return true;
  }

  @override
  Future<Uint8List?> pick() async => Uint8List.fromList([9]);
}

void main() {
  AppDatabase? db;
  late FakeBackupService service;
  late FakeFiles files;
  ProviderContainer? container;

  tearDown(() async {
    container?.dispose();
    await db?.close();
    container = null;
    db = null;
  });

  Future<void> pump(WidgetTester t, {String locale = 'en'}) async {
    final database = db = AppDatabase(NativeDatabase.memory());
    service = FakeBackupService();
    files = FakeFiles();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        backupServiceProvider.overrideWithValue(service),
        backupFilesProvider.overrideWithValue(files),
      ],
    );
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container!,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.dark),
          locale: Locale(locale),
          supportedLocales: kSupportedLocales,
          localizationsDelegates: appLocalizationDelegates,
          home: const BackupScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('shows the loss warning and never-backed-up state', (t) async {
    await pump(t);
    expect(find.textContaining('everything is gone'), findsOneWidget);
    expect(find.text('Never backed up'), findsOneWidget);
  });

  testWidgets('short password is refused', (t) async {
    await pump(t);
    await t.enterText(find.byKey(const ValueKey('backup-pw')), 'short');
    await t.enterText(find.byKey(const ValueKey('backup-pw-confirm')), 'short');
    await t.tap(find.byKey(const ValueKey('create-backup')));
    await t.pumpAndSettle();
    expect(find.text('Use at least 8 characters'), findsOneWidget);
    expect(service.createdWith, isNull);
  });

  testWidgets('mismatched confirmation is refused', (t) async {
    await pump(t);
    await t.enterText(find.byKey(const ValueKey('backup-pw')), 'long-enough-1');
    await t.enterText(find.byKey(const ValueKey('backup-pw-confirm')), 'long-enough-2');
    await t.tap(find.byKey(const ValueKey('create-backup')));
    await t.pumpAndSettle();
    expect(find.text("Passwords don't match"), findsOneWidget);
  });

  testWidgets('creates and saves a backup', (t) async {
    await pump(t);
    await t.enterText(find.byKey(const ValueKey('backup-pw')), 'Correct-Horse-9');
    await t.pump();
    expect(find.text('Strong'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('backup-pw-confirm')), 'Correct-Horse-9');
    await t.tap(find.byKey(const ValueKey('create-backup')));
    await t.pumpAndSettle();
    expect(service.createdWith, 'Correct-Horse-9');
    expect(files.savedName, endsWith('.plmbackup'));
    expect(find.text('Backup saved'), findsOneWidget);
  });

  testWidgets('restore confirm shows date and version; wrong password is reported', (t) async {
    await pump(t);
    await t.tap(find.byKey(const ValueKey('restore-backup')));
    await t.pumpAndSettle();
    expect(find.text('Replace all current data?'), findsOneWidget);
    expect(find.textContaining('0.9.3'), findsOneWidget);
    expect(find.textContaining('2026'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('restore-confirm')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('restore-pw')), 'whatever');
    await t.tap(find.byKey(const ValueKey('restore-pw-ok')));
    await t.pumpAndSettle();
    expect(service.restoredWith, 'whatever');
    expect(find.text('Wrong password, or the file is damaged.'), findsOneWidget);
  });

  testWidgets('a newer backup is reported as too new', (t) async {
    await pump(t);
    service.restoreError = const BackupTooNewException(2, 1);
    await t.tap(find.byKey(const ValueKey('restore-backup')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('restore-confirm')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('restore-pw')), 'x');
    await t.tap(find.byKey(const ValueKey('restore-pw-ok')));
    await t.pumpAndSettle();
    expect(find.textContaining('newer version'), findsOneWidget);
  });

  testWidgets('fits a small phone in Kurdish', (t) async {
    t.view.physicalSize = const Size(320 * 3, 568 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await pump(t, locale: 'ckb');
    expect(t.takeException(), isNull);
  });

  test('password strength', () {
    expect(passwordStrength('abc'), PasswordStrength.weak);
    expect(passwordStrength('abcdefghijkl'), PasswordStrength.weak);
    expect(passwordStrength('abcdefgh12'), PasswordStrength.fair);
    expect(passwordStrength('Abcdefgh12345!'), PasswordStrength.strong);
  });
}
