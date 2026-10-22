# My Personal Life Manager — Design

Date: 2026-10-22
Status: Draft for owner approval

## 1. Intent

A private Android app for one person (the owner) who runs a personal life plus two businesses (Buzzify and Related/EO). Today money lives in an Excel file at home and tasks and passwords live in the phone's notes app. Three things hurt:

1. **Money gets recorded late or not at all.** The spreadsheet is only reachable at home, and typing rows is tedious. The owner does not want a daily data-entry ritual. They want to record a spend or an income **the moment it happens, from the phone, by speaking one sentence**.
2. **Tasks get lost.** The work is spread across many clients and details, and tasks arrive from everywhere: WhatsApp, meetings, calls, and thoughts during the day.
3. **Passwords get lost.** They sit unprotected in phone notes, and important ones have been lost many times.

Success: the owner stops using Excel and phone notes for money, tasks and passwords. Capturing anything takes a few seconds, and at the end of the month the charts show the whole picture.

The original master spec (pasted by the owner, restated in the session brief) remains the baseline for entities, screens, finance rules, tasks, vault, reminders, search, backup, settings and tests. This document records **what changed or was decided on top of it**, and how the app is built.

## 2. Goals

- Voice- and sentence-first capture for finance entries and tasks. A one-tap mic is always reachable.
- Correct, deterministic money tracking across six cash accounts in IQD and USD, with a manual exchange rate.
- A money-management layer: income split into owner-defined buckets (expenses / emergency / investment), with alerts.
- Comprehensive charts.
- A secure password vault with biometric unlock and a recovery key.
- Tasks that capture from anywhere (voice, share from WhatsApp or other apps, meeting notes), with reliable reminders.
- A "Future Projects" space where the owner writes project ideas and an AI assistant helps plan them.
- Encrypted backup the owner can save anywhere.
- Arabic (default), English and Kurdish Sorani, with correct RTL.

## 3. Non-goals

- iOS, web, desktop.
- Multi-user, accounts, sync, any server of our own.
- Subscriptions, payments, analytics, crash reporting, telemetry.
- Investment advice. The app never suggests where to invest; it only tracks the owner's own allocations and reminds them.
- Automatic cloud backup.

## 4. Anti-goals (failure even if it "works")

- Capture feels like a chore. If recording a spend takes more than a few seconds or several screens, the product failed.
- Any data loss: a crash mid-write, a bad restore, a migration that drops rows.
- Any vault secret leaving the device, appearing in logs, prefs, plaintext DB columns, exports or AI requests.
- AI requests carrying more data than the owner was told about.
- Anything from Google (see constraints).

## 5. Constraints (owner decisions)

- **No Google, at all.** No Firebase, no Google Play Services APIs (ML Kit, Google Sign-In, Android `SpeechRecognizer` — which is backed by Google on most phones), no Gemini, no Google Drive, no fonts fetched from Google at runtime. Open-source code and font files bundled in the APK are fine. AndroidX libraries (BiometricPrompt, WorkManager) are fine: they are part of the platform toolchain, not a Google service.
- **Free only.** No paid APIs or services.
- **Online AI is allowed** for capture and planning (this overrides the original "never needs the internet" rule for these features only). Everything else works fully offline, and capture degrades gracefully offline (§8.4).
- **App size does not matter** to the owner.
- Personal phone only; release APK sideloaded.

## 6. Tech stack (builder's call unless marked)

