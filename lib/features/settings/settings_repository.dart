import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../../core/db/app_database.dart';

const kSupportedLocaleCodes = {'ar', 'en', 'ckb'};
const kMaxLockTimeout = Duration(hours: 1);

ThemeMode themeModeOf(String stored) => stored == 'light' ? ThemeMode.light : ThemeMode.dark;

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$AppSettingsTableTable, AppSetting> get _row =>
      _db.select(_db.appSettingsTable)..where((s) => s.id.equals(1));

  Stream<AppSetting> watch() => _row.watchSingle();

  Future<AppSetting> get() => _row.getSingle();

  Future<void> _write(AppSettingsTableCompanion c) =>
      (_db.update(_db.appSettingsTable)..where((s) => s.id.equals(1))).write(c);

  Future<void> setLocale(String code) {
    if (!kSupportedLocaleCodes.contains(code)) throw ArgumentError.value(code, 'code', 'unsupported locale');
    return _write(AppSettingsTableCompanion(localeCode: Value(code)));
  }

  Future<void> setThemeMode(ThemeMode m) =>
      _write(AppSettingsTableCompanion(themeMode: Value(m == ThemeMode.light ? 'light' : 'dark')));

  Future<void> setLockTimeout(Duration d) {
    final seconds = d.inSeconds.clamp(0, kMaxLockTimeout.inSeconds);
    return _write(AppSettingsTableCompanion(lockTimeoutSeconds: Value(seconds)));
  }

  Future<void> setBiometricEnabled(bool v) => _write(AppSettingsTableCompanion(biometricEnabled: Value(v)));

  Future<void> markSetupCompleted() => _write(const AppSettingsTableCompanion(setupCompleted: Value(true)));

  Future<void> setLastBackupAt(DateTime t) => _write(AppSettingsTableCompanion(lastBackupAt: Value(t)));
}
