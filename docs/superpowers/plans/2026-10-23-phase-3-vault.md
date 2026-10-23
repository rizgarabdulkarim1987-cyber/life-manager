# Phase 3 — Vault Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A signed release APK with a password vault the owner can trust enough to move real passwords into, after reading the security review. Concretely:
- a key hierarchy: a random Vault Data Key (VDK) wrapped by the master password (Argon2id), by a one-time recovery key (HKDF-SHA256) and by a biometric-bound Android Keystore key
- vault item CRUD with per-field AES-256-GCM encryption, search, filter and sort over non-secret fields only
- a password generator
- import from notes (local heuristic parser, no AI, no network)
- clipboard handling: marked sensitive, cleared after 30 s, never logged
- auto-lock (idle and app background), fresh auth before reveal and copy
- vault data inside the encrypted backup, the biometric wrap never
- schema v3 with a tested migration
- the written security self-review and a separate code-review pass

**Architecture:**
- Same layout as Phases 1–2: `lib/features/vault/` split into `crypto/` (pure Dart on the existing `Kdf` and `Aead` interfaces; no Flutter), `domain/` (generator, notes parser; pure Dart), `data/` (Drift repositories and the key service), `platform/` (method-channel ports for the Keystore key and the clipboard) and `ui/`.
- No new primitives. Argon2id is `Kdf` (`DartArgon2idKdf`), AES-256-GCM is `Aead` (`AesGcmAead`), HKDF-SHA256 and HMAC come from `package:cryptography`, randomness is `secureRandomBytes`. The biometric key is AES-256-GCM inside Android Keystore, driven by a small Kotlin channel.
- The VDK lives in memory only while the vault is unlocked, inside a `VaultKey` that zero-fills its bytes on lock. Repositories take a `VaultKey` argument; nothing secret is cached in providers.
- Wrapped VDKs (password, recovery) and encrypted fields live in the SQLCipher database, so they travel in backups unchanged. The biometric wrap lives in Keystore-backed secure storage, so it never does.
- Schema goes from v2 to v3 in one tested Drift migration.

**Tech Stack:**
- From Phases 1–2: Flutter 3.47.7 / Dart 3.13, Riverpod, go_router, Drift over SQLCipher, `cryptography` (+ `cryptography_flutter`), flutter_secure_storage, local_auth (app lock only), intl.
- New: none on the Dart side. Android: `androidx.biometric:biometric` (already pulled in by local_auth; declared explicitly so our Kotlin compiles against it).

**Spec:** `docs/superpowers/specs/2026-10-22-personal-life-manager-design.md`. Read §4 (anti-goals: vault secrets never leave the device or reach logs, prefs, plaintext columns, exports or AI), §9 (all), §13 (vault in backups), §14 phase 3, §15 ("Vault security review"), and Appendix A (Vault, Tests → Vault and Privacy). Phase 2 plan for format and rulings: `docs/superpowers/plans/2026-10-23-phase-2-finance-and-capture.md`.

## Decisions taken for this plan (builder's calls; the owner is asleep and asked for none)