- Flutter 3.47.7 stable / Dart 3.13 (installed on this machine under `C:\Users\pc\dev\flutter`), JDK 21 (Temurin), Android SDK in `%LOCALAPPDATA%\Android\Sdk`.
- Android only. `minSdk 26`, target/compile the latest SDK Flutter 3.47 supports. *(My call; Android 8+ covers any phone still in use.)*
- State management and DI: Riverpod. *(My call.)*
- Persistence: Drift on SQLite **with SQLCipher** (`sqlcipher_flutter_libs`). The whole database file is encrypted with a random 256-bit key stored via Android Keystore-backed secure storage. Vault secret fields are additionally encrypted with the Vault Data Key (§9). Foreign keys ON, migrations versioned and tested. *(My call: protects finance data on a lost or rooted phone at negligible cost.)*
- Charts: `fl_chart`.
- Notifications: `flutter_local_notifications` plus `timezone`.
- Biometrics: a crypto-bound Keystore approach (a key with `setUserAuthenticationRequired`, unlocked via BiometricPrompt), not a boolean `local_auth` gate. `local_auth` may be used for the prompt UI only if the key itself is auth-bound.
- Crypto: libsodium through `sodium_libs` for Argon2id; AES-256-GCM through the platform (`cryptography` + `cryptography_flutter`) or libsodium. No hand-rolled primitives.
- Share target: `receive_sharing_intent` (or equivalent) for text shared from WhatsApp and other apps.
- On-device speech: whisper.cpp through a maintained Flutter FFI plugin, or our own thin FFI binding.
- HTTP: `dio` or `http`, used only by the AI module.
- PDF: `pdf` package. CSV: hand-written exporter.
- Font: bundle a font with full Arabic **and Kurdish Sorani** glyph coverage (ڕ ڵ ێ ۆ ڤ ە). Vazirmatn is a good candidate; the builder verifies coverage.
- Flutter's `GlobalMaterialLocalizations` has no `ckb` locale. Provide a fallback delegate (Arabic material strings, RTL) for Kurdish.

## 7. Information architecture

Bottom navigation (RTL-aware): **Home · Finance · [Mic FAB] · Tasks · Vault**. Settings opens from the Home app bar. *(My call: the approved mockup puts the mic in the centre of the nav. With five tabs plus a FAB it becomes too crowded, so Settings moves to the top bar.)*

The FAB is a **mic button**. Tap = record. Long-press = a type-a-sentence sheet. Plus a small "+" menu for manual forms (transaction, transfer, task, vault item, note).

**Home (approved layout "B — full dashboard"):** month income / expense / surplus tiles, an income-vs-expense chart for the last 6 months, bucket progress bars, task summary (overdue / today), upcoming payments and reminders, workspace activity, and consolidated balance. Cards are reorderable and hideable. Vault content never appears here.

All 24 screens from the original spec remain, plus:
- **Capture Review** (shared by voice, typed sentence and share-intent)
- **Inbox / To Sort** (unparsed drafts and quick captures)
- **Buckets** (allocation rules and progress)
- **Future Projects** list and **Project Detail** with AI assistant
- **Vault Import from Notes**
- **Meeting Notes** (in the original spec, made explicit as a screen)

## 8. Capture (the heart of the app)

### 8.1 Flow

1. The owner taps the mic and speaks, in any language or a mix (Arabic, Kurdish Sorani, English, numbers, client names).
2. Speech → text (§8.2).
3. Text → structured intent (§8.3): one or more of `expense`, `income`, `transfer`, `task`, `debt_payment`, `note`.
4. **Capture Review** shows the transcript and the pre-filled form(s). The owner edits anything and taps Save. Nothing is ever saved without this review.
5. If parsing fails or no network is available, the capture is stored as an **Inbox draft** (transcript and optionally audio) and is never lost.

### 8.2 Speech to text

- **Online:** Groq's hosted Whisper model (the model name is configurable in Settings because Groq's catalogue changes).
- **Offline:** whisper.cpp on device with a multilingual model (default `small`; `base` selectable). The model is downloaded once from inside the app (checksum pinned) or bundled; builder's call. *(Owner: size does not matter.)*
- Kurdish Sorani is not officially supported by Whisper. Accuracy will be weaker, which is one reason the review step exists. The owner has been told.

### 8.3 Text to intent

- **Online:** a Groq-hosted LLM in JSON mode with a strict schema. The prompt includes **only**: the transcript, today's date and time zone, and the *names* of accounts, workspaces, categories, projects and buckets. **Never** balances, transaction history, task contents beyond the transcript, or anything from the vault.
- **Offline / fallback:** a local rule-based parser:
  - Arabic-Indic and Western digits; multipliers (ألف, مليون, k, thousand); and currency words (دينار، دولار، $، IQD، USD).
  - Category keyword dictionaries in all three languages, editable per category.
  - Workspace names and aliases; relative dates (اليوم، باجر/غداً، tomorrow, at 11).
  - Rules: no workspace means Personal; a currency picks the matching account of that workspace.
