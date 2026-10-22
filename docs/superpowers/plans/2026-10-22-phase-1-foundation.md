# Phase 1 — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An installable, signed release APK that has the app's foundation working end to end. Phases 2–6 then add features on top without reworking it:
- first-run setup (seeded workspaces and accounts)
- the dark/light theme
- Arabic, English and Kurdish Sorani with RTL
- an encrypted database
- app lock (PIN plus biometrics)
- a Settings screen
- encrypted backup and restore

**Architecture:**
- Flutter app with Riverpod for state and DI and go_router for navigation.
- Drift over SQLCipher, whose key lives in Android Keystore-backed secure storage.
- Code is split by feature (`lib/features/<feature>/`), with shared building blocks in `lib/core/`.
- Crypto is behind two small interfaces (`Kdf`, `Aead`), so host tests and the device use the same code paths.

**Tech Stack:**
- Flutter 3.47.7 / Dart 3.13, Riverpod, go_router, Drift with SQLCipher.
- Crypto and storage: sodium_libs (Argon2id), cryptography + cryptography_flutter (AES-256-GCM), flutter_secure_storage.
- Platform: local_auth, file_picker.
- Packaging: archive, crypto (sha256), flutter_localizations / gen-l10n.

**Spec:** `docs/superpowers/specs/2026-10-22-personal-life-manager-design.md`. Read §5, §6, §7, §9.1–9.2, §13, §14 phase 1, §15, and Appendix A (UI, Settings, Backup, Tests).

## Global Constraints

- No Google services or SDKs: no Firebase, Play Services, ML Kit or Google Fonts fetching. Fonts are bundled.
- No analytics, crash reporting or telemetry. Phase 1 adds no `INTERNET` permission.
- Android only. `minSdk 26`; compile and target the latest SDK that Flutter 3.47.7's template uses.
- applicationId `com.personal.lifemanager`, Dart package `life_manager`, app label "My Life Manager" (Arabic label «مدير حياتي»).
- Money is never `double`; amounts are integer minor units. Phase 1 seeds accounts only and does no money math.
- Default locale `ar`. Supported locales: `ar`, `en`, `ckb`. Default theme: dark.
- Argon2id default params: m = 65536 KiB, t = 3, p = 1, salt 16 bytes, key 32 bytes. Fallback when 64 MiB can't be allocated: m = 19456 KiB, t = 2, p = 1.
- AES-256-GCM: 12-byte random nonce per seal, 16-byte tag.
- Secrets (PIN, DB key, backup password, derived keys) never reach logs, prefs, plaintext DB columns, `toString`, or exceptions.
- `FLAG_SECURE` on the whole app.
- Release keystore and `android/key.properties` are never committed.
- Theme tokens (from the approved mockup):
  - dark: bg `#060A13`, surface `#0B1224`, surfaceHigh `#0F1A33`, border `#1B2744`, text `#EEF2FA`, textMuted `#A3ADC2`
  - accent `#3B82FF`, success `#3DDC97`, danger `#FF6B7A`, warning `#F5B544`
  - Card radius 20; small radius 14.
- Bottom nav (RTL-aware): Home · Finance · [Mic FAB] · Tasks · Vault. Settings opens from the Home app bar.
- Out of scope for Phase 1, and owned by later plans:
  - the weekly backup reminder notification (Phase 5, with notifications)
  - currency and exchange-rate settings (Phase 2)
  - the vault master password and recovery key (Phase 3)
  - the `INTERNET` permission and AI settings (Phase 2)
- `flutter` below means `C:\Users\pc\dev\flutter\bin\flutter` until Task 1 adds it to PATH.

## Review Focus

1. **Wrong backup password, or a corrupted or truncated backup file.** Expect a clear, specific error, with the live data untouched. Covered by Task 12 (`decode` tests) and Task 13 (`restore leaves live db untouched on wrong password`).
2. **Backup made by a newer app or schema version.** Expect it refused before anything is changed. Covered by Task 12 (`rejects newer formatVersion`) and Task 13 (`rejects newer schema`).
3. **App killed during restore.** Expect the next launch to finish the swap or roll back to the pre-restore DB, never an empty or half-written database. Covered by Task 13 (`recoverInterruptedRestore` tests).
4. **PIN typed with Arabic-Indic digits (٠١٢٣ / ۰۱۲۳) from an Arabic or Kurdish keyboard.** Expect it accepted as the same PIN. Covered by Task 9 (`normalizeDigits` and `verify accepts arabic-indic digits`).
5. **Biometrics missing, not enrolled, or failing.** Expect the PIN to always unlock, and the setup flow to skip the biometric step when unavailable. Covered by Task 9 (`LockScreen falls back to PIN`) and Task 10 (`skips biometric step when unavailable`).

---

## File Structure

```
pubspec.yaml, analysis_options.yaml, l10n.yaml, .gitignore
assets/fonts/Vazirmatn-*.ttf
tool/fetch_test_libs.ps1                       # libsodium.dll (+ sqlite3 if needed) for host tests → tool/test_libs/ (gitignored)
lib/main.dart                                  # bootstrap: recoverInterruptedRestore → open db → runApp
lib/app/app.dart                               # MaterialApp.router, theme, locale, lock overlay
lib/app/router.dart                            # go_router routes
lib/app/providers.dart                         # root providers (db, secureStore, kdf, aead, sodium)
lib/core/theme/tokens.dart, app_theme.dart
lib/core/l10n/ckb_fallback_localizations.dart
lib/l10n/app_en.arb, app_ar.arb, app_ckb.arb  # generated: lib/l10n/gen/
lib/core/security/sensitive.dart
lib/core/logging/app_logger.dart
lib/core/crypto/random.dart, kdf.dart, aead.dart
lib/core/storage/secure_store.dart
lib/core/db/tables.dart, app_database.dart, db_key.dart, seed.dart
lib/features/settings/settings_repository.dart, settings_screen.dart
lib/features/lock/digits.dart, pin_service.dart, biometric_authenticator.dart, lock_controller.dart, lock_screen.dart
lib/features/setup/setup_flow.dart, splash_screen.dart
lib/features/shell/shell_scaffold.dart, home_screen.dart, placeholder_screen.dart
lib/features/backup/backup_format.dart, backup_payload.dart, db_snapshot.dart, backup_service.dart, backup_screen.dart
android/app/src/main/kotlin/com/personal/lifemanager/MainActivity.kt
android/app/build.gradle.kts                   # signing via key.properties
docs/INSTALL.md
test/... mirrors lib/ ;  integration_test/db_cipher_test.dart, crypto_device_test.dart
```