1. **Where each wrap lives.** Password and recovery wraps are rows in the SQLCipher DB (`vault_key_wraps`), so a backup restores a vault that opens with the master password or recovery key on any phone (spec §13). The biometric wrap is a JSON blob in Keystore-backed secure storage under `vault_bio_wrap_v1`, tagged with the vault's random `vaultId`; it is never in a backup. A restore deletes it and the Keystore key, so biometrics must be turned on again with the master password.
2. **Key check.** `vault_meta` stores the VDK's AES-GCM seal of a fixed label (`checkBlob`). Every unlock path (password, recovery, biometric) must open it before the vault counts as unlocked. A biometric wrap whose `vaultId` differs from the DB, or whose VDK fails the check, is deleted and reported as invalidated.
3. **Associated data.** Wraps: `plm-vault-wrap-v1|<kind>|<vaultId>`. Fields: `plm-vault-field-v1|<item uid>|<field>`. The item identity is a random 128-bit `uid` (hex) created with the item, not the SQLite rowid, so it is known before the insert and survives restore. Moving a ciphertext to another item or field fails authentication.
4. **Encrypted fields:** password, notes, recovery codes. **Plain (SQLCipher-only) fields:** site name, URL, username, email, category, workspace, favourite flag and timestamps. Search, filter and sort run only on the plain fields (spec §9.2).
5. **Blob layout:** `0x01 ‖ nonce(12) ‖ ciphertext ‖ tag(16)`. The leading version byte allows a future algorithm change without guessing.
6. **Master password:** at least 10 characters, no composition rules, with a length-based strength hint. Arabic-Indic and Persian digits are normalized to Western digits before hashing (`normalizeDigits`), so switching keyboards cannot lock the owner out. Nothing else is changed: no trimming, no case folding.
7. **Argon2id calibration** (spec §9.1): start at m = 64 MiB, t = 3, p = 1. Time one derivation; if it took under 0.5 s, raise t to `ceil(3 × 0.75 s / elapsed)`, capped at 8. Never go below the spec start unless the phone runs out of memory, then fall back to m = 19 MiB, t = 2. The chosen parameters are stored with the wrap. Parameters read back from the DB are bounds-checked (m 19–1024 MiB, t 1–10, p 1–8) before use, so a crafted backup can't make the phone allocate gigabytes.
8. **Recovery key:** 20 random bytes (160 bits), RFC 4648 Base32 without padding, shown as eight groups of four (`ABCD-EFGH-…`). Typing is lenient: case, spaces and dashes are ignored, Arabic-Indic digits are normalized, and `0`, `1`, `8` are read as `O`, `I`, `B` (they are not in the alphabet). KEK = HKDF-SHA256(ikm = key, salt = 16 random bytes stored with the wrap, info = `plm-vault-recovery-v1`). The owner must type the whole key back before setup finishes. It is never stored, and a new one can be generated from Vault settings (the old one stops working).
9. **Forgot the master password:** unlocking with the recovery key leads straight to "set a new master password", which can't be skipped.
10. **No vault erase in Phase 3.** Deleting all vault data is irreversible and the owner should decide whether they want it; until then, a vault whose master password and recovery key are both lost stays locked (its items are unreadable by design). Listed under Next steps.
11. **Wrong secrets:** one shared failure counter for the password and the recovery key, persisted in secure storage: 5 free attempts, then 30 s doubling to a 1 h cap (same curve as the app PIN). Data is never deleted. The biometric path relies on Android's own lockout.
12. **Biometric key:** Keystore AES-256-GCM, `setUserAuthenticationRequired(true)`, auth on every use (`setUserAuthenticationParameters(0, AUTH_BIOMETRIC_STRONG)` on API 30+, validity −1 below), `setInvalidatedByBiometricEnrollment(true)`, unlocked through `BiometricPrompt` with a `CryptoObject` (spec §6, §9.1). Device credential is **not** accepted for this key: a PIN-unlocked phone must not open the vault without the master password. `local_auth` stays only for the app lock.
13. **Auto-lock:** after 2 minutes without a touch inside the app (configurable 1, 2, 5, 10 min; stored as `vaultAutoLockSeconds`), immediately when the app is hidden, and whenever the app lock locks. Locking zero-fills the VDK and drops every revealed value. Dart strings can't be wiped; that limit is written in the review (spec §9.2 "best effort; documented").
14. **Fresh auth** before reveal or copy when the last successful vault auth is older than 30 s: biometric if enabled (a real Keystore unwrap whose result must equal the in-memory VDK), else the master password.
15. **Clipboard:** a Kotlin channel sets the clip with `ClipDescription.EXTRA_IS_SENSITIVE` (Android 13+; harmless below) and a unique label, then clears it after 30 s on the main looper (`clearPrimaryClip` on API 28+, an empty clip below) unless the clip now has another label. If the process dies first, the clip is not cleared; the UI only says "cleared after 30 seconds where Android allows it". Copying never goes through `Clipboard.setData` and never logs. Usernames, emails and URLs use the same path (no 30 s promise shown for them, but they are cleared too).
16. **Import from notes** is a pure-Dart heuristic: blocks split on blank lines or separator lines, labels in Arabic, Iraqi Arabic, Sorani and English, URL and email detection, and single-line `site email password` forms. Every proposal is reviewed; nothing is saved without the owner keeping it. The pasted text field turns off suggestions and IME learning, and the text is cleared after saving. A closing dialog reminds the owner to delete the original note.
17. **Secret text fields** everywhere: `obscureText` where single-line, `autocorrect: false`, `enableSuggestions: false`, `enableIMEPersonalizedLearning: false`, `keyboardType: TextInputType.visiblePassword` for single-line secrets.
18. **Categories** are the ten fixed keys from the original spec (`personal, business, social, banking, hosting, domain, email, marketing, dev, other`), localized; custom vault categories can come later. Workspace link is optional (`SET NULL` on workspace delete is not needed because workspaces are archived, never deleted; FK is `restrict`).
19. **Secure attachments** are out of scope (attachments do not exist anywhere in the app yet). Listed under Next steps.
20. **Generator:** length 8–64 (default 20), lower / upper / digits / symbols (default all on), "avoid look-alikes" (`Il1O0`, default on), at least one character from each chosen class, uniform choice via `Random.secure()` and a Fisher–Yates shuffle. The entropy estimate shown is `length × log2(pool)` bits.
21. **Version** `1.2.0+3` (arm64 versionCode 2003 with `--split-per-abi`).

## Global Constraints

- Everything in the Phase 1 and Phase 2 Global Constraints still holds (no Google, no analytics, FLAG_SECURE app-wide, `minSdk 26`, applicationId, tokens, nav layout, default locale `ar`, all strings in all three ARB files, Sorani draft quality, logs carry error **types** only).
- **No vault secret ever** reaches a log line, an exception message, `toString`, a provider's state after lock, secure-storage keys other than the biometric wrap (which is itself encrypted), a plaintext DB column, a backup's plaintext DB snapshot, an export, the AI payload or the network. Tests assert the log, backup and snapshot cases with marker strings.
- Secrets in Dart are `Sensitive<String>` (or `VaultKey` for key bytes) from decryption to use. Key bytes are zero-filled in `finally` blocks.
- Only the existing `Kdf`, `Aead`, `secureRandomBytes`, and `package:cryptography`'s `Hkdf`/`Hmac` are used. No hand-written cipher, MAC or KDF. Base32 is an encoding, not a primitive, and is tested against RFC 4648 vectors.
- Every vault route renders through `VaultGate`: when the vault is locked it shows the unlock screen, never the route's content.
- No new Android permission (`USE_BIOMETRIC` exists). No network code in `lib/features/vault/` (a test asserts it imports neither `http` nor `http_port.dart`).
- UI tasks load `impeccable` first (Flutter: its principles), and keep the worst-case tests (320 dp, `ckb`, 2× text) passing for every new screen.

## Review Focus

1. **Every way to unlock, and every way it can go wrong:** wrong master password, wrong recovery key, tampered wrap row, a biometric wrap from another vault (after a restore), a Keystore key invalidated by a new fingerprint, cancelled prompt, lockout. Expect a generic error, the counter and backoff, no data deleted, and a vault that still opens with the right secret. Covered by Tasks 3 and 4.
2. **Secrets leaking:** logs during setup, unlock, CRUD, reveal, copy, import and failures; backup file bytes; the plaintext DB inside the backup; `toString` of every vault type. Covered by Tasks 1, 3, 6 and 12.
3. **Lock really locks:** idle timeout, app hidden, app lock, manual lock. Expect the VDK zero-filled, revealed fields gone, and deep routes showing the unlock screen. Covered by Tasks 5 and 9.
4. **Restore paths:** a v2 backup into this app (migrates, empty vault), a v3 backup with a vault onto a fresh install (opens with the master password and recovery key; biometrics off). Covered by Task 12.
5. **Sorani at 320 dp with 2× text** on the unlock, setup, list, detail, form, import and settings screens. Covered by Task 13.

