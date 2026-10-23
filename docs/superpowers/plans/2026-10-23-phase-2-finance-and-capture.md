# Phase 2 — Finance and Capture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A signed release APK in which the owner records money the moment it happens, by speaking or typing one sentence, and sees the whole picture in charts. Concretely:
- accounts, transactions, transfers (including IQD↔USD exchange and owner draws) and exchange rates
- buckets with manual allocation per income, plus alerts
- monthly budgets, debts and installments
- reports and charts, with CSV and PDF export
- Excel/CSV history import with undo and opening-balance adjustment
- the full capture pipeline: Groq online (Whisper + LLM) and offline (on-device Whisper + rule parser), Capture Review and the Inbox

**Architecture:**
- Same layout as Phase 1: `lib/core/` for shared building blocks, `lib/features/<feature>/` split into `data/` (Drift repositories), `domain/` (pure Dart, no Flutter, no DB) and `ui/`.
- All money math lives in `lib/core/money/` on `int` minor units and `BigInt` intermediates. Domain functions take plain value objects, so reports, buckets, alerts and the parsers are host-testable without a database.
- Capture is a pipeline of small interfaces (`AudioRecorderPort`, `SpeechToText`, `IntentParser`), each with an online (Groq) and an offline implementation. A capture row is written to the encrypted DB **before** any network call, so nothing is lost.
- Schema goes from v1 to v2 in one tested Drift migration.

**Tech Stack:**
- From Phase 1: Flutter 3.47.7 / Dart 3.13, Riverpod, go_router, Drift over SQLCipher (sqlite3 build hook), `cryptography`, flutter_secure_storage, file_picker, archive, crypto, intl.
- New: `fl_chart` (charts), `pdf` (PDF export), `xml` (xlsx reader), `http` (Groq only), `record` (microphone, WAV 16 kHz mono), `whisper_ggml` (whisper.cpp on device).

**Spec:** `docs/superpowers/specs/2026-10-22-personal-life-manager-design.md`. Read §4, §5, §7, §8 (all), §10 (all), §14 phase 2, §15, §17, and Appendix A (Finance, Settings, AI, Tests). Phase 1 plan and ledger: `docs/superpowers/plans/2026-10-22-phase-1-foundation.md`, `.superpowers/sdd/2026-10-22-phase-1-foundation/progress.md` (rulings there still hold: `DartArgon2idKdf`, SQLCipher via the sqlite3 hook, `flutter_lints`).

## Decisions taken for this plan (builder's calls; the owner skipped the questions)

1. One plan for all of spec §14 phase 2, in two parts: **A — Finance** (Tasks 1–14) and **B — Capture** (Tasks 15–20), then integration and release (Tasks 21–22). One release APK at the end.
2. Alerts (buckets, budgets, debts) are **in-app** in Phase 2: a Home card and a Finance banner. System notifications come with the notification and reminder stack in Phase 4.
3. `task` and `note` intents are parsed and kept as **Inbox drafts** until Tasks (Phase 4) and Notes exist. The Inbox says where they will go.
4. Transaction attachments, recurring payments and "upcoming payments" are out of scope; they arrive with Phases 4 and 5.
5. Debt principal and repayments are `debt_payment` transactions with a `debtLeg` of `principal` or `repayment`. They move cash but are never income or expense. The spec's `DebtPayments` entity is these rows.
6. An owner draw is a transfer row with `transferKind = 'owner_draw'`. Reports count it as an expense of the source workspace and income of the target workspace (spec §10.2).
7. Buckets count spending only from workspaces flagged `countsInBuckets` (seeded: Personal only), so business expenses don't eat the personal Expenses bucket. Allocation itself is available on income in any workspace (spec §10.3).
8. A split may allocate less than the whole income; the rest is shown as "unallocated". It can never exceed the income.
9. No exchange rate is seeded. Until the owner sets one, consolidated figures are hidden behind "set a rate" and per-currency subtotals are shown instead. Wrong numbers are worse than missing ones.
10. Week starts on Saturday (Iraq). Amounts are shown with Western digits in all locales (as Phase 1 did for Kurdish); Arabic-Indic digits are accepted wherever digits are typed or spoken.
11. Groq defaults: STT model `whisper-large-v3-turbo`, LLM model `llama-3.3-70b-versatile`, JSON mode `response_format: {"type":"json_object"}`. Both model names are editable in Settings → AI.
12. Offline Whisper uses `whisper_ggml` behind our own `SpeechToText` interface. Models are downloaded once inside the app from `huggingface.co/ggerganov/whisper.cpp` with a pinned SHA-256: `ggml-small.bin` (default) or `ggml-base.bin`.
13. Captured audio is stored as a BLOB inside the SQLCipher DB (max 120 s), never as a loose file. It is deleted once the capture is saved or discarded.
14. The Groq key lives in secure storage under `groq_api_key_v1`. Backups carry it only inside the encrypted body as payload entry `secrets/groq_api_key` (spec §15).
15. The xlsx reader is our own small reader on `archive` + `xml` (sheet XML, shared strings, styles for date cells). It reads numbers as their **decimal text**, never as `double`. CSV is a hand-written RFC 4180 reader.
16. Iraqi money slang in the rule parser, editable like other keywords: «ورقة» = 100 USD, «دفتر» = 10,000 USD, «ربع» / «نص» before ألف or مليون.
17. The owner's Excel layout is unknown. The wizard is generic; if the owner later shares an anonymised sample, it becomes a test fixture (see Next Steps).

## Global Constraints

- Everything in the Phase 1 Global Constraints still holds (no Google, no analytics, FLAG_SECURE, `minSdk 26`, applicationId `com.personal.lifemanager`, tokens, nav layout, default locale `ar`).
- **Money is never `double`.** Amounts are `int` minor units plus an ISO 4217 code. Exponents: IQD = 0, USD = 2, others per ISO 4217. Intermediate math uses `BigInt`. `double` is allowed only in chart widgets, converted from finished `int` results at the last step.
- Exchange rates are `rateE6` integers (rate × 10⁶) with an `effectiveFrom` date; history is kept. Conversion: `minor_out = round_half_even(minor_in × rate × 10^(exp_out − exp_in) / 10⁶)`, and the inverse for quote→base.
- Transfers, including IQD↔USD exchanges, are never income or expense (except owner draws, Decision 6). A cross-currency transfer stores both amounts and the rate used.
- Bucket percentages are basis points (1% = 100) and must sum to 10,000. Past allocations are immutable; percentage changes affect only income saved afterwards. The app never suggests percentages or investments.
- Nothing is saved from a capture without the Capture Review screen.
- **AI payload (spec §8.3):** only the transcript, the current local date-time and UTC offset, and the *names* of accounts, workspaces (with aliases), categories and buckets. Never balances, amounts from history, transaction descriptions, settings, or anything from the vault. Audio goes only to the STT endpoint.
- Online AI only after the one-time consent sheet for that feature (voice, text parsing), and only when online AI is enabled and a key is set. Otherwise the offline path runs, silently.
- Only host `api.groq.com` (AI) and `huggingface.co` (model download, with its CDN redirect) are contacted. No other network code.
- Logs carry error types only. Transcripts, amounts, descriptions, the Groq key and request/response bodies never reach a log.
- Every user-facing string goes into all three ARB files (`app_en.arb`, `app_ar.arb`, `app_ckb.arb`); the existing "every locale has every key" test enforces it. Sorani stays draft quality.
- UI tasks load `impeccable` first (Flutter: use its principles; the 21st tools are web-only, per the Phase 1 ruling). Charts load `dataviz`. Motion loads `animate`. Task 22 runs `break-ui` and `21st-ui-review`.
- `kAppVersion` and `pubspec.yaml` move to `1.1.0` / `1.1.0+2` in Task 22.

## Review Focus

1. **Amounts in every form the owner will speak or type:** Arabic-Indic digits, `٬` and `,` thousands separators, `٫` decimals, «خمسة وعشرين ألف», «ربع مليون», «25 ألف», «12.5 دولار», «ورقة». Expect exact minor units and the right currency, never a float artefact. Covered by Task 1 (`parseDecimalToMinor` tests) and Task 15 (`amount phrases` table test).
2. **Excel numbers and dates as Excel stores them:** `<v>1250000.0000000002</v>`, `<v>12.3</v>`, date serials (including the 1900 leap-year bug), and day-first text dates like `3/4/2024`. Expect exact minor units, the owner's day-first reading, and rows that can't be read flagged rather than guessed. Covered by Task 13 (`xlsx float artefact`, `date serial`, `day-first`).
3. **Network drops, Groq timeout, HTTP 401/429, or malformed LLM JSON in the middle of a capture.** Expect the capture row already in the DB (audio or transcript), a fallback to the offline path, and an Inbox draft if that also fails. Never a lost capture, never a crash. Covered by Task 19 (`pipeline fallbacks` tests).
4. **Editing or deleting a transaction that has bucket allocations, belongs to an import batch, is a transfer, or is a debt payment.** Expect balances, bucket totals and debt remaining to stay consistent. Covered by Task 3 (`edit and delete keep balances`) and Task 5 (`deleting income removes its allocations`).
5. **Restoring a Phase 1 (schema v1) backup into this app.** Expect the restore to succeed, migrate to v2 and keep every account and setting. Covered by Task 21 (`restores a v1 backup and migrates`).

---

## File Structure

```
lib/core/money/currency.dart, rounding.dart, money.dart, conversion.dart, amount_parse.dart, money_format.dart
lib/core/text/digits.dart                       # moved from features/lock (normalizeDigits) + normalizeForMatch
lib/core/db/finance_tables.dart, capture_tables.dart   # new tables; tables.dart keeps Phase 1 tables
lib/core/db/app_database.dart                   # schemaVersion 2, migration, seedFinanceDefaults
lib/core/db/finance_seed.dart                   # categories (systemKey + keywords), buckets
lib/core/net/http_port.dart                     # tiny injectable HTTP wrapper (http package)
lib/features/finance/domain/ledger.dart, buckets_math.dart, alerts.dart, budgets_math.dart, installments.dart, reports.dart
lib/features/finance/data/workspaces_repository.dart, accounts_repository.dart, transactions_repository.dart,
    rates_repository.dart, categories_repository.dart, buckets_repository.dart, budgets_repository.dart,
    debts_repository.dart, finance_providers.dart
lib/features/finance/ui/finance_overview_screen.dart, accounts_screen.dart, account_detail_screen.dart,
    transaction_form_screen.dart, transfer_form_screen.dart, history_screen.dart, buckets_screen.dart,
    budgets_screen.dart, debts_screen.dart, debt_detail_screen.dart, reports_screen.dart,
    widgets/money_text.dart, widgets/how_converted_sheet.dart, widgets/alerts_banner.dart, charts/*.dart
lib/features/finance/export/csv_export.dart, pdf_export.dart
lib/features/finance/import/csv_reader.dart, xlsx_reader.dart, sheet.dart, import_mapping.dart, import_service.dart,
    ui/import_wizard_screen.dart
lib/features/capture/domain/proposal.dart, lexicon.dart, intent_validator.dart
lib/features/capture/rules/numbers.dart, dates.dart, keywords.dart, rule_parser.dart
lib/features/capture/ai/ai_config.dart, consent.dart, ai_payload.dart, groq_client.dart, llm_parser.dart
lib/features/capture/speech/recorder.dart, speech_to_text.dart, groq_stt.dart, local_whisper_stt.dart, model_manager.dart
lib/features/capture/data/capture_repository.dart, capture_committer.dart
lib/features/capture/capture_pipeline.dart
lib/features/capture/ui/capture_sheet.dart, capture_review_screen.dart, inbox_screen.dart, consent_sheet.dart
lib/features/settings/ai_settings_screen.dart, finance_settings_screen.dart, categories_screen.dart, workspaces_screen.dart
lib/features/shell/home_screen.dart, shell_scaffold.dart (modified)
lib/features/backup/backup_service.dart (modified: secrets entry)
android/app/src/main/AndroidManifest.xml (INTERNET, RECORD_AUDIO)
test/... mirrors lib/ ; test/fixtures/import/*.csv, *.xlsx (synthetic, invented numbers only)
```