---

### Task 1: Toolchain finish and project scaffold

**Files:**
- Create: the project via `flutter create`, `.gitignore` additions, `analysis_options.yaml`, `pubspec.yaml` dependencies, `tool/fetch_test_libs.ps1`
- Test: `test/smoke_test.dart`

**Interfaces:**
- Produces: a buildable `life_manager` project; host-test native libs in `tool/test_libs/`.

- [ ] **Step 1: Finish the environment**
  - Add `C:\Users\pc\dev\flutter\bin`, `C:\Users\pc\dev\jdk-21\bin`, `%LOCALAPPDATA%\Android\Sdk\platform-tools` and `...\cmdline-tools\latest\bin` to the **user** PATH. Set user `JAVA_HOME=C:\Users\pc\dev\jdk-21` and `ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk`.
  - Accept the SDK licenses (the owner approved this on 2026-10-22): `flutter doctor --android-licenses`, answering `y`.
  - Run `sdkmanager "platform-tools" "platforms;android-<latest>" "build-tools;<latest>"`.
  - Run `flutter config --no-analytics`, then `dart --disable-analytics`.
  - Expected: `flutter doctor` shows ✓ for Flutter and Android toolchain. Chrome, Visual Studio and Android Studio may show ✗; that's fine.
- [ ] **Step 2: Create the project in the repo root**
  - Run `git init`, then `flutter create --org com.personal --project-name life_manager --platforms android .`
  - Rename the applicationId and namespace to `com.personal.lifemanager`, and set `minSdk = 26`.
- [ ] **Step 3: Add dependencies**
  - Add: flutter_riverpod, go_router, drift, drift_dev, build_runner, sqlite3 (SQLCipher variant: follow the current drift/sqlite3 docs for SQLCipher — `sqlcipher_flutter_libs` or the sqlite3 build-hook `source: sqlcipher` option, whichever the resolved versions document), path_provider, flutter_secure_storage, sodium_libs, cryptography, cryptography_flutter, local_auth, file_picker, archive, crypto, intl, flutter_localizations (sdk).
  - Dev dependencies: flutter_test, integration_test, mocktail, very_good_analysis.
  - Add `.gitignore` entries: `android/key.properties`, `*.jks`, `*.keystore`, `tool/test_libs/`, `.superpowers/`.
- [ ] **Step 4: Write `tool/fetch_test_libs.ps1`**
  - It downloads the libsodium stable MSVC zip from `https://download.libsodium.org/libsodium/releases/` (latest 1.0.x `-msvc.zip`), verifies it against the minisign/sha256 published alongside, and extracts `x64/Release/<vs>/dynamic/libsodium.dll` to `tool/test_libs/`.
  - If `flutter test` can't load SQLite for Drift on the host, it also fetches `sqlite3.dll` from sqlite.org.
- [ ] **Step 5: Write the smoke test** `test/smoke_test.dart`: `expect(1 + 1, 2);` (it proves the harness runs).
- [ ] **Step 6: Run** `flutter analyze` and `flutter test`. Expected: no analyzer errors; `All tests passed!`
- [ ] **Step 7: Run** `flutter build apk --debug`. Expected: `√ Built build\app\outputs\flutter-apk\app-debug.apk`.
- [ ] **Step 8: Commit** — `git add -A && git commit -m "chore: scaffold Flutter project and toolchain"`

---

### Task 2: Theme tokens and typography

**Files:**
- Create: `lib/core/theme/tokens.dart`, `lib/core/theme/app_theme.dart`, `assets/fonts/Vazirmatn-{Regular,Medium,Bold}.ttf` (from the Vazirmatn GitHub release, OFL)
- Test: `test/core/theme/app_theme_test.dart`

**Interfaces:**
- Produces: `class AppTokens extends ThemeExtension<AppTokens>` with fields `bg, surface, surfaceHigh, border, text, textMuted, accent, success, danger, warning` (all `Color`) and `radiusCard = 20.0`, `radiusSmall = 14.0`; `AppTokens.dark`, `AppTokens.light`; `ThemeData buildAppTheme(Brightness b)`; font family constant `kAppFont = 'Vazirmatn'`.

- [ ] **Step 1: Write the failing tests**

```dart
test('dark theme uses approved tokens', () {
  final t = buildAppTheme(Brightness.dark);
  final k = t.extension<AppTokens>()!;
  expect(t.scaffoldBackgroundColor, const Color(0xFF060A13));
  expect(k.accent, const Color(0xFF3B82FF));
  expect(k.text, const Color(0xFFEEF2FA));
  expect(t.colorScheme.primary, k.accent);
  expect(t.textTheme.bodyMedium!.fontFamily, kAppFont);
});
test('light theme has its own tokens and keeps accent', () {
  final k = buildAppTheme(Brightness.light).extension<AppTokens>()!;
  expect(k.accent, const Color(0xFF3B82FF));
  expect(k.bg.computeLuminance(), greaterThan(0.8));
});
test('text on surfaces meets 4.5:1 in both themes', () {
  for (final b in Brightness.values) {
    final k = buildAppTheme(b).extension<AppTokens>()!;
    expect(contrastRatio(k.text, k.surface), greaterThanOrEqualTo(4.5));
    expect(contrastRatio(k.textMuted, k.surface), greaterThanOrEqualTo(4.5));
  }
});
```

- [ ] **Step 2: Run** `flutter test test/core/theme` — Expected: FAIL (the symbols are undefined).
- [ ] **Step 3: Implement**
  - In `tokens.dart`: `AppTokens`, plus `double contrastRatio(Color a, Color b)` using the WCAG relative-luminance formula.
  - In `app_theme.dart`: `buildAppTheme`, Material 3, with `cardTheme` radius 20 and `scaffoldBackgroundColor = bg`.
  - Register the fonts in `pubspec.yaml`.
  - Light tokens: bg `#F5F7FB`, surface `#FFFFFF`, surfaceHigh `#EEF2F9`, border `#D9E0EC`, text `#0B1224`, textMuted `#4A5672`; accent, success, danger and warning keep the dark values, darkened only if the contrast test fails.
- [ ] **Step 4: Run** `flutter test test/core/theme` — Expected: PASS.
- [ ] **Step 5: Commit** — `feat(theme): add approved dark/light tokens and Vazirmatn`

---

### Task 3: Localization with Kurdish Sorani fallback and RTL

**Files:**
- Create: `l10n.yaml`, `lib/l10n/app_{en,ar,ckb}.arb`, `lib/core/l10n/ckb_fallback_localizations.dart`
- Test: `test/core/l10n/localization_test.dart`

