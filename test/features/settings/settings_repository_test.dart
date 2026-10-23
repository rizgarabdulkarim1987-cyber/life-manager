import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/features/settings/settings_repository.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SettingsRepository(db);
  });
  tearDown(() => db.close());

  test('setLocale is reflected in watch()', () async {
    await repo.setLocale('ckb');
    expect((await repo.watch().first).localeCode, 'ckb');
  });

  test('setLocale rejects unsupported codes', () {
    expect(() => repo.setLocale('fr'), throwsArgumentError);
  });

  test('setThemeMode persists light and dark', () async {
    await repo.setThemeMode(ThemeMode.light);
    expect((await repo.get()).themeMode, 'light');
    await repo.setThemeMode(ThemeMode.dark);
    expect((await repo.get()).themeMode, 'dark');
  });

  test('themeModeOf maps stored values', () {
    expect(themeModeOf('light'), ThemeMode.light);
    expect(themeModeOf('dark'), ThemeMode.dark);
    expect(themeModeOf('garbage'), ThemeMode.dark);
  });

  test('setLockTimeout clamps to 0..3600 seconds', () async {
    await repo.setLockTimeout(const Duration(hours: 5));
    expect((await repo.get()).lockTimeoutSeconds, 3600);
    await repo.setLockTimeout(const Duration(seconds: -4));
    expect((await repo.get()).lockTimeoutSeconds, 0);
  });

  test('biometric flag, setup flag and last backup persist', () async {
    await repo.setBiometricEnabled(true);
    await repo.markSetupCompleted();
    final t = DateTime.utc(2026, 10, 22, 12);
    await repo.setLastBackupAt(t);
    final s = await repo.get();
    expect(s.biometricEnabled, isTrue);
    expect(s.setupCompleted, isTrue);
    expect(s.lastBackupAt!.toUtc(), t);
  });
}
