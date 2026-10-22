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
  String get biometricsUnavailable =>
      'No fingerprint or face unlock is set up on this phone';

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
  String get setupWelcomeBody =>
      'Everything stays on this phone, under your lock.';

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
  String get setupEnableBiometricsBody =>
      'Your PIN always works as a fallback.';

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
      'Nothing leaves this phone. The app has no internet access yet.';

  @override
  String get restoreTooNew =>
      'This backup was made by a newer version of the app. Update the app first.';

  @override
  String get restoreWrongPassword => 'Wrong password, or the file is damaged.';

  @override
  String get restoreCorrupt =>
      'This file is damaged or isn\'t a backup from this app.';

  @override
  String get restoreSuccess => 'Restored. Restarting…';

  @override
  String get micSoon => 'Voice capture arrives in phase 2';

  @override
  String get passwordStrengthWeak =>
      'Weak: make it longer, or mix letters, numbers and symbols';

  @override
  String get passwordStrengthFair => 'Fair';

  @override
  String get passwordStrengthStrong => 'Strong';

  @override
  String get backupPasswordHint =>
      'You will need this password to restore. If you forget it, it cannot be recovered.';

  @override
  String get somethingWentWrong => 'Something went wrong. Please try again.';

  @override
  String get backupFailed =>
      'The backup couldn\'t be created. Your data is unchanged.';

  @override
  String get startupFailed =>
      'Your data couldn\'t be opened. Nothing was deleted.';

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
  String get finAdjustHint =>
      'Type what is actually in this account. The difference is saved as an adjustment.';

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
  String get finOwnerDrawHint =>
      'Counts as an expense of the business and income of the person';

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
  String get finPercentagesNote =>
      'Must add up to 100%. Only income you split after saving uses the new percentages.';

  @override
  String finPercentTotal(String percent) {
    return 'Total $percent%';
  }

  @override
  String get finBucketsUnconfirmed =>
      'Set your own percentages before splitting income into buckets.';

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
}