**Interfaces:**
- Produces:
  - `AppLocalizations` (generated, `lib/l10n/gen/app_localizations.dart`, accessed as `context.l10n` via an extension in `ckb_fallback_localizations.dart`).
  - `const kSupportedLocales = [Locale('ar'), Locale('en'), Locale('ckb')]` and `const kDefaultLocale = Locale('ar')`.
  - `List<LocalizationsDelegate> appLocalizationDelegates` (includes `CkbMaterialLocalizationsDelegate`, `CkbCupertinoLocalizationsDelegate` and `CkbWidgetsLocalizationsDelegate`, which load the Arabic Material, Cupertino and Widgets strings with `TextDirection.rtl` for `ckb`).
- ARB keys added here, all needed by Tasks 9–13: appTitle, navHome, navFinance, navTasks, navVault, settings, language, theme, themeDark, themeLight, appLock, biometrics, changePin, lockTimeout, backupRestore, createBackup, restoreBackup, backupPassword, backupWarning, enterPin, wrongPin, tryAgainIn, setupWelcome, setupChooseLanguage, setupCreatePin, setupConfirmPin, setupEnableBiometrics, setupBackupWarning, continueLabel, skip, comingInPhase, seedPersonal, seedBuzzify, seedEo, seedOtherProjects, seedCashIqd, seedCashUsd, restoreTooNew, restoreWrongPassword, restoreCorrupt, restoreSuccess. Sorani strings are drafts (spec §15).

- [ ] **Step 1: Write the failing tests**

```dart
Future<TextDirection> dirFor(WidgetTester t, Locale l) async {
  late TextDirection d;
  await t.pumpWidget(MaterialApp(locale: l, supportedLocales: kSupportedLocales,
    localizationsDelegates: appLocalizationDelegates,
    home: Builder(builder: (c) { d = Directionality.of(c); return Text(c.l10n.navHome); })));
  return d;
}
testWidgets('ar is RTL', (t) async => expect(await dirFor(t, const Locale('ar')), TextDirection.rtl));
testWidgets('ckb is RTL and loads material strings', (t) async {
  expect(await dirFor(t, const Locale('ckb')), TextDirection.rtl);
  expect(t.takeException(), isNull);
});
testWidgets('en is LTR', (t) async => expect(await dirFor(t, const Locale('en')), TextDirection.ltr));
test('every locale has every key', () { /* load the three ARB files as JSON; key sets (minus @-metadata) are equal */ });
```

- [ ] **Step 2: Run** `flutter test test/core/l10n` — Expected: FAIL.
- [ ] **Step 3: Implement** the ARB files, `l10n.yaml` (`output-dir: lib/l10n/gen`, `synthetic-package: false`) and the ckb fallback delegates. Run `flutter gen-l10n`.
- [ ] **Step 4: Run** `flutter test test/core/l10n` — Expected: PASS.
- [ ] **Step 5: Commit** — `feat(l10n): ar/en/ckb with RTL and Sorani material fallback`

---

### Task 4: Sensitive wrapper and redacting logger

**Files:**
- Create: `lib/core/security/sensitive.dart`, `lib/core/logging/app_logger.dart`
- Test: `test/core/security/sensitive_test.dart`, `test/core/logging/app_logger_test.dart`

**Interfaces:**
- Produces:
  - `final class Sensitive<T> { const Sensitive(this.value); final T value; @override String toString() => '‹redacted›'; }`
  - `abstract final class AppLogger { static void Function(String line) sink; static void info(String msg); static void warn(String msg, [Object? error]); static void error(String msg, [Object? error, StackTrace? st]); }`
  - In release mode `info` is a no-op. `error` logs only the error's `runtimeType`, never its `toString()`, so exception messages can't leak secrets.

- [ ] **Step 1: Write the failing tests**

```dart
test('Sensitive never prints its value', () {
  const s = Sensitive('1234');
  expect('$s', isNot(contains('1234')));
  expect([s].toString(), isNot(contains('1234')));
});
test('logger does not print error messages', () {
  final lines = <String>[]; AppLogger.sink = lines.add;
  AppLogger.error('backup failed', StateError('password=hunter2'));
  expect(lines.join(), isNot(contains('hunter2')));
  expect(lines.join(), contains('StateError'));
});
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(core): Sensitive wrapper and redacting logger`

---

### Task 5: Crypto primitives (Argon2id KDF, AES-256-GCM, secure random)

**Files:**
- Create: `lib/core/crypto/random.dart`, `lib/core/crypto/kdf.dart`, `lib/core/crypto/aead.dart`, `test/support/test_sodium.dart`
- Test: `test/core/crypto/kdf_test.dart`, `test/core/crypto/aead_test.dart`, `integration_test/crypto_device_test.dart`

**Interfaces:**
- Produces:
  - `Uint8List secureRandomBytes(int length)`: uses `Random.secure()`.
  - `class KdfParams { const KdfParams({required this.memoryKiB, required this.iterations, this.parallelism = 1}); Map<String, Object> toJson(); factory KdfParams.fromJson(Map<String, Object?> j); }`
  - `const kDefaultKdfParams = KdfParams(memoryKiB: 65536, iterations: 3);` and `const kFallbackKdfParams = KdfParams(memoryKiB: 19456, iterations: 2);`
  - `abstract interface class Kdf { Future<Uint8List> derive({required Uint8List password, required Uint8List salt, required KdfParams params, int length = 32}); }`
  - `final class SodiumArgon2idKdf implements Kdf { SodiumArgon2idKdf(Sodium sodium); }`
    - Uses `crypto.pwhash` with `alg: argon2id13`, `opsLimit = iterations` and `memLimit = memoryKiB * 1024`.
    - Asserts `parallelism == 1`, because libsodium fixes it.
    - If the call fails for lack of memory, it throws `KdfOutOfMemory` and the caller retries with `kFallbackKdfParams`.
    - `Future<KdfParams> calibrateKdf(Kdf kdf)`: tries the default params and falls back on `KdfOutOfMemory`.
  - `final class SealedBox { const SealedBox(this.nonce, this.cipherText); final Uint8List nonce; final Uint8List cipherText; }`, where `cipherText` includes the 16-byte tag.
  - `abstract interface class Aead { Future<SealedBox> seal(Uint8List plain, Uint8List key, {Uint8List? aad}); Future<Uint8List> open(SealedBox box, Uint8List key, {Uint8List? aad}); }`
    - `open` throws `AeadAuthException` on a tag mismatch.
  - `final class AesGcmAead implements Aead`: `AesGcm.with256bits()` from `package:cryptography`. Production calls `FlutterCryptography.enable()` in `main`.
  - `Future<Sodium> loadTestSodium()` in `test/support/test_sodium.dart`: `SodiumInit.init(() => DynamicLibrary.open('tool/test_libs/libsodium.dll'))`.

