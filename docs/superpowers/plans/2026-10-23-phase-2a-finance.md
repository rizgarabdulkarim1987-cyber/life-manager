# Phase 2A — Finance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An installable release APK where the owner can run their whole money life in the Finance tab:
- accounts with live balances in IQD and USD
- income, expenses, refunds, adjustments, transfers and owner draws
- a manual exchange rate with history
- the three buckets, with alerts
- monthly budgets
- debts and installments
- reports with charts
- CSV/PDF export
- import of their historical Excel/CSV file

Voice and sentence capture is **Phase 2B** (a separate plan), which builds on this one.

**Architecture:**
- Pure money math lives in `lib/core/money/` with no Flutter or DB imports.
- Schema v2 adds the finance tables to the existing Drift/SQLCipher database, through a tested 1→2 migration.
- Each finance area is a folder under `lib/features/finance/<area>/` with one repository (all DB access), its screens and its providers.
- Reports are read-only query functions that return plain DTOs, so charts, PDF and CSV share one source of numbers.

**Tech Stack:** Flutter 3.47.7 / Dart 3.13, Riverpod, go_router and Drift with SQLCipher, all from Phase 1. New packages:
- `fl_chart` (charts, named in spec §6)
- `pdf` (PDF export, spec §6)
- `excel` (reading `.xlsx`)
- `csv` (reading CSV only; the CSV *exporter* is hand-written, spec §6)

**Spec:** `docs/superpowers/specs/2026-10-22-personal-life-manager-design.md`. Read §4, §5, §7, §10 (all of it), §13 (restore migrates older schemas), §14 phase 2, §17, and Appendix A "Finance" and "Tests".

## Global Constraints

