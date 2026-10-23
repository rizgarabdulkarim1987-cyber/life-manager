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

  test('setBaseCurrency accepts ISO codes and rejects "iq"', () async {
    await repo.setBaseCurrency('USD');
    expect((await repo.get()).baseCurrency, 'USD');
    expect(() => repo.setBaseCurrency('iq'), throwsArgumentError);
  });

  test('AI settings persist', () async {
    await repo.setAiOnlineEnabled(false);
    await repo.setConsent(AiFeature.voice, ConsentState.granted);
    await repo.setConsent(AiFeature.parse, ConsentState.declined);
    await repo.setGroqModels(stt: 'whisper-large-v3', llm: 'some-llm');
    await repo.setLocalWhisperModel('base');
    await repo.setUnallocatedIncomeAlert(true);
    await repo.setBucketsConfirmed();
    final s = await repo.get();
    expect((s.aiOnlineEnabled, s.aiVoiceConsent, s.aiParseConsent), (false, 'granted', 'declined'));
    expect((s.groqSttModel, s.groqLlmModel, s.localWhisperModel), ('whisper-large-v3', 'some-llm', 'base'));
    expect((s.unallocatedIncomeAlert, s.bucketsConfirmed), (true, true));
    await repo.setConsent(AiFeature.voice, null);
    expect((await repo.get()).aiVoiceConsent, isNull);
  });

  test('model names must be non-empty and short', () {
    expect(() => repo.setGroqModels(stt: '  '), throwsArgumentError);
    expect(() => repo.setGroqModels(llm: 'x' * 101), throwsArgumentError);
    expect(() => repo.setLocalWhisperModel('large'), throwsArgumentError);
  });
}