---

## File Structure

```
lib/features/vault/crypto/vault_key.dart, field_cipher.dart, key_wrap.dart, recovery_key.dart, base32.dart, vault_kdf.dart
lib/features/vault/domain/password_generator.dart, notes_parser.dart, vault_category.dart, password_strength.dart
lib/features/vault/data/vault_key_service.dart, vault_items_repository.dart, vault_providers.dart, unlock_throttle.dart
lib/features/vault/platform/biometric_key_store.dart, secret_clipboard.dart
lib/features/vault/vault_session.dart
lib/features/vault/ui/vault_gate.dart, vault_setup_screen.dart, vault_unlock_screen.dart, vault_list_screen.dart,
    vault_item_screen.dart, vault_item_form_screen.dart, generator_sheet.dart, vault_import_screen.dart,
    vault_settings_screen.dart, fresh_auth.dart, secret_field.dart, recovery_key_view.dart
lib/core/db/vault_tables.dart                    # new tables; app_database.dart → schemaVersion 3
android/app/src/main/kotlin/com/personal/lifemanager/VaultChannel.kt
android/app/src/main/kotlin/com/personal/lifemanager/MainActivity.kt (modified: register the channel)
android/app/build.gradle.kts (androidx.biometric)
lib/features/backup/backup_service.dart (modified: afterRestore hook)
docs/superpowers/specs/2026-10-23-phase-3-vault-security-review.md
test/... mirrors lib/
```

---

### Task 1: Vault crypto core

**Files:**
- Create: `lib/features/vault/crypto/{vault_key,field_cipher,key_wrap,recovery_key,base32,vault_kdf}.dart`
- Test: `test/features/vault/crypto/*_test.dart`

**Interfaces:**
- Consumes: `Kdf`, `KdfParams`, `KdfOutOfMemory`, `Aead`, `SealedBox`, `AeadAuthException`, `secureRandomBytes`, `normalizeDigits`.
- Produces:
  - `final class VaultKey { VaultKey(Uint8List bytes); Uint8List get bytes; bool get isDestroyed; void destroy(); bool sameAs(VaultKey o); }` — 32 bytes or `ArgumentError`; `bytes` after `destroy` → `StateError`; `toString` → `‹redacted›`; `sameAs` is constant-time.
  - `VaultKey generateVaultKey()`.
  - `Uint8List encodeBlob(SealedBox b)` / `SealedBox decodeBlob(Uint8List blob)` — layout `0x01 ‖ nonce ‖ ct+tag`; bad version or length → `VaultCorrupt`.
  - `class FieldCipher { FieldCipher(Aead aead); Future<Uint8List> seal(VaultKey k, String uid, VaultField f, Sensitive<String> value); Future<Sensitive<String>> open(VaultKey k, String uid, VaultField f, Uint8List blob); }` with `enum VaultField { password, notes, recoveryCodes }`. AAD `plm-vault-field-v1|<uid>|<field.name>`. Auth failure → `VaultCorrupt`.
  - `sealed class VaultUnlockError implements Exception`: `VaultWrongSecret`, `VaultCorrupt`, `VaultLockedOut(Duration remaining)`, `VaultBiometricInvalidated`, `VaultBiometricCancelled`, `VaultBiometricUnavailable`. None carries text from input.
  - `class WrappedKey { final String kind; final KdfParams? kdf; final Uint8List salt; final Uint8List blob; }` (`kind` is `password` or `recovery`).
  - `class KeyWrapper { KeyWrapper(Kdf kdf, Aead aead); Future<WrappedKey> wrapWithPassword(VaultKey vdk, Sensitive<String> password, String vaultId, KdfParams p); Future<VaultKey> unwrapWithPassword(WrappedKey w, Sensitive<String> password, String vaultId); Future<WrappedKey> wrapWithRecovery(VaultKey vdk, RecoveryKey r, String vaultId); Future<VaultKey> unwrapWithRecovery(WrappedKey w, RecoveryKey r, String vaultId); Future<Uint8List> makeCheck(VaultKey vdk, String vaultId); Future<bool> verifyCheck(VaultKey vdk, String vaultId, Uint8List check); }` — KEKs are zero-filled in `finally`; wrong secret → `VaultWrongSecret`; `unwrapWithPassword` bounds-checks `w.kdf` with `checkVaultKdf` first (`VaultCorrupt`). The password is digit-normalized (Decision 6).
  - `final class RecoveryKey { Uint8List get bytes; String get display; static RecoveryKey generate(); static RecoveryKey? parse(String typed); }` — `display` is `XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX`; `toString` redacted; `parse` per Decision 8, `null` when not exactly 32 Base32 characters.
  - `String base32Encode(List<int> bytes)` / `Uint8List? base32Decode(String s)` (RFC 4648, no padding).
  - `Future<KdfParams> calibrateVaultKdf(Kdf kdf, {Duration Function(Future<void> Function()) timer})` and `void checkVaultKdf(KdfParams p)` (Decision 7).

- [ ] **Step 1: Write the failing tests**