- The LLM's output is validated against the schema and against existing IDs. Invalid output falls back to the rule parser's result, then to an Inbox draft.

### 8.4 Offline behaviour

Capture always works. Offline it uses on-device Whisper plus the rule parser. If confidence is low, an Inbox draft is created, and the app offers "finish with AI" once online. The owner can always fall back to manual forms.

### 8.5 Share from other apps

The app is registered as an Android share target for `text/plain`. Shared text, for example a WhatsApp message from a client, goes through §8.3, which can propose **multiple** tasks. The review lets the owner keep, edit or drop each one.

### 8.6 Meeting notes

A Meeting Note is free text, voice or typed, linked to a workspace or project. An "Extract action points" button runs §8.3 in task mode and lists proposed tasks to convert with one tap.

### 8.7 Consent and disclosure

The first use of each online AI feature (voice, text parsing, share, projects assistant) shows a one-time sheet stating exactly what is sent and to whom (Groq). Settings shows the same text and lets the owner disable online AI entirely, in which case everything uses the offline path.

## 9. Security and vault

### 9.1 Key hierarchy

- **DB key:** a random 256-bit key used for SQLCipher, stored in Keystore-backed secure storage. Released without user auth, because the app lock is a UX gate. Vault secrets have their own layer.
- **Vault Data Key (VDK):** a random 256-bit key. It encrypts every secret vault field (password, recovery codes, secure notes, secure attachments) with AES-256-GCM, using a unique nonce per field and the item ID plus field name as associated data.
- The VDK is stored only **wrapped**, three ways:
  1. With a KEK from the **master password** via Argon2id. Starting parameters: m = 64 MiB, t = 3, p = 1, 16-byte salt. Calibrate on the owner's phone to about 0.5–1 s and store the parameters with the wrap. If the device cannot allocate 64 MiB, fall back to OWASP's minimum (m = 19 MiB, t = 2).
  2. With a KEK from the **recovery key**: 160 random bits shown once as grouped Base32 (e.g. `XXXX-XXXX-…`). HKDF-SHA256 is enough because of its entropy. The owner must type it back to confirm before vault setup completes. The recovery key itself is never stored.
  3. With a **biometric-bound Keystore key** (auth required on every use, invalidated on biometric enrolment change). If it is invalidated, the owner unlocks with the master password, and biometrics are re-enrolled.
- Wrong master password: the GCM tag fails, a generic error is shown, and attempts are rate-limited with exponential backoff. Data is never deleted.

### 9.2 Behaviour

- Auto-lock after a configurable idle time (default 2 minutes) and on app background. The VDK is zeroed from memory on lock where Dart allows. Best effort; documented.
- Reveal and copy require a fresh auth if the last auth is older than 30 s.
- Copied secrets: clear the clipboard after 30 s where supported, and mark the clip sensitive (`ClipDescription.EXTRA_IS_SENSITIVE`, Android 13+). The UI copy does not promise clearing works on every Android version.
- `FLAG_SECURE` on the whole app (blocks screenshots and recents thumbnails). *(My call: finance data is sensitive too.)*
- Vault search runs only inside the unlocked vault, over non-secret fields (site, URL, username, email, category, workspace).
- **Import from Notes:** the owner pastes text, and a local heuristic parser (no AI, no network) splits it into proposed items. The owner reviews and saves each, and the app reminds them to delete the original note themselves.
- Logging: a logger with a redaction layer. Vault types do not implement `toString` with secrets. Tests assert that no secret appears in log output.
- Use test passwords only until a security review has been done (original spec).

## 10. Finance

### 10.1 Accounts and currencies

Seeded at initial setup (editable, more can be added):

