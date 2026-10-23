// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'My Life Manager';

  @override
  String get navHome => 'Home';

  @override
  String get navFinance => 'Finance';

  @override
  String get navTasks => 'Tasks';

  @override
  String get navVault => 'Vault';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get appLock => 'App lock';

  @override
  String get biometrics => 'Unlock with fingerprint';

  @override
  String get biometricsUnavailable => 'No fingerprint or face unlock is set up on this phone';

  @override
  String get changePin => 'Change PIN';

  @override
  String get currentPin => 'Current PIN';

  @override
  String get newPin => 'New PIN';

  @override
  String get pinChanged => 'PIN changed';

  @override
  String get lockTimeout => 'Lock after leaving the app';

  @override
  String get lockImmediately => 'Immediately';

  @override
  String lockAfterMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'After $minutes minutes',
      one: 'After 1 minute',
    );
    return '$_temp0';
  }

  @override
  String get backupRestore => 'Backup & restore';

  @override
  String lastBackup(String date) {
    return 'Last backup: $date';
  }

  @override
  String get neverBackedUp => 'Never backed up';

  @override
  String get createBackup => 'Create backup';

  @override
  String get restoreBackup => 'Restore from backup';

  @override
  String get backupPassword => 'Backup password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get passwordTooShort => 'Use at least 8 characters';

  @override
  String get passwordsDontMatch => 'Passwords don\'t match';

  @override
  String get backupWarning =>
      'Your data lives only on this phone. If you lose the phone or uninstall the app without a backup, everything is gone. Save backups somewhere off the phone.';

  @override
  String get backupCreated => 'Backup saved';

  @override
  String get restoreConfirmTitle => 'Replace all current data?';

  @override
  String restoreConfirmBody(String date, String version) {
    return 'Backup from $date, app version $version. Everything currently in the app will be replaced.';
  }

  @override
  String get replace => 'Replace';

  @override
  String get cancel => 'Cancel';

  @override
  String get enterPin => 'Enter your PIN';

  @override
  String get wrongPin => 'Wrong PIN';

  @override
  String attemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attempts left before a pause',
      one: '1 attempt left before a pause',
    );
    return '$_temp0';
  }

  @override
  String tryAgainIn(String time) {
    return 'Too many attempts. Try again in $time';
  }

  @override
  String get unlockReason => 'Unlock My Life Manager';

  @override
  String get useFingerprint => 'Use fingerprint';

  @override
  String get setupWelcome => 'Welcome';

  @override
  String get setupWelcomeBody => 'Everything stays on this phone, under your lock.';

  @override
  String get setupChooseLanguage => 'Choose your language';

  @override
  String get setupCreatePin => 'Create a 6-digit PIN';

  @override
  String get setupConfirmPin => 'Enter the PIN again';

  @override
  String get pinMismatch => 'The PINs don\'t match. Start again.';

  @override
  String get setupEnableBiometrics => 'Unlock with fingerprint too?';

  @override
  String get setupEnableBiometricsBody => 'Your PIN always works as a fallback.';

  @override
  String get enable => 'Enable';

  @override
  String get setupBackupWarning => 'One important thing';

  @override
  String get iUnderstand => 'I understand';

  @override
  String get continueLabel => 'Continue';

  @override
  String get skip => 'Skip';

  @override
  String get finish => 'Start';

  @override
  String comingInPhase(int phase) {
    return 'Arrives in phase $phase';
  }

  @override
  String get seedPersonal => 'Personal';

  @override
  String get seedBuzzify => 'Buzzify';

  @override
  String get seedEo => 'Related / EO';

  @override
  String get seedOtherProjects => 'Other Projects';

  @override
  String get seedCashIqd => 'Cash IQD';

  @override
  String get seedCashUsd => 'Cash USD';

  @override
  String get accounts => 'Accounts';

  @override
  String get homeMonthSummary => 'This month';

  @override
  String get homeChart => 'Income vs expenses';

  @override
  String get homeBuckets => 'Buckets';

  @override
  String get homeTasks => 'Tasks';

  @override
  String get privacy => 'Privacy';

  @override
  String get privacyPhase1 =>
      'Your data stays on this phone. Only if you turn on online AI and agree is a capture\'s voice or text sent to Groq. The vault never leaves the phone.';

  @override
  String get restoreTooNew => 'This backup was made by a newer version of the app. Update the app first.';

  @override
  String get restoreWrongPassword => 'Wrong password, or the file is damaged.';

  @override
  String get restoreCorrupt => 'This file is damaged or isn\'t a backup from this app.';

  @override
  String get restoreSuccess => 'Restored. Restarting…';

  @override
  String get passwordStrengthWeak => 'Weak: make it longer, or mix letters, numbers and symbols';

  @override
  String get passwordStrengthFair => 'Fair';

  @override
  String get passwordStrengthStrong => 'Strong';

  @override
  String get backupPasswordHint =>
      'You will need this password to restore. If you forget it, it cannot be recovered. A saved Groq key is kept inside the encrypted backup too.';

  @override
  String get somethingWentWrong => 'Something went wrong. Please try again.';

  @override
  String get backupFailed => 'The backup couldn\'t be created. Your data is unchanged.';

  @override
  String get startupFailed => 'Your data couldn\'t be opened. Nothing was deleted.';

  @override
  String get retry => 'Try again';

  @override
  String get cat_food => 'Food';

  @override
  String get cat_transport => 'Transport';

  @override
  String get cat_rent => 'Rent';

  @override
  String get cat_bills => 'Bills';

  @override
  String get cat_family => 'Family';

  @override
  String get cat_shopping => 'Shopping';

  @override
  String get cat_health => 'Health';

  @override
  String get cat_business => 'Business';

  @override
  String get cat_marketing => 'Marketing';

  @override
  String get cat_subscriptions => 'Subscriptions';

  @override
  String get cat_other_expense => 'Other expense';

  @override
  String get cat_salary => 'Salary';

  @override
  String get cat_business_income => 'Business income';

  @override
  String get cat_freelance => 'Freelance';

  @override
  String get cat_client_payment => 'Client payment';

  @override
  String get cat_other_income => 'Other income';

  @override
  String get bucket_expenses => 'Expenses';

  @override
  String get bucket_emergency => 'Emergency';

  @override
  String get bucket_investment => 'Investment';

  @override
  String get finIncome => 'Income';

  @override
  String get finExpense => 'Expenses';

  @override
  String get finSurplus => 'Surplus';

  @override
  String get finAllAccounts => 'All accounts';

  @override
  String get finHowConvertedHint => 'Tap to see how it was converted';

  @override
  String finNoTotal(String currencies) {
    return 'No rate for $currencies yet, so there is no single total';
  }

  @override
  String get finSetRate => 'Set a rate';

  @override
  String get finRateTitle => 'Exchange rate';

  @override
  String get finRateLabel => '1 USD in IQD';

  @override
  String get finRateInvalid => 'Type a rate like 1310';

  @override
  String get save => 'Save';

  @override
  String get finHowConverted => 'How it was converted';

  @override
  String get finSameCurrency => 'Same currency';

  @override
  String get finNoRate => 'No rate';

  @override
  String finRateLine(String base, String rate, String quote, String date) {
    return '1 $base = $rate $quote · from $date';
  }

  @override
  String get finPerCurrency => 'Per currency';

  @override
  String get finTotal => 'Total';

  @override
  String alertExpensesBucket(int percent) {
    return 'Expenses bucket at $percent% this month';
  }

  @override
  String get alertEmergencyReached => 'Emergency fund reached its target';

  @override
  String get alertEmergencyBelow => 'Emergency fund is below its target';

  @override
  String alertUnallocated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count incomes not split into buckets',
      one: '1 income not split into buckets',
    );
    return '$_temp0';
  }

  @override
  String alertBudget(String name, int percent) {
    return '$name budget at $percent%';
  }

  @override
  String alertDebtSoon(String name, String date) {
    return '$name: payment due $date';
  }

  @override
  String alertDebtOverdue(String name) {
    return '$name: payment overdue';
  }

  @override
  String get finHistory => 'History';

  @override
  String get finAddAccount => 'Add account';

  @override
  String get finAccountName => 'Name';

  @override
  String get finNameRequired => 'Type a name';

  @override
  String get finWorkspace => 'Workspace';

  @override
  String get finCurrency => 'Currency';

  @override
  String get finKind => 'Type';

  @override
  String get kindCash => 'Cash';

  @override
  String get kindBank => 'Bank';

  @override
  String get kindSavings => 'Savings';

  @override
  String get kindCustom => 'Other';

  @override
  String get rename => 'Rename';

  @override
  String get archive => 'Archive';

  @override
  String finArchiveAccount(String name) {
    return 'Archive $name? Its history stays.';
  }

  @override
  String get finBalance => 'Balance';

  @override
  String get finAdjustBalance => 'Adjust balance';

  @override
  String get finAdjustHint => 'Type what is actually in this account. The difference is saved as an adjustment.';

  @override
  String get finActualAmount => 'Actual amount';

  @override
  String get finAmountInvalid => 'Type an amount like 25000';

  @override
  String get finSearch => 'Search descriptions';

  @override
  String get filterAll => 'All';

  @override
  String get filterDates => 'Dates';

  @override
  String get filterAccount => 'Account';

  @override
  String get filterCategory => 'Category';

  @override
  String get filterType => 'Type';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get typeIncome => 'Income';

  @override
  String get typeExpense => 'Expense';

  @override
  String get typeRefund => 'Refund';

  @override
  String get typeAdjustment => 'Adjustment';

  @override
  String get typeTransfer => 'Transfer';

  @override
  String get typeOwnerDraw => 'Owner draw';

  @override
  String get typeDebtPayment => 'Debt payment';

  @override
  String get finPending => 'Pending';

  @override
  String get finUncategorised => 'Uncategorised';

  @override
  String get finNoTransactions => 'No transactions yet';

  @override
  String get finNoMatches => 'No transactions match these filters';

  @override
  String get finDeleted => 'Transaction deleted';

  @override
  String get undo => 'Undo';

  @override
  String get finToday => 'Today';

  @override
  String get finAddExpense => 'Add expense';

  @override
  String get finAddIncome => 'Add income';

  @override
  String get finAddRefund => 'Add refund';

  @override
  String get finAddTransfer => 'Transfer';

  @override
  String get finEditTransaction => 'Edit transaction';

  @override
  String get finEditTransfer => 'Edit transfer';

  @override
  String get finAmount => 'Amount';

  @override
  String finAmountRounded(String currency) {
    return 'Rounded to what $currency allows';
  }

  @override
  String get finAccount => 'Account';

  @override
  String get finChooseAccount => 'Choose an account';

  @override
  String get finCategory => 'Category';

  @override
  String get finNoCategory => 'No category';

  @override
  String get finDate => 'Date';

  @override
  String get finTime => 'Time';

  @override
  String get finDescription => 'Description';

  @override
  String get finNotReceived => 'Not received yet';

  @override
  String get finNotReceivedHint => 'Pending income doesn\'t count in balances';

  @override
  String get finAllocate => 'Split into buckets';

  @override
  String finAllocateNoRate(String currency) {
    return 'Set a $currency rate first to split this income';
  }

  @override
  String get finAllocatePending => 'Only received income can be split';

  @override
  String get finUnallocated => 'Not split';

  @override
  String get finOverAllocated => 'Over by';

  @override
  String get finBucketTag => 'Paid from bucket';

  @override
  String get finBucketNone => 'Normal spending';

  @override
  String get finClearAllocationsTitle => 'Clear the bucket split?';

  @override
  String get finClearAllocationsBody =>
      'This income is split into buckets. Changing its money clears the split; you can split it again afterwards.';

  @override
  String get finClearAndSave => 'Clear and save';

  @override
  String get finFrom => 'From';

  @override
  String get finTo => 'To';

  @override
  String get finToAmount => 'Amount received';

  @override
  String finRateField(String quote, String base) {
    return '$quote per 1 $base';
  }

  @override
  String get finTwoOfThree => 'Type any two; the third is worked out';

  @override
  String get finOwnerDraw => 'Owner draw (salary)';

  @override
  String get finOwnerDrawHint => 'Counts as an expense of the business and income of the person';

  @override
  String get finSameAccount => 'Choose two different accounts';

  @override
  String get finSaved => 'Saved';

  @override
  String get finBuckets => 'Buckets';

  @override
  String get finBudgets => 'Budgets';

  @override
  String get finDebts => 'Debts';

  @override
  String get finAvailable => 'Available';

  @override
  String get finAllocated => 'Split in';

  @override
  String get finSpent => 'Spent';

  @override
  String get finTarget => 'Target';

  @override
  String get finSetTarget => 'Set target';

  @override
  String get finTargetHint => 'Leave empty for no target';

  @override
  String get finEditPercentages => 'Edit percentages';

  @override
  String get finPercentagesNote => 'Must add up to 100%. Only income you split after saving uses the new percentages.';

  @override
  String finPercentTotal(String percent) {
    return 'Total $percent%';
  }

  @override
  String get finBucketsUnconfirmed => 'Set your own percentages before splitting income into buckets.';

  @override
  String get finExpensesMonthly => 'Resets every month';

  @override
  String get finCarriesOver => 'Carries over';

  @override
  String get finAddBudget => 'Add budget';

  @override
  String get finEditBudget => 'Edit budget';

  @override
  String get finBudgetNeedsScope => 'Choose a category, a workspace or both';

  @override
  String get finAnyWorkspace => 'All workspaces';

  @override
  String get finAnyCategory => 'All categories';

  @override
  String get finRemaining => 'Remaining';

  @override
  String finOfBudget(String amount) {
    return 'of $amount';
  }

  @override
  String finMissingRatesNote(String currencies) {
    return 'Left out: $currencies (no rate on those dates)';
  }

  @override
  String get finNoBudgets => 'No budgets yet';

  @override
  String get finOwedToMe => 'Owed to me';

  @override
  String get finOwedByMe => 'I owe';

  @override
  String get finAddDebt => 'Add debt';

  @override
  String get finCounterparty => 'Person or company';

  @override
  String get finStartDate => 'Started';

  @override
  String get finRecordMoveNow => 'Record the money now';

  @override
  String get finRecordMoveGiven => 'Money left this account';

  @override
  String get finRecordMoveReceived => 'Money came into this account';

  @override
  String get finInstallments => 'Installments';

  @override
  String get finInstallmentCount => 'Number of monthly installments (optional)';

  @override
  String get finFirstDue => 'First due';

  @override
  String finNextDue(String date) {
    return 'Next due $date';
  }

  @override
  String get finOverdue => 'Overdue';

  @override
  String get finPaid => 'Paid';

  @override
  String get finNoDebts => 'Nothing here';

  @override
  String get finRecordRepayment => 'Record repayment';

  @override
  String finRepaymentTooBig(String amount) {
    return 'Up to $amount';
  }

  @override
  String finWrongCurrency(String currency) {
    return 'Choose an account in $currency';
  }

  @override
  String get finPayments => 'Payments';

  @override
  String get finPrincipal => 'Principal';

  @override
  String get finRepayment => 'Repayment';

  @override
  String get finClosed => 'Settled';

  @override
  String get finNotes => 'Notes';

  @override
  String get finReports => 'Reports';

  @override
  String get repRange => 'Range';

  @override
  String get repThisMonth => 'This month';

  @override
  String get repLastMonth => 'Last month';

  @override
  String repLastMonths(int count) {
    return 'Last $count months';
  }

  @override
  String get repCustom => 'Custom dates';

  @override
  String get repGroupBy => 'Group by';

  @override
  String get repDaily => 'Daily';

  @override
  String get repWeekly => 'Weekly';

  @override
  String get repMonthly => 'Monthly';

  @override
  String get repAllWorkspaces => 'All workspaces';

  @override
  String get repTabIncomeExpense => 'Income vs expenses';

  @override
  String get repTabCategory => 'By category';

  @override
  String get repTabWorkspace => 'By workspace';

  @override
  String get repTabCashFlow => 'Cash flow';

  @override
  String get repTabBalance => 'Balance over time';

  @override
  String get repTabDebts => 'Outstanding debts';

  @override
  String get repShowTable => 'Show as table';

  @override
  String get repShowChart => 'Show as chart';

  @override
  String repSkipped(int count, String currencies) {
    return '$count left out: no $currencies rate on their dates';
  }

  @override
  String get repMoneyIn => 'Money in';

  @override
  String get repMoneyOut => 'Money out';

  @override
  String get repNet => 'Net';

  @override
  String get repOther => 'Other';

  @override
  String get repPeriodColumn => 'Period';

  @override
  String get repBalance => 'Balance';

  @override
  String get repNothing => 'Nothing in this range';

  @override
  String repBucketsMonth(String month, String currency) {
    return '$month, in $currency';
  }

  @override
  String get repExport => 'Export';

  @override
  String get repExportCsv => 'Transactions as CSV';

  @override
  String get repExportPdf => 'Report as PDF';

  @override
  String get repNotEncrypted => 'This file is not encrypted. Anyone who gets it can read it.';

  @override
  String get repExportFailed => 'Could not save the file';

  @override
  String get setFinance => 'Finance';

  @override
  String get setFinanceSettings => 'Currency and rates';

  @override
  String get setFinanceSettingsHint => 'Base currency, USD rate, alerts';

  @override
  String get setCategories => 'Categories';

  @override
  String get setCategoriesHint => 'Names and the words that pick them';

  @override
  String get setWorkspaces => 'Workspaces';

  @override
  String get setWorkspacesHint => 'Names, aliases, buckets';

  @override
  String get setBaseCurrency => 'Base currency';

  @override
  String get setBaseCurrencyHint => 'Totals, buckets and reports use it unless you pick another.';

  @override
  String setRateDate(String date) {
    return 'From $date';
  }

  @override
  String get setRateHistory => 'Rate history';

  @override
  String get setNoRates => 'No rate yet. USD and IQD stay apart until you add one.';

  @override
  String get setRateSaved => 'Rate saved';

  @override
  String get setAlerts => 'Alerts';

  @override
  String get setUnallocatedAlert => 'Remind me about income not split into buckets';

  @override
  String get setUnallocatedAlertHint => 'Shows on the Finance screen';

  @override
  String get setIncomeCategories => 'Income';

  @override
  String get setExpenseCategories => 'Expenses';

  @override
  String get setAddCategory => 'Add category';

  @override
  String get setEditCategory => 'Edit category';

  @override
  String get setKeywords => 'Words that pick this category';

  @override
  String get setBuiltInWords => 'Built in';

  @override
  String get setYourWords => 'Your words';

  @override
  String get setAddWord => 'Add a word';

  @override
  String setRemoveWord(String word) {
    return 'Remove $word';
  }

  @override
  String setArchiveCategory(String name) {
    return 'Archive $name? Old entries keep it.';
  }

  @override
  String get setAddWorkspace => 'Add workspace';

  @override
  String get setEditWorkspace => 'Edit workspace';

  @override
  String get setIcon => 'Icon';

  @override
  String get setColour => 'Colour';

  @override
  String get setAliases => 'Other names you say';

  @override
  String get setAliasesHint => 'Voice and quick capture match these too';

  @override
  String get setAddAlias => 'Add a name';

  @override
  String get setCountsInBuckets => 'Counts in buckets';

  @override
  String get setCountsInBucketsHint => 'Its expenses come out of the Expenses bucket';

  @override
  String setArchiveWorkspace(String name) {
    return 'Archive $name? Its history stays.';
  }

  @override
  String setArchiveBlocked(String name) {
    return 'Archive or move its accounts first. $name still has accounts in use.';
  }

  @override
  String get setArchived => 'Archived';

  @override
  String get ok => 'OK';

  @override
  String get impTitle => 'Import';

  @override
  String get impEntry => 'Import a sheet';

  @override
  String get impStepFile => 'Choose a file';

  @override
  String get impStepColumns => 'Columns';

  @override
  String get impStepDefaults => 'Defaults';

  @override
  String get impStepValues => 'Match values';

  @override
  String get impStepPreview => 'Check and import';

  @override
  String get impStepOpening => 'Balances today';

  @override
  String impStepOf(int n, int total) {
    return 'Step $n of $total';
  }

  @override
  String get impPickHint => 'An .xlsx or .csv from your bank or an old sheet. Nothing is saved until you tap Import.';

  @override
  String get impPick => 'Choose a file';

  @override
  String get impPickAnother => 'Choose another file';

  @override
  String get impTooLarge => 'This file is too big: over 50,000 rows or 64 columns.';

  @override
  String get impUnreadable => 'This file could not be read as .xlsx or .csv.';

  @override
  String get impSheet => 'Sheet';

  @override
  String get impHeaderRow => 'Which row has the column names?';

  @override
  String impRowN(int n) {
    return 'Row $n';
  }

  @override
  String get impColDate => 'Date';

  @override
  String get impDateOrder => 'Date order';

  @override
  String get impDayFirst => 'Day first (31/12)';

  @override
  String get impMonthFirst => 'Month first (12/31)';

  @override
  String get impYearFirst => 'Year first (2025-12-31)';

  @override
  String get impAmountMode => 'How amounts are written';

  @override
  String get impSigned => 'One column, minus means expense';

  @override
  String get impTypeColumn => 'One column plus a type column';

  @override
  String get impSplit => 'Separate income and expense columns';

  @override
  String get impColAmount => 'Amount';

  @override
  String get impColIncome => 'Income column';

  @override
  String get impColExpense => 'Expense column';

  @override
  String get impColType => 'Type';

  @override
  String get impColCurrency => 'Currency';

  @override
  String get impColCategory => 'Category';

  @override
  String get impColWorkspace => 'Workspace';

  @override
  String get impColAccount => 'Account';

  @override
  String get impColDescription => 'Description';

  @override
  String get impNone => 'Not in the file';

  @override
  String impColumnLetter(String letter) {
    return 'Column $letter';
  }

  @override
  String get impNeedDateAmount => 'Pick the date and amount columns to go on.';

  @override
  String get impDefaultsHint => 'Used for rows that do not say.';

  @override
  String get impNoValues => 'Nothing to match: the file has no type, category, workspace or account column.';

  @override
  String get impCreateNew => 'Create new';

  @override
  String get impSkipRow => 'Skip these rows';

  @override
  String get impLeaveEmpty => 'Leave empty';

  @override
  String get impUseDefault => 'Use the default';

  @override
  String get impReady => 'Ready';

  @override
  String get impDuplicates => 'Already in the app';

  @override
  String get impProblems => 'Can\'t read';

  @override
  String get impSkipDuplicates => 'Skip rows already in the app';

  @override
  String get impProblemDate => 'no date';

  @override
  String get impProblemAmount => 'no amount';

  @override
  String get impProblemType => 'unknown type';

  @override
  String get impProblemAccount => 'no account';

  @override
  String get impDuplicateTag => 'already there';

  @override
  String impFirstRows(int count) {
    return 'First $count rows';
  }

  @override
  String impImport(int count) {
    return 'Import $count rows';
  }

  @override
  String impImported(int count) {
    return 'Imported $count rows';
  }

  @override
  String get impOpeningHint => 'Type what each account really holds today. A difference is saved as an adjustment.';

  @override
  String impComputed(String amount) {
    return 'In the app: $amount';
  }

  @override
  String get impActual => 'Actual today';

  @override
  String get impSaveBalances => 'Save balances';

  @override
  String get impDone => 'Done';

  @override
  String get impNext => 'Next';

  @override
  String get impBack => 'Back';

  @override
  String get impPastImports => 'Past imports';

  @override
  String get impUndo => 'Undo';

  @override
  String impUndoConfirm(int count, String name) {
    return 'Remove the $count rows imported from $name?';
  }

  @override
  String get impUndone => 'Undone';

  @override
  String impBatchLine(int count, String date) {
    return '$count rows · $date';
  }

  @override
  String get setAi => 'Online AI';

  @override
  String get setAiHint => 'Groq key, models and what is sent';

  @override
  String get aiOnline => 'Use online AI';

  @override
  String get aiOnlineHint => 'When off, everything is understood on the phone, a little less accurately.';

  @override
  String get aiKey => 'Groq API key';

  @override
  String get aiKeyHint => 'Free from console.groq.com. Kept encrypted on this phone only.';

  @override
  String aiKeySaved(String last4) {
    return 'Saved key ••••$last4';
  }

  @override
  String get aiKeyRemove => 'Remove';

  @override
  String get aiKeyPaste => 'Paste';

  @override
  String get aiKeySave => 'Save key';

  @override
  String get aiTest => 'Test key';

  @override
  String get aiTestOk => 'The key works.';

  @override
  String get aiTestUnauthorized => 'Groq refused this key. Check it and save it again.';

  @override
  String get aiTestOffline => 'Could not reach Groq. Check the internet.';

  @override
  String get aiTestBusy => 'Groq is busy. Try again in a minute.';

  @override
  String get aiTestOther => 'Groq did not answer as expected. Try again later.';

  @override
  String get aiModels => 'Models';

  @override
  String get aiSttModel => 'Speech-to-text model';

  @override
  String get aiLlmModel => 'Understanding model';

  @override
  String get aiModelsSave => 'Save models';

  @override
  String get aiModelsSaved => 'Models saved';

  @override
  String get aiConsents => 'What is sent to Groq';

  @override
  String get aiConsentVoiceTitle => 'Voice to text';

  @override
  String get aiConsentParseTitle => 'Filling in the form';

  @override
  String get aiConsentVoice => 'Your voice recording is sent to Groq to turn it into text.';

  @override
  String get aiConsentParse =>
      'The text of what you said, today\'s date and time, and the names of your accounts, workspaces, categories and buckets are sent to Groq to fill in the form. Balances, past transactions and the vault are never sent.';

  @override
  String get aiConsentGranted => 'Allowed';

  @override
  String get aiConsentDeclined => 'Not allowed';

  @override
  String get aiConsentUnset => 'Not asked yet';

  @override
  String get aiConsentReset => 'Ask again';

  @override
  String get aiOfflineModel => 'Offline speech model';

  @override
  String get aiOfflineModelHint => 'Turns speech into text on the phone when online AI is off or unreachable.';

  @override
  String get consentTitle => 'Send this to Groq?';

  @override
  String get consentWho => 'Groq, Inc. processes it on servers in the United States.';

  @override
  String get consentNever => 'Never sent: your balances, past transactions, PIN, backups or the vault.';

  @override
  String get consentOff => 'You can turn this off any time in Settings → Online AI.';

  @override
  String get consentAllow => 'Allow';

  @override
  String get consentDecline => 'No, keep it on the phone';

  @override
  String get aiModelSmall => 'Small: more accurate';

  @override
  String get aiModelBase => 'Base: faster';

  @override
  String aiModelSize(int mb) {
    return '$mb MB';
  }

  @override
  String aiModelInstall(int mb) {
    return 'Download ($mb MB)';
  }

  @override
  String get aiModelInstalled => 'Downloaded and checked';

  @override
  String get aiModelNotInstalled => 'Not downloaded';

  @override
  String get aiModelDelete => 'Delete';

  @override
  String get aiModelCancel => 'Stop';

  @override
  String aiModelProgress(int percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get aiModelVerifying => 'Checking the file…';

  @override
  String get aiModelFailed => 'The download stopped. Try again, ideally on Wi-Fi.';

  @override
  String get aiModelMismatch => 'The file did not match and was deleted. Try again.';

  @override
  String get aiModelSorani => 'Offline, Kurdish (Sorani) is recognised less accurately than Arabic and English.';

  @override
  String get capMicTooltip => 'Capture by voice (hold to type)';

  @override
  String get capListening => 'Listening…';

  @override
  String get capCapHint => 'Up to 2 minutes';

  @override
  String get capStop => 'Done';

  @override
  String get capProcessing => 'Working it out…';

  @override
  String get capMicDenied => 'Microphone access is off. Allow it in Android settings.';

  @override
  String get capTypeHint => 'Type what happened';

  @override
  String get capSend => 'Send';

  @override
  String get capManual => 'Or add by hand';

  @override
  String get capNote => 'Note';

  @override
  String get capVaultItem => 'Vault item';

  @override
  String get capSavedToInbox => 'Saved to Inbox';

  @override
  String get capOpen => 'Open';

  @override
  String get capReason_noSpeechEngine =>
      'No speech engine yet. Turn on online AI or install an offline model in Settings.';

  @override
  String get capReason_sttFailed => 'Couldn\'t turn the recording into text. It is kept in the Inbox.';

  @override
  String get capReason_empty => 'Nothing was heard.';

  @override
  String get capReason_lowConfidence => 'Not sure what you meant. It is kept in the Inbox.';

  @override
  String get capReviewTitle => 'Review';

  @override
  String get capTranscript => 'What you said';

  @override
  String get capParseAgain => 'Read again';

  @override
  String get capByAi => 'Filled by online AI';

  @override
  String get capByRules => 'Filled offline on this phone';

  @override
  String get capKeepCard => 'Save this';

  @override
  String get capCheckThis => 'Check this one';

  @override
  String get capMissingFields => 'Fill in the highlighted fields or turn this one off';

  @override
  String get capKeepInInbox => 'Keep in Inbox';

  @override
  String capInboxUntil(int phase) {
    return 'Kept in the Inbox until phase $phase';
  }

  @override
  String get capDebt => 'Debt';

  @override
  String get capNewDebt => 'New debt';

  @override
  String get capWhichDebt => 'Which debt';

  @override
  String get capDrop => 'Dropped';

  @override
  String get capNothingFound => 'Nothing to save was found. Edit the text and read it again.';

  @override
  String get capDone => 'Saved';

  @override
  String get capInbox => 'Inbox';

  @override
  String get capInboxEmpty => 'Nothing waiting. Anything you say or type and don\'t save lands here.';

  @override
  String get capNotTranscribed => 'Voice, not transcribed yet';

  @override
  String get capTranscribe => 'Transcribe';

  @override
  String get capFinishAi => 'Finish with AI';

  @override
  String get capFinishAllAi => 'Finish all with AI';

  @override
  String capFinishing(int n, int total) {
    return 'Finishing $n of $total…';
  }

  @override
  String get capOpenReview => 'Review';

  @override
  String get capDiscard => 'Discard';

  @override
  String get capDiscardTitle => 'Discard this capture?';

  @override
  String get capDiscardBody => 'Its text and recording are deleted. Nothing saved from it changes.';

  @override
  String capWillBecomeTask(int phase) {
    return 'Will become a task in phase $phase';
  }

  @override
  String capWillBecomeNote(int phase) {
    return 'Will become a note in phase $phase';
  }
}
