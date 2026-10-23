# Phase 3 — Vault security review

Date: 2026-10-23
Scope: `lib/features/vault/`, `lib/core/crypto/`, `android/.../VaultChannel.kt`, the backup/restore hook, schema v3.
Basis: spec §4, §9, §13, §15 and the Phase 3 plan (`docs/superpowers/plans/2026-10-23-phase-3-vault.md`, Decisions 1–21).
Author: the builder, as a self-review (Part A) followed by a second pass that read the code again with fresh eyes and fixed what it found (Appendix).

**Read this before moving any real password into the vault.** The vault is built and tested, but nothing here has run on a real phone yet (section 7). Until you have done the on-device checks, use test passwords only (spec §9.2).

---

## 1. Assets

| Asset | Where it lives | Protected by |
|---|---|---|
| Passwords, secure notes, recovery codes of vault items | `vault_items.*_blob` columns | AES-256-GCM per field with the Vault Data Key (VDK), inside the SQLCipher database |
| VDK (Vault Data Key, 256 bit) | Memory while unlocked; otherwise only as three wraps | Master password wrap, recovery-key wrap, optional fingerprint wrap |
| Site, URL, username, email, category, titles | `vault_items` plain columns | SQLCipher only (needed for search, spec §9.2) |
| Master password, recovery key | The owner's head and paper | Never stored |
| DB key (SQLCipher) | Keystore-backed secure storage | Android Keystore |
| Failure counter / lockout | Secure storage `vault_unlock_failures_v1` | Android Keystore |
| Fingerprint wrap | Secure storage `vault_bio_wrap_v1` + Keystore key `vault_bio_kek_v1` | Strong biometric on every use |

## 2. Threat model

| Threat | What happens | Verdict |
|---|---|---|
| **Lost or stolen phone, locked** | Attacker has the encrypted app data. DB is SQLCipher; the DB key is in the Keystore (hardware-backed on most phones). Vault fields are *also* sealed under the VDK, which needs the master password or recovery key. | Holds. Offline guessing of the master password costs Argon2id (m 64 MiB, t ≥ 3) per guess. A weak master password is the weak point; the app only enforces length ≥ 10. |
| **Stolen phone, unlocked, app locked** | App PIN/biometric gate; vault has its own password on top. Auto-lock after 2 min, on app hidden and whenever the app lock locks. | Holds. |
| **Stolen phone, unlocked, vault open** | Attacker can read plain fields and, for 30 s after the last auth, reveal/copy secrets; after that the master password (or the owner's fingerprint) is needed. The vault locks after ≤ 2 min idle. | Accepted window: ≤ 2 min, secrets only within the 30 s fresh-auth window. Delete and edit of plain fields need no fresh auth (edit does; delete doesn't). |
| **Rooted phone / malware with root** | Can read process memory (VDK, revealed strings), hook the clipboard, read the DB key. | **Not defended** (section 6). |
| **Malicious or damaged backup file** | Backup is AES-GCM under the backup password; a restored vault row could carry crafted KDF parameters or ciphertext. | Parameters are bounds-checked before any derivation (m 19–256 MiB, t 1–10, p 1–8); tampered ciphertext fails authentication and reads as "wrong password"; nothing is deleted. |
| **Shoulder surfing** | Secrets are masked; reveal is timed (30 s) and needs fresh auth; `FLAG_SECURE` blocks screenshots and recents. | Holds. |
| **Clipboard snooping** | Clip is marked sensitive (Android 13+ hides it from the toast/preview), uniquely labelled, cleared after 30 s. | Partly: clipboard is readable by the foreground app / default keyboard for up to 30 s; if the process dies the clip is not cleared (section 6). |
| **Keyboard learning** | Secret fields use `obscureText`, `autocorrect: false`, `enableSuggestions: false`, `enableIMEPersonalizedLearning: false`, `visiblePassword`. | Best effort: a keyboard that ignores the flags is outside our control. |
| **Log / backup / export / AI leakage** | Tests assert a marker secret never appears in logs, the backup file, its plaintext DB snapshot or the AI payload; vault code has no network imports. | Holds (tests listed in section 5). |
| **Coerced unlock** | Attacker forces the owner to unlock. | **Not defended** (no duress mode). |
| **Brute force of the unlock screen** | 5 free tries, then 30 s doubling to 1 h, persisted. | Holds against the UI; see limit 5 (clock rollback). |

## 3. Key hierarchy