---

## Part A — Finance

### Task 1: Money core

**Files:**
- Create: `lib/core/money/{currency,rounding,money,conversion,amount_parse,money_format}.dart`, `lib/core/text/digits.dart`
- Modify: `lib/features/lock/digits.dart` becomes `export '../../core/text/digits.dart';` (callers keep working)
- Test: `test/core/money/*_test.dart`, `test/core/money/no_double_test.dart`

**Interfaces:**
- Produces:
  - `int currencyExponent(String code)`: IQD 0, USD 2, EUR 2, GBP 2, TRY 2, JPY 0, KWD 3, BHD 3, JOD 3; unknown → 2.
  - `BigInt divRoundHalfEven(BigInt n, BigInt d)` (d > 0; n may be negative).
  - `final class Money { const Money(this.minor, this.currency); final int minor; final String currency; Money operator +(Money o); Money operator -(Money o); Money operator -(); bool get isZero; }` — mixing currencies throws `CurrencyMismatch`. Value equality.
  - `final class RateValue { const RateValue({required this.base, required this.quote, required this.rateE6, required this.effectiveFrom}); }` — 1 `base` = `rateE6 / 10⁶` `quote`.
  - `Money convert(Money m, String to, RateValue r)`: same currency returns `m`; base→quote uses `N = rateE6 · 10^max(0, eOut−eIn)`, `D = 10⁶ · 10^max(0, eIn−eOut)`; quote→base uses `N = 10⁶ · 10^max(0, eOut−eIn)`, `D = rateE6 · 10^max(0, eIn−eOut)`; result `divRoundHalfEven(minor·N, D)`. A pair that doesn't match throws `RateMismatch`.
  - `final class ParsedAmount { final int minor; final bool rounded; }` and `ParsedAmount? parseDecimalToMinor(String s, String currency)`: accepts Western and Arabic-Indic digits, `,` `٬` and spaces as grouping, `.` and `٫` as decimal; more fraction digits than the exponent rounds half-even and sets `rounded`; anything else → `null`.
  - `String formatMoney(Money m, {required String localeCode, bool showCode = true})`: Western digits, grouping, fraction digits = exponent; label IQD → «د.ع» (ar, ckb) / `IQD` (en), USD → `$`.
  - `String normalizeDigits(String s)` (moved unchanged) and `String normalizeForMatch(String s)`: digits normalized, lower-cased, Arabic diacritics and tatweel removed, أ/إ/آ → ا, ى → ي, ة → ه, Persian ک/ی → ك/ي.

- [ ] **Step 1: Write the failing tests**

