import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../../core/db/app_database.dart';

const kSupportedLocaleCodes = {'ar', 'en', 'ckb'};
const kMaxLockTimeout = Duration(hours: 1);
const kVaultAutoLockChoices = [Duration(minutes: 1), Duration(minutes: 2), Duration(minutes: 5), Duration(minutes: 10)];

enum AiFeature { voice, parse }

enum ConsentState { granted, declined }

final _isoCode = RegExp(r'^[A-Z]{3}$');

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

  Future<void> setBaseCurrency(String code) {
    if (!_isoCode.hasMatch(code)) throw ArgumentError.value(code, 'code', 'not an ISO 4217 code');
    return _write(AppSettingsTableCompanion(baseCurrency: Value(code)));
  }

  /// Idle time before the vault locks itself (spec §9.2): 1, 2, 5 or 10 minutes.
  Future<void> setVaultAutoLock(Duration d) {
    if (!kVaultAutoLockChoices.contains(d)) throw ArgumentError.value(d, 'd', 'unsupported vault auto-lock');
    return _write(AppSettingsTableCompanion(vaultAutoLockSeconds: Value(d.inSeconds)));
  }

  Future<void> setAiOnlineEnabled(bool v) => _write(AppSettingsTableCompanion(aiOnlineEnabled: Value(v)));

  /// `null` resets the consent so the sheet shows again.
  Future<void> setConsent(AiFeature f, ConsentState? s) {
    final v = Value(s?.name);
    return _write(
      f == AiFeature.voice
          ? AppSettingsTableCompanion(aiVoiceConsent: v)
          : AppSettingsTableCompanion(aiParseConsent: v),
    );
  }

  Future<void> setGroqModels({String? stt, String? llm}) {
    String check(String m) {
      final t = m.trim();
      if (t.isEmpty || t.length > 100) throw ArgumentError.value(m, 'model');
      return t;
    }

    return _write(
      AppSettingsTableCompanion(
        groqSttModel: stt == null ? const Value.absent() : Value(check(stt)),
        groqLlmModel: llm == null ? const Value.absent() : Value(check(llm)),
      ),
    );
  }

  Future<void> setLocalWhisperModel(String m) {
    if (m != 'small' && m != 'base') throw ArgumentError.value(m, 'model');
    return _write(AppSettingsTableCompanion(localWhisperModel: Value(m)));
  }

  Future<void> setUnallocatedIncomeAlert(bool v) => _write(AppSettingsTableCompanion(unallocatedIncomeAlert: Value(v)));

  Future<void> setBucketsConfirmed() => _write(const AppSettingsTableCompanion(bucketsConfirmed: Value(true)));
}