- [ ] **Step 1: Write the failing tests**

```dart
// kdf_test.dart (uses loadTestSodium(); skip with a clear message if the dll is missing: "run tool/fetch_test_libs.ps1")
test('argon2id is deterministic and 32 bytes', () async {
  final k1 = await kdf.derive(password: utf8b('pw'), salt: Uint8List(16), params: kDefaultKdfParams);
  final k2 = await kdf.derive(password: utf8b('pw'), salt: Uint8List(16), params: kDefaultKdfParams);
  expect(k1.length, 32); expect(k1, k2);
});
test('salt and password both change the key', () async { /* k(pw,salt0) != k(pw,salt1) and != k(pw2,salt0) */ });
test('matches an independent Argon2id implementation', () async {
  const p = KdfParams(memoryKiB: 1024, iterations: 2);
  final sodiumKey = await kdf.derive(password: utf8b('correct horse'), salt: Uint8List.fromList(List.filled(16, 7)), params: p);
  final ref = await Argon2id(parallelism: 1, memory: 1024, iterations: 2, hashLength: 32)
      .deriveKey(secretKey: SecretKey(utf8b('correct horse')), nonce: List.filled(16, 7));
  expect(sodiumKey, await ref.extractBytes());
});
test('KdfParams json round-trips', () { expect(KdfParams.fromJson(kDefaultKdfParams.toJson()).memoryKiB, 65536); });

// aead_test.dart
test('seal/open round-trips with aad', ...);           // open(seal(x,k,aad),k,aad) == x
test('fresh 12-byte nonce per seal', ...);             // two seals of same input → different nonces, nonce.length == 12
test('wrong key throws AeadAuthException', ...);
test('tampered ciphertext throws AeadAuthException', ...);
test('different aad throws AeadAuthException', ...);
```

- [ ] **Step 2: Run** `pwsh tool/fetch_test_libs.ps1`, then `flutter test test/core/crypto`. Expected: FAIL, because the symbols are undefined.
- [ ] **Step 3: Implement** the three files.
- [ ] **Step 4: Run** `flutter test test/core/crypto` — Expected: PASS.
- [ ] **Step 5: Write** `integration_test/crypto_device_test.dart`. It runs the same determinism, cross-check and round-trip assertions with `SodiumInit.init()` (sodium_libs) and `FlutterCryptography.enable()` on a device. It runs when a device or emulator is available: `flutter test integration_test/crypto_device_test.dart -d <id>`.
- [ ] **Step 6: Commit** — `feat(crypto): Argon2id KDF and AES-256-GCM behind interfaces`

---

### Task 6: Secure store and database key

**Files:**
- Create: `lib/core/storage/secure_store.dart`, `lib/core/db/db_key.dart`
- Test: `test/core/db/db_key_test.dart`

**Interfaces:**
- Produces:
  - `abstract interface class SecureStore { Future<String?> read(String key); Future<void> write(String key, String value); Future<void> delete(String key); }`
  - `FlutterSecureStore implements SecureStore` uses `FlutterSecureStorage` with `AndroidOptions(encryptedSharedPreferences: false)` unless the package version's docs require otherwise. Follow the package's current Keystore-backed default.
  - `InMemorySecureStore implements SecureStore` lives in lib, for tests.
  - `Future<Sensitive<String>> obtainDatabaseKey(SecureStore store)`: reads key `db_key_v1`. If it is absent, it writes 32 random bytes as 64 lowercase hex characters and returns them.

- [ ] **Step 1: Write the failing tests**

```dart
test('creates a 64-hex key once and reuses it', () async {
  final s = InMemorySecureStore();
  final a = await obtainDatabaseKey(s); final b = await obtainDatabaseKey(s);
  expect(a.value, matches(RegExp(r'^[0-9a-f]{64}$'))); expect(b.value, a.value);
});
test('different stores get different keys', ...);
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(core): secure store and database key provisioning`

---

### Task 7: Database schema v1, SQLCipher open, and seed

**Files:**
- Create: `lib/core/db/tables.dart`, `lib/core/db/app_database.dart`, `lib/core/db/seed.dart`, `drift_schemas/` (via `drift_dev schema dump`)
- Test: `test/core/db/app_database_test.dart`, `test/core/db/seed_test.dart`, `test/core/db/migration_test.dart`, `integration_test/db_cipher_test.dart`

**Interfaces:**
- Consumes: `obtainDatabaseKey` (Task 6).
- Produces the Drift tables:
  - `Workspaces`:
    - `id` int pk autoIncrement
    - `name` text 1..80
    - `iconKey` text
    - `colorArgb` int
    - `description` text nullable
    - `notes` text nullable
    - `sortOrder` int
    - `isArchived` bool default false
    - `createdAt` dateTime
  - `Accounts`:
    - `id` int pk
    - `workspaceId` int references `Workspaces.id` `onDelete: KeyAction.restrict`
    - `name` text 1..80
    - `kind` text, check in (`cash`, `bank`, `savings`, `custom`)
    - `currencyCode` text length 3
    - `openingBalanceMinor` int default 0
    - `sortOrder` int
    - `isArchived` bool default false
    - `createdAt` dateTime
  - `AppSettingsTable` (annotated `@DataClassName('AppSetting')`; one row, `id` int pk check `= 1`):
    - `localeCode` text default `'ar'`
    - `themeMode` text default `'dark'`
    - `lockTimeoutSeconds` int default 300
    - `biometricEnabled` bool default false
    - `baseCurrency` text default `'IQD'`
    - `setupCompleted` bool default false
    - `lastBackupAt` dateTime nullable
  - `BackupMetadata`:
    - `id` int pk
    - `createdAt` dateTime
    - `kind` text check in (`export`, `restore`)
    - `fileName` text
    - `schemaVersion` int
    - `appVersion` text
    - `sizeBytes` int