| Workspace | IQD | USD |
|---|---|---|
| Personal | Personal Cash IQD | Personal Cash USD |
| Buzzify | Buzzify Cash IQD | Buzzify Cash USD |
| Related / EO | EO Cash IQD | EO Cash USD |

The owner keeps business money separate from personal money. Other account types (bank, savings, custom) and currencies remain available but are not seeded.

### 10.2 Money math

- Amounts are stored as **integer minor units** (`int64`) plus a currency code. Minor-unit exponent: IQD = 0, USD = 2, others per ISO 4217.
- The exchange rate is stored as an integer-scaled decimal (rate × 10⁶) with an effective-from date. History is kept so old reports stay reproducible.
- Conversion: `minor_out = round_half_even(minor_in × rate × 10^(exp_out − exp_in) / 10⁶)`, computed with `BigInt` or `Decimal`, never `double`.
- Every consolidated figure has a "how converted" affordance that shows the rate, its date and the per-currency subtotals.
- Transfers between accounts, including IQD↔USD exchanges, are never income or expense. A cross-currency transfer records both legs and the rate used.
- Moving money from a business workspace to Personal is a transfer, unless the owner tags it as salary or owner draw. A draw is an expense for the business and income for Personal. *(My call, matching how the owner described keeping money separate.)*

### 10.3 Buckets (money management)

- Three default buckets: **Expenses, Emergency, Investment.** The owner sets percentages manually; they must sum to 100%. The app never suggests numbers.
- Percentage changes apply only to income recorded after the change. Past allocations are immutable.
- Each bucket has an optional target, for example an emergency-fund target amount.
- **Buckets are numbers only (owner decision).** They are virtual envelopes tracked by the app; the money physically stays in the owner's cash accounts, and no transfers are created.
- **Allocation is manual per income (owner decision).** On any income in any workspace, Capture Review and the income form have an "Allocate to buckets" toggle. When the owner turns it on, the default percentages pre-fill the split and the owner can adjust it before saving. Income saved without allocation is simply not counted in buckets. Turning the toggle on is not prompted, so nothing nags. *(My call: since allocation is manual, the "unallocated income" alert below applies only if the owner enables it in Settings; off by default.)*
- Bucket figures are kept in a base currency (IQD by default, configurable), converted with the rate in effect on the income date; the conversion is shown. The Expenses bucket resets each calendar month. Emergency and Investment carry over. Spending from Emergency or Investment is recorded by tagging an expense or withdrawal with that bucket.
- Alerts (notification and Home card):
  - Expense spending reaches 80% and 100% of the Expenses bucket for the month.
  - (Optional, off by default) Income was saved without allocation.
  - The emergency bucket reaches its target, or drops below it after a withdrawal.
### 10.3a Excel import (owner decision: yes)

The owner's historical transactions live in an Excel file, and they want them imported so charts and reports have history from day one.
- Import `.xlsx` and `.csv` from the system file picker, fully on-device. No AI is involved.
- Steps:
  1. Pick a sheet and the header row.
  2. Map columns to date, amount, currency, type, category, workspace, account and description. Unmapped values get defaults chosen in the wizard.
  3. Map distinct category and workspace values to existing ones, or create new ones.
  4. Preview the first rows, then import.
- Imported rows carry an `import_batch_id`, so one batch can be undone in full. Imports are idempotent: the same rows imported twice are flagged as duplicates by date, amount and description.
- Opening balances: after import, the wizard compares the computed balance per account with the owner's actual cash today and offers a balance-adjustment transaction for the difference.
- The exact layout of the owner's sheet is unknown. The builder asks the owner for a sample file, which can be anonymised, before building the mapping defaults. The wizard must work with any reasonable layout regardless.
- This lands in Phase 2.

### 10.4 Everything else

As in the original spec: transaction types, the categories list, debts and installments with partial payments, monthly budgets per category and workspace, reports (daily/weekly/monthly, income vs expense, by category, by workspace, cash flow, outstanding debts) and CSV/PDF export. Charts cover all report dimensions, plus balance over time and bucket progress.

## 11. Tasks and reminders