```dart
test('field round-trip and AAD binding', () async {
  final blob = await fc.seal(k, 'uid-a', VaultField.password, const Sensitive('TEST-ONLY-pw-7731'));
  expect((await fc.open(k, 'uid-a', VaultField.password, blob)).value, 'TEST-ONLY-pw-7731');
  expect(() => fc.open(k, 'uid-b', VaultField.password, blob), throwsA(isA<VaultCorrupt>()));
  expect(() => fc.open(k, 'uid-a', VaultField.notes, blob), throwsA(isA<VaultCorrupt>()));
});
test('two seals of the same value differ (fresh nonce)', ...);
test('blob with bit flipped → VaultCorrupt; version byte 2 → VaultCorrupt', ...);
test('password wrap: right → same VDK; wrong → VaultWrongSecret; other vaultId → VaultWrongSecret', ...);
test('Arabic-Indic digits in the master password unwrap the same', ...);
test('recovery wrap round-trip; parse is lenient (lowercase, spaces, 0/1/8)', ...);
test('base32 RFC 4648 vectors: "f"→MY, "fo"→MZXQ, "foobar"→MZXW6YTBOI', ...);
test('recovery display is 8 groups of 4 and parse(display) == key', ...);
test('calibrate: fast device raises t (cap 8); OOM falls back to 19 MiB t=2; slow stays at spec start', ...);
test('checkVaultKdf rejects m = 4 GiB and t = 50', ...);
test('VaultKey destroy zero-fills, toString redacted, bytes after destroy throws', ...);
test('no vault type prints a secret', () { /* RecoveryKey, VaultKey, Sensitive, WrappedKey toString */ });
```