- Everything from the Phase 1 plan's Global Constraints still holds: no Google, no telemetry, `FLAG_SECURE`, `minSdk 26`, locales `ar`/`en`/`ckb` with `ar` the default, dark theme by default, and the same theme tokens.
- No `INTERNET` permission in 2A. AI is 2B.
- Money is never `double`, anywhere: not in the DB, not in DTOs, not in charts' source data. Amounts are `int` minor units plus a 3-letter currency code. Minor-unit exponent: IQD = 0, USD = 2, others per ISO 4217 (§10.2). Charts may convert to `double` only inside the widget that draws them.
- Exchange rate = integer `rateMicros` (rate × 10⁶) with an `effectiveFrom` day; history is kept (§10.2).
- Conversion: `minor_out = round_half_even(minor_in × rate × 10^(exp_out − exp_in) / 10⁶)`, using `BigInt`, never `double` (§10.2).
- Transfers, including IQD↔USD exchanges, are never income or expense. A cross-currency transfer records both legs and the rate used (§10.2).
- A business → Personal move is a transfer unless tagged as an owner draw. A draw counts as an expense for the business and as income for Personal (§10.2).
- Buckets: Expenses, Emergency, Investment. Percentages are set by the owner, are never suggested by the app, and must sum to exactly 100%. Buckets are numbers only: allocating creates no transfers. Allocation is manual, per income, behind an "Allocate to buckets" toggle that is off by default. Past allocations never change (§10.3).
- Bucket figures are in the base currency (`AppSetting.baseCurrency`, default IQD), converted at the rate in effect on the income day. The Expenses bucket resets each calendar month; Emergency and Investment carry over (§10.3).
- Every consolidated figure has a "how converted" affordance: rate, rate date, and per-currency subtotals (§10.2).
- Days are stored as `int` day keys `yyyymmdd` in the device's local calendar (for example `20261023`), never as `DateTime`. This keeps month grouping exact and free of time-zone drift.
- Imports never use AI or the network (§10.3a).
- The CSV exporter is hand-written. Exports go through the system file picker, the same way `FilePickerBackupFiles` saves backups.
- Every user-facing string goes in all three ARB files (`app_en.arb`, `app_ar.arb`, `app_ckb.arb`). The Sorani strings are drafts (§15).
- No Arabic or Kurdish string is split per character. Every screen works in RTL, and at 2.0× text scale on a 360×640 phone.
- Owned by later plans, not 2A:
  - system notifications for bucket, budget and installment alerts (Phase 5, which adds `flutter_local_notifications`). 2A shows these alerts as in-app cards.
  - the quick "+" menu on the mic FAB, Capture Review and the Inbox (2B)
  - category keyword dictionaries (2B)
  - Home dashboard cards (Phase 5)
  - workspace editing (Phase 4, with workspaces' task side)
  - the optional transaction attachment from Appendix A (Phase 4, which adds the `Attachments` entity for notes and tasks too)

## Review Focus

1. **Amounts typed with Arabic-Indic digits or Arabic separators**, such as `١٬٥٠٠٬٠٠٠` or `۲۵٫۵۰`. Expect them read as 1,500,000 IQD and 25.50 USD. An amount with more decimals than the currency allows (`12.345` USD, `10.5` IQD) is rejected with a message, never rounded silently. Covered by Task 1 (`parseAmount` tests).
2. **No exchange rate set, or none on or before the day needed.** Expect a consolidated total or a bucket allocation to show "rate missing" with a link to set one, never a wrong total that silently skips USD, and never a crash. Covered by Task 2 (`rateOn returns null`) and Task 9 (`allocation needs a rate`).
3. **Editing or deleting one leg of a transfer or owner draw.** Expect both legs to change, or be deleted, together, and balances to stay consistent. Covered by Task 5 (`deleting either leg deletes both`, `editing amount updates both legs`).
4. **Restoring a Phase 1 backup (schema v1) into this app.** Expect it to migrate, keep every workspace and account, and add the default categories and buckets. Covered by Task 2 (`v1 database migrates to v2 keeping rows`) and Task 2 (`restores a schema-1 backup`).
5. **Importing the same file twice, or undoing an import.** Expect repeated rows flagged as duplicates and skipped by default. Undo removes exactly that batch's transactions and their bucket allocations, and nothing else. Covered by Task 13 (`second import flags duplicates`, `undo removes only that batch`).

---

### Task 1: Money core (currencies, conversion, parsing, formatting)

**Files:**
- Create: `lib/core/money/currency.dart`, `lib/core/money/money.dart`, `lib/core/money/convert.dart`, `lib/core/money/amount_input.dart`, `lib/core/money/day_key.dart`
- Modify: move `normalizeDigits` from `lib/features/lock/digits.dart` to `lib/core/text/digits.dart`, and update its two imports in `pin_service.dart`
- Test: `test/core/money/convert_test.dart`, `amount_input_test.dart`, `money_format_test.dart`, `day_key_test.dart`

**Interfaces:**
- Produces:
  - `int currencyExponent(String code)`: IQD 0, USD 2, EUR 2, GBP 2, TRY 2, JPY 0, KWD 3. Any other valid 3-letter code returns 2. Throws `ArgumentError` for codes that are not 3 uppercase letters.
  - `class Money { const Money(this.minor, this.currency); final int minor; final String currency; Money operator +(Money o); Money operator -(Money o); Money operator -(); }`. Equality is by value. `+`/`-` throw `ArgumentError` on mixed currencies.
  - `int roundHalfEven(BigInt numerator, BigInt denominator)`: handles negative numerators symmetrically.
  - `int convertMinor({required int minor, required String from, required String to, required int rateMicros})`: `rateMicros` is the price of 1 `from` unit in `to` units × 10⁶.
  - `int convertMinorInverse({required int minor, required String from, required String to, required int rateMicros})`: `rateMicros` is the price of 1 `to` unit in `from` units × 10⁶. Formula: `round_half_even(minor × 10⁶ × 10^(exp_to − exp_from) / rateMicros)`.
  - `sealed class AmountParse`, with `AmountOk(int minor)`, `AmountEmpty()`, `AmountInvalid()`, `AmountTooManyDecimals(int allowed)` and `AmountTooLarge()`.
  - `AmountParse parseAmount(String input, String currency)`. Rules:
    - Normalize Arabic-Indic and Extended Arabic-Indic digits.
    - The decimal separator is `.` or `٫` (U+066B). Group separators `,`, `٬` (U+066C), space and NBSP are dropped.
    - Leading or trailing spaces are allowed. A sign is not allowed (the type gives the direction).
    - Magnitude limit: 10¹⁵ minor units.
  - `String formatMoney(Money m, String localeCode, {bool withCode = true})`: uses `intl` `NumberFormat` with exactly `currencyExponent` decimals. Western digits in `en`, Arabic-Indic digits in `ar` and `ckb` (`NumberFormat('#,##0', 'ar')` does this). Example: `formatMoney(Money(150000, 'USD'), 'en')` returns `'1,500.00 USD'`.
  - `int dayKey(DateTime local)` returns `yyyy*10000 + mm*100 + dd`. `DateTime dayFromKey(int key)` returns local midnight. `int monthKey(int dayKey)` returns `dayKey ~/ 100`, for example `202610`.

- [ ] **Step 1: Write the failing tests**

```dart
// convert_test.dart — 1 USD = 1,310 IQD → rateMicros 1310000000
test('USD→IQD', () => expect(convertMinor(minor: 150000, from: 'USD', to: 'IQD', rateMicros: 1310000000), 1965000));
test('IQD→USD inverse rounds half-even', () {
  // 655 IQD / 1310 = 0.50 USD = 50 minor exactly; 1 IQD → 0.0763… cents → 0
  expect(convertMinorInverse(minor: 655, from: 'IQD', to: 'USD', rateMicros: 1310000000), 50);
  expect(convertMinorInverse(minor: 1, from: 'IQD', to: 'USD', rateMicros: 1310000000), 0);
});
test('half-even ties', () {
  expect(roundHalfEven(BigInt.from(5), BigInt.from(2)), 2);   // 2.5 → 2
  expect(roundHalfEven(BigInt.from(7), BigInt.from(2)), 4);   // 3.5 → 4
  expect(roundHalfEven(BigInt.from(-5), BigInt.from(2)), -2);
});
test('no precision loss at 10^15 minor', () =>
    expect(convertMinor(minor: 1000000000000000, from: 'IQD', to: 'IQD', rateMicros: 1000000), 1000000000000000));
// amount_input_test.dart
test('arabic-indic with arabic group separator', () => expect(parseAmount('١٬٥٠٠٬٠٠٠', 'IQD'), const AmountOk(1500000)));
test('persian digits with arabic decimal', () => expect(parseAmount('۲۵٫۵۰', 'USD'), const AmountOk(2550)));
test('USD 3 decimals rejected', () => expect(parseAmount('12.345', 'USD'), const AmountTooManyDecimals(2)));
test('IQD decimals rejected', () => expect(parseAmount('10.5', 'IQD'), const AmountTooManyDecimals(0)));
test('empty / garbage / negative', () {
  expect(parseAmount('  ', 'IQD'), isA<AmountEmpty>());
  expect(parseAmount('12a', 'IQD'), isA<AmountInvalid>());
  expect(parseAmount('-5', 'IQD'), isA<AmountInvalid>());
});
test('USD "7" → 700 minor', () => expect(parseAmount('7', 'USD'), const AmountOk(700)));
// money_format_test.dart
test('en USD', () => expect(formatMoney(const Money(150000, 'USD'), 'en'), '1,500.00 USD'));
test('ar IQD uses arabic-indic digits', () => expect(formatMoney(const Money(1500000, 'IQD'), 'ar'), contains('١')));
test('mixed-currency add throws', () => expect(() => const Money(1, 'IQD') + const Money(1, 'USD'), throwsArgumentError));
// day_key_test.dart
test('dayKey / monthKey', () { expect(dayKey(DateTime(2026, 10, 23, 23, 59)), 20261023); expect(monthKey(20261023), 202610); });
```

The `AmountParse` subclasses need value equality for `expect(..., const AmountOk(1500000))`.

- [ ] **Step 2: Run** `flutter test test/core/money`. Expected: FAIL (files missing).
- [ ] **Step 3: Implement** the five files and move `normalizeDigits`. `roundHalfEven` uses `BigInt` `~/` and `remainder`, comparing `2·|rem|` with `|den|`.
- [ ] **Step 4: Run** `flutter test test/core/money test/features/lock`. Expected: PASS.
- [ ] **Step 5: Commit** with message `feat(money): integer money math, half-even conversion, amount parsing`.

---

### Task 2: Schema v2, migration, finance defaults, exchange rates

**Files:**
- Modify: `lib/core/db/tables.dart`, `lib/core/db/app_database.dart` (`schemaVersion => 2`, `onCreate`/`onUpgrade`)
- Create: `lib/core/db/finance_defaults.dart`, `lib/features/finance/rates/rates_repository.dart`, `drift_schemas/drift_schema_v2.json` and `test/core/db/generated/schema_v2.dart` (both via `drift_dev`)
- Test: `test/core/db/migration_test.dart` (extend), `test/core/db/finance_defaults_test.dart`, `test/features/finance/rates/rates_repository_test.dart`, `test/features/backup/backup_service_test.dart` (add one test)

**Interfaces:**
- Produces new tables:
  - `Categories`:
    - `id` int pk
    - `systemKey` text nullable unique: a seeded category whose label comes from l10n
    - `name` text nullable 1..60: a custom category. Check: exactly one of `systemKey` or `name` is non-null.
    - `kind` text, check in (`expense`, `income`)
    - `iconKey` text
    - `colorArgb` int
    - `workspaceId` int nullable, references `Workspaces` `onDelete: setNull`
    - `sortOrder` int
    - `isArchived` bool default false
  - `Transactions`:
    - `id` int pk
    - `accountId` int, references `Accounts` `restrict`
    - `workspaceId` int, references `Workspaces` `restrict`
    - `categoryId` int nullable, references `Categories` `restrict`
    - `type` text, check in (`income`, `expense`, `refund`, `adjustment`, `transfer_out`, `transfer_in`, `debt_payment`)
    - `amountMinor` int: the **signed** change to the account balance, in the account's currency. income/refund/transfer_in are > 0; expense/transfer_out are < 0; adjustment and debt_payment are ≠ 0 with either sign.
    - `occurredOn` int: a day key
    - `description` text nullable ≤ 500
    - `transferGroup` text nullable: the same random 16-hex-char id on both legs
    - `isOwnerDraw` bool default false: only on transfer legs
    - `rateMicros` int nullable: set on both legs of a cross-currency transfer
    - `bucketKey` text nullable: `emergency` or `investment` when spending from that bucket
    - `debtId` int nullable, references `Debts` `restrict`
    - `importBatchId` int nullable, references `ImportBatches` `restrict`
    - `isPending` bool default false: the payment status from Appendix A
    - `createdAt` dateTime
    - `updatedAt` dateTime
    - Indexes on (`accountId`, `occurredOn`), (`occurredOn`), (`transferGroup`) and (`importBatchId`).
  - `ExchangeRates`:
    - `id` int pk
    - `fromCurrency` text(3)
    - `toCurrency` text(3)
    - `rateMicros` int > 0
    - `effectiveFrom` int: a day key
    - `createdAt` dateTime
    - unique (`fromCurrency`, `toCurrency`, `effectiveFrom`)
  - `Buckets`:
    - `id` int pk
    - `key` text unique, check in (`expenses`, `emergency`, `investment`)
    - `percentBp` int 0..10000 (basis points)
    - `targetMinor` int nullable: in the base currency
    - `sortOrder` int
  - `BucketAllocations`:
    - `id` int pk
    - `transactionId` int, references `Transactions` `cascade`
    - `bucketKey` text
    - `amountMinor` int: in the base currency
    - `baseCurrency` text(3)
    - `rateMicros` int nullable: null when the income was already in the base currency
    - `rateDay` int nullable
  - `Budgets`:
    - `id` int pk
    - `month` int: a month key
    - `categoryId` int nullable, references `Categories` `cascade`
    - `workspaceId` int nullable, references `Workspaces` `cascade`
    - `amountMinor` int > 0: in the base currency
    - Check: at least one of `categoryId` and `workspaceId` is set. Unique (`month`, `categoryId`, `workspaceId`).
  - `Debts`:
    - `id` int pk
    - `direction` text, check in (`owed_to_me`, `owed_by_me`)
    - `counterparty` text 1..80
    - `workspaceId` int, references `Workspaces` `restrict`
    - `currencyCode` text(3)
    - `principalMinor` int > 0
    - `startedOn` int
    - `notes` text nullable
    - `closedAt` dateTime nullable
    - `createdAt` dateTime
  - `Installments`:
    - `id` int pk
    - `debtId` int, references `Debts` `cascade`
    - `seq` int
    - `dueOn` int
    - `amountMinor` int > 0
    - unique (`debtId`, `seq`)
  - `ImportBatches`:
    - `id` int pk
    - `fileName` text
    - `rowCount` int
    - `createdAt` dateTime
    - `undoneAt` dateTime nullable
- Produces new settings columns on `AppSettingsTable`:
  - `unallocatedIncomeAlert` bool default false (§10.3)
  - `budgetAlertsEnabled` bool default true
- Produces `Future<void> seedFinanceDefaults(AppDatabase db)` (idempotent):
  - Expense categories by `systemKey`: `food`, `transport`, `rent`, `bills`, `family`, `shopping`, `health`, `business`, `marketing`, `subscriptions` (Appendix A).
  - Income categories: `salary`, `sales`, `client_payment`, `other_income` (builder's call; the spec lists none).
  - Buckets `expenses` 7000 bp, `emergency` 2000 bp, `investment` 1000 bp. Each bucket must exist and the total must be 100%, but the app must never *suggest* split numbers (§10.3). The Buckets screen (Task 9) therefore asks the owner to confirm or edit these on first open, and the defaults are never shown as advice.
- Migration:
  - `onCreate`: `createAll()` then `seedFinanceDefaults`.
  - `onUpgrade` from 1: create the new tables, add the two settings columns, then `seedFinanceDefaults`.
  - Everything runs in drift's migration transaction.
- Produces `class RatesRepository { RatesRepository(AppDatabase db); Future<void> setRate({required String from, required String to, required int rateMicros, required int effectiveFrom}); Future<RateOn?> rateOn({required String from, required String to, required int day}); Stream<List<ExchangeRate>> watchHistory(String from, String to); Future<Money?> convert(Money m, String to, int day); }`:
  - `class RateOn { final int rateMicros; final int effectiveFrom; final bool inverse; }`: the latest row with `effectiveFrom <= day` for the pair. If none exists, the reverse pair is used with `inverse: true`.
  - `convert` returns `m` unchanged when the currencies match, and `null` when no rate exists.
  - `setRate` with the same pair and day replaces that row.
- Add `ratesRepositoryProvider` to a new `lib/features/finance/finance_providers.dart`. Every later task adds its repository provider to this file.

- [ ] **Step 1: Write the failing tests**

```dart
// migration_test.dart
test('v1 database migrates to v2 keeping rows', () async {
  final schema = await verifier.schemaAt(1);
  final old = v1.DatabaseAtV1(schema.newConnection());
  await old.into(old.workspaces).insert(/* one workspace */);
  await old.into(old.accounts).insert(/* one IQD account, openingBalanceMinor 250000 */);
  await old.close();
  final db = AppDatabase(schema.newConnection());
  await verifier.migrateAndValidate(db, 2);
  expect((await db.select(db.accounts).getSingle()).openingBalanceMinor, 250000);
  expect(await db.select(db.categories).get(), hasLength(14));
  expect((await db.select(db.buckets).get()).fold<int>(0, (s, b) => s + b.percentBp), 10000);
});
// finance_defaults_test.dart
test('fresh v2 db has defaults once', () async { await seedFinanceDefaults(db); expect(await db.select(db.categories).get(), hasLength(14)); });
test('category needs exactly one of systemKey/name', ...); // both null → SqliteException; both set → SqliteException
// rates_repository_test.dart
test('rateOn picks latest effectiveFrom <= day', () async {
  await repo.setRate(from: 'USD', to: 'IQD', rateMicros: 1300000000, effectiveFrom: 20261001);
  await repo.setRate(from: 'USD', to: 'IQD', rateMicros: 1310000000, effectiveFrom: 20261020);
  expect((await repo.rateOn(from: 'USD', to: 'IQD', day: 20261019))!.rateMicros, 1300000000);
  expect((await repo.rateOn(from: 'USD', to: 'IQD', day: 20261020))!.rateMicros, 1310000000);
});
test('rateOn returns null before first rate', () async { /* day 20260901 → null */ });
test('reverse pair used as inverse', () async { /* IQD→USD lookup finds USD→IQD row, inverse true; convert(Money(1310000,'IQD'),'USD') == Money(100000,'USD') */ });
test('same pair+day replaces', ...);
// backup_service_test.dart
test('restores a schema-1 backup', () async { /* build payload from a v1 db via verifier.schemaAt(1); restore; workspaces kept; categories seeded */ });
```

- [ ] **Step 2: Run** `dart run build_runner build -d`, then `flutter test test/core/db test/features/finance/rates`. Expected: FAIL.
- [ ] **Step 3: Implement** the tables, the migration, `seedFinanceDefaults` and `RatesRepository`. Then run `dart run drift_dev schema dump lib/core/db/app_database.dart drift_schemas/` and `dart run drift_dev schema generate drift_schemas/ test/core/db/generated/`.
- [ ] **Step 4: Run** `flutter test`. Expected: all PASS, including every Phase 1 test.
- [ ] **Step 5: Commit** with message `feat(db): schema v2 finance tables, migration and exchange rates`.

---

### Task 3: Accounts and single-leg transactions

**Files:**
- Create: `lib/features/finance/accounts/accounts_repository.dart`, `lib/features/finance/transactions/transactions_repository.dart`, `lib/features/finance/transactions/txn_query.dart`
- Test: `test/features/finance/accounts/accounts_repository_test.dart`, `test/features/finance/transactions/transactions_repository_test.dart`

**Interfaces:**
- Consumes: `Money`, `dayKey` (Task 1); the tables (Task 2).
- Produces:
  - `class AccountBalance { final Account account; final Money balance; }`. The balance is `openingBalanceMinor + SUM(transactions.amountMinor)`.
  - `class AccountsRepository`:
    - `Stream<List<AccountBalance>> watchBalances({int? workspaceId, bool includeArchived = false});`
    - `Future<int> create({required int workspaceId, required String name, required String kind, required String currency, int openingMinor = 0});`
    - `Future<void> rename(int id, String name);`
    - `Future<void> archive(int id, bool archived);`
    - `Future<void> delete(int id);`: throws `AccountInUseException` when the account has transactions. The UI offers archive instead.
  - `class TxnDraft { int accountId; int workspaceId; int? categoryId; String type; int amountMinor /* unsigned, > 0 */; bool? adjustmentPositive; int occurredOn; String? description; String? bucketKey; bool isPending; }`
  - `class TransactionsRepository`:
    - `Future<int> add(TxnDraft d);`: for `income`, `expense`, `refund` and `adjustment` only. The sign is applied from `type`. Other types throw `ArgumentError`. Validation:
      - `amountMinor > 0`
      - an `income` category must be of kind `income`
      - an `expense`/`refund` category must be of kind `expense`
      - an `adjustment` has no category
      - `bucketKey` only on `expense`
    - `Future<void> update(int id, TxnDraft d);`: refuses transfer and debt-payment legs (those use Tasks 4 and 11).
    - `Future<void> delete(int id);`: when the row has a `transferGroup`, it deletes every row in that group in one DB transaction. Task 4's `deleteGroup` calls this same path, and Task 11 extends it for `debt_payment` rows (re-opening the debt).
    - `Stream<List<TxnRow>> watch(TxnQuery q);`
  - `class TxnQuery { int? fromDay, toDay; Set<int>? accountIds, workspaceIds, categoryIds; Set<String>? types; String? text; int limit = 200; int offset = 0; }`. Results are ordered by `occurredOn DESC, id DESC`. `text` is a case-insensitive match on `description`.
  - `class TxnRow { final Transaction txn; final Account account; final Category? category; }`

- [ ] **Step 1: Write the failing tests**
  - `balance = opening + income − expense`: opening 100000 IQD, income 50000, expense 20000, so the balance is 130000.
  - `expense stored negative`: `add(type: 'expense', amountMinor: 5000)` stores −5000.
  - `adjustment negative`: with `adjustmentPositive: false`, stores −300.
  - `income with expense category throws ArgumentError`.
  - `zero amount throws`.
  - `delete account with transactions throws AccountInUseException; archive works and hides it from watchBalances()`.
  - `query filters`: three transactions over two days and two accounts. Filtering by `accountIds`, by day range and by `text` each returns the expected ids in date-descending order.
- [ ] **Step 2: Run** `flutter test test/features/finance`. Expected: FAIL.
- [ ] **Step 3: Implement.** Balances use one `SELECT … SUM … GROUP BY account_id` watched query, not one query per account.
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** with message `feat(finance): accounts with balances and transaction repository`.

---

### Task 4: Transfers and owner draws

**Files:**
- Create: `lib/features/finance/transactions/transfers_repository.dart`
- Test: `test/features/finance/transactions/transfers_repository_test.dart`

**Interfaces:**
- Consumes: `convertMinor`, `convertMinorInverse` (Task 1); `RatesRepository` (Task 2); the tables.
- Produces:
  - `class TransferDraft { int fromAccountId; int toAccountId; int amountOutMinor /* > 0, in the from-account's currency */; int? amountInMinor; int? rateMicros; bool isOwnerDraw; int occurredOn; String? description; }`
  - Rules:
    - Same currency: `amountInMinor` defaults to `amountOutMinor` and must equal it. `rateMicros` must be null.
    - Different currencies: the caller gives `rateMicros`, quoted as "1 USD = N IQD" whichever way the money moves. `amountInMinor` defaults to the converted amount and may be overridden, because the owner can type the cash actually received. The stored `rateMicros` is the one the owner entered.
    - `fromAccountId == toAccountId` throws.
    - `isOwnerDraw` requires the from-workspace ≠ the to-workspace, and the to-workspace must be Personal (the seeded workspace with `sortOrder 0`).
  - `class TransfersRepository`:
    - `Future<String> add(TransferDraft d);`: inserts a `transfer_out` leg (−out) and a `transfer_in` leg (+in) with the same new `transferGroup`, in one DB transaction. Each leg's `workspaceId` is its account's workspace.
    - `Future<void> update(String group, TransferDraft d);`
    - `Future<void> deleteGroup(String group);`
    - `Future<TransferDraft> load(String group);`

- [ ] **Step 1: Write the failing tests**
  - `same-currency transfer moves balance, net zero`.
  - `USD→IQD exchange records both legs and rate`: 100.00 USD out at 1310 means −10000 USD and +131000 IQD, with `rateMicros` 1310000000 on both legs.
  - `IQD→USD exchange computes amountIn with inverse`: 131000 IQD gives +10000 USD.
  - `amountIn override kept`.
  - `deleting either leg deletes both`: `TransactionsRepository.delete(outLegId)` leaves no rows in the group.
  - `editing amount updates both legs`.
  - `owner draw to non-Personal throws`.
  - `same account throws`.
- [ ] **Step 2: Run.** Expected: FAIL. **Step 3: Implement.** **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** with message `feat(finance): transfers, currency exchange and owner draws`.

---

### Task 5: Categories repository and management screen

**Files:**
- Create: `lib/features/finance/categories/categories_repository.dart`, `lib/features/finance/categories/categories_screen.dart`, `lib/features/finance/categories/category_label.dart`
- Modify: `lib/l10n/app_*.arb`, `lib/features/settings/settings_screen.dart` (new "Categories" tile), `lib/app/router.dart` (`/settings/categories`)
- Test: `test/features/finance/categories/categories_repository_test.dart`, `categories_screen_test.dart`

**Interfaces:**
- Produces:
  - `String categoryLabel(BuildContext c, Category cat)`: the l10n string for `systemKey` (keys `cat_food` … `cat_other_income`), otherwise `name`.
  - `class CategoriesRepository`:
    - `Stream<List<Category>> watch({String? kind, bool includeArchived = false});`
    - `Future<int> create({required String name, required String kind, required String iconKey, required int colorArgb, int? workspaceId});`
    - `Future<void> rename(int id, String name);`: on a system category this converts it to a custom one (it sets `name` and clears `systemKey`).
    - `Future<void> archive(int id, bool v);`
    - `Future<void> delete(int id);`: throws `CategoryInUseException` when transactions or budgets use it.
- The screen has Expense and Income tabs, a list with icon and color, add/rename/archive actions, and a delete action that falls back to an archive offer.

- [ ] **Step 1: Write the failing tests**
  - `rename system category keeps id and shows new name`.
  - `delete in-use throws CategoryInUseException`.
  - `archived hidden by default`.
  - Widget test: `labels are localized in ar and en`. The `food` category shows the Arabic label under `ar` and `Food` under `en`.
- [ ] **Step 2: Run.** Expected: FAIL. **Step 3: Implement.** **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** with message `feat(finance): categories with localized system labels and management screen`.

---

### Task 6: Finance overview and Accounts screens

**Files:**
- Create: `lib/features/finance/overview/finance_overview_screen.dart`, `lib/features/finance/overview/consolidated.dart`, `lib/features/finance/accounts/accounts_screen.dart`, `lib/features/finance/accounts/account_form.dart`, `lib/features/finance/widgets/money_text.dart`, `lib/features/finance/widgets/how_converted_sheet.dart`
- Modify: `lib/app/router.dart` (replace the `/finance` placeholder; add `/finance/accounts`), the ARB files
- Test: `test/features/finance/overview/consolidated_test.dart`, `finance_overview_screen_test.dart`, `test/features/finance/accounts/accounts_screen_test.dart`

**Interfaces:**
- Consumes: `AccountsRepository` (Task 3), `RatesRepository` (Task 2), `formatMoney` (Task 1).
- Produces:
  - `class Consolidated { final Money? total /* null when a needed rate is missing */; final Map<String, Money> byCurrency; final Map<String, RateOn> ratesUsed; final Set<String> missingRates; }`
  - `Future<Consolidated> consolidate(List<Money> amounts, String base, int day, RatesRepository rates)`
  - `MoneyText(Money m)`: renders with `formatMoney` using the current locale. Tabular figures. Danger color when negative.
  - `HowConvertedSheet(Consolidated c)`: shows the per-currency subtotals, each rate with its date, and the total (§10.2).
- Overview, top to bottom:
  - the consolidated balance card, which opens `HowConvertedSheet`. When `missingRates` is non-empty it shows "Set the USD rate", which opens the rate form.
  - this month's income, expense and surplus for all workspaces, in the base currency
  - alert cards (Tasks 9 and 10 add them)
  - a workspace filter chip row
  - entries for Accounts, History, Budgets, Buckets, Debts and Reports
  - an "Add" FAB that opens the transaction form (Task 7)
- The rate form lives in a bottom sheet shared with Settings: pair USD→IQD, "1 USD = [N] IQD", effective day (default today). Add a "Currency & exchange rate" tile to Settings (base currency picker IQD/USD, current rate, history list).
- The Accounts screen groups accounts by workspace, with a balance per account. It supports add/edit/archive, and turns a delete of an account that has transactions into an archive offer.

- [ ] **Step 1: Write the failing tests**
  - `consolidate with rate`: 100000 IQD plus 10000 USD at 1310 gives a total of 1410000 IQD, with both `byCurrency` entries.
  - `consolidate missing rate → total null, missingRates {'USD'}`.
  - Widget test: `overview shows rate-missing prompt instead of a total`. The seeded db has a USD income and no rate.
  - Widget test: `overview total after setting rate`.
  - Widget test: `accounts grouped by workspace in RTL`, under `ar`.
- [ ] **Step 2: Run.** Expected: FAIL. **Step 3: Implement.** **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** with message `feat(finance): overview with consolidated balance, accounts screen, rate settings`.

---

### Task 7: Add/edit transaction form

**Files:**
- Create: `lib/features/finance/transactions/transaction_form_screen.dart`, `lib/features/finance/transactions/transaction_form_controller.dart`, `lib/features/finance/widgets/amount_field.dart`
- Modify: `lib/app/router.dart` (`/finance/txn/new?type=` and `/finance/txn/:id`), the ARB files
- Test: `test/features/finance/transactions/transaction_form_test.dart`

**Interfaces:**
- Consumes: `parseAmount` (Task 1); `TransactionsRepository` (Task 3); `TransfersRepository` (Task 4); `CategoriesRepository` (Task 5).
- Produces:
  - `AmountField({required String currency, required ValueChanged<AmountParse> onChanged})`. It uses a decimal keyboard and accepts Arabic-Indic input. Under the field it shows the localized error for `AmountTooManyDecimals`, `AmountInvalid` and `AmountTooLarge`.
  - `TransactionFormScreen({String initialType = 'expense', int? editId, String? editTransferGroup})`:
    - A segmented type selector: Expense · Income · Transfer. "More" opens Refund and Adjustment.
    - Fields:
      - amount
      - account: grouped by workspace, showing the currency
      - category: filtered by kind, hidden for transfer and adjustment
      - date: defaults to today
      - description
      - workspace: defaults to the account's workspace; editable for single legs only
      - pending toggle
      - expense only: "Paid from bucket" (none, emergency, investment)
    - Transfer mode: from-account, to-account and amount-out. When the currencies differ it shows "1 USD = N IQD" (prefilled from `rateOn(today)`) and an editable amount-in. Owner-draw toggle, visible only for business → Personal.
    - Income mode adds the "Allocate to buckets" toggle (default off). Task 9 provides its content; this task leaves a slot `Widget? incomeExtras`.
    - Save is disabled until the form is valid. The form pops with a snackbar when done.
- The screen must fit a 360×640 phone at 2.0× text in `ckb`. The form scrolls, and the Save button stays pinned above the keyboard.

- [ ] **Step 1: Write the failing widget tests**
  - `typing ١٥٠٠٠ in IQD expense saves −15000`.
  - `USD 12.345 shows decimals error and Save disabled`.
  - `transfer USD→IQD shows rate field prefilled from latest rate and computed amount-in`.
  - `owner-draw toggle only for business→Personal`.
  - `edit transfer leg opens transfer mode with both legs`.
  - `fits 360x640 at 2.0x in ckb without overflow` (reuse the `test/ui/worst_case_test.dart` helpers).
- [ ] **Step 2: Run.** Expected: FAIL. **Step 3: Implement.** **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** with message `feat(finance): transaction form with transfers and Arabic-Indic amount entry`.

---

### Task 8: Transaction history screen

**Files:**
- Create: `lib/features/finance/transactions/history_screen.dart`, `lib/features/finance/transactions/history_filters_sheet.dart`
- Modify: `lib/app/router.dart` (`/finance/history`), the ARB files
- Test: `test/features/finance/transactions/history_screen_test.dart`

**Interfaces:**
- Consumes: `TransactionsRepository.watch(TxnQuery)` (Task 3).
- The list is grouped by day, with sticky day headers and a per-day net for each currency.
- A transfer shows as **one** row ("A → B", with both amounts when they differ). The row is built from the out-leg, and the in-leg is skipped.
- Filters: date range, account, workspace, category, type and search text.
- Swipe to delete asks first. A transfer delete says that both sides will be removed.
- Paging: 200 rows at a time, loading more on scroll.

- [ ] **Step 1: Write the failing widget tests**
  - `transfer appears once`.
  - `filter by workspace`.
  - `delete transfer removes both legs after confirm`.
  - `empty state when no transactions`.
  - `1,000 transactions scroll without exception` (break-ui worst case).
- [ ] **Step 2: Run.** Expected: FAIL. **Step 3: Implement.** **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** with message `feat(finance): transaction history with filters`.

---

### Task 9: Buckets: percentages, allocation, progress, alerts

**Files:**
- Create: `lib/features/finance/buckets/buckets_repository.dart`, `lib/features/finance/buckets/allocation.dart`, `lib/features/finance/buckets/buckets_screen.dart`, `lib/features/finance/buckets/allocate_section.dart`, `lib/features/finance/alerts/finance_alerts.dart`
- Modify: `transaction_form_screen.dart` (fill `incomeExtras`), `finance_overview_screen.dart` (alert cards), `settings_screen.dart` (the "Alert on unallocated income" switch, default off), the ARB files
- Test: `test/features/finance/buckets/allocation_test.dart`, `buckets_repository_test.dart`, `buckets_screen_test.dart`, `test/features/finance/alerts/finance_alerts_test.dart`

**Interfaces:**
- Consumes: `convertMinor` and `roundHalfEven` (Task 1); `RatesRepository` (Task 2); `TransactionsRepository` (Task 3).
- Produces:
  - `Map<String, int> splitByPercent(int totalMinor, Map<String, int> percentBp)`. It uses a largest-remainder split, so the parts always sum to `totalMinor` exactly. Ties go to bucket order: expenses, emergency, investment.
  - `class BucketsRepository`:
    - `Stream<List<Bucket>> watch();`
    - `Future<void> setPercents(Map<String, int> bp)`: throws `ArgumentError` unless the values sum to 10000 and each is 0..10000.
    - `Future<void> setTarget(String key, int? minor);`
    - `Future<void> allocate({required int transactionId, required Map<String, int> amountsBaseMinor, int? rateMicros, int? rateDay});`: only for `income` transactions; the amounts must sum to the converted income. Allocations are written once; re-allocating the same transaction throws.
    - `Future<void> clearAllocation(int transactionId);`: used only when the income itself is deleted or its amount edited. The form then asks the owner to allocate again.
    - `Stream<List<BucketProgress>> watchProgress(int monthKey);`
  - `class BucketProgress { String key; int allocatedMinor; int spentMinor; int balanceMinor; int? targetMinor; }`:
    - Expenses: allocated and spent within `monthKey` only. Spent is the sum of `−amountMinor` of expenses with no `bucketKey`, converted to base at each day's rate.
    - Emergency and Investment: everything up to the end of `monthKey`. Spent is the expenses tagged with that `bucketKey`.
  - `sealed class FinanceAlert`, with `ExpensesBucketAt(int percent /* 80 or 100 */)`, `EmergencyReachedTarget()`, `EmergencyBelowTarget()`, `UnallocatedIncome(int count)` and `RateMissing(String currency)`. `Stream<List<FinanceAlert>> watchFinanceAlerts(int monthKey)` (Task 10 adds the budget alerts here).
- `AllocateSection` (in the income form) has the toggle, off by default. When it is turned on, it pre-fills `splitByPercent` of the converted amount and each bucket's amount stays editable. The sum must equal the total before saving. If the income is not in the base currency and no rate exists, the toggle shows "Set a rate to allocate" and is disabled.
- `BucketsScreen` has the percentages editor, with a live sum and Save disabled unless the sum is 100%; a target per bucket; and a progress bar per bucket with `HowConvertedSheet` access. On first open, while percentages have never been confirmed, a banner says "Set your own percentages", and no advice text is shown. A bool settings column `bucketsConfirmed` is added in this task's migration step. (It is still schema v2, because v2 has not shipped yet: edit the v2 table definition and re-dump.)

- [ ] **Step 1: Write the failing tests**

```dart
test('largest remainder sums exactly', () {
  final s = splitByPercent(1000001, {'expenses': 7000, 'emergency': 2000, 'investment': 1000});
  expect(s.values.reduce((a, b) => a + b), 1000001);
});
test('percents must sum to 100%', () => expect(() => repo.setPercents({'expenses': 7000, 'emergency': 2000, 'investment': 900}), throwsArgumentError));
test('past allocations unchanged after percent change', () async { /* allocate, change percents, allocation rows identical */ });
test('USD income allocates in base IQD at income-day rate', () async { /* 100.00 USD at 1310 → 131000 IQD split */ });
test('allocation needs a rate', () async { /* USD income, no rate → allocate throws RateMissingException; alerts include RateMissing('USD') */ });
test('expenses bucket resets monthly, emergency carries over', () async { /* allocations in Sep and Oct; progress(202610) */ });
test('expense alert at 80 and 100 percent', () async { /* allocated 100000; spend 80000 → ExpensesBucketAt(80); 100000 → ExpensesBucketAt(100) */ });
test('unallocated alert only when setting on', ...);
// buckets_screen_test.dart
testWidgets('save disabled until sum is 100%', ...);
```

- [ ] **Step 2: Run.** Expected: FAIL. **Step 3: Implement.** **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** with message `feat(finance): buckets with manual allocation, progress and alerts`.

---

### Task 10: Monthly budgets

**Files:**
- Create: `lib/features/finance/budgets/budgets_repository.dart`, `lib/features/finance/budgets/budgets_screen.dart`
- Modify: `finance_alerts.dart` (budget alerts), `lib/app/router.dart` (`/finance/budgets`), the ARB files
- Test: `test/features/finance/budgets/budgets_repository_test.dart`, `budgets_screen_test.dart`

**Interfaces:**
- Produces:
  - `class BudgetStatus { Budget budget; int actualMinor; int remainingMinor; int percentUsed /* integer, floor, may exceed 100 */; }`. Actual is the expenses minus refunds in that month that match the budget's category and/or workspace, converted to base at each day's rate.
  - `class BudgetsRepository`:
    - `Stream<List<BudgetStatus>> watch(int monthKey);`
    - `Future<void> upsert({required int month, int? categoryId, int? workspaceId, required int amountMinor});`
    - `Future<void> delete(int id);`
    - `Future<int> copyFromPreviousMonth(int monthKey);`: copies the budgets that do not exist yet, and returns the number copied.
  - Adds `BudgetAt(int budgetId, int percent /* 80 or 100 */)` to `FinanceAlert`, emitted only when `budgetAlertsEnabled` is on.
- The screen has a month switcher, one row per budget (label, actual / budget, remaining, a percent bar that turns warning at ≥ 80 and danger at ≥ 100), an add/edit sheet, and "Copy last month".

- [ ] **Step 1: Write the failing tests**
  - `actual counts expenses minus refunds in month`.
  - `workspace-only budget sums all categories in that workspace`.
  - `transfers never count`.
  - `percentUsed over 100`.
  - `copyFromPreviousMonth skips existing`.
  - `budget alert at 80`.
- [ ] **Step 2: Run.** Expected: FAIL. **Step 3: Implement.** **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** with message `feat(finance): monthly budgets per category and workspace`.

---

### Task 11: Debts and installments

**Files:**
- Create: `lib/features/finance/debts/debts_repository.dart`, `lib/features/finance/debts/installment_schedule.dart`, `lib/features/finance/debts/debts_screen.dart`, `lib/features/finance/debts/debt_detail_screen.dart`
- Modify: `lib/app/router.dart` (`/finance/debts`, `/finance/debts/:id`), the ARB files
- Test: `test/features/finance/debts/installment_schedule_test.dart`, `debts_repository_test.dart`, `debts_screen_test.dart`

**Interfaces:**
- Produces:
  - `List<(int seq, int dueOn, int amountMinor)> evenSchedule({required int principalMinor, required int count, required int firstDueOn, required int everyMonths})`. Split evenly; the remainder goes to the **last** installment. Due days clamp to month end (Jan 31 + 1 month = Feb 28/29).
  - `class InstallmentStatus { Installment inst; int paidMinor; bool isPaid; bool isOverdue /* dueOn < today && !isPaid */; }`. Payments fill installments in `seq` order.
  - `class DebtSummary { Debt debt; int paidMinor; int remainingMinor; List<InstallmentStatus> installments; int? nextDueOn; }`
  - `class DebtsRepository`:
    - `Stream<List<DebtSummary>> watch({bool includeClosed = false});`
    - `Future<int> create({required String direction, required String counterparty, required int workspaceId, required String currency, required int principalMinor, required int startedOn, String? notes, List<(int, int, int)>? schedule});`
    - `Future<int> recordPayment({required int debtId, required int accountId, required int amountMinor, required int occurredOn, String? description});`. This inserts a `debt_payment` transaction: −amount when `owed_by_me` and +amount when `owed_to_me`. The account currency must equal the debt currency. A payment above the remaining amount throws `OverpaymentException`. When the remaining amount reaches 0, it sets `closedAt`.
    - `Future<void> deletePayment(int transactionId);`: re-opens the debt if needed.
- The screens have two tabs, "I owe" and "Owed to me", with remaining amount, next due date and an overdue badge. The detail screen shows the installment table with partial payments and has a "Record payment" sheet.

- [ ] **Step 1: Write the failing tests**
  - `evenSchedule 1000 over 3 → 333, 333, 334`.
  - `month-end clamp 20260131 +1 → 20260228`.
  - `partial payment fills first installment then second`: 3 × 333/333/334, paying 500, gives #1 paid and #2 167 paid.
  - `owed_by_me payment lowers account balance`.
  - `overpayment throws`.
  - `final payment closes debt; deleting it re-opens`.
  - `currency mismatch throws`.
- [ ] **Step 2: Run.** Expected: FAIL. **Step 3: Implement.** **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** with message `feat(finance): debts and installments with partial payments`.

---

### Task 12: Reports, charts, CSV and PDF export

**Files:**
- Create: `lib/features/finance/reports/report_queries.dart`, `lib/features/finance/reports/reports_screen.dart`, `lib/features/finance/reports/charts.dart`, `lib/features/finance/export/csv_export.dart`, `lib/features/finance/export/pdf_export.dart`, `lib/features/finance/export/export_files.dart`
- Modify: `pubspec.yaml` (add `fl_chart` and `pdf`), `lib/app/router.dart` (`/finance/reports`), the ARB files
- Test: `test/features/finance/reports/report_queries_test.dart`, `test/features/finance/export/csv_export_test.dart`, `pdf_export_test.dart`, `test/features/finance/reports/reports_screen_test.dart`

**Interfaces:**
- Consumes: the repositories from Tasks 2–11, plus `consolidate` (Task 6) for conversions.
- Produces (all amounts in base-currency minor units; each result carries `Consolidated`-style `missingRates`):
  - `enum Period { day, week, month }`. Weeks start on Saturday, the Iraqi convention (builder's call).
  - `class ReportFilter { int fromDay; int toDay; Set<int>? workspaceIds; }`
  - `Future<List<PeriodTotals>> incomeVsExpense(ReportFilter f, Period p)` with `class PeriodTotals { int periodStartDay; int incomeMinor; int expenseMinor; }`. Owner-draw legs count here; plain transfers never do. Refunds reduce expense. Adjustments and debt payments are excluded.
  - `Future<List<(int categoryId, int minor)>> spendByCategory(ReportFilter f)`
  - `Future<List<(int workspaceId, int minor)>> spendByWorkspace(ReportFilter f)`
  - `Future<List<(int day, int inMinor, int outMinor)>> cashFlow(ReportFilter f)`: every balance change, including transfers between currencies (converted).
  - `Future<List<(int day, int balanceMinor)>> balanceOverTime(ReportFilter f)`: the consolidated end-of-day balance.
  - `Future<List<DebtSummary>> outstandingDebts()`
  - `Future<List<BucketProgress>> bucketProgress(int monthKey)` (Task 9).
- Reports screen: a period picker (this month, last month, last 6 months, this year, custom) and a workspace filter. Sections:
  - an income vs expense bar chart
  - a spend-by-category donut with a legend list
  - a spend-by-workspace bar chart
  - a cash-flow line chart
  - a balance-over-time line chart
  - bucket progress
  - outstanding debts

  Charts use `fl_chart` with theme tokens, and every chart has a table fallback (the dataviz rules: legible in both themes, never color-only). In RTL the time axis still runs oldest → newest left-to-right. Export buttons: CSV and PDF.
- `String transactionsCsv(List<TxnRow> rows, String localeCode)`:
  - Hand-written, RFC 4180: CRLF, quoting of `"`, `,` and newlines. A UTF-8 BOM so Excel opens Arabic correctly.
  - Columns: `date,type,workspace,account,category,amount,currency,description,transfer_group`.
  - Amounts are plain decimals with Western digits and `.` (for example `-1500.00`), whatever the UI locale.
- `Future<Uint8List> reportPdf(ReportData d, String localeCode)`: the `pdf` package with Vazirmatn from `assets/fonts` and `TextDirection.rtl` for `ar`/`ckb`. Tables only (totals, by category, by workspace, debts). No chart images in 2A.
- `class ExportFiles { Future<bool> save(String fileName, Uint8List bytes); }`: uses `FilePicker.saveFile`, the same as `FilePickerBackupFiles`. It is behind a provider so tests can fake it.

- [ ] **Step 1: Write the failing tests**
  - `plain transfer not in income/expense; owner draw is`.
  - `refund reduces category spend`.
  - `USD expense converted at its day's rate`.
  - `missing rate reported, not zero`.
  - `week buckets start Saturday`.
  - `csv quotes comma, quote and newline; has BOM; Arabic text intact`.
  - `csv amount uses western digits even under ar`.
  - `pdf builds non-empty bytes for ar with Arabic text` (it starts with `%PDF`).
  - Widget test: `reports screen renders all sections with data and with none` (an empty state, not a crash).
- [ ] **Step 2: Run.** Expected: FAIL. **Step 3: Implement.** **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** with message `feat(finance): reports with charts, CSV and PDF export`.

---

### Task 13: Excel/CSV import engine

**Files:**
- Create: `lib/features/finance/import/sheet_reader.dart`, `lib/features/finance/import/import_mapping.dart`, `lib/features/finance/import/import_service.dart`
- Modify: `pubspec.yaml` (add `excel` and `csv`)
- Test: `test/features/finance/import/sheet_reader_test.dart`, `import_mapping_test.dart`, `import_service_test.dart`, plus fixtures `test/fixtures/import_sample.xlsx` and `import_sample.csv` (invented data with Arabic descriptions, mixed currencies, Arabic-Indic numbers, a header on row 3, and blank rows)

**Interfaces:**
- Produces:
  - `class SheetData { List<String> sheetNames; List<List<String>> rows(String sheet); }`
  - `Future<SheetData> readSheet(Uint8List bytes, String fileName)`. It picks the reader by extension (`.xlsx` → `excel`, `.csv` → `csv`, with comma/semicolon/tab auto-detected). Every cell becomes a trimmed string. Excel dates become `yyyy-mm-dd`. It throws `ImportFormatException` for anything else, or for a corrupt file.
  - `enum ImportField { date, amount, currency, type, category, workspace, account, description }`
  - `class ImportMapping { String sheet; int headerRow; Map<ImportField, int> columns; String defaultCurrency; String defaultType /* 'expense' */; int defaultWorkspaceId; int? defaultAccountId; Map<String, int> categoryValues; Map<String, int> workspaceValues; Map<String, String> typeValues /* e.g. 'صرف'→'expense' */; String dateFormat /* 'auto' | 'd/m/y' | 'm/d/y' | 'y-m-d' */; bool signedAmountMeansType; }`
  - `ImportMapping guessMapping(SheetData d, String sheet)`. Header synonyms in ar/en/ckb, such as `التاريخ`/`date`/`بەروار` and `المبلغ`/`amount`/`بڕ`. This is where defaults tuned to the owner's real sheet go, once they share a sample (§10.3a).
  - `class ImportRowResult { int rowIndex; TxnDraft? draft; String? error; bool isDuplicate; }`
  - `Future<List<ImportRowResult>> preview(SheetData d, ImportMapping m)`:
    - Uses `parseAmount` for amounts. A negative amount with `signedAmountMeansType` set means an expense.
    - Picks the account from the workspace and currency when none is mapped.
    - A duplicate is an existing transaction, or an earlier row in the same file, with the same `occurredOn`, signed `amountMinor` and trimmed `description` (§10.3a).
  - `Future<int> commit(String fileName, List<ImportRowResult> rows, {bool includeDuplicates = false})`. One DB transaction: it creates the `ImportBatches` row and inserts the valid, non-duplicate rows with `importBatchId`. It returns the batch id.
  - `Future<void> undo(int batchId)`: deletes that batch's transactions (their bucket allocations cascade) and sets `undoneAt`.
  - `Future<List<(Account, Money computed)>> balancesAfterImport()`. `Future<void> addOpeningAdjustment(int accountId, int actualMinor, int day)` inserts an `adjustment` for `actual − computed` (§10.3a).

- [ ] **Step 1: Write the failing tests**
  - `reads xlsx header on row 3 and skips blank rows`.
  - `csv semicolon detected`.
  - `guessMapping finds Arabic headers`.
  - `arabic-indic amounts parsed`.
  - `ambiguous date 03/04/2026 uses chosen d/m/y`.
  - `row with bad amount has error, others import`.
  - `second import flags duplicates`.
  - `undo removes only that batch`: a manual transaction and another batch survive.
  - `opening adjustment equals actual − computed`.
  - `corrupt file → ImportFormatException`.
- [ ] **Step 2: Run.** Expected: FAIL. **Step 3: Implement.** **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** with message `feat(import): Excel/CSV import engine with duplicates and undo`.

---

### Task 14: Import wizard screen

**Files:**
- Create: `lib/features/finance/import/import_wizard_screen.dart`, `lib/features/finance/import/import_history_screen.dart`
- Modify: `lib/app/router.dart` (`/settings/import`, `/settings/import/history`), `settings_screen.dart` (the "Import from Excel" tile), the ARB files
- Test: `test/features/finance/import/import_wizard_test.dart`

**Interfaces:**
- Consumes: Task 13 and `FilePicker.pickFiles` (limited to `xlsx` and `csv`), behind a provider like `BackupFiles`.
- The wizard follows §10.3a:
  1. Pick the file, then the sheet and the header row (preview of the first 10 rows).
  2. Map the columns. Each field is a dropdown pre-filled by `guessMapping`, plus defaults for unmapped fields.
  3. Map the distinct category, workspace and type values to existing ones, or "create new".
  4. Preview: counts of ok, error and duplicate rows; the first 20 rows; an "Include duplicates" switch (default off). Then Import.
  5. Opening balances: per account, the computed balance and a field for "actual cash today". "Add adjustment" posts the difference.
- Import history lists the batches with date, file and row count, plus "Undo" behind a confirm.

- [ ] **Step 1: Write the failing widget tests** (with a fake picker returning the fixture)
  - `walks all steps and imports N rows`.
  - `errors listed with row numbers`.
  - `undo from history`.
  - `fits 360x640 at 2.0x in ar`.
- [ ] **Step 2: Run.** Expected: FAIL. **Step 3: Implement.** **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** with message `feat(import): import wizard and history with undo`.

---

### Task 15: Worst-case UI pass, release APK, docs

**Files:**
- Modify: `test/ui/worst_case_test.dart` (add the finance screens), `docs/INSTALL.md` (a "What's new in 2A" section and the import tip), `pubspec.yaml` version `1.1.0+2`
- Create: `integration_test/finance_flow_test.dart`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Extend the worst-case tests.** Cover Overview, Accounts, History, Form, Buckets, Budgets, Debts, Reports and Import at 1.0× and 2.0× in `ar`, `en` and `ckb` on 360×640, with this data:
  - an 80-character account name
  - a 500-character description
  - 10¹² IQD amounts
  - zero transactions
  - 1,000 transactions
- [ ] **Step 2: Write the integration test** `integration_test/finance_flow_test.dart` (on device). It runs through:
  - add a USD rate
  - add an income in USD with allocation
  - add an expense from the emergency bucket
  - make an IQD↔USD exchange
  - add a budget
  - add a debt and pay part of it
  - export CSV through the fake saver
  - back up, restore, and check that every figure is identical
- [ ] **Step 3: Run** `flutter test` and `flutter analyze`. Expected: all PASS, with no issues.
- [ ] **Step 4: Build** with `flutter build apk --release`. Expected: `build/app/outputs/flutter-apk/app-release.apk` is produced. Check that the merged manifest has no `INTERNET` permission: `grep -c INTERNET build/app/intermediates/merged_manifests/release/AndroidManifest.xml` must print `0`.
- [ ] **Step 5: Commit** with message `chore(release): phase 2A finance release`.