As in the original spec: fields, statuses, priorities, views (Today, Tomorrow, This Week, Upcoming, Overdue, Completed, By Workspace, By Priority, Calendar), recurrence and subtasks. Additions:

- An **Inbox** view for quick captures without a due date or workspace. *(My call.)*
- Capture via voice, share-intent and meeting notes (§8).
- Reminders:
  - Exact alarms with `SCHEDULE_EXACT_ALARM`, a user permission flow, and a fallback to inexact alarms with an in-app warning. `POST_NOTIFICATIONS` is requested at runtime.
  - Reschedule on `BOOT_COMPLETED`, `TIMEZONE_CHANGED`, `TIME_SET` and `MY_PACKAGE_REPLACED`.
  - Notification actions: Done, Snooze (10 min / 1 h / tomorrow), and Open.
  - Overdue task reminders re-notify until the task is completed or snoozed. *(The owner said things slip; "persistent until handled" is my call.)*

Seeded workspaces and their default project/tag sets come from the original spec (Buzzify, Related/EO, Personal, Other Projects).

## 12. Future Projects

- A list of project ideas. Each has a title, description, estimated cost and currency, a target date, status (idea / planning / active / done / dropped), free-form notes, and a step checklist that can be converted into Tasks.
- **AI assistant:** a chat panel per project. Requests include only that project's text and, if the owner toggles it, the investment bucket's current amount and monthly allocation, so the AI can estimate saving time. The toggle is off by default and its sent payload is shown. The AI never gives investment advice; the system prompt forbids it.
- Distinct from the original spec's "Projects" entity, which groups tasks inside a workspace. A Future Project can later be "promoted" into a workspace project.

## 13. Backup and restore

- One file, `*.plmbackup`. Header (plaintext): magic, format version, DB schema version, app version, creation time (UTC), KDF parameters, salt, nonce. Body: AES-256-GCM over a zip of the DB export and attachments. The key comes from the **backup password** via Argon2id. The GCM tag provides integrity, and a SHA-256 manifest of entries is checked after decryption.
- Vault fields stay encrypted with the VDK inside the backup. The wrapped VDK blobs (master-password and recovery-key wraps, not the biometric one) are included. Restoring therefore needs the backup password, and the master password or recovery key to open the vault.
- Export goes through the Android system file picker or the share sheet. The owner chooses: laptop, USB, a messenger, anywhere.
- Restore:
  1. Pick the file, then read and validate the header.
  2. Refuse a newer format or schema version with a clear message.
  3. Decrypt into a temp dir, verify the manifest, and migrate if the schema is older.
  4. Swap atomically, keeping the previous DB until the app reopens successfully, so it can roll back.
- A reminder to back up runs weekly by default (configurable). Settings and first-run onboarding warn plainly that losing the phone or uninstalling without a backup loses everything.

## 14. Phasing

Each phase ends with a tested, installable release APK.

1. **Foundation:** project setup, signing, theme (dark default, light optional), i18n with RTL in all three languages, encrypted DB and migrations, app lock and biometrics, Settings shell, initial setup (seeded workspaces and accounts), encrypted backup and restore.
2. **Finance and capture:** accounts, transactions, transfers, exchange rates, buckets and alerts, Excel import, budgets, debts and installments, reports and charts, CSV/PDF export, the full capture pipeline (online Groq plus offline Whisper and rule parser), Capture Review, and Inbox.
3. **Vault:** key hierarchy, CRUD, generator, recovery key, import from notes, clipboard handling.
4. **Tasks:** full task model and views, calendar, reminders, share-intent, meeting notes and action points.
5. **Home and Reminders:** the full Home dashboard (layout B, customizable), the Reminders screen, universal search.
6. **Future Projects** with the AI assistant.

## 15. Builder-check decisions