- [ ] **Step 2: Run** `flutter test test/features/vault/crypto` — Expected: FAIL (symbols undefined).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(vault): key wrapping, field encryption and recovery key`

---

### Task 2: Schema v3 and migration

**Files:**
- Create: `lib/core/db/vault_tables.dart`, `drift_schemas/drift_schema_v3.json`, `test/core/db/generated/schema_v3.dart`
- Modify: `lib/core/db/tables.dart` (settings column), `lib/core/db/app_database.dart`, `test/core/db/migration_test.dart`
- Test: `test/core/db/schema_v3_test.dart`

**Interfaces:**
- Produces:
  - `VaultMeta` (`vault_meta`, one row, `id` check `= 1`): `vaultId` text (32 hex), `checkBlob` blob, `createdAt`.
  - `VaultKeyWraps` (`vault_key_wraps`): `id`, `kind` text unique check in (`password`,`recovery`), `kdfJson` text nullable (non-null exactly when `kind = 'password'`), `salt` blob, `blob` blob, `createdAt`.
  - `VaultItems` (`vault_items`): `id`, `uid` text unique (32 hex), `title` text 1..120, `url` nullable ≤ 2000, `username` nullable ≤ 200, `email` nullable ≤ 200, `category` text check in the ten keys, `workspaceId` nullable FK restrict, `favorite` bool default false, `passwordBlob`, `notesBlob`, `recoveryCodesBlob` (blobs, nullable), `passwordChangedAt` nullable, `createdAt`, `updatedAt`. Index on (`title`).
  - `AppSettingsTable.vaultAutoLockSeconds` int default 120 check in (60, 120, 300, 600).
  - `schemaVersion => 3`; `onUpgrade`: the v2 block stays, then `if (from < 3)` creates the three tables and index and adds the column.

- [ ] **Step 1: Write the failing tests**

```dart
test('v2 → v3 keeps every v2 row and adds empty vault tables', ...);   // SchemaVerifier, migrateAndValidate(db, 3)
test('v1 → v3 in one open', ...);
test('vault item with an unknown category is rejected', ...);
test('password wrap without kdfJson is rejected; recovery wrap with kdfJson is rejected', ...);
test('a second password wrap is rejected (unique kind)', ...);
test('vault_meta accepts only id 1', ...);
test('vaultAutoLockSeconds defaults to 120 and rejects 45', ...);
```

- [ ] **Step 2: Run** `dart run build_runner build -d`, then `flutter test test/core/db` — Expected: FAIL.
- [ ] **Step 3: Implement**, then `dart run drift_dev schema dump lib/core/db/app_database.dart drift_schemas/` and `dart run drift_dev schema generate drift_schemas/ test/core/db/generated/`.
- [ ] **Step 4: Run** `flutter test` — Expected: PASS.
- [ ] **Step 5: Commit** — `feat(db): schema v3 for the vault with tested migration`

---

### Task 3: Key service and items repository

**Files:**
- Create: `lib/features/vault/data/{vault_key_service,vault_items_repository,unlock_throttle,vault_providers}.dart`, `lib/features/vault/domain/vault_category.dart`
- Test: `test/features/vault/data/vault_key_service_test.dart`, `vault_items_repository_test.dart`, `unlock_throttle_test.dart`

**Interfaces:**
- Consumes: Task 1, Task 2, `SecureStore`, `normalizeForMatch`.
- Produces:
  - `class UnlockThrottle { UnlockThrottle(SecureStore s, {DateTime Function()? now}); Future<Duration?> blockedFor(); Future<void> recordFailure(); Future<void> reset(); }` — key `vault_unlock_failures_v1`, Decision 11.
  - `class VaultKeyService { VaultKeyService({required AppDatabase db, required KeyWrapper wrapper, required UnlockThrottle throttle, required BioWrapStore bio, required Kdf kdf}); Future<bool> isSetUp(); Future<(VaultKey, RecoveryKey)> setUp(Sensitive<String> masterPassword, {KdfParams? params}); Future<VaultKey> unlockWithPassword(Sensitive<String> pw); Future<VaultKey> unlockWithRecovery(String typed); Future<void> changeMasterPassword(VaultKey vdk, Sensitive<String> next, {KdfParams? params}); Future<RecoveryKey> regenerateRecoveryKey(VaultKey vdk); Future<String> vaultId(); }`
    - `setUp` throws `StateError` if a vault exists and `ArgumentError` for a password under 10 characters (after digit normalization); writes meta, both wraps and the check in **one** DB transaction.
    - Unlock: `throttle.blockedFor()` → `VaultLockedOut`; wrong → `recordFailure`, `VaultWrongSecret`; right → `reset`, verify check (`VaultCorrupt` if it fails).
    - `unlockWithRecovery` with an unparsable key counts as a failure.
  - `BioWrapStore` is defined in Task 4; until then the service takes an `InMemoryBioWrapStore`.
  - `const kVaultCategories = ['personal','business','social','banking','hosting','domain','email','marketing','dev','other']`; `String vaultCategoryLabel(String key, AppLocalizations l)`; `IconData vaultCategoryIcon(String key)` (ui helper lives in `ui/`).
  - `class VaultItemInput { String title; String? url, username, email; String category; int? workspaceId; bool favorite; Sensitive<String>? password, notes, recoveryCodes; }` — empty strings become `null`.
  - `class VaultSecrets { final Sensitive<String>? password, notes, recoveryCodes; }`.
  - `enum VaultSort { title, updated, created }`; `class VaultQuery { String text; String? category; bool favoritesOnly; VaultSort sort; }`.
  - `class VaultItemsRepository { VaultItemsRepository(AppDatabase db, FieldCipher fc); Stream<List<VaultItem>> watch(VaultQuery q); Future<VaultItem?> get(int id); Future<int> create(VaultKey k, VaultItemInput in); Future<void> update(VaultKey k, int id, VaultItemInput in); Future<void> delete(int id); Future<VaultSecrets> secrets(VaultKey k, int id); Future<int> count(); }` — `update` re-seals every secret field (fresh nonces) and sets `passwordChangedAt` only when the password changed; text search matches title, URL, username and email through `normalizeForMatch`, never a blob.

- [ ] **Step 1: Write the failing tests**

```dart
test('setUp then unlockWithPassword returns the same VDK', ...);
test('setUp twice → StateError; 9-char password → ArgumentError', ...);
test('wrong password 5× → 5th is VaultLockedOut(30s); after 30s right password unlocks and resets', ...);
test('recovery key unlocks; garbage counts as a failure', ...);
test('changeMasterPassword: old fails, new works, items still decrypt', ...);
test('regenerateRecoveryKey: old key fails, new works', ...);
test('tampered password wrap → VaultWrongSecret, nothing deleted', ...);
test('check blob mismatch → VaultCorrupt', ...);
test('create + secrets round-trip; DB row holds no plaintext secret', () async {
  // raw SELECT of every column; for each value (as text and as UTF-8 bytes) expect no 'TEST-ONLY-pw-7731'
});
test('search matches title/username/email/url without diacritics, never the password', ...);
test('sort by title, updated, created; category and favourite filters', ...);
test('update re-seals with new nonces and bumps passwordChangedAt only on password change', ...);
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(vault): key service with throttled unlock, encrypted items repository`

---

### Task 4: Biometric-bound Keystore key

**Files:**
- Create: `lib/features/vault/platform/biometric_key_store.dart`, `android/app/src/main/kotlin/com/personal/lifemanager/VaultChannel.kt`
- Modify: `MainActivity.kt` (`configureFlutterEngine` registers `VaultChannel`), `android/app/build.gradle.kts` (`implementation("androidx.biometric:biometric:1.1.0")`), `lib/features/vault/data/vault_key_service.dart`
- Test: `test/features/vault/platform/biometric_key_store_test.dart`, extend `vault_key_service_test.dart`

**Interfaces:**
- Produces:
  - Channel `com.personal.lifemanager/vault`, methods `bioAvailable` → bool; `bioEncrypt {data: Uint8List, title, subtitle, cancel}` → Uint8List (`iv(12) ‖ ct+tag`); `bioDecrypt {data, title, subtitle, cancel}` → Uint8List; `bioDelete`. Errors are `PlatformException` codes only: `invalidated`, `cancelled`, `lockout`, `unavailable`, `failed`. The Kotlin side never logs and never puts data in an error message.
  - Kotlin key: alias `vault_bio_kek_v1`, Decision 12. `bioEncrypt` creates the key if missing. `KeyPermanentlyInvalidatedException` or a missing key on decrypt → delete the key, `invalidated`.
  - `class BioPromptText { final String title, subtitle, cancel; }`
  - `abstract interface class BiometricKeyStore { Future<bool> isAvailable(); Future<Uint8List> encrypt(Uint8List data, BioPromptText t); Future<Uint8List> decrypt(Uint8List data, BioPromptText t); Future<void> deleteKey(); }` + `PlatformBiometricKeyStore` (maps codes to `VaultBiometricInvalidated` / `VaultBiometricCancelled` / `VaultBiometricUnavailable` / `VaultWrongSecret` for `failed` and `lockout` → `VaultLockedOut(Duration.zero)`).
  - `abstract interface class BioWrapStore { Future<BioWrap?> read(); Future<void> write(BioWrap w); Future<void> clear(); }`, `class BioWrap { final String vaultId; final Uint8List blob; }`, `SecureBioWrapStore(SecureStore)` under `vault_bio_wrap_v1`, `InMemoryBioWrapStore`.
  - `VaultKeyService` additions: `Future<bool> biometricEnabled()` (wrap exists and matches `vaultId`); `Future<void> enableBiometric(VaultKey vdk, BioPromptText t)`; `Future<void> disableBiometric()` (clears wrap and deletes the Keystore key); `Future<VaultKey> unlockWithBiometric(BioPromptText t)` — mismatched `vaultId`, `invalidated`, or a failed check → clear wrap + delete key + `VaultBiometricInvalidated`; `Future<void> forgetDeviceKeys()` (used after restore).

- [ ] **Step 1: Write the failing tests**

```dart
test('channel: encrypt sends data and prompt text; codes map to typed errors', ...); // TestDefaultBinaryMessenger mock
test('enable + unlockWithBiometric returns the VDK', ...);           // FakeBiometricKeyStore (xor with a fixed key)
test('wrap from another vaultId → invalidated, wrap cleared', ...);
test('invalidated key → wrap cleared; password still unlocks; enable again works', ...);
test('cancelled → VaultBiometricCancelled, wrap kept', ...);
test('disableBiometric clears wrap and deletes key', ...);
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** (Dart and Kotlin). **Step 4: Run** `flutter test` → PASS, then `flutter build apk --debug` → the Kotlin compiles.
- [ ] **Step 5: Commit** — `feat(vault): biometric-bound Keystore wrap of the vault key`