- Produces the database API:
  - `class AppDatabase extends _$AppDatabase { AppDatabase(QueryExecutor e); @override int get schemaVersion => 1; }`
  - `beforeOpen` runs `PRAGMA foreign_keys = ON` and inserts the settings row if it is missing.
  - `Future<AppDatabase> openAppDatabase({required File file, required Sensitive<String> hexKey})` returns a `NativeDatabase` whose `setup` runs ``PRAGMA key = "x'<hex>'"`` and then asserts `PRAGMA cipher_version` is non-empty.
  - `File appDatabaseFile(Directory supportDir)` returns `<supportDir>/app.db`.
  - `class SeedNames { personal, buzzify, eo, otherProjects, cashIqd, cashUsd }`: localized strings passed in from l10n.
  - `Future<void> seedInitialData(AppDatabase db, SeedNames n)`: idempotent; it does nothing if any workspace exists. It creates:
    - workspaces in order Personal, Buzzify, Related / EO, Other Projects, with colors accent, `#8B5CF6`, warning and textMuted
    - accounts `"<workspace> · <cashIqd>"` (IQD) and `"<workspace> · <cashUsd>"` (USD), kind `cash`, for Personal, Buzzify and EO
  - `Future<bool> isSetupCompleted(AppDatabase db)`

- [ ] **Step 1: Write the failing tests** (host, `AppDatabase(NativeDatabase.memory())`)

```dart
test('settings row exists with defaults', () async {
  final s = await db.select(db.appSettingsTable).getSingle();
  expect(s.localeCode, 'ar'); expect(s.themeMode, 'dark'); expect(s.lockTimeoutSeconds, 300); expect(s.setupCompleted, false);
});
test('foreign keys are enforced', () async {
  expect(() => db.into(db.accounts).insert(AccountsCompanion.insert(workspaceId: 999, name: 'x', kind: 'cash', currencyCode: 'IQD', sortOrder: 0, createdAt: DateTime.now())),
      throwsA(isA<SqliteException>()));
});
test('cannot delete a workspace that has accounts', ...);
test('seed creates 4 workspaces and 6 cash accounts, IQD+USD per Personal/Buzzify/EO', () async {
  await seedInitialData(db, names);
  expect(await db.select(db.workspaces).get(), hasLength(4));
  final acc = await db.select(db.accounts).get();
  expect(acc, hasLength(6));
  expect(acc.where((a) => a.currencyCode == 'IQD'), hasLength(3));
  expect(acc.every((a) => a.kind == 'cash'), isTrue);
});
test('seed is idempotent', () async { await seedInitialData(db, names); await seedInitialData(db, names); expect(await db.select(db.accounts).get(), hasLength(6)); });
// migration_test.dart: drift_dev SchemaVerifier — v1 schema matches drift_schemas/drift_schema_v1.json
```

- [ ] **Step 2: Run** `dart run build_runner build -d`, then `flutter test test/core/db`. Expected: FAIL.
- [ ] **Step 3: Implement** the tables, the database and the seed. Run `dart run drift_dev schema dump lib/core/db/app_database.dart drift_schemas/` and `dart run drift_dev schema generate drift_schemas/ test/core/db/generated/`.
- [ ] **Step 4: Run** `flutter test test/core/db` — Expected: PASS.
- [ ] **Step 5: Write** `integration_test/db_cipher_test.dart`. It checks that:
  - `cipher_version` is non-empty
  - data persists across close and reopen with the same key
  - reopening with a different key throws
  - the raw file's first 16 bytes are not `SQLite format 3\0`
- [ ] **Step 6: Commit** — `feat(db): schema v1 on SQLCipher with seed data`

---

### Task 8: Settings repository and app-level providers

**Files:**
- Create: `lib/features/settings/settings_repository.dart`, `lib/app/providers.dart`
- Test: `test/features/settings/settings_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` (Task 7).
- Produces:
  - `class SettingsRepository { SettingsRepository(AppDatabase db); Stream<AppSetting> watch(); Future<AppSetting> get(); Future<void> setLocale(String code); Future<void> setThemeMode(ThemeMode m); Future<void> setLockTimeout(Duration d); Future<void> setBiometricEnabled(bool v); Future<void> markSetupCompleted(); Future<void> setLastBackupAt(DateTime t); }`
  - `setLocale` throws `ArgumentError` for codes outside `ar`, `en` and `ckb`.
  - `lockTimeout` is clamped to 0–3600 s; 0 means lock immediately on background.
  - Providers in `providers.dart`: `appDatabaseProvider`, `secureStoreProvider`, `sodiumProvider`, `kdfProvider`, `aeadProvider` and `settingsRepositoryProvider`. All except the last are overridden in `main()` and in tests. `settingsProvider` is a `StreamProvider<AppSetting>`.