```
 master password ──Argon2id(m,t,p, salt16)──► KEK_pw ─┐
                                                      │ AES-256-GCM wrap
 recovery key (160 bit) ─HKDF-SHA256(salt16)─► KEK_rc ─┼─────────────────►  VDK (256 bit, random)
                                                      │                         │
 biometric Keystore key (AES-256-GCM, per-use auth) ──┘                         │ AES-256-GCM, fresh 96-bit nonce,
   (wrap stored only on this phone, never in a backup)                          ▼ AAD = item uid ‖ field name
                                                              password / notes / recovery codes (blobs)
```

* **Three wraps**: password and recovery wraps are rows in `vault_key_wraps` (they travel in encrypted backups); the fingerprint wrap is a JSON blob in secure storage tagged with the vault's random `vaultId` and is **not** backed up. A restore deletes it and the Keystore key (plan Decision 1).
* **Key check** (`vault_meta.checkBlob`): AES-GCM seal of the label `plm-vault-check-v1` under the VDK. All three unlock paths must open it before the vault counts as unlocked (Decision 2). A wrong key from any path, including a foreign biometric wrap, is rejected and wiped.
* **Re-wrapping** (change master password, new recovery key) replaces one wrap row in a transaction; items are never re-encrypted.

## 4. Crypto parameters

| Item | Value | Code |
|---|---|---|
| Field/wrap cipher | AES-256-GCM, 12-byte random nonce per seal, 16-byte tag | `core/crypto/aead.dart` |
| Blob layout | `0x01 ‖ nonce(12) ‖ ciphertext ‖ tag(16)` | `crypto/field_cipher.dart` |
| Field AAD | `plm-vault-field-v1|<item uid hex>|<field name>` (uid: 128 random bits, not the row id) | `field_cipher.dart` |
| Wrap AAD | `plm-vault-wrap-v1|<kind>|<vaultId>` | `key_wrap.dart` |
| Key check AAD | `plm-vault-check-v1|<vaultId>` | `key_wrap.dart` |
| VDK | 32 bytes from `Random.secure()` | `vault_key.dart`, `core/crypto/random.dart` |
| Master-password KDF | Argon2id v1.3, m = 64 MiB, t = 3 (raised up to 8 on a fast phone, aiming ≈ 0.75 s), p = 1, 16-byte salt, 32-byte output; fallback m = 19 MiB, t = 2 only on out-of-memory; params stored with the wrap | `crypto/vault_kdf.dart`, `core/crypto/kdf.dart` |
| Accepted stored KDF params | m 19–256 MiB, t 1–10, p 1–8, otherwise `VaultCorrupt` | `checkVaultKdf` |
| Password normalisation | Arabic-Indic/Persian digits → Western; nothing else changed | `core/text/digits.dart` |
| Minimum master password | 10 characters (code points), no composition rules | `vault_key_service.dart` |
| Recovery key | 20 random bytes (160 bit), RFC 4648 Base32, 8 groups of 4; KEK = HKDF-SHA256(ikm = key, salt = 16 random bytes, info = `plm-vault-recovery-v1`) | `recovery_key.dart`, `key_wrap.dart` |
| Biometric key | Keystore AES-256-GCM, `setUserAuthenticationRequired(true)`, auth every use (`setUserAuthenticationParameters(0, AUTH_BIOMETRIC_STRONG)` on API 30+, validity −1 below), `setInvalidatedByBiometricEnrollment(true)`, device PIN **not** accepted, unlocked with `BiometricPrompt` + `CryptoObject` | `VaultChannel.kt` |
| Throttle | 5 free attempts, then 30 s, doubling, cap 1 h; shared by password and recovery key; unreadable record = 1 h lockout | `unlock_throttle.dart` |
| Auto-lock | default 120 s (1/2/5/10 min), immediately on app hidden and on app-lock lock | `vault_session.dart`, `app/app.dart` |
| Fresh-auth window | 30 s | `vault_session.dart` |
| Reveal timeout | 30 s | `vault_item_screen.dart` |
| Clipboard | `EXTRA_IS_SENSITIVE`, label `plm-<random>`, cleared after 30 s unless another label replaced it | `VaultChannel.kt`, `secret_clipboard.dart` |
| Primitives | Only `package:cryptography` (AES-GCM, Argon2id, HKDF, HMAC) and the platform Keystore. No hand-written cipher/MAC/KDF. Base32 is an encoding and is tested against RFC 4648 vectors. | |

## 5. Spec §9 checklist and the test that proves each line