---

### Task 5: Vault session and auto-lock

**Files:**
- Create: `lib/features/vault/vault_session.dart`
- Modify: `lib/app/app.dart` (hide → `vaultSession.lock()`; app lock → vault lock), `lib/features/settings/settings_repository.dart` (`setVaultAutoLock(int seconds)`)
- Test: `test/features/vault/vault_session_test.dart`

**Interfaces:**
- Produces:
  - `sealed class VaultState`: `VaultNotSetUp`, `VaultLocked`, `VaultUnlocked(DateTime lastAuthAt)`.
  - `class VaultSession extends Notifier<VaultState>` (`vaultSessionProvider`): `Future<void> refresh()` (set-up check), `void unlocked(VaultKey k, {required DateTime at})`, `VaultKey requireKey()` (`StateError` when locked), `void touch(DateTime at)` (restarts the idle timer), `void lock()` (destroys the key, cancels timers), `bool needsFreshAuth(DateTime now)` (> 30 s), `void freshAuthAt(DateTime at)`. The idle duration comes from `vaultAutoLockSeconds`. Timers use `Timer`, so tests drive them with `fake_async`-style `t.pump`.
  - Disposal of the provider locks.

- [ ] **Step 1: Write the failing tests**

```dart
test('unlock then idle 120 s → locked and key destroyed', ...);
test('touch at 100 s pushes the lock to 220 s', ...);
test('app hidden → locked at once', ...);   // via the App lifecycle in a widget test
test('app lock locking also locks the vault', ...);
test('needsFreshAuth false at 29 s, true at 31 s; freshAuthAt resets', ...);
test('setVaultAutoLock rejects 45', ...);
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(vault): session with idle and background auto-lock`

---

### Task 6: Secret clipboard

**Files:**
- Create: `lib/features/vault/platform/secret_clipboard.dart`
- Modify: `VaultChannel.kt` (methods `copySecret {text, label, clearAfterMs}` and `clearSecret {label}`)
- Test: `test/features/vault/platform/secret_clipboard_test.dart`

**Interfaces:**
- Produces:
  - `abstract interface class SecretClipboard { Future<void> copy(Sensitive<String> value, {Duration clearAfter = kClipboardClear}); }`, `const kClipboardClear = Duration(seconds: 30)`.
  - `PlatformSecretClipboard` — calls the channel with a fresh label `plm-<16 hex>`; on `MissingPluginException` (tests, other platforms) falls back to `Clipboard.setData` plus a Dart `Timer` that clears only if the clip still equals the value. Never logs the value; on error logs the type only.
  - Kotlin: `ClipData.newPlainText(label, text)`, `description.extras = PersistableBundle().apply { putBoolean("android.content.extra.IS_SENSITIVE", true) }`, `Handler(Looper.getMainLooper()).postDelayed` clearing when the current description label equals ours or can't be read (Decision 15).

- [ ] **Step 1: Write the failing tests**

```dart
test('copy sends text, a plm- label and 30000 ms; logs nothing', ...);
test('fallback clears after 30 s only when the clip is unchanged', ...);
test('channel error logs only the type', ...);
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(vault): sensitive clipboard with 30 s clear`

---

### Task 7: Password generator and strength

**Files:**
- Create: `lib/features/vault/domain/password_generator.dart`, `password_strength.dart`
- Test: `test/features/vault/domain/password_generator_test.dart`, `password_strength_test.dart`

**Interfaces:**
- Produces:
  - `class GeneratorOptions { int length = 20; bool lower = true, upper = true, digits = true, symbols = true, avoidLookAlikes = true; }`
  - `Sensitive<String> generatePassword(GeneratorOptions o, {Random? random})` — `ArgumentError` when length is outside 8–64 or no class is on (Decision 20).
  - `double estimateEntropyBits(GeneratorOptions o)`.
  - `enum Strength { weak, fair, strong, veryStrong }` and `Strength masterPasswordStrength(String pw)` (length-based: < 10 weak, < 14 fair, < 20 strong, else very strong) — used for the master password and shown next to item passwords.

- [ ] **Step 1: Write the failing tests**

```dart
test('length honoured 8..64; out of range throws', ...);
test('each chosen class appears at least once over 1000 runs', ...);
test('avoidLookAlikes never yields I l 1 O 0', ...);
test('digits only: rough uniformity over 20000 chars (each digit 8–12 %)', ...);
test('entropy: 20 chars from 4 classes without look-alikes ≈ 20·log2(pool)', ...);
test('toString of the result is redacted', ...);
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(vault): password generator`

---

### Task 8: Import-from-notes parser

**Files:**
- Create: `lib/features/vault/domain/notes_parser.dart`
- Test: `test/features/vault/domain/notes_parser_test.dart`

