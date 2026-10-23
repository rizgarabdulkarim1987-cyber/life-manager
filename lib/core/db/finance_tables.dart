// Drift check constraints reference their own column getter by design.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import 'tables.dart';

const kTransactionTypes = ['income', 'expense', 'transfer', 'adjustment', 'refund', 'debt_payment'];

/// `systemKey` categories are seeded and named from l10n until renamed.
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => text().check(kind.isIn(const ['income', 'expense']))();
  TextColumn get systemKey => text().nullable().unique()();
  TextColumn get name => text().nullable().withLength(min: 1, max: 80)();
  TextColumn get iconKey => text()();
  IntColumn get colorArgb => integer()();
  IntColumn get workspaceId => integer().nullable().references(Workspaces, #id, onDelete: KeyAction.restrict)();

  /// Comma-separated keywords the owner added (the defaults live in code).
  TextColumn get extraKeywords => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  List<String> get customConstraints => ['CHECK (system_key IS NOT NULL OR name IS NOT NULL)'];
}

/// 1 [baseCode] = rateE6 / 10⁶ [quoteCode] from [effectiveFrom]. History is kept.
class ExchangeRates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get baseCode => text().withLength(min: 3, max: 3)();
  TextColumn get quoteCode => text().withLength(min: 3, max: 3)();
  IntColumn get rateE6 => integer().check(rateE6.isBiggerThanValue(0))();
  DateTimeColumn get effectiveFrom => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {baseCode, quoteCode, effectiveFrom},
  ];
}

class ImportBatches extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fileName => text()();
  IntColumn get rowCount => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get undoneAt => dateTime().nullable()();
}

class Debts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get direction => text().check(direction.isIn(const ['owed_to_me', 'owed_by_me']))();
  TextColumn get counterparty => text().withLength(min: 1, max: 80)();
  IntColumn get workspaceId => integer().references(Workspaces, #id, onDelete: KeyAction.restrict)();
  IntColumn get principalMinor => integer().check(principalMinor.isBiggerThanValue(0))();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get closedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class Installments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get debtId => integer().references(Debts, #id, onDelete: KeyAction.cascade)();
  IntColumn get seq => integer()();
  DateTimeColumn get dueDate => dateTime()();
  IntColumn get amountMinor => integer().check(amountMinor.isBiggerThanValue(0))();
}

@TableIndex(name: 'tx_account_time', columns: {#accountId, #occurredAt})
@TableIndex(name: 'tx_time', columns: {#occurredAt})
@TableIndex(name: 'tx_batch', columns: {#importBatchId})
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text().check(type.isIn(kTransactionTypes))();
  IntColumn get accountId => integer().references(Accounts, #id, onDelete: KeyAction.restrict)();
  IntColumn get workspaceId => integer().references(Workspaces, #id, onDelete: KeyAction.restrict)();

  /// Integer minor units of [currencyCode]; signed only for adjustments.
  IntColumn get amountMinor => integer()();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();

  IntColumn get toAccountId => integer().nullable().references(Accounts, #id, onDelete: KeyAction.restrict)();
  IntColumn get toAmountMinor => integer().nullable()();
  IntColumn get rateE6 => integer().nullable()();
  TextColumn get transferKind => text().nullable().check(transferKind.isIn(const ['transfer', 'owner_draw']))();

  IntColumn get categoryId => integer().nullable().references(Categories, #id, onDelete: KeyAction.restrict)();
  TextColumn get bucketTag => text().nullable().check(bucketTag.isIn(const ['emergency', 'investment']))();
  TextColumn get paymentStatus =>
      text().withDefault(const Constant('paid')).check(paymentStatus.isIn(const ['paid', 'pending']))();

  IntColumn get debtId => integer().nullable().references(Debts, #id, onDelete: KeyAction.restrict)();
  TextColumn get debtLeg => text().nullable().check(debtLeg.isIn(const ['principal', 'repayment']))();

  IntColumn get importBatchId => integer().nullable().references(ImportBatches, #id, onDelete: KeyAction.restrict)();
  IntColumn get captureId => integer().nullable()();

  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get description => text().nullable().withLength(max: 500)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<String> get customConstraints => [
    "CHECK (amount_minor > 0 OR (type = 'adjustment' AND amount_minor <> 0))",
    "CHECK ((type = 'transfer') = (to_account_id IS NOT NULL AND to_amount_minor IS NOT NULL AND transfer_kind IS NOT NULL))",
    "CHECK (type = 'transfer' OR rate_e6 IS NULL)",
    'CHECK (to_amount_minor IS NULL OR to_amount_minor > 0)',
    'CHECK (rate_e6 IS NULL OR rate_e6 > 0)',
    "CHECK (bucket_tag IS NULL OR type = 'expense')",
    "CHECK ((type = 'debt_payment') = (debt_id IS NOT NULL AND debt_leg IS NOT NULL))",
  ];
}

/// Virtual envelopes (spec §10.3): numbers only, no money moves.
class Buckets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get systemKey => text().nullable().unique()();
  TextColumn get name => text().nullable()();

  /// Basis points; all buckets sum to 10000.
  IntColumn get percentBp => integer().check(percentBp.isBetweenValues(0, 10000))();

  /// In the base currency.
  IntColumn get targetMinor => integer().nullable()();
  IntColumn get sortOrder => integer()();
}

/// Immutable split of one income, in the base currency at the income-date rate.
class BucketAllocations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer().references(Transactions, #id, onDelete: KeyAction.cascade)();
  IntColumn get bucketId => integer().references(Buckets, #id, onDelete: KeyAction.restrict)();
  IntColumn get amountBaseMinor => integer().check(amountBaseMinor.isBiggerThanValue(0))();
  TextColumn get baseCurrency => text().withLength(min: 3, max: 3)();
  IntColumn get rateE6Used => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id, onDelete: KeyAction.restrict)();
  IntColumn get workspaceId => integer().nullable().references(Workspaces, #id, onDelete: KeyAction.restrict)();
  IntColumn get amountMinor => integer().check(amountMinor.isBiggerThanValue(0))();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  List<String> get customConstraints => ['CHECK (category_id IS NOT NULL OR workspace_id IS NOT NULL)'];
}