- [ ] **Step 1: Write the failing tests**
  - `setLocale('ckb')` is reflected in `watch()`.
  - `setLocale('fr')` throws.
  - `setThemeMode(ThemeMode.light)` persists `'light'`.
  - `setLockTimeout(Duration(hours: 5))` stores 3600.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(settings): settings repository and root providers`

---

### Task 9: App lock (PIN, biometrics, lifecycle)

**Files:**
- Create: `lib/features/lock/digits.dart`, `pin_service.dart`, `biometric_authenticator.dart`, `lock_controller.dart`, `lock_screen.dart`
- Test: `test/features/lock/digits_test.dart`, `pin_service_test.dart`, `lock_controller_test.dart`, `lock_screen_test.dart`

**Interfaces:**
- Consumes: `Kdf`, `secureRandomBytes`, `KdfParams` (Task 5); `SecureStore` (Task 6); `SettingsRepository` (Task 8).
- Produces:
  - `String normalizeDigits(String s)`: maps U+0660–0669 and U+06F0–06F9 to `0`–`9`.
  - `class PinService { PinService(SecureStore store, Kdf kdf, {DateTime Function()? now, KdfParams params = kDefaultKdfParams}); Future<bool> hasPin(); Future<void> setPin(String pin); Future<PinCheckResult> verify(String pin); }`
    - A PIN is exactly 6 digits after `normalizeDigits`; anything else makes `setPin` throw `ArgumentError`.
    - Storage key `app_pin_v1`, holding JSON `{salt, hash, kdf}` (base64 values).
    - The hash is the 32-byte Argon2id output, compared in constant time.
    - Failures are persisted under key `app_pin_failures_v1` as `{count, lockedUntil}`. After 5 consecutive failures the lockout is 30 s; each further failure doubles it, capped at 1 h. Success resets the count.
  - `sealed class PinCheckResult`, with `PinOk`, `PinWrong(int attemptsBeforeLockout)` and `PinLockedOut(Duration remaining)`.
  - `abstract interface class BiometricAuthenticator { Future<bool> isAvailable(); Future<bool> authenticate(String reason); }`
    - `LocalAuthBiometricAuthenticator` implements it with `local_auth`, `biometricOnly: false` (device credential allowed, spec §15) and `stickyAuth: true`.
    - Any `PlatformException` → `false`.
  - `bool shouldRelock({required DateTime pausedAt, required DateTime resumedAt, required Duration timeout})`: true when `resumedAt - pausedAt >= timeout`.
  - `enum LockStatus { locked, unlocked }`
  - `class LockController extends Notifier<LockStatus>`: starts `locked`; has `unlock()`, `lockNow()`, `onPaused(DateTime)` and `onResumed(DateTime)`.
  - `LockScreen`: a PIN pad with large keys and Western digits shown. If biometrics are enabled and available, it auto-prompts on open, and a biometric failure or cancel leaves the PIN pad usable. While `PinLockedOut` it shows `tryAgainIn` with a countdown.
- In `app.dart` (Task 11) a `LockGate` overlays `LockScreen` whenever the status is `locked` and setup is completed. It listens through `AppLifecycleListener`.

- [ ] **Step 1: Write the failing tests**

```dart
test('normalizeDigits', () { expect(normalizeDigits('١٢٣۴۵۶'), '123456'); expect(normalizeDigits('12ab'), '12ab'); });
test('setPin rejects non-6-digit', () { expect(() => pins.setPin('123'), throwsArgumentError); });
test('verify ok and wrong', () async {
  await pins.setPin('123456');
  expect(await pins.verify('123456'), isA<PinOk>());
  expect(await pins.verify('000000'), isA<PinWrong>());
});
test('verify accepts arabic-indic digits', () async { await pins.setPin('123456'); expect(await pins.verify('١٢٣٤٥٦'), isA<PinOk>()); });
test('5 failures lock out 30s, 6th doubles to 60s, persists across instances', () async {
  for (var i = 0; i < 5; i++) await pins.verify('000000');
  final r = await pins.verify('123456');
  expect(r, isA<PinLockedOut>()); expect((r as PinLockedOut).remaining, lessThanOrEqualTo(const Duration(seconds: 30)));
  final again = PinService(store, kdf, now: () => clock.add(const Duration(seconds: 31)));
  await again.verify('000000');
  expect((await again.verify('123456') as PinLockedOut).remaining, greaterThan(const Duration(seconds: 30)));
});
test('stored pin record contains no plaintext pin', () async { await pins.setPin('123456'); expect(await store.read('app_pin_v1'), isNot(contains('123456'))); });
test('shouldRelock boundary', () { /* 299s → false, 300s → true with 300s timeout; timeout 0 → always true */ });
testWidgets('LockScreen falls back to PIN when biometrics fail', (t) async {
  // FakeBiometric(available: true, result: false); enter 1,2,3,4,5,6 → LockController.state == unlocked
});
testWidgets('LockScreen RTL renders PIN pad in ar', ...);  // no overflow, digits ordered 1-2-3 left→right visually per platform keypad convention
```

  Tests use a cheap `KdfParams(memoryKiB: 1024, iterations: 1)` injected through a `PinService` named parameter `params`. Production uses the output of `calibrateKdf`.

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** `flutter test test/features/lock` → PASS.
- [ ] **Step 5: Commit** — `feat(lock): PIN with Argon2id and backoff, biometric unlock, relock timer`

---

### Task 10: Splash and initial setup flow

**Files:**
- Create: `lib/features/setup/splash_screen.dart`, `lib/features/setup/setup_flow.dart`
- Test: `test/features/setup/setup_flow_test.dart`

**Interfaces:**
- Consumes: `SettingsRepository`, `seedInitialData`, `SeedNames`, `PinService`, `BiometricAuthenticator`.
- Produces: `SetupFlow`, a widget `PageView` with steps:
  1. **Language:** three large tiles (العربية / English / کوردی). Changes the locale live.
  2. **Create PIN:** enter, then confirm. A mismatch shows an error and restarts the step.
  3. **Biometrics:** skipped automatically if `isAvailable()` is false.
  4. **Backup warning:** the text from `setupBackupWarning`, with a checkbox «فهمت» that must be ticked to continue.
  5. **Finish:** `seedInitialData` with `SeedNames` from the current l10n, then `markSetupCompleted`, then `LockController.unlock()`, then go to `/home`.
- `SplashScreen` routes to `/setup` or `/home` (behind the lock) based on `setupCompleted`.

- [ ] **Step 1: Write the failing tests**
  - `completes setup and seeds`: pump `SetupFlow` with fakes, pick English, enter `123456` twice, enable biometrics, tick the warning, tap continue. Then `setupCompleted == true`, there are 6 accounts, and `pins.verify('123456')` is `PinOk`.
  - `skips biometric step when unavailable`: no biometric page is found.
  - `PIN confirmation mismatch stays on PIN step`.
  - `cannot finish without acknowledging backup warning`: the continue button is disabled.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(setup): first-run flow with seed, PIN, biometrics, backup warning`

---

### Task 11: App shell, router, Home placeholder, and Settings screen

**Files:**
- Create: `lib/app/app.dart`, `lib/app/router.dart`, `lib/features/shell/shell_scaffold.dart`, `home_screen.dart`, `placeholder_screen.dart`, `lib/features/settings/settings_screen.dart`; modify `lib/main.dart`
- Test: `test/features/shell/shell_test.dart`, `test/features/settings/settings_screen_test.dart`

**Interfaces:**
- Consumes: everything above.
- Produces:
  - Routes `/splash`, `/setup`, `/home`, `/finance`, `/tasks`, `/vault`, `/settings`, `/settings/backup`.
  - `ShellScaffold` is a `StatefulShellRoute` with a bottom `NavigationBar` of four destinations, plus a centred, notched 64 px circular mic FAB. In Phase 1 the FAB opens a bottom sheet saying `comingInPhase` (phase 2).
  - `HomeScreen` has an app bar with a settings icon that goes to `/settings`. Its body shows layout-B card slots (month summary, chart, buckets, tasks) as empty-state cards that say they arrive in Phase 2/4/5, plus a real card listing the seeded accounts grouped by workspace (name and currency) from the DB.
  - `PlaceholderScreen(title, phase)` is used for Finance, Tasks and Vault.
  - `SettingsScreen` sections:
    - Language: radio list of three.
    - Theme: dark / light.
    - App lock: biometric switch, disabled with a hint when unavailable; change PIN, which needs the current PIN; lock timeout choices 0 / 1 / 5 / 15 / 30 min.
    - Backup & Restore: link with a "last backup" subtitle, or "never" in the warning color.
    - Privacy: a short static text saying no data leaves the device in Phase 1.
  - `main()`:
    1. `WidgetsFlutterBinding.ensureInitialized()`
    2. `FlutterCryptography.enable()`
    3. `BackupService.recoverInterruptedRestore(supportDir)` (Task 13)
    4. `obtainDatabaseKey`, then `openAppDatabase`
    5. `SodiumInit.init()`
    6. `runApp(ProviderScope(overrides: [...], child: RestartScope(child: App())))`

    `RestartScope` rebuilds the `ProviderScope` with a new `UniqueKey` when `RestartScope.restart(context)` is called. It is used after a restore.