**Interfaces:**
- Produces:
  - `class NoteProposal { String title; String? url, username, email; Sensitive<String>? password; String? notes; String category; }` (category guessed from title keywords: facebook/instagram/tiktok → social, gmail/outlook → email, bank/rafidain/مصرف → banking, hostinger/cpanel → hosting, godaddy/namecheap/domain → domain, github/gitlab → dev, else other).
  - `List<NoteProposal> parseNotes(String text)` — Decision 16. Labels (case/diacritic-insensitive via `normalizeForMatch`): user `user, username, login, يوزر, اليوزر, اسم المستخدم, ناوی بەکارهێنەر`; email `email, mail, e-mail, ايميل, الايميل, بريد, ئیمەیڵ`; password `pass, password, pw, pwd, باسورد, الباسورد, كلمة السر, كلمه المرور, الرمز, رمز, پاسۆرد, وشەی نهێنی`; site `site, website, url, link, موقع, الموقع, رابط, ماڵپەڕ`; notes `note, notes, ملاحظة, ملاحظات, تێبینی`; codes `codes, backup codes, recovery, رموز, كودات, کۆدەکان`. Separators `:`, `：`, `=`, `-` after a label. A block without a password or username/email yields nothing. At most 500 proposals; text over 200,000 characters → `ArgumentError`.

- [ ] **Step 1: Write the failing tests** — a table of inputs to expected proposals, including: labelled English block; Iraqi labels («اليوزر: ahmed», «الباسورد = 1234»); Sorani labels; a single line `gmail ahmed@gmail.com Pa55word!`; URLs with and without scheme; blocks separated by `---`; blank-line-separated blocks; a shopping list (no proposals); Arabic-Indic digits kept as typed in passwords (passwords are never normalized); 200,001 characters → `ArgumentError`.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(vault): local import-from-notes parser`

---

### Task 9: Vault UI — gate, setup and unlock

Load `impeccable` before this task.

**Files:**
- Create: `lib/features/vault/ui/{vault_gate,vault_setup_screen,vault_unlock_screen,recovery_key_view,secret_field}.dart`
- Modify: `lib/app/router.dart` (replace the `/vault` placeholder), ARB files
- Test: `test/features/vault/ui/vault_setup_test.dart`, `vault_unlock_test.dart`

**Interfaces:**
- Produces:
  - `VaultGate({required Widget Function(BuildContext, VaultKey) builder})`: `VaultNotSetUp` → setup intro, `VaultLocked` → `VaultUnlockScreen`, `VaultUnlocked` → builder; a `Listener` around the builder calls `touch` on every pointer down.
  - `SecretField` (Decision 17) with show/hide.
  - **Setup:** intro (what the vault is, what the master password and recovery key are for, "use test passwords until you've read the security review") → master password ×2 with the strength hint → calibration progress → recovery key shown in `RecoveryKeyView` (monospace, LTR, grouped, copy button through `SecretClipboard`, "write it on paper") → type it back → optional "unlock with fingerprint" → done.
  - **Unlock:** master password field, fingerprint button when enabled (auto-prompts once), "Use recovery key" → recovery entry → forced new master password (Decision 9), the generic error, the lockout countdown, invalidated-biometric notice.

- [ ] **Step 1: Write the failing widget tests**
  - Setup with a 9-character password keeps Next disabled; mismatched confirmation shows an error.
  - The recovery key step won't finish until the exact key is typed back (lowercase and without dashes is accepted).
  - Wrong master password shows the generic error; the 5th shows the countdown.
  - Recovery-key unlock leads to the new-password step; Back can't skip it.
  - Locked vault on a deep route (`/vault/item/1`) shows the unlock screen.
  - In `ar` the recovery key renders LTR.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(vault): setup with recovery key, unlock and gate`

---

### Task 10: Vault UI — list, detail, form, generator

Load `impeccable` before this task.

**Files:**
- Create: `lib/features/vault/ui/{vault_list_screen,vault_item_screen,vault_item_form_screen,generator_sheet,fresh_auth}.dart`
- Test: `test/features/vault/ui/vault_list_test.dart`, `vault_item_test.dart`, `vault_form_test.dart`

**Interfaces:**
- Produces:
  - Routes: `/vault` (list), `/vault/new`, `/vault/item/:id`, `/vault/item/:id/edit`, `/vault/import`, `/vault/settings` — all inside `VaultGate`; forms cover the shell.
  - `Future<bool> ensureFreshAuth(BuildContext c, WidgetRef ref)` (Decision 14).
  - **List:** search field (non-secret fields), category chips, favourites toggle, sort menu, item tiles (category icon, title, username or email, favourite star), empty states (no items / no matches), app-bar actions lock, generator, import, settings; "+" button.
  - **Detail:** title, URL, username, email (each with copy), password masked with reveal and copy (fresh auth), notes and recovery codes hidden behind reveal, "password changed on" date, edit, delete (confirm). Revealed values hide again after 30 s and on lock.
  - **Form:** title (required), URL, username, email, password (`SecretField` + generate + strength), category, workspace (optional), favourite, notes and recovery codes (multiline, IME learning off). Save disabled until title is set. Leaving with changes asks to discard.
  - **Generator sheet:** length slider, class switches, look-alike switch, entropy, regenerate, copy, "use this password" (form only).

- [ ] **Step 1: Write the failing widget tests**
  - Create an item through the form; the list shows it; the DB row has no plaintext password.
  - Search «احمد» finds an item whose username is «أحمد»; searching the password finds nothing.
  - Reveal more than 30 s after unlock asks for the master password first; within 30 s it does not.
  - Copy password calls `SecretClipboard.copy` once with the value; nothing reaches `AppLogger.sink`.
  - Delete asks for confirmation, then the item is gone.
  - Generator "use this password" fills the form field.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(vault): item list, detail with fresh-auth reveal, form and generator`

---

### Task 11: Vault UI — import from notes, settings, shortcuts

Load `impeccable` before this task.

**Files:**
- Create: `lib/features/vault/ui/{vault_import_screen,vault_settings_screen}.dart`
- Modify: `lib/features/capture/ui/capture_sheet.dart` (enable the vault-item shortcut → `/vault/new`), `lib/features/settings/settings_screen.dart` (Vault row → `/vault/settings`; Privacy text), ARB files
- Test: `test/features/vault/ui/vault_import_test.dart`, `vault_settings_test.dart`

**Interfaces:**
- Produces:
  - **Import:** paste area (IME learning off) → "Find items" → one card per proposal (edit, keep/drop, password masked) → "Save N items" → dialog "delete the original note yourself" → back to list; the paste field is cleared.
  - **Vault settings:** auto-lock (1/2/5/10 min), fingerprint switch (enable needs the vault unlocked and a prompt; unavailable state explained), change master password (current + new ×2), new recovery key (fresh auth, then the confirm-by-typing step), and a "how your vault is protected" text matching the review.

- [ ] **Step 1: Write the failing widget tests**
  - Pasting two blocks shows two cards; dropping one and saving creates one item and shows the reminder.
  - Change master password with a wrong current one fails; with the right one, the new one unlocks.
  - New recovery key needs typing back; the old one stops working.
  - Fingerprint switch off clears the wrap.
  - The capture sheet's vault shortcut opens `/vault/new`.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(vault): import from notes, vault settings and shortcut`