- **App lock** (my call): On by default. Unlock with biometrics or the device credential through BiometricPrompt (`BIOMETRIC_STRONG | DEVICE_CREDENTIAL`). Fallback is a 6-digit app PIN set at initial setup, hashed with Argon2id. It is separate from the vault master password. The app relocks after 5 minutes in the background (configurable).
- **Translations** (my call): The builder writes the English source strings and drafts of the Arabic and Kurdish Sorani strings, plus the parser keyword dictionaries. The Sorani UI is labelled draft quality until the owner has reviewed it. Settings has a "report wrong wording" note field that stores feedback locally. The keyword dictionaries are editable in-app per category.
- **Groq key** (my call): The owner creates a free Groq account and pastes the key into Settings → AI. The key is stored in Keystore-backed secure storage and is never logged or exported in plaintext. It is included in backups only inside the encrypted body. With no key set, the app runs entirely on the offline path.
- **Vault security review** (my call): Before Phase 3 is called done, the builder produces a written self-review checklist covering §9, threat model, crypto parameters, log and backup leakage tests, and clipboard. A separate code-review pass then runs on the vault and crypto code. Moving real passwords in is the owner's decision after reading that review.

## 16. Owner answers from the builder check

- Buckets: manual allocation per income, and numbers only (§10.3).
- Excel history: yes, import it (§10.3a).

## 17. Left to the builder

Folder structure, package versions, exact widget design within the approved direction (layout B, dark midnight/navy, electric-blue accent, rounded cards, subtle motion), the rule parser's internals, chart styling, PDF layout, the Whisper plugin choice, and the test harness. Tests cover every item in the original spec's test list, plus capture parsing, bucket allocation, the backup round-trip and AI payload contents (asserting nothing beyond §8.3 is sent).

## Appendix A — Original master spec (baseline)

Restated from the owner's master spec. Where this appendix conflicts with §1–§17, the sections above win. The main overrides: online AI is allowed for capture and planning, nothing from Google, and the accounts and buckets in §10.

**Product:** A private, offline-first Android app for the owner's personal phone only. Not SaaS: no subscriptions, payments, multi-user setup, Firebase or paid cloud services, and no analytics.

**Tech:**
- Flutter for Android; SQLite through Drift with migrations and referential integrity.
- Android Keystore; audited crypto only (Argon2id KDF with reviewed mobile parameters, AES-256-GCM).
- flutter_local_notifications with current Android scheduling: exact alarms and permissions, rescheduled on reboot and time-zone change.
- Biometric auth; encrypted backup and restore.

**UI:**
- Premium, minimal design. Dark by default (midnight black and deep navy, white text, electric-blue accents) with an optional light mode.
- Rounded cards, good charts, smooth subtle motion.
- English, Arabic and Kurdish Sorani, with correct RTL.
- Bottom nav: Home, Finance, Tasks, Vault, Settings, plus a floating Quick Add (§7 adjusts this).

**Home dashboard:**
- Total balances; monthly income, expenses and surplus.
- Upcoming payments; overdue tasks and tasks due today.
- Workspace activity and reminders.
- A monthly finance chart and a task completion summary.
- Customizable widgets. Never shows vault contents.

**Finance**
- **Accounts:** Personal Cash/Bank, Business Cash/Bank, Savings, custom. IQD, USD and more. Per-account balances, plus a consolidated view using a manual exchange rate that always shows how amounts were converted.
- **Income:**
  - Types: salary, business, freelance, client payments, other.
  - Fields: amount, currency, account, category, date, description, workspace, optional attachment, payment status.
- **Expense categories:** food, transport, rent, bills, family, shopping, health, business, marketing, subscriptions, custom. Each can link to a workspace or project.
- **Transaction types:** income, expense, transfer, balance adjustment, refund, debt payment. Transfers are never income or expense.
- **Debts and installments:** owed to me and owed by me; due dates, partial payments, remaining balance, reminders.
- **Monthly budgets** per category and per workspace: budget, actual, remaining, percent used.
- **Reports:** daily, weekly and monthly expenses; income vs expenses; spending by category and by workspace; cash flow; outstanding debts. Export as CSV and PDF.
- **Money math** is deterministic with proper decimal precision. No floating point.