| Spec line | Status | Proof |
|---|---|---|
| §9.1 VDK random 256-bit, AES-256-GCM per field, unique nonce, item id + field name as AAD | ✅ | `field_cipher_test`: "round-trips and binds the ciphertext to its item and field", "a fresh nonce on every seal", "a flipped bit fails authentication", "the blob does not contain the plaintext"; `vault_items_repository_test`: "another vault key cannot read the secrets" |
| §9.1 Wrap 1: Argon2id, m 64 MiB, t 3, p 1, 16-byte salt, parameters stored | ✅ | `key_wrap_test`: "right password → same VDK…", "works with the real Argon2id at the OWASP floor"; `vault_key_service_test`: "stored KDF parameters are the ones chosen at setup" |
| §9.1 Calibrate to ≈ 0.5–1 s; fallback to OWASP minimum if 64 MiB can't be allocated | ✅ logic, ⚠️ not timed on a phone | `key_wrap_test` "KDF parameters": slow phone keeps the start, fast phone raises t capped at 8, out of memory falls back |
| §9.1 Hostile stored parameters can't make the phone allocate gigabytes | ✅ | `key_wrap_test`: "hostile KDF parameters from the database are refused before deriving", "checkVaultKdf … refuses extremes" |
| §9.1 Wrap 2: recovery key 160 bits, grouped Base32, HKDF-SHA256 | ✅ | `recovery_key_test` (RFC vectors, 160 bits as 8×4, lenient parsing), `key_wrap_test` "right key → same VDK; another key → VaultWrongSecret" |
| §9.1 Owner must type the recovery key back before setup completes; key never stored | ✅ | `vault_key_service_test` "nothing is written until the recovery key is confirmed and the setup committed"; `vault_setup_unlock_test` "setup: length rule, mismatch, recovery key typed back…" |
| §9.1 Wrap 3: biometric-bound Keystore key, auth every use, invalidated on enrolment change; on invalidation the master password unlocks and biometrics are re-enrolled | ✅ in Dart with a fake Keystore, ⚠️ real Keystore not run | `vault_biometric_test`: "a new fingerprint invalidates the key; the password still unlocks; enabling again works", "a wrap from another vault (after a restore) is invalidated and cleared", "a key that decrypts to something else fails the key check and is cleared", "cancelling the prompt keeps the wrap"; `vault_setup_unlock_test` "fingerprint unlock opens the vault; an invalidated key falls back with a notice". Kotlin: code review only (section 7) |
| §9.1 Wrong password: generic error, GCM failure, rate limit with backoff, data never deleted | ✅ | `vault_key_service_test`: "wrong password: generic error, 5th attempt locks out 30 s…", "a wrong attempt never deletes anything", "a tampered password wrap reads as a wrong password and nothing is deleted"; `unlock_throttle_test` (curve, persistence, damaged record = lockout); `vault_setup_unlock_test` "wrong master password: generic error, then a lockout countdown on the 5th" |
| §9.2 Auto-lock after idle (default 2 min) and on app background; VDK zeroed | ✅ | `vault_session_test`: "unlock, then 120 s idle → locked and the key wiped", "a touch restarts the idle timer", "the idle time follows the setting", "hiding the app locks the vault at once", "the app lock locking also locks the vault", "disposing the container wipes the key"; `field_cipher_test` "destroy zero-fills…" |
| §9.2 Reveal and copy need fresh auth if older than 30 s | ✅ | `vault_session_test` "fresh auth is needed after 30 s"; `vault_items_ui_test` "reveal within 30 s of unlock needs nothing more; after that the master password" |
| §9.2 Locked vault shows no content, also on deep routes | ✅ | `vault_setup_unlock_test` "a locked vault on a deep route shows the unlock screen, not the item"; `vault_items_ui_test` "locking drops the revealed value and shows the unlock screen" |
| §9.2 Clipboard: cleared after 30 s where supported, marked sensitive, UI doesn't over-promise | ✅ Dart side, ⚠️ native side not run | `secret_clipboard_test`: "copy sends the text, a fresh plm- label and 30 000 ms, and logs nothing", fallback clears only if unchanged; `vault_items_ui_test` "copy password goes through the secret clipboard once and logs nothing" |
| §9.2 `FLAG_SECURE` on the whole app | ✅ by inspection | `MainActivity.kt` sets it on the window. No automated test (needs a device). |
| §9.2 Search runs only over non-secret fields | ✅ | `vault_items_repository_test` "search matches title, username, email and URL, folding Arabic; never the password"; `vault_items_ui_test` "search matches folded Arabic in usernames and never the password" |
| §9.2 Import from notes: local parser, no network, reviewed per item, reminder to delete the note | ✅ | `notes_parser_test` (labels in ar/ckb/en, limits); `no_network_test` "vault code has no network imports"; `vault_import_settings_test` "import: two blocks give two cards; dropping one saves one and shows the reminder" |
| §9.2 Logging redaction; vault types print no secrets; tests assert no secret in logs | ✅ | `vault_backup_test` "no vault secret reaches the log across the whole vault lifecycle"; `toString` tests: `field_cipher_test`, `key_wrap_test` "no wrap type prints secret material", `recovery_key_test`, `vault_items_repository_test` "VaultItemInput and VaultSecrets never print a secret", `notes_parser_test`, `password_generator_test` |
| §4 / §13 Vault never in plaintext columns, backups, exports, AI | ✅ | `vault_items_repository_test` "create and read back secrets; the row holds no plaintext secret"; `vault_backup_test` "the backup file and its plaintext database hold no vault secret"; `ai_payload_test` (vault marker never in the payload) |
| §13 Vault travels in backups and opens with the master password/recovery key on another phone; biometrics off | ✅ | `vault_backup_test`: "the vault survives backup and restore; fingerprint unlock is reset", "restoring a v2 backup gives an empty vault on schema 3", "a failing after-restore step is logged by type and the restore still completes"; migration v2→v3 in `test/core/db/migration_test.dart` |
| §9.2 "Use test passwords only until a security review has been done" | ⛔ owner's call | The setup screen shows a notice (`vltSetupTestFirst`); INSTALL.md repeats it |
| Layout robustness (320 dp, Sorani, 2× text) on every vault screen | ✅ | `test/ui/vault_worst_case_test.dart` |