---

### Task 12: Backup, restore and leak tests

**Files:**
- Modify: `lib/features/backup/backup_service.dart` (`Future<void> Function()? afterRestore`), `lib/main.dart` (wire `VaultKeyService.forgetDeviceKeys`), `lib/features/backup/backup_screen.dart` (copy: the vault is in the backup; fingerprint must be turned on again)
- Test: `test/features/vault/vault_backup_test.dart`, `test/features/vault/vault_leak_test.dart`, `test/features/vault/no_network_test.dart`

**Interfaces:**
- Produces: `BackupService(afterRestore: …)` runs after a successful swap (after the Groq key step). Failures in it are logged by type and don't fail the restore.

- [ ] **Step 1: Write the failing tests**
  - `vault survives backup and restore`: set up a vault (FakeKdf), add items, back up, restore into a fresh DB; master password and recovery key both unlock; secrets decrypt; biometric wrap cleared and `deleteKey` called.
  - `backup file and its plaintext DB contain no vault secret`: decode the backup, read `db/app.db` bytes, assert no marker password, notes, recovery code, master password or recovery-key display string (UTF-8 and UTF-16LE).
  - `restoring a v2 backup gives an empty vault on schema 3`.
  - `logs contain no secret`: run setup, unlocks (right and wrong), create, update, reveal, copy, import, generator, change password, regenerate recovery, backup and restore with `AppLogger.sink` capturing; assert no marker appears.
  - `vault code has no network imports`: no file under `lib/features/vault/` imports `package:http` or `core/net/`.
  - AI payload (Phase 2 test) extended: a vault item title marker never appears in `buildParsePayload`.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(backup): vault travels encrypted; device keys reset on restore; leak tests`

---

### Task 13: Worst-case UI and localization

**Files:**
- Modify: `test/ui/worst_case_test.dart`, ARB files as needed
- Test: same

- [ ] **Step 1:** Add worst-case tests at 320 dp, `ckb`, 1× and 2× text for: setup (each step), unlock (with lockout message), list with 200 items whose titles are 120 characters, detail with a 2000-character URL and long notes, form with the keyboard open, import with 50 proposals, settings. Plus one `ar` RTL test that the password and recovery key render LTR.
- [ ] **Step 2: Run** → FAIL where something overflows. **Step 3: Fix.** **Step 4: Run** `flutter test` → PASS.
- [ ] **Step 5: Commit** — `test(vault): worst-case layouts at 320 dp, Sorani, 2x text`

---

### Task 14: Security self-review and code-review pass

**Files:**
- Create: `docs/superpowers/specs/2026-10-23-phase-3-vault-security-review.md`
- Modify: whatever the review finds

- [ ] **Step 1:** Write the review (spec §15): assets, threat model (lost/stolen phone locked and unlocked, rooted phone, malicious backup file, shoulder surfing, clipboard snooping, keyboard learning, log/backup leakage, coerced unlock), the key hierarchy diagram, every crypto parameter, a §9 checklist with the test that proves each line, known limits (Dart strings, clipboard on process death, root), and what was not verified on a device.
- [ ] **Step 2:** Run a separate code-review pass over `lib/features/vault/`, `lib/core/crypto/`, `VaultChannel.kt` and the backup changes; record findings in the review's appendix; fix each with a test where possible.
- [ ] **Step 3: Run** `flutter analyze` and `flutter test` → no issues, all passed.
- [ ] **Step 4: Commit** — `docs(vault): security self-review` and `fix(vault): code-review findings`

---

### Task 15: Release APK and install notes

**Files:**
- Modify: `pubspec.yaml` (`version: 1.2.0+3`), `lib/main.dart` (`kAppVersion = '1.2.0'`), `docs/INSTALL.md`, `PRODUCT.md` (Phase 3 done)

- [ ] **Step 1: Run** `flutter analyze` and `flutter test` → clean.
- [ ] **Step 2: Run** `flutter build apk --release --split-per-abi` → `app-arm64-v8a-release.apk`. Check `aapt dump permissions`: unchanged from Phase 2.
- [ ] **Step 3: Update `docs/INSTALL.md`** (Arabic, then English): setting up the vault, the recovery key on paper, fingerprint unlock and when it turns itself off (new fingerprint, restore), clipboard behaviour, import from notes, "use test passwords until you've read the review", and that on-device checks of the biometric key and clipboard still need a phone.
- [ ] **Step 4: Commit** — `chore(release): phase 3 release build and install notes`, then push the branch.

---

## Next steps (separate plans, not part of this one)

- **Owner, before real passwords:** read the security review; run the on-device checks listed in it (biometric key, invalidation on a new fingerprint, clipboard clear on Android 13+).
- **Vault erase** (Decision 10) and **secure attachments** (Decision 19), if the owner wants them.
- **Phase 4 — Tasks**, **Phase 5 — Home and Reminders** (universal search must keep excluding vault secrets; only vault titles may ever appear, and only while the vault is unlocked), **Phase 6 — Future Projects**.