**Workspaces:** unlimited and fully editable. Each has a name, icon, color, description, notes and reports, plus linked tasks, transactions and accounts. Seeded:
- **Buzzify:** clients, marketing, design, video, invoices, payments, proposals, meetings
- **Related / EO:** partner follow-ups, SMS campaigns, marketing, meetings, reports, operations, deadlines
- **Personal**
- **Other Projects**

**Tasks**
- **Fields:** title, description, workspace, project, priority, status, created date, due date and time, reminder, recurrence, tags, notes, attachments, subtasks.
  - Priority: Low, Medium, High, Urgent.
  - Status: To Do, In Progress, Waiting, Completed, Cancelled.
- **Views:** Today, Tomorrow, This Week, Upcoming, Overdue, Completed, By Workspace, By Priority, Calendar.
- **Quick entry** such as "Call the client tomorrow at 11 AM", via a local rule-based parser. AI is optional (§8 extends this).
- **Meeting notes** whose action points convert into tasks.

**Vault**
- **Item fields:** site name, URL, email, username, password, workspace, category, notes, recovery codes, optional secure attachments.
- **Categories:** Personal, Business, Social Media, Banking, Hosting, Domain, Email, Marketing Tools, Dev Tools, Other.
- **Features:** search, filter, sort, CRUD, password generator, copy username/password, show/hide, auto-lock, biometric and master-password unlock, encrypted backup.
- **Security rules:**
  - Never hardcode keys.
  - Never store raw secrets in SQLite, prefs, logs, crash reports or backups.
  - Never send vault data to AI or cloud.
  - Clear the clipboard where supported, without promising it works on every Android version.
  - FLAG_SECURE, and hide the app in recents.
  - Require auth before revealing or copying a secret.
  - Use test passwords only until a security review is done.

**Reminders:** tasks, recurring items, bills, installments, follow-ups, meetings, subscription renewals and appointments. Snooze, repeat and dismiss, plus completing a task from the notification where supported.

**Search:** universal search across transactions, tasks, workspaces, notes, projects and account names. Vault search stays inside the unlocked vault and never exposes passwords.

**AI:** architecture plus a Settings area to configure a provider. No hardcoded key. Tell the owner before any personal or financial data is sent. Never send vault data.

**Backup:**
- An encrypted, password-protected full backup, exported manually to a location the owner chooses and imported manually.
- Integrity verification, safe restore, version compatibility and the creation date.
- No automatic cloud upload.
- A warning that uninstalling or losing the phone without a backup loses the data.

**Settings:** language, theme, currency, exchange rate, notifications, app lock, biometrics, backup/restore, export, workspace and category management, privacy, AI config.

**Entities:** Workspaces, Projects, Tasks, Subtasks, TaskReminders, Accounts, Transactions, TransactionCategories, Budgets, Debts, DebtPayments, Installments, PasswordVaultItems, VaultCategories, Notes, Attachments, RecurringPayments, AppSettings, BackupMetadata.

**Screens (24), all wired to persistent data:** Splash, Initial Setup, Home, Finance Overview, Accounts, Add Transaction, Transaction History, Budgets, Debts & Installments, Finance Reports, Workspace List, Workspace Dashboard, Task List, Add/Edit Task, Task Detail, Calendar, Vault Login, Vault List, Add/Edit Vault Item, Vault Item Detail, Reminders, Search, Backup & Restore, Settings.

**Tests:**
- **Finance:** IQD/USD math, conversion, transaction CRUD, transfers, budgets, debt repayment.
- **Tasks and reminders:** recurrence, notification scheduling, workspace filtering.
- **Vault:** encrypt/decrypt, wrong master password, biometric flow.
- **Persistence and backup:** data persistence, backup export and restore, app restart, migrations, offline use.
- **RTL layouts.**
- **Privacy:** no sensitive data in logs or unencrypted exports.

**Deliverables:**
- Complete source, project structure, dependencies, DB, screens, vault, notifications, backup, tests and Android build config.
- A release APK and install instructions.
- Release signing uses a private keystore kept out of git; never commit keys or passwords.
- If the APK cannot be compiled, provide the exact build commands. Never claim an APK was built unless the build succeeded.