- [ ] **Step 1: Write the failing tests**
  - The shell shows 4 destinations plus the FAB.
  - In `ar` the first destination (Home) is at the right edge.
  - Tapping the Settings icon opens Settings.
  - Changing the language in Settings to `en` makes `navHome` read "Home" without a restart.
  - The theme switch changes `Theme.of(context).brightness`.
  - The Home accounts card lists 6 seeded accounts.
  - Long-text test: with the Sorani locale and a 320 px-wide surface, Settings renders without a `RenderFlex` overflow.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** `flutter test` (the whole suite) → PASS.
- [ ] **Step 5: Run** `flutter build apk --debug` → it builds.
- [ ] **Step 6: Commit** — `feat(shell): router, bottom nav with mic FAB, home placeholder, settings`

---

### Task 12: Backup file format and payload

**Files:**
- Create: `lib/features/backup/backup_format.dart`, `lib/features/backup/backup_payload.dart`
- Test: `test/features/backup/backup_format_test.dart`, `backup_payload_test.dart`

**Interfaces:**
- Consumes: `Kdf`, `KdfParams`, `Aead`, `SealedBox`, `secureRandomBytes` (Task 5).
- Produces the file layout, all big-endian:
  - `"PLMB"` (4 bytes)
  - `formatVersion` u16
  - `headerLength` u32
  - header JSON, UTF-8
  - AES-GCM ciphertext+tag

  The AAD is every byte before the ciphertext.
- Header JSON:
  - `{"schemaVersion":int,"appVersion":str,"createdAtUtc":ISO-8601,"kdf":KdfParams.toJson(),"salt":b64(16),"nonce":b64(12)}`
- Constants and classes:
  - `const kBackupFormatVersion = 1;` and `const kBackupExtension = 'plmbackup';`
  - `class BackupHeader { int formatVersion; int schemaVersion; String appVersion; DateTime createdAtUtc; KdfParams kdf; Uint8List salt; Uint8List nonce; }`
  - `class BackupCodec { BackupCodec(Kdf kdf, Aead aead); Future<Uint8List> encode({required Uint8List payload, required Sensitive<String> password, required int schemaVersion, required String appVersion, required KdfParams kdf, DateTime? now}); BackupHeader readHeader(Uint8List file); Future<(BackupHeader, Uint8List)> decode(Uint8List file, Sensitive<String> password); }`
- Exceptions (all `implements Exception`, with no secret in any field):
  - `BackupFormatException`: bad magic, truncated input, or bad JSON.
  - `BackupTooNewException(int found, int supported)`: thrown for `formatVersion > kBackupFormatVersion` by `readHeader`.
  - `BackupWrongPasswordException`: the GCM tag fails. The tag can't tell a wrong password from a tampered body, so the message says "wrong password or damaged file".
- Payload:
  - `Uint8List buildPayload(Map<String, Uint8List> files)`: a zip with all files plus `manifest.json` = `{"files":[{"path","size","sha256"}]}`.
  - `Map<String, Uint8List> readPayload(Uint8List zip)`: verifies every manifest entry, with no extra or missing files. Otherwise it throws `BackupCorruptException`.
  - Paths are validated: no `..`, absolute paths or backslashes (zip-slip).

- [ ] **Step 1: Write the failing tests**

```dart
test('round-trip', () async {
  final f = await codec.encode(payload: bytes, password: const Sensitive('pw'), schemaVersion: 1, appVersion: '1.0.0', kdf: cheap, now: DateTime.utc(2026,10,22));
  final (h, p) = await codec.decode(f, const Sensitive('pw'));
  expect(p, bytes); expect(h.schemaVersion, 1); expect(h.createdAtUtc, DateTime.utc(2026,10,22));
});
test('starts with PLMB magic', ...);
test('wrong password → BackupWrongPasswordException', ...);
test('flipping a header byte → BackupWrongPasswordException (AAD)', ...);
test('truncated file → BackupFormatException', ...);       // first 10 bytes only
test('random bytes → BackupFormatException', ...);
test('rejects newer formatVersion → BackupTooNewException', ...); // patch u16 at offset 4 to 2
test('header has no plaintext of payload or password', ...);
// payload
test('payload round-trip with manifest', ...);
test('modified file content → BackupCorruptException', ...);
test('zip with ../evil path → BackupCorruptException', ...);
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(backup): encrypted .plmbackup format with manifest integrity`

---

### Task 13: Backup service, safe restore, and Backup screen

**Files:**
- Create: `lib/features/backup/db_snapshot.dart`, `backup_service.dart`, `backup_screen.dart`
- Test: `test/features/backup/backup_service_test.dart`, `backup_screen_test.dart`