## 6. Known limits (accepted, and why)

1. **Dart strings can't be wiped.** A decrypted password becomes an immutable `String` (`Sensitive<String>`), and the Flutter text engine, `TextEditingController`s and the platform channel make further copies. We zero every `Uint8List` we own (VDK, KEKs, plaintext buffers, the copy sent to the Keystore, recovery-key bytes) and drop references on lock, but garbage collection decides when string memory is overwritten. Anyone who can read the app's memory while it is unlocked can read revealed secrets. Spec §9.2 calls this best effort.
2. **The Argon2id password bytes cross into an isolate** (`Isolate.run`); that copy cannot be wiped either.
3. **The clipboard is not cleared if the process dies** within the 30 s (the clearing is a main-looper timer inside the app). Android 13+ hides sensitive clips from previews, but the foreground app and the default keyboard can still read a clip. The UI only promises "cleared after 30 seconds where Android allows it".
4. **Rooted phones / debuggers / malware with root:** out of scope (memory, Keystore usage and the clipboard can all be observed).
5. **Clock rollback:** the lockout compares against the device clock (`DateTime.now`). Someone who can change the system time can shorten a lockout. Cost per guess is still Argon2id. Not changed because a monotonic clock does not survive reboots.
6. **No duress/decoy mode** and no remote wipe. Wrong attempts never delete data (spec §9.1).
7. **Lost master password *and* recovery key = vault is unreadable.** By design. There is no vault erase in Phase 3 (Decision 10); a lost vault stays locked.
8. **Plain fields are not field-encrypted** (titles, URLs, usernames, emails): they rely on SQLCipher and the DB key. That's the trade-off that allows search (Decision 4). Don't put secrets in titles or usernames.
9. **Weak master password:** only length ≥ 10 is enforced. Offline guessing of a short, common password is feasible even at m = 64 MiB. A strength hint is shown; use a long passphrase.
10. **Unlocked-vault edits:** deleting an item doesn't ask for fresh auth (only reveal, copy and edit do).
11. **Backup restore keeps the failure counter** (it lives in secure storage, not in the DB), so a restore right after many wrong attempts can show a lockout of up to an hour.

## 7. Not verified on a device (no phone was connected)

Everything below is covered by Dart tests against fakes or by code reading only. Please run these on the phone before trusting the vault with real data:

1. **Biometric Keystore key** (`VaultChannel.kt`): turning fingerprint unlock on, unlocking with it, the prompt text, the 30 s fresh-auth re-prompt, and that the device PIN is *not* accepted for this key.
2. **Invalidation on a new fingerprint:** add a fingerprint in Android settings, then open the vault: expect the "fingerprint changed, use your password" message, the master password works, and fingerprint unlock can be turned on again. Also test API-level differences if the phone is older than Android 11 (validity −1 path).
3. **Clipboard clear on Android 13+:** copy a password, wait 30 s, paste somewhere: expect empty. Check the "sensitive" preview hiding on Android 13+, and that copying something else within 30 s is not wiped.
4. **Argon2id timing on the phone:** setup should take roughly 0.5–1 s. Pure-Dart Argon2id at m = 64 MiB, t = 3 was never timed on a phone; if setup/unlock feels slow (> 2 s) or runs out of memory, report it. The out-of-memory fallback has only been tested with a fake.
5. **`FLAG_SECURE`:** screenshots blocked and recents thumbnail blank on the vault screens.
6. **App-hidden lock:** switching apps locks the vault at once (tested with lifecycle events, not a real task switch).
7. **A real backup → restore round trip** on the phone with a vault in it, including restoring onto a freshly installed app.
8. **Keyboard behaviour:** that the keyboard you use respects the "no suggestions / no personalised learning" flags on the password field.

## 8. Decisions you should look at first

1. **Decision 10 — no vault erase.** Lost master password + recovery key means a permanently locked vault.
2. **Decision 4 — which fields are encrypted.** Titles, URLs, usernames and emails are plain (SQLCipher only), so search works.
3. **Decision 12 — device PIN does not unlock the vault.** Only a strong biometric or the master password do; on a phone with no strong biometric the vault is password-only.
4. **Decision 13 / 14 — 2 min auto-lock and a 30 s fresh-auth window** (reveal/copy/edit). Both are changeable in vault settings (auto-lock) or in code (30 s).
5. **Decision 6 — master password rule:** length ≥ 10 only; a long passphrase is recommended.
6. **Decision 1 — fingerprint is not in backups:** after every restore, turn fingerprint unlock on again.

---

## Appendix — second-pass code review (fresh read of the code listed above)

Method: re-read every file in `lib/features/vault/`, `lib/core/crypto/`, `VaultChannel.kt` and the backup diff, looking for ways to unlock wrongly, leak a secret, fail to lock, or crash on hostile data. Findings are ordered by importance. Each fix has a test.

| # | Severity | Finding | Fix | Test |
|---|---|---|---|---|
| A1 | Medium | A restored (or corrupted) vault row could request up to **1 GiB** of Argon2id memory (`checkVaultKdf` allowed m ≤ 1024 MiB). On a phone that is an out-of-memory kill during unlock — a denial of service by a crafted backup. Real wraps only ever use 19–64 MiB. | Cap at 256 MiB. | `key_wrap_test`: "checkVaultKdf … refuses extremes" now includes 512 MiB |
| A2 | Medium | Android's biometric **lockout** (too many wrong fingers) was mapped to `VaultLockedOut(Duration.zero)`, which the unlock screen rendered as "Try again in 0:00" with a zero countdown — a dead end that hides the password route. | Map `lockout` to `VaultBiometricUnavailable`, which falls back to the master password silently. | `biometric_key_store_test`: "platform error codes become typed vault errors" (`lockout` → unavailable) |
| A3 | Low | `enableBiometric` copied the VDK into a new `Uint8List` for the platform call and never wiped that copy. | Zero-fill the copy in `finally`. | `vault_biometric_test`: "the key copy handed to the Keystore is wiped afterwards" |
| A4 | Low | `KeyWrapper._open` left a wrongly sized plaintext un-zeroed before throwing `VaultCorrupt`. | Zero-fill before throwing. | Covered by the existing wrap tests (no behaviour change) |
| A5 | Low (UI) | Vault import's **Save** button sat in the app bar and overflowed at 320 dp, Sorani, 2× text (found by the Task 13 worst-case test). | Moved to a bottom bar. | `vault_worst_case_test`: "import with 50 proposals" (1× and 2×) |

Reviewed and found sound (no change): AAD binding of fields/wraps/check; the uid-not-rowid identity; constant-time key comparison; throttle fail-closed on a damaged record; every unlock path ends in the key check; biometric wrap tagged by `vaultId` so a restore can't reuse it; clipboard label check (a later copy of something else is not wiped); `FLAG_SECURE`; `allowBackup=false` so the secure-storage wraps never go to Auto Backup; Kotlin error codes carry no messages; all `AppLogger` calls in vault code pass the error object (a type name or `StateError` text, never user input); `VaultSession` zero-fills on lock, on a second unlock and on provider disposal.

Not changed, listed in section 6: clock rollback (L5), delete without fresh auth (L10), throttle counter surviving a restore (L11), a possible race if two unlock attempts run at once (the unlock screen disables the button while one is running).