```dart
test('USD→IQD', () => expect(convert(const Money(10000, 'USD'), 'IQD', r1310), const Money(131000, 'IQD')));
test('IQD→USD', () => expect(convert(const Money(131000, 'IQD'), 'USD', r1310), const Money(10000, 'USD')));
test('half-even at rate 1000', () {
  final r = RateValue(base: 'USD', quote: 'IQD', rateE6: 1000000000, effectiveFrom: d0);
  expect([5, 15, 25].map((i) => convert(Money(i, 'IQD'), 'USD', r).minor), [0, 2, 2]);
});
test('wrong pair throws', () => expect(() => convert(const Money(1, 'EUR'), 'IQD', r1310), throwsA(isA<RateMismatch>())));
test('parse', () {
  expect(parseDecimalToMinor('١٢٬٥٠٠', 'IQD')!.minor, 12500);
  expect(parseDecimalToMinor('12.5', 'USD')!.minor, 1250);
  expect(parseDecimalToMinor('١٢٫٥', 'USD')!.minor, 1250);
  expect(parseDecimalToMinor('1,250,000', 'IQD')!.minor, 1250000);
  final r = parseDecimalToMinor('10.005', 'USD')!; expect((r.minor, r.rounded), (1000, true));
  expect(parseDecimalToMinor('12a', 'IQD'), isNull);
});
test('format', () {
  expect(formatMoney(const Money(1250000, 'IQD'), localeCode: 'en'), '1,250,000 IQD');
  expect(formatMoney(const Money(1250, 'USD'), localeCode: 'ar'), contains('12.50'));
});
test('normalizeForMatch', () => expect(normalizeForMatch('أكلة'), normalizeForMatch('اكله')));
// no_double_test.dart: every file under lib/core/money, lib/features/finance/{domain,data,import,export}
// and lib/features/capture/{domain,rules} contains no `double`, `toDouble(`, or `num.parse(`.
```

- [ ] **Step 2: Run** `flutter test test/core/money` — Expected: FAIL (symbols undefined).
- [ ] **Step 3: Implement** the six files and the digits move.
- [ ] **Step 4: Run** `flutter test` (whole suite, since the lock imports moved) — Expected: PASS.
- [ ] **Step 5: Commit** — `feat(money): integer money, half-even conversion, parsing and formatting`

---

### Task 2: Schema v2, migration and finance seed

**Files:**
- Create: `lib/core/db/finance_tables.dart`, `lib/core/db/capture_tables.dart`, `lib/core/db/finance_seed.dart`, `drift_schemas/drift_schema_v2.json`
- Modify: `lib/core/db/tables.dart`, `lib/core/db/app_database.dart`, `test/core/db/migration_test.dart`
- Test: `test/core/db/schema_v2_test.dart`, `test/core/db/finance_seed_test.dart`

**Interfaces:**
- Consumes: Phase 1 tables, `seedInitialData`.
- Produces (all FKs `restrict` unless noted; all timestamps UTC):
  - `Workspaces` + `aliases` text default `''` (comma-separated) + `countsInBuckets` bool default false.
  - `AppSettingsTable` + `aiOnlineEnabled` bool default true, `aiVoiceConsent` text nullable (`granted`/`declined`), `aiParseConsent` text nullable, `groqSttModel` text default `'whisper-large-v3-turbo'`, `groqLlmModel` text default `'llama-3.3-70b-versatile'`, `localWhisperModel` text default `'small'` check in (`small`,`base`), `unallocatedIncomeAlert` bool default false, `bucketsConfirmed` bool default false (Task 10). (`baseCurrency` from v1 is the bucket and consolidation base.)
  - `Categories`: `id`, `kind` check in (`income`,`expense`), `systemKey` text nullable unique, `name` text nullable (null → localized from `systemKey`), `iconKey`, `colorArgb`, `workspaceId` nullable FK, `extraKeywords` text default `''`, `sortOrder`, `isArchived` default false. Check: `systemKey IS NOT NULL OR name IS NOT NULL`.
  - `ExchangeRates`: `id`, `baseCode` text(3), `quoteCode` text(3), `rateE6` int check `> 0`, `effectiveFrom` dateTime, `createdAt`. Unique (`baseCode`,`quoteCode`,`effectiveFrom`).
  - `ImportBatches`: `id`, `fileName`, `rowCount` int, `createdAt`, `undoneAt` nullable.
  - `Debts`: `id`, `direction` check in (`owed_to_me`,`owed_by_me`), `counterparty` text 1..80, `workspaceId` FK, `principalMinor` int check `> 0`, `currencyCode`, `startDate`, `dueDate` nullable, `notes` nullable, `closedAt` nullable, `createdAt`.
  - `Installments`: `id`, `debtId` FK **cascade**, `seq` int, `dueDate`, `amountMinor` int check `> 0`.
  - `Transactions`:
    - `id`, `type` check in (`income`,`expense`,`transfer`,`adjustment`,`refund`,`debt_payment`)
    - `accountId` FK, `workspaceId` FK (copied from the account), `amountMinor` int, `currencyCode`
    - check `amountMinor > 0 OR (type = 'adjustment' AND amountMinor <> 0)`
    - `toAccountId` nullable FK, `toAmountMinor` nullable, `rateE6` nullable, `transferKind` nullable check in (`transfer`,`owner_draw`); check: these are non-null exactly when `type = 'transfer'` (`rateE6` only when currencies differ)
    - `categoryId` nullable FK; `bucketTag` nullable check in (`emergency`,`investment`) — only on `expense`
    - `paymentStatus` text default `'paid'` check in (`paid`,`pending`) — pending income does not move the balance
    - `debtId` nullable FK, `debtLeg` nullable check in (`principal`,`repayment`) — both non-null exactly when `type = 'debt_payment'`
    - `importBatchId` nullable FK, `captureId` nullable
    - `occurredAt`, `description` text nullable max 500, `createdAt`, `updatedAt`
    - indexes on (`accountId`,`occurredAt`), (`occurredAt`), (`importBatchId`)
  - `Buckets`: `id`, `systemKey` nullable unique (`expenses`,`emergency`,`investment`), `name` nullable, `percentBp` int check 0..10000, `targetMinor` nullable (base currency), `sortOrder`.
  - `BucketAllocations`: `id`, `transactionId` FK **cascade**, `bucketId` FK, `amountBaseMinor` int check `> 0`, `baseCurrency`, `rateE6Used` nullable, `createdAt`.
  - `Budgets`: `id`, `categoryId` nullable FK, `workspaceId` nullable FK, check at least one non-null, `amountMinor` > 0, `currencyCode`, `isArchived`, `createdAt`.
  - `Captures`: `id`, `source` check in (`voice`,`text`), `status` check in (`pending`,`done`,`discarded`), `audio` blob nullable, `transcript` text nullable, `parsedJson` text nullable, `parsedBy` text nullable (`ai`,`rules`), `failureType` text nullable, `createdAt`, `updatedAt`.
  - `AppDatabase.schemaVersion => 2`. `onUpgrade` from 1: `createTable` for each new table, `addColumn` for the new workspace and settings columns, then `seedFinanceDefaults`, then set `countsInBuckets = true` on the workspace with `sortOrder = 0` and `iconKey = 'person'`.
  - `Future<void> seedFinanceDefaults(AppDatabase db)` (in `finance_seed.dart`, idempotent, also called by `seedInitialData`):
    - expense `systemKey`s in order: `food, transport, rent, bills, family, shopping, health, business, marketing, subscriptions, other_expense`
    - income `systemKey`s: `salary, business_income, freelance, client_payment, other_income`
    - buckets `expenses` 7000 bp, `emergency` 2000, `investment` 1000 *(placeholders the owner must confirm in the Buckets screen before the first allocation; spec says the owner sets them)*
  - `const Map<String, List<String>> kDefaultCategoryKeywords` keyed by `systemKey`, Arabic (incl. Iraqi), Sorani and English words, e.g. `food: ['اكل','غدا','عشا','فطور','مطعم','لفة','سمون','خواردن','food','lunch']`, `transport: ['تكسي','بانزين','بنزين','كروة','تاکسی','taxi','fuel','uber']`.

- [ ] **Step 1: Write the failing tests**

```dart
test('fresh v2 db seeds 16 categories and 3 buckets summing to 10000', ...);
test('seed is idempotent', ...);
test('transfer row without toAccountId is rejected', () async {
  expect(() => insertTx(type: 'transfer', toAccountId: null), throwsA(isA<SqliteException>()));
});
test('expense with amount 0 or negative is rejected; adjustment −500 is accepted', ...);
test('bucketTag on an income is rejected', ...);
test('deleting a transaction cascades its allocations', ...);
// migration_test.dart
test('v1 → v2 keeps workspaces, accounts, settings, backup rows and seeds finance defaults', () async {
  // SchemaVerifier: start at v1 with the seeded data, migrate to 2, validateDatabaseSchema(),
  // then: same 4 workspaces and 6 accounts; Personal.countsInBuckets == true; others false;
  // localeCode/lockTimeout unchanged; categories 16; buckets 3.
});
```

- [ ] **Step 2: Run** `dart run build_runner build -d`, then `flutter test test/core/db` — Expected: FAIL.
- [ ] **Step 3: Implement** the tables, migration and seed. Run `dart run drift_dev schema dump lib/core/db/app_database.dart drift_schemas/` and `dart run drift_dev schema generate drift_schemas/ test/core/db/generated/`.
- [ ] **Step 4: Run** `flutter test` — Expected: PASS (Phase 1 tests still green).
- [ ] **Step 5: Commit** — `feat(db): schema v2 for finance and capture with tested migration`

---

### Task 3: Ledger, workspaces, accounts and transactions

**Files:**
- Create: `lib/features/finance/domain/ledger.dart`, `lib/features/finance/data/{workspaces_repository,accounts_repository,transactions_repository,finance_providers}.dart`
- Test: `test/features/finance/domain/ledger_test.dart`, `test/features/finance/data/transactions_repository_test.dart`, `test/helpers/finance_fixtures.dart`

**Interfaces:**
- Consumes: `Money` (Task 1), tables (Task 2).
- Produces:
  - `int balanceEffect(Transaction t, int accountId)` (pure): income (paid) `+`, pending income `0`, expense `−`, refund `+`, adjustment `±amount`, transfer `−amount` on `accountId` and `+toAmount` on `toAccountId`, debt_payment: `owed_by_me` principal `+` / repayment `−`, `owed_to_me` principal `−` / repayment `+` (needs the debt direction: signature is `int balanceEffect(Transaction t, int accountId, {String? debtDirection})`).
  - `class WorkspacesRepository { Stream<List<Workspace>> watchAll(); Future<int> create({required String name, required String iconKey, required int colorArgb}); Future<void> update(Workspace w); Future<void> setAliases(int id, List<String> aliases); Future<void> archive(int id); }`
  - `class AccountsRepository { Stream<List<Account>> watchAll({bool includeArchived = false}); Future<int> create({required int workspaceId, required String name, required String kind, required String currencyCode, int openingBalanceMinor = 0}); Future<void> update(Account a); Future<void> archive(int id); Future<Money> balanceOf(int accountId, {DateTime? asOf}); Stream<Map<int, Money>> watchBalances(); }` — currency of an account can't change once it has transactions (`StateError`).
  - `class TransactionsRepository` with:
    - `Future<int> addSimple({required String type, required int accountId, required int amountMinor, required DateTime occurredAt, int? categoryId, String? description, String? bucketTag, String paymentStatus = 'paid', int? importBatchId, int? captureId})` for income / expense / refund / adjustment
    - `Future<int> addTransfer({required int fromAccountId, required int toAccountId, required int amountMinor, required DateTime occurredAt, int? toAmountMinor, int? rateE6, String transferKind = 'transfer', String? description, int? captureId})` — same currency: `toAmountMinor = amountMinor`, `rateE6 = null`; different currencies: both required. Same account → `ArgumentError`.
    - `Future<void> update(int id, TransactionsCompanion changes, {bool clearAllocations = false})` — re-validates; changing the amount, account or date of an income that has allocations throws `AllocationsLocked` unless `clearAllocations: true` is passed (the UI asks first).
    - `Future<void> delete(int id)` — allocations cascade.
    - `Stream<List<Transaction>> watch(TxFilter f)` with `class TxFilter { DateTime? from, to; Set<int>? accountIds, workspaceIds, categoryIds; Set<String>? types; String? text; }` (text matches description and category name via `normalizeForMatch`).
  - All writes run inside `db.transaction`, set `workspaceId` from the account and `currencyCode` from the account (a mismatching input currency → `ArgumentError`).
  - Providers in `finance_providers.dart`: `workspacesRepositoryProvider`, `accountsRepositoryProvider`, `transactionsRepositoryProvider`, `balancesProvider` (`StreamProvider<Map<int, Money>>`).
  - Test helper `Future<FinanceFixture> financeFixture()` → in-memory DB seeded with Phase 1 + finance defaults; fields `personalIqd`, `personalUsd`, `buzzIqd`, `buzzUsd`, `eoIqd`, `eoUsd` (account ids), `personalWs`, `buzzWs`, `eoWs`, and `cat(String systemKey)`.

- [ ] **Step 1: Write the failing tests**

```dart
test('opening + income − expense + refund', () async {
  // personalIqd opening 100000; income 50000; expense 20000; refund 5000 → 135000
});
test('pending income does not move the balance until marked paid', ...);
test('IQD→USD exchange transfer moves both legs and is not income or expense', () async {
  await tx.addTransfer(fromAccountId: f.personalIqd, toAccountId: f.personalUsd, amountMinor: 131000, toAmountMinor: 10000, rateE6: 1310000000, occurredAt: d);
  expect(await acc.balanceOf(f.personalIqd), const Money(-131000, 'IQD'));
  expect(await acc.balanceOf(f.personalUsd), const Money(10000, 'USD'));
});
test('cross-currency transfer without rate → ArgumentError', ...);
test('transfer to the same account → ArgumentError', ...);
test('edit and delete keep balances', () async {
  // add expense 20000, update to 25000 → balance −25000; delete → 0; transfer delete restores both accounts
});
test('editing an allocated income throws AllocationsLocked unless clearAllocations', ...);
test('asOf balance ignores later transactions', ...);
test('filter by text matches Arabic without diacritics', ...);
test('account currency is locked once it has transactions', ...);
```

- [ ] **Step 2: Run** `flutter test test/features/finance` — Expected: FAIL.
- [ ] **Step 3: Implement.** Balances are computed in SQL as `opening + SUM(CASE …)` per account (one query for all accounts in `watchBalances`), mirroring `balanceEffect`; the pure function is the reference the tests compare against.
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(finance): ledger, accounts, transfers and transaction repository`

---

### Task 4: Exchange rates, categories, consolidation and finance settings data

**Files:**
- Create: `lib/features/finance/data/rates_repository.dart`, `categories_repository.dart`
- Modify: `lib/features/settings/settings_repository.dart`, `lib/features/finance/data/finance_providers.dart`
- Test: `test/features/finance/data/rates_repository_test.dart`, `categories_repository_test.dart`, `test/features/settings/settings_repository_test.dart` (extend)

**Interfaces:**
- Consumes: `RateValue`, `convert` (Task 1); `AccountsRepository.watchBalances` (Task 3).
- Produces:
  - `class RatesRepository { Future<void> setRate({required String base, required String quote, required int rateE6, required DateTime effectiveFrom}); Future<RateValue?> rateOn(String a, String b, DateTime day); Stream<List<RateValue>> watchHistory(String a, String b); }` — `rateOn` returns the latest rate with `effectiveFrom ≤ day` for the pair in either direction; none → `null`. Setting a rate for an existing `(pair, effectiveFrom)` replaces it.
  - `ParsedAmount`-based rate input: `int? parseRateE6(String s)` (e.g. `"1310"` → 1310000000, `"1,312.5"` → 1312500000; up to 6 decimals).
  - `class ConvertedLine { final Money original; final Money converted; final RateValue? rate; }` and `class Consolidated { final String base; final Money? total; final Map<String, Money> subtotals; final List<ConvertedLine> lines; final List<String> missingRates; }` — `total == null` when any currency has no rate (Decision 9).
  - `Future<Consolidated> consolidate(Map<int, Money> balances, {required String base, required DateTime day})` in `rates_repository.dart`; `consolidatedProvider` (base from settings, today).
  - `class CategoriesRepository { Stream<List<Category>> watch({String? kind, bool includeArchived = false}); Future<int> create({required String kind, required String name, String iconKey = 'tag', int? colorArgb, int? workspaceId}); Future<void> rename(int id, String name); Future<void> setExtraKeywords(int id, List<String> words); Future<void> archive(int id); }` and `String categoryLabel(Category c, AppLocalizations l10n)` (name, else the l10n string for `systemKey`).
  - `SettingsRepository` additions: `setBaseCurrency(String code)` (3 uppercase letters), `setAiOnlineEnabled(bool)`, `setConsent(AiFeature f, ConsentState s)`, `setGroqModels({String? stt, String? llm})` (non-empty, ≤ 100 chars), `setLocalWhisperModel(String m)`, `setUnallocatedIncomeAlert(bool)`. `enum AiFeature { voice, parse }`, `enum ConsentState { granted, declined }`.
  - ARB: one localized label per category `systemKey` (`cat_food`, …) and bucket `systemKey`.

- [ ] **Step 1: Write the failing tests**

```dart
test('rateOn picks latest effective ≤ day and works in reverse direction', () async {
  await rates.setRate(base: 'USD', quote: 'IQD', rateE6: 1300000000, effectiveFrom: DateTime.utc(2026, 1, 1));
  await rates.setRate(base: 'USD', quote: 'IQD', rateE6: 1310000000, effectiveFrom: DateTime.utc(2026, 6, 1));
  expect((await rates.rateOn('IQD', 'USD', DateTime.utc(2026, 3, 1)))!.rateE6, 1300000000);
  expect(await rates.rateOn('USD', 'IQD', DateTime.utc(2025, 12, 31)), isNull);
});
test('consolidate without a rate hides the total but keeps subtotals', ...);
test('consolidate with a rate shows every converted line', ...);
test('parseRateE6', () { expect(parseRateE6('١٣١٠'), 1310000000); expect(parseRateE6('0'), isNull); });
test('setBaseCurrency rejects "iq"', ...);
test('categoryLabel uses the localized systemKey until renamed', ...);
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(finance): exchange-rate history, consolidation, categories`

---

### Task 5: Buckets and alerts

**Files:**
- Create: `lib/features/finance/domain/buckets_math.dart`, `lib/features/finance/domain/alerts.dart`, `lib/features/finance/data/buckets_repository.dart`
- Test: `test/features/finance/domain/buckets_math_test.dart`, `alerts_test.dart`, `test/features/finance/data/buckets_repository_test.dart`

**Interfaces:**
- Consumes: `convert`, `RatesRepository.rateOn` (Task 4), `TransactionsRepository` (Task 3).
- Produces:
  - `List<int> defaultSplit(int totalBaseMinor, List<int> percentBp)`: each share `floor(total·bp/10000)`, the remainder goes to the bucket with the largest bp (first by order on a tie). Sum == total.
  - `class BucketStatus { final Bucket bucket; final int allocatedMinor; final int spentMinor; final int availableMinor; final int? targetMinor; }` (all base currency). Expenses: allocated and spent within the given calendar month (local time); spending = expenses − refunds in workspaces with `countsInBuckets`, untagged, converted at each transaction's date rate. Emergency and Investment: all-time allocations − all-time expenses tagged with that bucket (any workspace).
  - `class BucketsRepository { Stream<List<Bucket>> watch(); Future<void> setPercents(Map<int, int> bpByBucket); Future<void> setTarget(int bucketId, int? targetMinor); Future<void> allocate(int incomeTxId, Map<int, int> amountBaseMinorByBucket); Future<List<BucketStatus>> status(DateTime month); Future<int> incomeInBase(int incomeTxId); }`
    - `setPercents` throws `ArgumentError` unless the sum is exactly 10000.
    - `allocate` requires an `income` transaction without allocations, a rate when its currency ≠ base (`MissingRate` otherwise), every amount > 0, and the sum ≤ the income in base. Rows store `rateE6Used`.
  - `sealed class FinanceAlert` with `ExpensesBucketUsed(int percentBp)` (fires at ≥ 8000 and ≥ 10000), `EmergencyTargetReached`, `EmergencyBelowTarget`, `UnallocatedIncome(int count)` (only when the setting is on; counts this month's income without allocations), `BudgetUsed(int budgetId, int percentBp)`, `DebtDueSoon(int debtId, DateTime due)` (≤ 7 days), `DebtOverdue(int debtId)`. Each has a stable `key` string.
  - `List<FinanceAlert> evaluateAlerts({required List<BucketStatus> buckets, required List<BudgetProgress> budgets, required List<DebtSummary> debts, required int unallocatedIncomeCount, required bool unallocatedAlertOn, required DateTime now})` — pure. `BudgetProgress` and `DebtSummary` come from Task 6; until then the tests pass empty lists.
  - `financeAlertsProvider` (`FutureProvider<List<FinanceAlert>>`, refreshed when transactions change).

- [ ] **Step 1: Write the failing tests**

```dart
test('defaultSplit 1,000,001 at 7000/2000/1000 → 700001/200000/100000', ...);
test('setPercents must sum to 10000', ...);
test('USD income allocated in IQD base uses the income-date rate', () async {
  // rate 1310 from 2026-01-01; income 100.00 USD on 2026-02-01 → incomeInBase 131000
});
test('allocate without a rate → MissingRate', ...);
test('allocations above the income → ArgumentError; below is allowed', ...);
test('percent change does not alter past allocations', ...);
test('expenses bucket resets each month; emergency carries over', ...);
test('business workspace expenses do not count against the Expenses bucket', ...);
test('deleting income removes its allocations', ...);
test('alerts at 79.99% none, 80% one, 100% one ExpensesBucketUsed(10000)', ...);
test('emergency below target after a tagged withdrawal', ...);
test('unallocated alert only when the setting is on', ...);
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(finance): buckets with manual allocation and in-app alerts`

---

### Task 6: Budgets, debts and installments

**Files:**
- Create: `lib/features/finance/domain/budgets_math.dart`, `installments.dart`, `lib/features/finance/data/budgets_repository.dart`, `debts_repository.dart`
- Test: `test/features/finance/domain/installments_test.dart`, `test/features/finance/data/budgets_repository_test.dart`, `debts_repository_test.dart`

**Interfaces:**
- Consumes: Tasks 3–5.
- Produces:
  - `class BudgetProgress { final Budget budget; final int actualMinor; final int remainingMinor; final int percentBp; final List<String> missingRates; }` — actual = expenses − refunds in the month matching the category and/or workspace, converted to the budget currency at each transaction's date rate; transactions in a currency with no rate are left out and listed in `missingRates`.
  - `class BudgetsRepository { Stream<List<Budget>> watch(); Future<int> create({int? categoryId, int? workspaceId, required int amountMinor, required String currencyCode}); Future<void> update(Budget b); Future<void> archive(int id); Future<List<BudgetProgress>> progress(DateTime month); }`
  - `List<(DateTime due, int amountMinor)> equalInstallments({required int totalMinor, required int count, required DateTime firstDue})`: monthly, same day-of-month clamped to month length; each `total ~/ count`, the last takes the remainder.
  - `class InstallmentState { final Installment inst; final int paidMinor; final bool isPaid; final bool isOverdue; }` — `List<InstallmentState> applyPayments(List<Installment> schedule, int totalRepaidMinor, DateTime today)` fills installments in `seq` order.
  - `class DebtSummary { final Debt debt; final int repaidMinor; final int remainingMinor; final DateTime? nextDue; final bool overdue; }`
  - `class DebtsRepository { Stream<List<DebtSummary>> watchSummaries({bool includeClosed = false}); Future<int> create({required String direction, required String counterparty, required int workspaceId, required int principalMinor, required String currencyCode, required DateTime startDate, DateTime? dueDate, String? notes, int? recordPrincipalFromAccountId, int installmentCount = 0, DateTime? firstInstallmentDue}); Future<int> recordRepayment({required int debtId, required int accountId, required int amountMinor, required DateTime occurredAt}); Future<void> close(int debtId); Future<List<InstallmentState>> installments(int debtId); }`
    - `recordPrincipalFromAccountId` adds a `debt_payment`/`principal` transaction on that account (Decision 5).
    - A repayment above the remaining amount → `ArgumentError`. Reaching 0 sets `closedAt`. The account currency must equal the debt currency.

- [ ] **Step 1: Write the failing tests**

```dart
test('equalInstallments 1,000,000 / 3 from 2027-01-31 → 333333, 333333, 333334 on 2027-01-31, 2027-02-28, 2027-03-31', ...);
test('applyPayments 400000 marks #1 paid, #2 partly paid', ...);
test('borrowed money adds cash, repayment removes it, neither is income or expense', ...);
test('lent money removes cash, repayment adds it', ...);
test('repayment over remaining → ArgumentError; exact remaining closes the debt', ...);
test('budget per category: 80000 of 100000 → 8000 bp, remaining 20000', ...);
test('budget per workspace in USD converts IQD expenses at their date rate', ...);
test('budget skips a currency with no rate and lists it', ...);
test('refund reduces budget actual', ...);
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS. Wire `BudgetProgress` and `DebtSummary` into `financeAlertsProvider` (Task 5) and add one alert test with a real budget and an overdue debt.
- [ ] **Step 5: Commit** — `feat(finance): budgets, debts, installments and repayments`

---

### Task 7: Reports engine

**Files:**
- Create: `lib/features/finance/domain/reports.dart`, `lib/features/finance/data/reports_query.dart`
- Test: `test/features/finance/domain/reports_test.dart`

**Interfaces:**
- Consumes: `Transaction`, `RateValue`, `convert`, `DebtSummary`.
- Produces (pure; inputs are already-loaded rows plus a `RateLookup = RateValue? Function(String from, String to, DateTime day)`):
  - `enum Period { day, week, month }`; `DateTime periodStart(DateTime local, Period p)` (week starts Saturday).
  - `class ReportScope { final DateTime from, to; final Set<int>? workspaceIds; final String currency; }` — every figure is in `scope.currency`; rows that can't be converted are counted in `skippedCount` / `missingRates` on the result instead of guessed.
  - `class Series { final List<(DateTime, int)> points; }`
  - `IncomeExpense incomeVsExpense(List<Transaction> txs, ReportScope s, Period p, RateLookup r)` — income and expense per period, surplus. Rules: transfers excluded except `owner_draw` (expense of source workspace, income of target); refunds reduce expense; adjustments and debt payments excluded; pending income excluded.
  - `List<(int categoryId, int minor)> byCategory(...)`, `List<(int workspaceId, int income, int expense)> byWorkspace(...)`.
  - `CashFlow cashFlow(...)`: inflow and outflow per period across all cash movement, including transfers in and out of the scoped workspaces and debt payments (transfers inside the scope net to zero).
  - `Series balanceOverTime(List<Transaction> txs, Map<int, int> openingByAccount, Set<int> accountIds, ReportScope s, RateLookup r)` — daily closing balance.
  - `List<DebtSummary> outstandingDebts(List<DebtSummary> all)` — open ones, overdue first, then by due date.
  - `class ReportResult<T> { final T data; final int skippedCount; final Set<String> missingRates; }` wraps each of the above.
  - `ReportsQuery` (data): loads the transactions in range once and builds the `RateLookup` from `RatesRepository`.

- [ ] **Step 1: Write the failing tests** (a fixed list of ~20 invented transactions across two months, three workspaces and two currencies, rate 1310)

```dart
test('monthly income vs expense, IQD scope', () { /* exact ints per month, surplus = income − expense */ });
test('IQD↔USD exchange is neither income nor expense', ...);
test('owner draw: Buzzify expense, Personal income; whole-scope total unchanged', ...);
test('weekly buckets start on Saturday', () => expect(periodStart(DateTime(2026, 10, 23), Period.week), DateTime(2026, 10, 17)));
test('byCategory sorts descending and nets refunds', ...);
test('cash flow counts debt principal as inflow', ...);
test('balanceOverTime matches AccountsRepository.balanceOf on each day', ...);
test('USD rows with no rate are skipped and reported', ...);
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(finance): reports engine for all report dimensions`

---

### Task 8: Finance UI — overview, accounts, history

Load `impeccable` before this task.

**Files:**
- Create: `lib/features/finance/ui/{finance_overview_screen,accounts_screen,account_detail_screen,history_screen}.dart`, `widgets/{money_text,how_converted_sheet,alerts_banner}.dart`
- Modify: `lib/app/router.dart` (replace the `/finance` placeholder)
- Test: `test/features/finance/ui/finance_overview_test.dart`, `history_screen_test.dart`

**Interfaces:**
- Consumes: Tasks 3–7 providers.
- Produces:
  - Routes: `/finance`, `/finance/accounts`, `/finance/accounts/:id`, `/finance/history` (query params `account`, `workspace`, `category`), plus the routes Tasks 9–14 add under `/finance`.
  - `MoneyText(Money m, {TextStyle? style, bool signed = false})`: uses `formatMoney` with the current locale; `success` colour for positive and `danger` for negative when `signed`; always `TextDirection.ltr` inside RTL so `−25,000 د.ع` doesn't flip.
  - `HowConvertedSheet(Consolidated c)`: every line with original, rate, its date, converted, and subtotals per currency (spec §10.2). Any consolidated figure in the app opens it on tap.
  - `AlertsBanner(List<FinanceAlert>)`: one line per alert, tappable to the related screen.
  - **Finance Overview:** this month's income / expense / surplus tiles (base currency), consolidated balance (or "set a rate" when `total == null`), the alerts banner, accounts grouped by workspace with balances, and entry tiles to History, Buckets, Budgets, Debts, Reports and Import, plus "Add" actions (expense, income, transfer).
  - **Accounts:** list, add, rename, archive; currency picker (IQD, USD, then the others from `currencyExponent`'s list). **Account detail:** balance, the account's history, and "adjust balance" (creates an `adjustment` from the difference between the typed actual amount and the current balance).
  - **History:** filters (date range, account, workspace, category, type), text search, day group headers with day totals, swipe-to-delete with undo snackbar (re-inserts the same row), tap to edit (Task 9).
- ARB keys for everything above.

- [ ] **Step 1: Write the failing widget tests**
  - Overview shows the three month tiles with exact formatted values from a fixture.
  - Without a rate, the consolidated card shows the "set a rate" action and per-currency subtotals; with one, tapping it opens `HowConvertedSheet` listing the rate 1,310 and its date.
  - In `ar`, a negative amount renders as one LTR run (`find.text` matches `−25,000 د.ع`).
  - History filter by workspace Buzzify hides Personal rows; searching «اكل» matches «أكل».
  - Deleting from History then tapping Undo restores the balance.
  - Worst case at 320 px, `ckb`: an account name of 80 characters and a balance of 999,999,999,999 IQD render without overflow.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** `flutter test` → PASS.
- [ ] **Step 5: Commit** — `feat(finance): overview, accounts and history screens`

---

### Task 9: Transaction and transfer forms

Load `impeccable` before this task.

**Files:**
- Create: `lib/features/finance/ui/transaction_form_screen.dart`, `transfer_form_screen.dart`, `widgets/amount_field.dart`, `widgets/allocation_editor.dart`
- Test: `test/features/finance/ui/transaction_form_test.dart`, `transfer_form_test.dart`

**Interfaces:**
- Consumes: `TransactionsRepository`, `BucketsRepository`, `CategoriesRepository`, `RatesRepository`, `parseDecimalToMinor`.
- Produces:
  - Routes `/finance/tx/new?type=income|expense|refund` and `/finance/tx/:id`, `/finance/transfer/new`, `/finance/transfer/:id`.
  - `AmountField({required String currency, required ValueChanged<int?> onMinor})`: numeric keyboard, accepts Arabic-Indic digits, shows a "rounded" hint when `ParsedAmount.rounded`.
  - `AllocationEditor({required int totalBaseMinor, required List<Bucket> buckets, required ValueChanged<Map<int,int>> onChanged})`: pre-filled with `defaultSplit`, editable per bucket, shows the unallocated rest, blocks Save when the sum > total. This widget is reused by Capture Review (Task 19).
  - **Transaction form** fields: type segmented (expense / income / refund), amount, account (grouped by workspace; its currency is shown), category (filtered by kind), date and time (default now), description, income-only payment status and the "Allocate to buckets" toggle (off by default, disabled with a hint when there is no rate for a foreign-currency income), expense-only bucket tag (none / emergency / investment). Saving an allocated income calls `addSimple` then `allocate` in one DB transaction.
  - Editing an allocated income asks to clear its allocations before saving (`AllocationsLocked`).
  - **Transfer form:** from, to, amount; when the currencies differ, a second amount and the rate. The rate is always shown as the stored pair's quote per 1 base (IQD per 1 USD). Typing two of the three fills the third, shown read-only; from the two amounts, `rateE6 = divRoundHalfEven(quoteMinor·10⁶·10^(eBase), baseMinor·10^(eQuote))`. An "owner draw (salary)" switch appears when the workspaces differ.
  - Pre-fill entry points for Task 19 and the "+" shortcuts: `TransactionFormScreen({TransactionDraft? initial})` and `TransferFormScreen({TransferDraft? initial})`. This task creates `lib/features/capture/domain/proposal.dart` with just these two classes, every field nullable: `TransactionDraft {type, accountId, amountMinor, categoryId, occurredAt, description, bucketTag}` and `TransferDraft {fromAccountId, toAccountId, amountMinor, toAmountMinor, rateE6, transferKind}`. Task 15 adds the proposal classes to the same file.

- [ ] **Step 1: Write the failing widget tests**
  - Typing `٢٥٠٠٠` in an IQD expense and saving stores 25000.
  - Income 100.00 USD with allocation on and rate 1310 pre-fills 91700 / 26200 / 13100 IQD; saving creates three allocation rows.
  - Allocation sum above the total disables Save.
  - Transfer IQD→USD: entering 131000 and 100.00 shows rate 1,310; saving stores both legs.
  - Owner draw switch is hidden when both accounts are in the same workspace.
  - Editing an allocated income shows the clear-allocations dialog.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(finance): transaction and transfer forms with bucket allocation`

---

### Task 10: Buckets, budgets and debts screens

Load `impeccable` before this task.

**Files:**
- Create: `lib/features/finance/ui/{buckets_screen,budgets_screen,debts_screen,debt_detail_screen}.dart`
- Test: `test/features/finance/ui/buckets_screen_test.dart`, `budgets_screen_test.dart`, `debts_screen_test.dart`

**Interfaces:**
- Consumes: Tasks 5–6.
- Produces:
  - Routes `/finance/buckets`, `/finance/budgets`, `/finance/debts`, `/finance/debts/:id`.
  - **Buckets:** per bucket available / allocated / spent for the selected month (month switcher), progress bar, target with its own bar; an "edit percentages" sheet that blocks Save until the sum is 100% and states that only future income is affected; a banner until the owner has saved percentages at least once (`bucketsConfirmed`, Task 2; add `SettingsRepository.setBucketsConfirmed()` here). Until then the allocation toggle (Task 9) opens this screen instead of allocating. No suggested numbers anywhere.
  - **Budgets:** list with actual / budget / remaining / percent bars for the month, coloured at 80% (warning) and 100% (danger), add/edit sheet (category and/or workspace, amount, currency), and the `missingRates` note.
  - **Debts:** two tabs (owed to me / owed by me), each row with counterparty, remaining, next due, overdue badge. Add sheet with "record the money now from/to account" and an optional installment count. **Debt detail:** installment list from `applyPayments`, payment history, "record repayment" sheet.

- [ ] **Step 1: Write the failing widget tests**
  - Percentages 70/20/5 keep Save disabled; 70/20/10 enables it.
  - At 85% spent the Expenses bar uses the warning colour.
  - Recording a repayment equal to the remaining moves the debt out of the open list.
  - Debts tabs in `ar` keep "owed to me" first in reading order.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(finance): buckets, budgets and debts screens`

---

### Task 11: Reports screen, charts and CSV/PDF export

Load `impeccable` and `dataviz` before this task.

**Files:**
- Create: `lib/features/finance/ui/reports_screen.dart`, `lib/features/finance/ui/charts/{income_expense_chart,category_chart,balance_chart,bucket_chart}.dart`, `lib/features/finance/export/csv_export.dart`, `pdf_export.dart`
- Modify: `pubspec.yaml` (`fl_chart`, `pdf`)
- Test: `test/features/finance/export/csv_export_test.dart`, `pdf_export_test.dart`, `test/features/finance/ui/reports_screen_test.dart`

**Interfaces:**
- Consumes: Task 7 (`ReportsQuery`, report functions), Task 5 (`BucketStatus`).
- Produces:
  - Route `/finance/reports`. Controls: range (this month, last month, last 3/6/12 months, custom), period (day/week/month), workspace filter, report currency (IQD/USD).
  - Tabs: Income vs expense (bars + surplus line), By category (horizontal bars, top 8 + "other"), By workspace, Cash flow, Balance over time (line), Buckets, Outstanding debts (list). Each chart has a data table toggle and the `skippedCount`/`missingRates` note. Charts convert `int` to `double` only inside `charts/`.
  - `String transactionsCsv(List<Transaction> txs, CsvLabels labels)`: UTF-8 with BOM (Excel opens Arabic correctly), header row, columns `date, type, workspace, account, category, amount, currency, description, transfer_to, to_amount, rate`; amounts as decimal text from minor units (`12.50`), never scientific; RFC 4180 quoting; cells starting with `= + - @` prefixed with `'` (CSV injection).
  - `Future<Uint8List> reportPdf(ReportPdfData d)`: A4, bundled Vazirmatn (`assets/fonts`), RTL for `ar`/`ckb`, title, range, scope, summary table, category table, debts table. No chart images (tables only; my call: keeps the PDF exact and small).
  - Export buttons save through `FilePicker.platform.saveFile` (as Backup does) with names `life-manager-<report>-YYYY-MM-DD.csv|pdf`. Before saving, a one-line notice says the file is **not encrypted**.
  - `ReportPdfData` holds already-formatted strings plus the locale code.

- [ ] **Step 1: Write the failing tests**

```dart
test('csv amounts are exact decimals and Arabic survives', () {
  final s = transactionsCsv([usdExpense1250, iqdIncome], labels);
  expect(s.startsWith('﻿'), isTrue);
  expect(s, contains('12.50')); expect(s, contains('اكل'));
  expect(s, isNot(contains('e+')));
});
test('csv quotes commas, quotes and newlines; neutralises =SUM(', ...);
test('pdf starts with %PDF and embeds the Vazirmatn font', ...);
testWidgets('switching to USD scope relabels totals and shows skipped note when no rate', ...);
testWidgets('data table toggle lists the same numbers as the chart', ...);
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(finance): reports with charts and CSV/PDF export`

---

### Task 12: Finance settings — base currency, rates, categories, workspaces

Load `impeccable` before this task.

**Files:**
- Create: `lib/features/settings/finance_settings_screen.dart`, `categories_screen.dart`, `workspaces_screen.dart`
- Modify: `lib/features/settings/settings_screen.dart` (new "Finance" section), `lib/app/router.dart`
- Test: `test/features/settings/finance_settings_test.dart`, `categories_screen_test.dart`, `workspaces_screen_test.dart`

**Interfaces:**
- Consumes: `SettingsRepository`, `RatesRepository`, `CategoriesRepository`, `WorkspacesRepository`, `parseRateE6`.
- Produces:
  - Routes `/settings/finance`, `/settings/categories`, `/settings/workspaces`.
  - **Finance settings:** base currency (IQD/USD), USD↔IQD rate entry with an effective date (default today) and the rate history list, the "alert on unallocated income" switch (off by default).
  - **Categories:** income and expense lists, add, rename, archive, and keyword chips per category (default keywords shown read-only, extra keywords editable — spec §8.3 "editable per category").
  - **Workspaces:** list, add (name, icon from a fixed set, colour from a fixed palette), rename, aliases as chips (used by the parser), "counts in buckets" switch, archive (blocked while it has non-archived accounts).

- [ ] **Step 1: Write the failing widget tests**
  - Entering rate `١٣١٠` stores 1310000000 effective today and shows it at the top of the history.
  - Adding the keyword «سمون» to Food persists it in `extraKeywords`.
  - Adding the alias «بز» to Buzzify persists it.
  - Archiving a workspace with active accounts shows the blocking message.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(settings): finance settings, rates, categories and workspaces`

---

### Task 13: Import engine — CSV and xlsx readers, mapping, batches

**Files:**
- Create: `lib/features/finance/import/{sheet,csv_reader,xlsx_reader,import_mapping,import_service}.dart`, `test/fixtures/import/` (synthetic `.csv` and `.xlsx`, invented numbers; the xlsx files are generated by `test/fixtures/import/make_fixtures.dart` using `archive` so they are reproducible)
- Modify: `pubspec.yaml` (`xml`)
- Test: `test/features/finance/import/{csv_reader,xlsx_reader,import_mapping,import_service}_test.dart`

**Interfaces:**
- Consumes: `parseDecimalToMinor`, `TransactionsRepository`, `CategoriesRepository`, `WorkspacesRepository`, `AccountsRepository`.
- Produces:
  - `sealed class Cell`: `TextCell(String)`, `NumberCell(String decimalText)`, `DateSerialCell(String serialText)`, `EmptyCell`. `class Sheet { final String name; final List<List<Cell>> rows; }`
  - `List<Sheet> readCsv(Uint8List bytes)`: strips the UTF-8 BOM, detects the delimiter from `, ; \t` on the first line, RFC 4180 quotes; one sheet named after nothing (`''`).
  - `List<Sheet> readXlsx(Uint8List bytes)`: `xl/workbook.xml` names, `xl/_rels/workbook.xml.rels` targets, `xl/sharedStrings.xml`, inline strings, `xl/styles.xml` `cellXfs` → a number cell whose `numFmtId` is 14–22 or 45–47, or a custom format containing `d`, `m` or `y` outside quotes, becomes `DateSerialCell`. Cell refs (`B7`) place cells; gaps become `EmptyCell`. Limits: 50,000 rows, 64 columns, 50 MB uncompressed; beyond → `ImportTooLarge`. Malformed → `ImportFormatException`.
  - `DateTime? excelSerialToDate(String serial)` (1900 system; serials ≥ 61 subtract 1 for the leap bug; fraction = time).
  - `enum DateOrder { dayFirst, monthFirst, iso }` (default `dayFirst`) and `DateTime? parseTextDate(String s, DateOrder o)` accepting `/ - .` separators and Arabic-Indic digits.
  - `int? decimalTextToMinor(String text, String currency)` — `"1250000.0000000002"` → 1250000 for IQD: the text is first rounded half-even to **6** decimal places (absorbing binary artefacts), then to the currency exponent. Wraps `parseDecimalToMinor`.
  - `class ColumnMapping { int dateCol; DateOrder dateOrder; AmountMode amountMode; int? amountCol, incomeCol, expenseCol, typeCol, currencyCol, categoryCol, workspaceCol, accountCol, descriptionCol; }` with `enum AmountMode { signed, typeColumn, splitColumns }`.
  - `class ImportDefaults { String currency; int workspaceId; Map<String, int> accountByWorkspaceCurrency /* "wsId:IQD" → accountId */; }` and `class ValueMaps { Map<String, String> typeValues /* raw → income|expense|skip */; Map<String, int?> categories; Map<String, int?> workspaces; Map<String, int?> accounts; }` (null → "create new" resolved by the wizard before import).
  - `class ImportRow { final int sourceRow; final String type; final int accountId; final int amountMinor; final DateTime occurredAt; final int? categoryId; final String? description; final bool duplicate; final String? problem; }`
  - `List<ImportRow> planImport(Sheet s, int headerRow, ColumnMapping m, ImportDefaults d, ValueMaps v, {required Set<String> existingKeys})` — pure. A row with no readable date or amount gets `problem` (`'date'`, `'amount'`, `'type'`) and is not imported. Duplicate key: `'yyyy-mm-dd|accountId|amountMinor|normalizeForMatch(description)'`, checked against `existingKeys` and earlier rows in the same file.
  - `class ImportService { Future<Set<String>> existingKeys(DateTime from, DateTime to); Future<int> commit(String fileName, List<ImportRow> rows, {bool skipDuplicates = true}); Future<void> undo(int batchId); Stream<List<ImportBatch>> watchBatches(); }` — `commit` inserts one `ImportBatches` row and all transactions in one DB transaction; `undo` deletes the batch's transactions (allocations cascade) and sets `undoneAt`.

- [ ] **Step 1: Write the failing tests**

```dart
test('csv: BOM, semicolons, quoted newline', ...);
test('xlsx float artefact', () { // fixture cell <v>1250000.0000000002</v>, IQD
  expect(decimalTextToMinor('1250000.0000000002', 'IQD'), 1250000);
  expect(decimalTextToMinor('12.3', 'USD'), 1230);
});
test('date serial', () { expect(excelSerialToDate('45658'), DateTime(2025, 1, 1)); expect(excelSerialToDate('60'), isNull /* 1900-02-29 does not exist */); });
test('day-first', () => expect(parseTextDate('3/4/2024', DateOrder.dayFirst), DateTime(2024, 4, 3)));
test('xlsx fixture: shared strings, date-styled cells and gaps', ...);
test('split columns: income column 500000 and expense column empty → income', ...);
test('signed mode: −20000 → expense 20000', ...);
test('row with unreadable amount gets problem "amount"', ...);
test('same row twice in one file → second flagged duplicate', ...);
test('re-importing the same file flags every row duplicate', ...);
test('undo removes every transaction of the batch and restores balances', ...);
test('50,001 rows → ImportTooLarge', ...);
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(import): csv/xlsx readers, column mapping, batches with undo`

---

### Task 14: Import wizard and opening balances

Load `impeccable` before this task.

**Files:**
- Create: `lib/features/finance/import/ui/import_wizard_screen.dart`
- Modify: `lib/app/router.dart` (`/finance/import`)
- Test: `test/features/finance/import/import_wizard_test.dart`

**Interfaces:**
- Consumes: Task 13; `AccountsRepository.balanceOf`; `TransactionsRepository.addSimple` (adjustment).
- Produces: a stepper (buttons only, no swipe — the Phase 1 setup ruling) with:
  1. Pick file (`FilePicker.platform.pickFiles(withData: true, allowedExtensions: ['xlsx','csv'])`), then sheet, then header row (first 10 rows shown; the first non-empty row is pre-selected).
  2. Columns: date (+ date order), amount mode and its columns, optional type, currency, category, workspace, account and description columns. Guesses from header names in three languages (`تاريخ/date/بەروار`, `مبلغ/amount/بڕ`, `وارد/income`, `صادر/expense`, …).
  3. Defaults: currency, workspace, and per-workspace-currency account for rows without those columns.
  4. Values: each distinct type, category, workspace and account value maps to an existing item, "create new" or "skip".
  5. Preview: first 20 planned rows, counts of ready / duplicate / problem rows, a "skip duplicates" switch (on), then Import.
  6. Opening balances: per touched account, the computed balance and a field for the actual cash today; a difference creates an `adjustment` dated now with description «تسوية بعد الاستيراد».
  - Past batches list with Undo (confirm dialog shows the row count) on the Import screen.
  - Nothing is written before step 5's Import tap; "create new" items are created in the same DB transaction as the batch.

- [ ] **Step 1: Write the failing widget tests**
  - Full happy path with the CSV fixture creates the batch, and the preview counts match `planImport`.
  - Backing out at step 4 leaves the DB unchanged (transaction count and categories count equal before and after).
  - Opening-balance step: typing an actual amount 10,000 above the computed one creates one adjustment of +10000.
  - Undo from the batches list asks for confirmation and removes the rows.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(import): import wizard with mapping, preview and opening balances`

---

## Part B — Capture

### Task 15: Offline rule parser

**Files:**
- Create: `lib/features/capture/rules/{numbers,dates,keywords,rule_parser}.dart`, `lib/features/capture/domain/lexicon.dart`
- Modify: `lib/features/capture/domain/proposal.dart`
- Test: `test/features/capture/rules/{numbers,dates,rule_parser}_test.dart`

**Interfaces:**
- Consumes: `normalizeForMatch`, `normalizeDigits`, `parseDecimalToMinor`, `kDefaultCategoryKeywords`.
- Produces:
  - `class Lexicon { final List<LexWorkspace> workspaces; final List<LexAccount> accounts; final List<LexCategory> categories; final List<LexBucket> buckets; final int personalWorkspaceId; final String baseCurrency; }` — each item has `id`, display `name`, and matchable `terms` (name, aliases, default and extra keywords) already passed through `normalizeForMatch`. `Future<Lexicon> loadLexicon(AppDatabase db, AppLocalizations l10n)`.
  - `class AmountMatch { final String digitsText; final String? currency; final int start, end; }` and `List<AmountMatch> findAmounts(String normalized)`: digits with separators; Arabic number words (واحد … تسعة، عشرة … تسعين، مية/ميتين … تسعمية، ألف/الف/آلاف/تلاف، مليون/ملايين), Sorani (یەک … هەزار، ملیۆن), English (one … thousand, million, `k`, `m`); «ونص» adds half of the preceding unit; «ربع»/«نص» before ألف/مليون; «ورقة» = 100 USD and «دفتر» = 10,000 USD (Decision 16). Currency words: دينار/دنانير/دینار/IQD/iqd/«ع» → IQD; دولار/دولارات/دۆلار/$/USD/usd/«اخضر» → USD.
  - `({DateTime? date, int? hour, int? minute}) findWhen(String normalized, DateTime now)`: اليوم/today/ئەمڕۆ, امس/البارحة/yesterday/دوێنێ, باجر/بكرة/غدا/tomorrow/سبەی, عقب باجر/بعد بكرة, weekday names (next occurrence; today's name → today), «بالساعة 11»/«at 11»/«الساعة ١١ونص», «الصبح/صباحا/am» and «بالليل/مساء/العصر/pm».
  - `enum IntentType { expense, income, transfer, task, debtPayment, note }`.
  - Proposal classes (all fields nullable except `type`, `confidence` 0–100 int):
    - `MoneyProposal { IntentType type; int? amountMinor; String? currency; int? accountId; int? workspaceId; int? categoryId; DateTime? occurredAt; String? description; String? bucketTag; int confidence; }`
    - `TransferProposal { int? fromAccountId; int? toAccountId; int? amountMinor; int? toAmountMinor; int? rateE6; String? transferKind; DateTime? occurredAt; int confidence; }`
    - `DebtProposal { String? counterparty; String? direction; String? leg; int? amountMinor; String? currency; int? accountId; DateTime? occurredAt; int confidence; }`
    - `TaskProposal { String title; DateTime? due; int? workspaceId; int confidence; }`, `NoteProposal { String text; int? workspaceId; }`
    - `sealed class Proposal` over those five, plus `TransactionDraft toTransactionDraft()` / `TransferDraft toTransferDraft()` adapters for the Task 9 forms.
  - `abstract interface class IntentParser { Future<List<Proposal>> parse(String transcript, Lexicon lex, DateTime now); }`
  - `class RuleParser implements IntentParser`:
    - Splits clauses on newlines, `.`, `،`, and «وبعدين» / «and then» / «پاشان».
    - Intent cues (normalized, editable later): income «استلمت، قبضت، وصلني، دخلي، راتب، received, got paid, وەرگرت»; transfer «حولت، نقلت، من … الى/لـ، transfer, گواستمەوە»; exchange: «صرفت/صرّفت» with **two** amounts in different currencies, or «صرفت … دولار ب …» → `TransferProposal` IQD↔USD with the implied rate; debt «سلفة، دين، دينت، تسلفت، رجعلي، سددت، قسط، owe, loan, قەرز»; task «ذكرني، لازم، اتصل، موعد، اجتماع، remind, call, meeting, بیرم بخەرەوە»; note «ملاحظة، note، تێبینی». No cue + amount → expense. No amount and no other cue → task.
    - Resolution: workspace by term match, else Personal; currency from the amount, else the account match, else `baseCurrency`; account = the workspace's non-archived account in that currency, else `null`; category by keyword in the clause (longest match wins); description = the clause with the amount, currency and date words removed, trimmed.
    - `confidence`: start 100; −40 no amount (money intents); −20 no category; −20 no account; −10 per ambiguous match (two categories with equal-length hits).
  - `const kLowConfidence = 60`.

- [ ] **Step 1: Write the failing tests** — the `amount phrases` table test and the parse table

```dart
final amounts = {
  'صرفت ٢٥ ألف على الغدا': (25000, 'IQD'),
  'خمسة وعشرين الف دينار': (25000, 'IQD'),
  'ربع مليون': (250000, null),
  'مليون ونص': (1500000, null),
  '12.5 دولار': (1250, 'USD'),
  '١٢٫٥ $': (1250, 'USD'),
  'ورقة': (10000, 'USD'),
  'دفترين': (2000000, 'USD'),
  '25k': (25000, null),
  'سێ هەزار دینار': (3000, 'IQD'),
};
test('amount phrases', () { /* each → minor in the given currency (base IQD when null) */ });
test('expense, workspace and category', () async {
  final p = (await parser.parse('دفعت 40 الف تكسي لبزفاي', lex, now)).single as MoneyProposal;
  expect((p.type, p.amountMinor, p.accountId, p.categoryId), (IntentType.expense, 40000, f.buzzIqd, f.cat('transport')));
});
test('no workspace → Personal; USD picks the USD account', ...);
test('income cue', ...);  // 'استلمت 500 دولار من العميل' → income, personalUsd
test('exchange: صرفت 100 دولار ب 131 الف → transfer USD→IQD with rate 1310', ...);
test('two clauses → two proposals', ...);  // 'تغديت ب 15 الف وبعدين بانزين 20 الف'
test('task with tomorrow at 11', ...);      // 'ذكرني اتصل بالعميل باجر الساعة 11' → TaskProposal due tomorrow 11:00
test('debt repayment', ...);                // 'رجعلي احمد 50 الف من السلفة' → DebtProposal owed_to_me repayment
test('no amount → task with confidence ≥ 60; expense without amount → confidence < 60', ...);
test('english and mixed: "lunch 15k buzzify"', ...);
test('yesterday sets occurredAt to yesterday at the current time', ...);
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(capture): offline rule parser for money, transfers, debts and tasks`

---

### Task 16: Captures store, validation and committing

**Files:**
- Create: `lib/features/capture/domain/intent_validator.dart`, `lib/features/capture/data/capture_repository.dart`, `capture_committer.dart`
- Test: `test/features/capture/domain/intent_validator_test.dart`, `test/features/capture/data/capture_repository_test.dart`, `capture_committer_test.dart`

**Interfaces:**
- Consumes: proposals and `Lexicon` (Task 15); repositories (Tasks 3, 5, 6).
- Produces:
  - The AI JSON schema (also used in the Task 17 prompt):
    ```
    {"intents":[{"type":"expense|income|transfer|task|debt_payment|note",
      "amount":"<decimal string>|null","currency":"IQD|USD|null",
      "to_amount":"<decimal string>|null","to_currency":"IQD|USD|null",
      "workspace":"<name>|null","account":"<name>|null","to_account":"<name>|null",
      "category":"<name>|null","date":"YYYY-MM-DD|null","time":"HH:MM|null",
      "description":"<text>|null","title":"<text>|null",
      "counterparty":"<text>|null","debt_direction":"owed_to_me|owed_by_me|null","debt_leg":"principal|repayment|null"}]}
    ```
  - `List<Proposal> validateIntents(Object? json, Lexicon lex, DateTime now)`: throws `InvalidAiOutput` when the root or any intent breaks the schema (wrong type, unknown keys, amount not matching `^\d{1,15}(\.\d{1,6})?$`, more than 10 intents, any string over 300 chars). Names that don't match an existing item become `null` fields (the owner fills them in review), not a failure. Then the same resolution defaults as `RuleParser` (Personal, account by currency).
  - `class CaptureRepository { Future<int> createVoice(Uint8List wav); Future<int> createText(String text); Future<void> setTranscript(int id, String t); Future<void> setParsed(int id, List<Proposal> p, {required String by}); Future<void> setFailure(int id, String errorType); Future<void> markDone(int id); Future<void> discard(int id); Stream<List<Capture>> watchPending(); Future<Capture?> get(int id); Future<int> pendingCount(); }` — `markDone` and `discard` null the `audio` column; `setFailure` stores the error **type** only.
  - `String encodeProposals(List<Proposal>)` / `List<Proposal> decodeProposals(String)` for `parsedJson` (stable JSON, round-trips).
  - `class CaptureCommitter { Future<void> commit(int captureId, List<CommitItem> items); }` where `CommitItem` is `MoneyCommit(MoneyProposal p, Map<int,int>? allocation)`, `TransferCommit(TransferProposal p)`, `DebtCommit(DebtProposal p, int? debtId)`, or `KeepInInbox(Proposal p)`. Money and transfer items are written with `captureId` set; everything plus `markDone` runs in **one** DB transaction. If any `KeepInInbox` item exists, a new pending text capture holding just those proposals is created instead of losing them (Decision 3). Incomplete money items (null amount or account) → `ArgumentError` before anything is written.

- [ ] **Step 1: Write the failing tests**

```dart
test('valid AI json → proposals with resolved ids', ...);
test('amount 25000.5 for IQD rounds half-even to 25000 and keeps the proposal', ...);
test('amount as a number (not string) → InvalidAiOutput', ...);
test('unknown key → InvalidAiOutput', ...);
test('unknown category name → categoryId null, not a failure', ...);
test('11 intents → InvalidAiOutput', ...);
test('proposals json round-trip', ...);
test('commit writes expense and transfer atomically and marks done; audio removed', ...);
test('commit failure in the second item leaves nothing written and capture pending', ...);
test('task proposal is kept as a new pending capture', ...);
test('setFailure stores only the type name', () async { await repo.setFailure(id, 'SocketException'); /* failureType == 'SocketException' */ });
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(capture): capture drafts, AI output validation, atomic commit`

---

### Task 17: Groq client, AI settings, consent and the LLM parser

Load `impeccable` before the settings screen step.

**Files:**
- Create: `lib/core/net/http_port.dart`, `lib/features/capture/ai/{ai_config,consent,ai_payload,groq_client,llm_parser}.dart`, `lib/features/capture/ui/consent_sheet.dart`, `lib/features/settings/ai_settings_screen.dart`
- Modify: `pubspec.yaml` (`http`), `android/app/src/main/AndroidManifest.xml` (add `android.permission.INTERNET`; keep the comment updated), `test/android_config_test.dart` (INTERNET now required; `usesCleartextTraffic` absent or false), `lib/features/settings/settings_screen.dart` (AI row; Privacy text updated)
- Test: `test/features/capture/ai/{ai_payload,groq_client,llm_parser}_test.dart`, `test/features/settings/ai_settings_screen_test.dart`

**Interfaces:**
- Consumes: `SecureStore`, `SettingsRepository` (Task 4), `Lexicon`, `validateIntents` (Task 16), `RuleParser` (Task 15), `AppLogger`.
- Produces:
  - `abstract interface class HttpPort { Future<HttpReply> postJson(Uri u, Map<String, String> headers, String body, Duration timeout); Future<HttpReply> postMultipart(Uri u, Map<String, String> headers, Map<String, String> fields, String fileField, String fileName, Uint8List file, Duration timeout); Stream<List<int>> getStream(Uri u, Duration timeout); }`, `class HttpReply { final int status; final String body; }`, `class PackageHttpPort implements HttpPort` (`package:http`), and a `FakeHttpPort` in `test/helpers/fakes.dart` that records requests.
  - `const kGroqKeyStoreKey = 'groq_api_key_v1'`; `class GroqKeyStore { Future<Sensitive<String>?> read(); Future<void> write(Sensitive<String> key); Future<void> clear(); }` — trims; rejects empty.
  - `Future<bool> canUseOnline(AiFeature f)` in `ai_config.dart` (exposed as `canUseOnlineProvider`): true only when `aiOnlineEnabled`, a key exists and that feature's consent is `granted`.
  - `Map<String, Object> buildParsePayload(String transcript, Lexicon lex, DateTime now)` → exactly `{"transcript", "now" ("YYYY-MM-DDTHH:MM" local), "utcOffset" ("+03:00"), "accounts": [names], "workspaces": [{"name", "aliases": [..]}], "categories": [{"name", "kind"}], "buckets": [names]}`.
  - `const kParseSystemPrompt`: English text stating the task (extract intents from a possibly mixed Arabic/Kurdish/English transcript), the JSON schema from Task 16, "amounts as strings", "use only names from the lists or null", "never give financial or investment advice", "output only JSON".
  - `sealed class GroqError implements Exception`: `GroqUnauthorized` (401/403), `GroqRateLimited` (429), `GroqServerError(int status)`, `GroqNetworkError` (socket/timeout), `GroqBadResponse`. No field carries a body or the key.
  - `class GroqClient { GroqClient(HttpPort http, GroqKeyStore keys); Future<String> chatJson({required String model, required String system, required String user}); Future<String> transcribe({required String model, required Uint8List wav}); }` — base `https://api.groq.com/openai/v1`; chat: `POST /chat/completions` `{model, temperature: 0, response_format: {type: json_object}, messages: [system, user]}`, timeout 15 s, returns `choices[0].message.content`; STT: `POST /audio/transcriptions` multipart `file=capture.wav`, `model`, `response_format=json`, `temperature=0`, timeout 30 s, returns `text`. Header `Authorization: Bearer <key>`.
  - `class LlmParser implements IntentParser { LlmParser(GroqClient c, String Function() model, RuleParser fallback); }` — sends `buildParsePayload`, decodes, `validateIntents`; on any `GroqError`, `FormatException` or `InvalidAiOutput` it logs the error **type** and returns the rule parser's result. Exposes `String lastParsedBy` (`'ai'` / `'rules'`).
  - `Future<bool> ensureConsent(BuildContext c, AiFeature f)`: when consent is null, shows `ConsentSheet` (what is sent, to whom — Groq, Inc., servers in the US — what is never sent, and that it can be turned off in Settings → AI); stores granted/declined. Declined → offline path, never asked again.
  - Consent copy (en source; ar/ckb translated): voice — "Your voice recording is sent to Groq to turn it into text."; parse — "The text of what you said, today's date and time, and the names of your accounts, workspaces, categories and buckets are sent to Groq to fill in the form. Balances, past transactions and the vault are never sent."
  - **AI settings screen** (`/settings/ai`): online AI switch; Groq key field (obscured, paste, "saved" state shows only `••••` + last 4 chars, clear button); STT and LLM model name fields; per-feature consent state with reset; the two consent texts; offline Whisper model section (filled by Task 18); a "test key" button that calls `chatJson` with a fixed tiny prompt and reports ok / unauthorized / offline.

- [ ] **Step 1: Write the failing tests**

```dart
test('payload contains only the allowed keys and names', () async {
  // DB fixture with a transaction described 'SECRET-DESC-7731' of 987654 IQD, balances, a budget
  final body = jsonEncode(buildParsePayload('غدا 15 الف', lex, now));
  expect(jsonDecode(body).keys.toSet(), {'transcript','now','utcOffset','accounts','workspaces','categories','buckets'});
  for (final s in ['SECRET-DESC-7731', '987654', 'openingBalance']) { expect(body, isNot(contains(s))); }
});
test('chat request shape', () async {
  // FakeHttpPort: url https://api.groq.com/openai/v1/chat/completions, Bearer header,
  // response_format json_object, temperature 0, model from settings
});
test('401 → GroqUnauthorized; 429 → GroqRateLimited; timeout → GroqNetworkError', ...);
test('LlmParser falls back to rules on malformed json and logs only the type', () async {
  final lines = <String>[]; AppLogger.sink = lines.add;
  // fake returns '{"intents":[{"type":"expense","amount":15000}]}' (number, invalid)
  // → result equals RuleParser result; lastParsedBy == 'rules'; lines contain 'InvalidAiOutput' and not 'غدا'
});
test('canUseOnline false without key, without consent, or with AI disabled', ...);
test('key store never returns an empty key and Sensitive hides it', ...);
testWidgets('AI settings shows only the last 4 key chars', ...);
testWidgets('consent sheet declined → consent stored declined; not shown again', ...);
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** `flutter test` → PASS (including the updated `android_config_test`).
- [ ] **Step 5: Commit** — `feat(ai): Groq client, consent, minimal payload and validated LLM parsing`

---

### Task 18: Speech — recorder, Groq STT, on-device Whisper and model download

**Files:**
- Create: `lib/features/capture/speech/{recorder,speech_to_text,groq_stt,local_whisper_stt,model_manager}.dart`
- Modify: `pubspec.yaml` (`record`, `whisper_ggml`), `AndroidManifest.xml` (`android.permission.RECORD_AUDIO`), `test/android_config_test.dart`, `lib/features/settings/ai_settings_screen.dart` (model section), `integration_test/whisper_device_test.dart` (new)
- Test: `test/features/capture/speech/{model_manager,groq_stt,speech_selector}_test.dart`

**Interfaces:**
- Consumes: `GroqClient.transcribe`, `HttpPort.getStream`, `canUseOnline`, `SettingsRepository`.
- Produces:
  - **Step 0 ruling first:** add `whisper_ggml` (2.6.x), read its API and Android build notes, and confirm it accepts a model file path we provide and a 16 kHz mono WAV. If it can't, switch to `flutter_whisper_ggml` behind the same interface and record the ruling in the ledger. Neither may download models on its own or pull Google dependencies (check `./gradlew :app:dependencies` for `com.google.android.gms` / `firebase`: must be absent).
  - `abstract interface class AudioRecorderPort { Future<bool> ensurePermission(); Future<void> start(); Stream<double> get level; Future<Uint8List> stop(); Future<void> cancel(); }` — `RecordAudioRecorder` uses `record` with `RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1)` into `<cache>/capture_tmp/rec.wav`; `stop` reads the bytes and deletes the file; an app-start sweep deletes `capture_tmp/`. Hard cap 120 s (auto-stop).
  - `abstract interface class SpeechToText { Future<String> transcribe(Uint8List wav); }`; `GroqStt implements SpeechToText` (model from settings); `LocalWhisperStt implements SpeechToText` (language auto, model path from `ModelManager`; runs off the UI isolate as the plugin allows); `NoSpeechEngine` throws `SpeechUnavailable`.
  - `class WhisperModelSpec { final String id; final String fileName; final Uri url; final String sha256; final int sizeBytes; }` and `const kWhisperModels = {'small': ..., 'base': ...}` with `url = https://huggingface.co/ggerganov/whisper.cpp/resolve/main/<fileName>`. The implementer copies each file's SHA-256 and size from its Hugging Face file page into these constants (a test asserts 64 lowercase hex characters and a non-zero size).
  - `class ModelManager { Future<File?> installed(String id); Stream<ModelDownloadProgress> download(String id); Future<void> delete(String id); }` — streams to `<support>/models/<file>.part`, hashes while writing, renames only when the SHA-256 matches, else deletes the part file and throws `ModelChecksumMismatch`. Resumes by restarting (no partial resume). `sealed ModelDownloadProgress`: `Downloading(int received, int total)`, `Verifying`, `Installed`.
  - `Future<SpeechToText> pickSpeechEngine()` (provider): online Groq when `canUseOnline(AiFeature.voice)`, else local Whisper when the selected model is installed, else `NoSpeechEngine`. The pipeline (Task 19) also falls back from Groq to local on `GroqError`.
  - AI settings model section: selected model (small/base), install / delete buttons, progress, the size, and the note that Kurdish Sorani accuracy is weaker (spec §8.2).

- [ ] **Step 1: Write the failing tests**

```dart
test('download verifies sha256 and installs', ...);      // FakeHttpPort streams bytes whose sha matches a test spec
test('checksum mismatch deletes the part file and throws', ...);
test('kWhisperModels pins a 64-hex sha and size', ...);
test('GroqStt sends multipart file=capture.wav with the configured model', ...);
test('pickSpeechEngine: online when allowed; local when installed; NoSpeechEngine otherwise', ...);
// integration_test/whisper_device_test.dart (device only): transcribes a bundled 3-second English WAV fixture with ggml-base.
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** `flutter test` → PASS, then `flutter build apk --debug` → builds with the native plugin.
- [ ] **Step 5: Commit** — `feat(speech): recorder, Groq and on-device Whisper, verified model download`

---

### Task 19: Capture pipeline, mic FAB sheet and Capture Review

Load `impeccable` and `animate` before this task.

**Files:**
- Create: `lib/features/capture/capture_pipeline.dart`, `lib/features/capture/ui/{capture_sheet,capture_review_screen}.dart`
- Modify: `lib/features/shell/shell_scaffold.dart` (FAB tap / long-press), `lib/app/router.dart`
- Test: `test/features/capture/capture_pipeline_test.dart`, `test/features/capture/ui/capture_review_test.dart`, `capture_sheet_test.dart`

**Interfaces:**
- Consumes: Tasks 15–18, `TransactionFormScreen`/`TransferFormScreen` (Task 9), `AllocationEditor` (Task 9).
- Produces:
  - `sealed class CaptureOutcome`: `ReadyForReview(int captureId)`, `SavedToInbox(int captureId, String reasonKey)`.
  - `class CapturePipeline { Future<CaptureOutcome> fromVoice(Uint8List wav); Future<CaptureOutcome> fromText(String text); Future<CaptureOutcome> reparse(int captureId); }`:
    1. Write the capture row first (`createVoice` / `createText`).
    2. Voice: STT engine from `pickSpeechEngine`; a `GroqError` falls back to local Whisper once; `SpeechUnavailable` or a second failure → `setFailure` → `SavedToInbox(id, 'noSpeechEngine' | 'sttFailed')` (audio kept).
    3. Store the transcript. Empty transcript → `SavedToInbox(id, 'empty')`.
    4. Parse with `LlmParser` when `canUseOnline(AiFeature.parse)`, else `RuleParser`; store with `parsedBy`.
    5. No proposals, or every money proposal below `kLowConfidence` → `SavedToInbox(id, 'lowConfidence')`; otherwise `ReadyForReview(id)`.
    Consent is asked by the UI before calling the pipeline (`ensureConsent`), never inside it.
  - Route `/capture/:id` → `CaptureReviewScreen(captureId)`.
  - **Capture sheet** (FAB): tap → bottom sheet that starts recording at once (permission asked on first use), shows a live level meter, elapsed time and the 120 s cap, Stop and Cancel; then a "processing" state; then it navigates to review or shows a snackbar "saved to Inbox" with an Open action. Long-press → a sheet with a multiline text field and Send, plus the manual-form shortcuts row (expense, income, transfer; task, vault item and note disabled with their phase). Reduced motion: no pulsing meter animation.
  - **Capture Review:** the transcript (editable, with "parse again" → `reparse`), one card per proposal with keep/drop, editable fields (type, amount via `AmountField`, account, category, date, description, bucket tag; transfer amounts and rate; debt counterparty and leg; task/note shown read-only with "kept in Inbox until Phase 4"), the "Allocate to buckets" toggle on income with `AllocationEditor`, a badge saying whether AI or the offline parser filled it, Save (→ `CaptureCommitter.commit`), and "keep in Inbox". Back without saving leaves the capture pending. Cards with missing required fields block Save and are highlighted.

- [ ] **Step 1: Write the failing tests**

```dart
group('pipeline fallbacks', () {
  test('row exists before any network call', ...);            // FakeHttpPort asserts captureRepo.pendingCount() == 1 on first request
  test('Groq STT network error → local whisper used', ...);
  test('no engine → SavedToInbox noSpeechEngine with audio kept', ...);
  test('LLM 429 → rules parse, ReadyForReview, parsedBy rules', ...);
  test('LLM malformed and rules find nothing → SavedToInbox lowConfidence', ...);
  test('offline text capture never touches HttpPort', ...);
});
testWidgets('review: two proposals, drop one, save → one transaction with captureId; capture done', ...);
testWidgets('review: missing account blocks Save', ...);
testWidgets('review: editing transcript and parse again replaces the cards', ...);
testWidgets('fab long-press opens the text sheet; send runs fromText', ...);
testWidgets('first voice use shows the consent sheet before recording uploads', ...);
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** `flutter test` → PASS.
- [ ] **Step 5: Commit** — `feat(capture): pipeline, mic sheet and Capture Review`

---

### Task 20: Inbox and "finish with AI"

Load `impeccable` before this task.

**Files:**
- Create: `lib/features/capture/ui/inbox_screen.dart`
- Modify: `lib/features/shell/home_screen.dart` (Inbox icon with a count badge in the app bar), `lib/features/finance/ui/finance_overview_screen.dart` (Inbox tile), `lib/app/router.dart` (`/inbox`)
- Test: `test/features/capture/ui/inbox_screen_test.dart`

**Interfaces:**
- Consumes: `CaptureRepository.watchPending`, `CapturePipeline.reparse`, `canUseOnline`.
- Produces:
  - Rows show: source icon, time, transcript preview (or "voice, not transcribed yet"), the reason (`failureType` mapped to a friendly line; never the raw type), and for kept task/note proposals "will become a task / note in Phase 4".
  - Actions per row: Open review (when it has proposals), Transcribe / Parse again (offline engines), **Finish with AI** (shown only when online AI is allowed for the needed features; asks consent first), Discard (confirm; deletes audio).
  - Header action "Finish all with AI" runs `reparse` sequentially with a progress line and stops on the first `GroqUnauthorized`.

- [ ] **Step 1: Write the failing widget tests**
  - A voice capture without transcript shows Transcribe and, with AI allowed, Finish with AI.
  - Finish with AI on a low-confidence draft with a fake LLM reply opens the review.
  - Discard asks for confirmation and removes the row; the Home badge count drops by one.
  - With online AI disabled, no "Finish with AI" button appears anywhere.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(capture): inbox with offline retry and finish-with-AI`

---

## Integration and release

### Task 21: Home cards, backup of the Groq key, v1 backup compatibility

Load `impeccable` and `dataviz` before this task.

**Files:**
- Modify: `lib/features/shell/home_screen.dart`, `lib/features/backup/backup_service.dart`, `lib/features/backup/backup_screen.dart` (copy only)
- Test: `test/features/shell/home_finance_cards_test.dart`, `test/features/backup/backup_service_test.dart` (extend), `test/fixtures/backup/v1_backup.plmbackup` (generated by a test helper from the Phase 1 schema via `test/core/db/generated/schema_v1.dart`, cheap KDF, invented data)

**Interfaces:**
- Consumes: Tasks 3–7, 16 (`pendingCount`), 17 (`GroqKeyStore`); Phase 1 `BackupService`.
- Produces:
  - Home: the Phase 1 placeholder cards for month summary, chart and buckets become real — month income / expense / surplus tiles (base currency, `HowConvertedSheet` on tap), income vs expense for the last 6 months (`IncomeExpenseChart` from Task 11), bucket progress bars, the consolidated balance card (replacing the accounts card's plain list with balances), and the alerts card. Tasks and upcoming-payments cards stay placeholders for Phases 4–5. Vault content never appears.
  - `BackupService.createBackup` adds payload entry `secrets/groq_api_key` (UTF-8 key) only when a key is set. `restore` writes it back with `GroqKeyStore.write` after the DB swap succeeds, or clears the stored key when the backup has none. A backup without the entry (all Phase 1 backups) restores fine.
  - Restore of a schema-1 backup: allowed (1 ≤ 2); Drift migrates on the next open.

- [ ] **Step 1: Write the failing tests**
  - `restores a v1 backup and migrates`: restore the v1 fixture, reopen → schema 2, 4 workspaces, 6 accounts, 16 categories, settings preserved.
  - `groq key round-trips inside the encrypted body`: set key `gsk_TEST_ONLY_0000`, back up, assert the file bytes don't contain it, clear the store, restore, read it back.
  - `backup bytes contain no transaction description plaintext` (description `SECRET-DESC-7731`).
  - Home shows the 6-month chart with exact bar values from a fixture and the Expenses bucket bar.
  - Home at 320 px in `ckb` with a 999,999,999,999 IQD month total renders without overflow.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** `flutter test` → PASS.
- [ ] **Step 5: Commit** — `feat(home): finance cards; backup carries the Groq key; v1 restore`

---

### Task 22: UI review, release APK and install notes

**Files:**
- Modify: `pubspec.yaml` (`version: 1.1.0+2`), `lib/main.dart` (`kAppVersion = '1.1.0'`), `docs/INSTALL.md`, `PRODUCT.md` (Operating Context: Phase 2 done), `android/app/proguard-rules.pro` (keep rules the whisper plugin documents)
- Test: `test/ui/worst_case_test.dart` (extend)

- [ ] **Step 1: Worst-case pass** — run `break-ui` on Finance Overview, History, Transaction form, Capture Review, Inbox and Reports; then `21st-ui-review` principles on the same screens (RTL, contrast, 48 dp targets, reduced motion). Add one worst-case widget test per screen found broken (80-char names, 999,999,999,999 IQD, zero rows, 5,000 history rows scroll, Sorani at 320 px). Fix what breaks.
- [ ] **Step 2: Run** `flutter analyze` and `flutter test`. Expected: no issues; all tests passed.
- [ ] **Step 3: Run** `flutter build apk --release`. Expected: `√ Built build\app\outputs\flutter-apk\app-release.apk`. Then check with `aapt dump permissions`: exactly `INTERNET`, `RECORD_AUDIO`, `USE_BIOMETRIC` (plus any the plugins document as required — list them in the ledger); no `com.google.android.gms` classes (`apkanalyzer dex packages … | grep -c com.google.android.gms` → 0).
- [ ] **Step 4: If a phone is connected,** run `flutter test integration_test -d <id>` (Phase 1 crypto and SQLCipher tests plus `whisper_device_test`). If not, record in INSTALL.md that they still need to run.
- [ ] **Step 5: Update `docs/INSTALL.md`** (Arabic, then English): updating over Phase 1 keeps data (same signing key; take a backup first anyway), creating a free Groq key and pasting it in Settings → AI, downloading the offline speech model over Wi-Fi (size), what is sent to Groq, and how to turn online AI off.
- [ ] **Step 6: Commit** — `chore(release): phase 2 release build, UI review fixes, install notes`

---

## Next steps (separate plans, not part of this one)

- **Before or during execution:** if the owner shares an anonymised sample of their Excel sheet, add it as a fixture in Task 13 and tune the Task 14 header guesses to it.
- **Phase 3 — Vault:** key hierarchy (VDK wrapped by master password, recovery key and biometric key), CRUD, generator, import from notes, clipboard handling, and the written security self-review.
- **Phase 4 — Tasks:** task model and views, calendar, notifications and reminders (which also take over the Phase 2 bucket/budget/debt alerts as system notifications), share-intent, meeting notes and action points, and turning Inbox task/note drafts into real items.
- **Phase 5 — Home and Reminders:** the full customizable Home (layout B), the Reminders screen, recurring payments, universal search, and the weekly backup reminder.
- **Phase 6 — Future Projects** with the AI assistant.