**Interfaces:**
- Consumes: `BackupCodec`, `buildPayload`/`readPayload` (Task 12); `AppDatabase`, `openAppDatabase`, `appDatabaseFile` (Task 7); `SettingsRepository` (Task 8); `RestartScope` (Task 11).
- Produces:
  - `abstract interface class DbSnapshotter { Future<Uint8List> exportPlain(AppDatabase db); Future<void> importToEncrypted({required File plainDb, required File target, required Sensitive<String> hexKey}); }`
    - `SqlCipherSnapshotter`: `ATTACH ... KEY ''` plus `SELECT sqlcipher_export('plain')` for export, and the reverse with the DB key for import.
    - `PlainSnapshotter`: `VACUUM INTO`, for host tests.
  - `class BackupService { BackupService({required AppDatabase db, required Directory supportDir, required BackupCodec codec, required DbSnapshotter snapshotter, required Sensitive<String> dbKey, required SettingsRepository settings, required String appVersion}); }` with methods:
    - `Future<Uint8List> createBackup(Sensitive<String> password, {KdfParams? kdf})`: the payload is `{'db/app.db': plain snapshot}`. Inserts a `BackupMetadata` row (`export`) and calls `setLastBackupAt`.
    - `BackupHeader inspect(Uint8List file)`
    - `Future<void> restore(Uint8List file, Sensitive<String> password)` (algorithm below)
    - `static Future<void> recoverInterruptedRestore(Directory supportDir)`
  - Filenames in `supportDir`: `app.db`, `app.db.pre-restore`, `app.db.incoming`, `restore.pending`, and the dir `restore_tmp/`.
  - Restore algorithm:
    1. `decode` and `readPayload`. Any exception propagates with nothing on disk changed.
    2. Write `db/app.db` to `restore_tmp/app.db`, open it read-only as plain, and read `PRAGMA user_version`. If it is greater than `AppDatabase.schemaVersion`, delete the temp dir and throw `BackupTooNewException`.
    3. `importToEncrypted` into `app.db.incoming`.
    4. `db.close()`, rename `app.db` to `app.db.pre-restore`, write `restore.pending`, then rename `app.db.incoming` to `app.db`.
    5. Delete `restore_tmp/`. The caller calls `RestartScope.restart`.
  - `recoverInterruptedRestore` runs at startup, before the DB opens:
    - `restore.pending` exists and `app.db` exists and opens with `PRAGMA integrity_check == 'ok'`: delete `pre-restore` and the marker, and record a `restore` metadata row on first open.
    - `restore.pending` exists and `app.db` is missing or fails the check: move `app.db.pre-restore` back to `app.db` and delete the marker.
    - No marker but `app.db.incoming` exists: delete it, because the restore was interrupted before the swap.
  - `BackupScreen`:
    - **Create:** password plus confirm, at least 8 characters, with a strength hint. Then `createBackup`, then `FilePicker.platform.saveFile(fileName: 'life-manager-YYYY-MM-DD.plmbackup', bytes: ...)`.
    - **Restore:** `FilePicker.platform.pickFiles(withData: true)`, then `inspect`, then a confirm dialog showing `createdAtUtc` in local time, the app version and the warning that current data will be replaced. Then the password, then `restore`, then `restart`.
    - Errors map to `restoreWrongPassword`, `restoreCorrupt` and `restoreTooNew`.
    - The screen states the backup-loss warning from spec §13.

- [ ] **Step 1: Write the failing tests** (host: temp dir, `PlainSnapshotter`, cheap KDF)
  - `backup then restore brings data back`: seed, back up, delete all accounts, restore, reopen, and find 6 accounts.
  - `restore leaves live db untouched on wrong password`: the file hash of `app.db` is unchanged and no marker exists.
  - `rejects newer schema`: create a backup whose snapshot has `user_version = 99`. `BackupTooNewException` is thrown and live data is unchanged.
  - `recoverInterruptedRestore rolls back when new db is missing`: the marker and `pre-restore` exist, `app.db` does not. Afterwards `app.db` equals the old content.
  - `recoverInterruptedRestore commits when new db is healthy`: `pre-restore` and the marker are removed.
  - `recoverInterruptedRestore removes orphan incoming`.
  - `createBackup records metadata and lastBackupAt`.
  - `backup bytes do not contain the db plaintext`: search for a distinctive seeded workspace name; it is not found.
  - Widget test: the restore confirm dialog shows the backup date and the app version, and the wrong-password path shows `restoreWrongPassword`.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** `flutter test` → PASS.
- [ ] **Step 5: Commit** — `feat(backup): export, safe restore with rollback, backup screen`

---

### Task 14: Android hardening, release signing, release APK, install doc

**Files:**
- Modify: `android/app/src/main/kotlin/com/personal/lifemanager/MainActivity.kt`, `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`
- Create: `android/key.properties.example`, `docs/INSTALL.md`, `test/android_config_test.dart`

**Interfaces:**
- Produces: a signed release APK.

- [ ] **Step 1: Write the failing test** `test/android_config_test.dart`. It reads the files as text and asserts:
  - `MainActivity.kt` contains `FlutterFragmentActivity` and `WindowManager.LayoutParams.FLAG_SECURE`
  - the manifest has no `android.permission.INTERNET`, and does have `android:allowBackup="false"` and `android:label="@string/app_name"`
  - `build.gradle.kts` references `key.properties` and contains `minSdk = 26`
  - `.gitignore` contains `key.properties` and `*.jks`
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement**
  - `MainActivity : FlutterFragmentActivity` (required by local_auth) sets `FLAG_SECURE` in `onCreate`.
  - Set `allowBackup="false"` and `fullBackupContent="false"`, so Android auto-backup never copies the DB.
  - Add a `USE_BIOMETRIC` permission.
  - Add Arabic `app_name` resources.
  - Release `signingConfig` reads `storeFile`, `storePassword`, `keyAlias` and `keyPassword` from `android/key.properties`. If the file is missing, the release build fails with a message pointing to `docs/INSTALL.md`.
  - Enable R8 with Flutter's default rules plus keep rules required by sodium_libs and SQLCipher.
- [ ] **Step 4: Run** `flutter test test/android_config_test.dart` → PASS.
- [ ] **Step 5: Generate the keystore outside the repo**
  - Run `keytool -genkeypair -v -keystore C:\Users\pc\.keystores\life-manager-release.jks -alias lifemanager -keyalg RSA -keysize 4096 -validity 10000` with a randomly generated password.
  - Write `android/key.properties` (gitignored) pointing to it.
  - Never print the password in chat or commit it.
  - Tell the owner that the keystore and `key.properties` must be backed up, because without them future updates can't install over the app.
- [ ] **Step 6: Run** `flutter build apk --release`. Expected: `√ Built build\app\outputs\flutter-apk\app-release.apk (NN MB)`. Confirm with `git status` that `key.properties` and the `.jks` are not staged.
- [ ] **Step 7: Write `docs/INSTALL.md`**
  - Content:
    - enable install from unknown sources for the file manager
    - copy the APK to the phone and install it
    - first-run steps
    - build commands: `flutter pub get`, `dart run build_runner build -d`, `flutter test`, `flutter build apk --release`
    - recreating `key.properties` from `key.properties.example`
    - the backup warning
  - Write it in Arabic, followed by English.
- [ ] **Step 8: Run the full verification** `flutter analyze && flutter test`. Expected: no issues and all tests passed. If a phone is connected via USB debugging, also run `flutter test integration_test -d <id>`. If not, record in INSTALL.md that the on-device crypto and SQLCipher checks ran on device X, or still need to run.
- [ ] **Step 9: Commit** — `feat(android): FLAG_SECURE, release signing, install guide`
