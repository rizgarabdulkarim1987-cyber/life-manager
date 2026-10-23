import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_ckb.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ar'), Locale('ckb'), Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'My Life Manager'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get navFinance;

  /// No description provided for @navTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get navTasks;

  /// No description provided for @navVault.
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get navVault;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @appLock.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get appLock;

  /// No description provided for @biometrics.
  ///
  /// In en, this message translates to:
  /// **'Unlock with fingerprint'**
  String get biometrics;

  /// No description provided for @biometricsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No fingerprint or face unlock is set up on this phone'**
  String get biometricsUnavailable;

  /// No description provided for @changePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get changePin;

  /// No description provided for @currentPin.
  ///
  /// In en, this message translates to:
  /// **'Current PIN'**
  String get currentPin;

  /// No description provided for @newPin.
  ///
  /// In en, this message translates to:
  /// **'New PIN'**
  String get newPin;

  /// No description provided for @pinChanged.
  ///
  /// In en, this message translates to:
  /// **'PIN changed'**
  String get pinChanged;

  /// No description provided for @lockTimeout.
  ///
  /// In en, this message translates to:
  /// **'Lock after leaving the app'**
  String get lockTimeout;

  /// No description provided for @lockImmediately.
  ///
  /// In en, this message translates to:
  /// **'Immediately'**
  String get lockImmediately;

  /// No description provided for @lockAfterMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{After 1 minute} other{After {minutes} minutes}}'**
  String lockAfterMinutes(int minutes);

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & restore'**
  String get backupRestore;

  /// No description provided for @lastBackup.
  ///
  /// In en, this message translates to:
  /// **'Last backup: {date}'**
  String lastBackup(String date);

  /// No description provided for @neverBackedUp.
  ///
  /// In en, this message translates to:
  /// **'Never backed up'**
  String get neverBackedUp;

  /// No description provided for @createBackup.
  ///
  /// In en, this message translates to:
  /// **'Create backup'**
  String get createBackup;

  /// No description provided for @restoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get restoreBackup;

  /// No description provided for @backupPassword.
  ///
  /// In en, this message translates to:
  /// **'Backup password'**
  String get backupPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters'**
  String get passwordTooShort;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get passwordsDontMatch;

  /// No description provided for @backupWarning.
  ///
  /// In en, this message translates to:
  /// **'Your data lives only on this phone. If you lose the phone or uninstall the app without a backup, everything is gone. Save backups somewhere off the phone.'**
  String get backupWarning;

  /// No description provided for @backupCreated.
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get backupCreated;

  /// No description provided for @restoreConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace all current data?'**
  String get restoreConfirmTitle;

  /// No description provided for @restoreConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Backup from {date}, app version {version}. Everything currently in the app will be replaced.'**
  String restoreConfirmBody(String date, String version);

  /// No description provided for @replace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @enterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN'**
  String get enterPin;

  /// No description provided for @wrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN'**
  String get wrongPin;

  /// No description provided for @attemptsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 attempt left before a pause} other{{count} attempts left before a pause}}'**
  String attemptsLeft(int count);

  /// No description provided for @tryAgainIn.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {time}'**
  String tryAgainIn(String time);

  /// No description provided for @unlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock My Life Manager'**
  String get unlockReason;

  /// No description provided for @useFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint'**
  String get useFingerprint;

  /// No description provided for @setupWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get setupWelcome;

  /// No description provided for @setupWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Everything stays on this phone, under your lock.'**
  String get setupWelcomeBody;

  /// No description provided for @setupChooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get setupChooseLanguage;

  /// No description provided for @setupCreatePin.
  ///
  /// In en, this message translates to:
  /// **'Create a 6-digit PIN'**
  String get setupCreatePin;

  /// No description provided for @setupConfirmPin.
  ///
  /// In en, this message translates to:
  /// **'Enter the PIN again'**
  String get setupConfirmPin;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'The PINs don\'t match. Start again.'**
  String get pinMismatch;

  /// No description provided for @setupEnableBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Unlock with fingerprint too?'**
  String get setupEnableBiometrics;

  /// No description provided for @setupEnableBiometricsBody.
  ///
  /// In en, this message translates to:
  /// **'Your PIN always works as a fallback.'**
  String get setupEnableBiometricsBody;

  /// No description provided for @enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// No description provided for @setupBackupWarning.
  ///
  /// In en, this message translates to:
  /// **'One important thing'**
  String get setupBackupWarning;

  /// No description provided for @iUnderstand.
  ///
  /// In en, this message translates to:
  /// **'I understand'**
  String get iUnderstand;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get finish;

  /// No description provided for @comingInPhase.
  ///
  /// In en, this message translates to:
  /// **'Arrives in phase {phase}'**
  String comingInPhase(int phase);

  /// No description provided for @seedPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get seedPersonal;

  /// No description provided for @seedBuzzify.
  ///
  /// In en, this message translates to:
  /// **'Buzzify'**
  String get seedBuzzify;

  /// No description provided for @seedEo.
  ///
  /// In en, this message translates to:
  /// **'Related / EO'**
  String get seedEo;

  /// No description provided for @seedOtherProjects.
  ///
  /// In en, this message translates to:
  /// **'Other Projects'**
  String get seedOtherProjects;

  /// No description provided for @seedCashIqd.
  ///
  /// In en, this message translates to:
  /// **'Cash IQD'**
  String get seedCashIqd;

  /// No description provided for @seedCashUsd.
  ///
  /// In en, this message translates to:
  /// **'Cash USD'**
  String get seedCashUsd;

  /// No description provided for @accounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// No description provided for @homeMonthSummary.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get homeMonthSummary;

  /// No description provided for @homeChart.
  ///
  /// In en, this message translates to:
  /// **'Income vs expenses'**
  String get homeChart;

  /// No description provided for @homeBuckets.
  ///
  /// In en, this message translates to:
  /// **'Buckets'**
  String get homeBuckets;

  /// No description provided for @homeTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get homeTasks;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @privacyPhase1.
  ///
  /// In en, this message translates to:
  /// **'Your data stays on this phone. Only if you turn on online AI and agree is a capture\'s voice or text sent to Groq. The vault never leaves the phone.'**
  String get privacyPhase1;

  /// No description provided for @restoreTooNew.
  ///
  /// In en, this message translates to:
  /// **'This backup was made by a newer version of the app. Update the app first.'**
  String get restoreTooNew;

  /// No description provided for @restoreWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password, or the file is damaged.'**
  String get restoreWrongPassword;

  /// No description provided for @restoreCorrupt.
  ///
  /// In en, this message translates to:
  /// **'This file is damaged or isn\'t a backup from this app.'**
  String get restoreCorrupt;

  /// No description provided for @restoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Restored. Restarting…'**
  String get restoreSuccess;

  /// No description provided for @passwordStrengthWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak: make it longer, or mix letters, numbers and symbols'**
  String get passwordStrengthWeak;

  /// No description provided for @passwordStrengthFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get passwordStrengthFair;

  /// No description provided for @passwordStrengthStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get passwordStrengthStrong;

  /// No description provided for @backupPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'You will need this password to restore. If you forget it, it cannot be recovered. A saved Groq key is kept inside the encrypted backup too.'**
  String get backupPasswordHint;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get somethingWentWrong;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'The backup couldn\'t be created. Your data is unchanged.'**
  String get backupFailed;

  /// No description provided for @startupFailed.
  ///
  /// In en, this message translates to:
  /// **'Your data couldn\'t be opened. Nothing was deleted.'**
  String get startupFailed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @cat_food.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get cat_food;

  /// No description provided for @cat_transport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get cat_transport;

  /// No description provided for @cat_rent.
  ///
  /// In en, this message translates to:
  /// **'Rent'**
  String get cat_rent;

  /// No description provided for @cat_bills.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get cat_bills;

  /// No description provided for @cat_family.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get cat_family;

  /// No description provided for @cat_shopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get cat_shopping;

  /// No description provided for @cat_health.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get cat_health;

  /// No description provided for @cat_business.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get cat_business;

  /// No description provided for @cat_marketing.
  ///
  /// In en, this message translates to:
  /// **'Marketing'**
  String get cat_marketing;

  /// No description provided for @cat_subscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get cat_subscriptions;

  /// No description provided for @cat_other_expense.
  ///
  /// In en, this message translates to:
  /// **'Other expense'**
  String get cat_other_expense;

  /// No description provided for @cat_salary.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get cat_salary;

  /// No description provided for @cat_business_income.
  ///
  /// In en, this message translates to:
  /// **'Business income'**
  String get cat_business_income;

  /// No description provided for @cat_freelance.
  ///
  /// In en, this message translates to:
  /// **'Freelance'**
  String get cat_freelance;

  /// No description provided for @cat_client_payment.
  ///
  /// In en, this message translates to:
  /// **'Client payment'**
  String get cat_client_payment;

  /// No description provided for @cat_other_income.
  ///
  /// In en, this message translates to:
  /// **'Other income'**
  String get cat_other_income;

  /// No description provided for @bucket_expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get bucket_expenses;

  /// No description provided for @bucket_emergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get bucket_emergency;

  /// No description provided for @bucket_investment.
  ///
  /// In en, this message translates to:
  /// **'Investment'**
  String get bucket_investment;

  /// No description provided for @finIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get finIncome;

  /// No description provided for @finExpense.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get finExpense;

  /// No description provided for @finSurplus.
  ///
  /// In en, this message translates to:
  /// **'Surplus'**
  String get finSurplus;

  /// No description provided for @finAllAccounts.
  ///
  /// In en, this message translates to:
  /// **'All accounts'**
  String get finAllAccounts;

  /// No description provided for @finHowConvertedHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to see how it was converted'**
  String get finHowConvertedHint;

  /// No description provided for @finNoTotal.
  ///
  /// In en, this message translates to:
  /// **'No rate for {currencies} yet, so there is no single total'**
  String finNoTotal(String currencies);

  /// No description provided for @finSetRate.
  ///
  /// In en, this message translates to:
  /// **'Set a rate'**
  String get finSetRate;

  /// No description provided for @finRateTitle.
  ///
  /// In en, this message translates to:
  /// **'Exchange rate'**
  String get finRateTitle;

  /// No description provided for @finRateLabel.
  ///
  /// In en, this message translates to:
  /// **'1 USD in IQD'**
  String get finRateLabel;

  /// No description provided for @finRateInvalid.
  ///
  /// In en, this message translates to:
  /// **'Type a rate like 1310'**
  String get finRateInvalid;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @finHowConverted.
  ///
  /// In en, this message translates to:
  /// **'How it was converted'**
  String get finHowConverted;

  /// No description provided for @finSameCurrency.
  ///
  /// In en, this message translates to:
  /// **'Same currency'**
  String get finSameCurrency;

  /// No description provided for @finNoRate.
  ///
  /// In en, this message translates to:
  /// **'No rate'**
  String get finNoRate;

  /// No description provided for @finRateLine.
  ///
  /// In en, this message translates to:
  /// **'1 {base} = {rate} {quote} · from {date}'**
  String finRateLine(String base, String rate, String quote, String date);

  /// No description provided for @finPerCurrency.
  ///
  /// In en, this message translates to:
  /// **'Per currency'**
  String get finPerCurrency;

  /// No description provided for @finTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get finTotal;

  /// No description provided for @alertExpensesBucket.
  ///
  /// In en, this message translates to:
  /// **'Expenses bucket at {percent}% this month'**
  String alertExpensesBucket(int percent);

  /// No description provided for @alertEmergencyReached.
  ///
  /// In en, this message translates to:
  /// **'Emergency fund reached its target'**
  String get alertEmergencyReached;

  /// No description provided for @alertEmergencyBelow.
  ///
  /// In en, this message translates to:
  /// **'Emergency fund is below its target'**
  String get alertEmergencyBelow;

  /// No description provided for @alertUnallocated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 income not split into buckets} other{{count} incomes not split into buckets}}'**
  String alertUnallocated(int count);

  /// No description provided for @alertBudget.
  ///
  /// In en, this message translates to:
  /// **'{name} budget at {percent}%'**
  String alertBudget(String name, int percent);

  /// No description provided for @alertDebtSoon.
  ///
  /// In en, this message translates to:
  /// **'{name}: payment due {date}'**
  String alertDebtSoon(String name, String date);

  /// No description provided for @alertDebtOverdue.
  ///
  /// In en, this message translates to:
  /// **'{name}: payment overdue'**
  String alertDebtOverdue(String name);

  /// No description provided for @finHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get finHistory;

  /// No description provided for @finAddAccount.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get finAddAccount;

  /// No description provided for @finAccountName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get finAccountName;

  /// No description provided for @finNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Type a name'**
  String get finNameRequired;

  /// No description provided for @finWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get finWorkspace;

  /// No description provided for @finCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get finCurrency;

  /// No description provided for @finKind.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get finKind;

  /// No description provided for @kindCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get kindCash;

  /// No description provided for @kindBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get kindBank;

  /// No description provided for @kindSavings.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get kindSavings;

  /// No description provided for @kindCustom.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get kindCustom;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @finArchiveAccount.
  ///
  /// In en, this message translates to:
  /// **'Archive {name}? Its history stays.'**
  String finArchiveAccount(String name);

  /// No description provided for @finBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get finBalance;

  /// No description provided for @finAdjustBalance.
  ///
  /// In en, this message translates to:
  /// **'Adjust balance'**
  String get finAdjustBalance;

  /// No description provided for @finAdjustHint.
  ///
  /// In en, this message translates to:
  /// **'Type what is actually in this account. The difference is saved as an adjustment.'**
  String get finAdjustHint;

  /// No description provided for @finActualAmount.
  ///
  /// In en, this message translates to:
  /// **'Actual amount'**
  String get finActualAmount;

  /// No description provided for @finAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Type an amount like 25000'**
  String get finAmountInvalid;

  /// No description provided for @finSearch.
  ///
  /// In en, this message translates to:
  /// **'Search descriptions'**
  String get finSearch;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterDates.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get filterDates;

  /// No description provided for @filterAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get filterAccount;

  /// No description provided for @filterCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get filterCategory;

  /// No description provided for @filterType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get filterType;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @typeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get typeIncome;

  /// No description provided for @typeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get typeExpense;

  /// No description provided for @typeRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get typeRefund;

  /// No description provided for @typeAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get typeAdjustment;

  /// No description provided for @typeTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get typeTransfer;

  /// No description provided for @typeOwnerDraw.
  ///
  /// In en, this message translates to:
  /// **'Owner draw'**
  String get typeOwnerDraw;

  /// No description provided for @typeDebtPayment.
  ///
  /// In en, this message translates to:
  /// **'Debt payment'**
  String get typeDebtPayment;

  /// No description provided for @finPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get finPending;

  /// No description provided for @finUncategorised.
  ///
  /// In en, this message translates to:
  /// **'Uncategorised'**
  String get finUncategorised;

  /// No description provided for @finNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get finNoTransactions;

  /// No description provided for @finNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No transactions match these filters'**
  String get finNoMatches;

  /// No description provided for @finDeleted.
  ///
  /// In en, this message translates to:
  /// **'Transaction deleted'**
  String get finDeleted;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @finToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get finToday;

  /// No description provided for @finAddExpense.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get finAddExpense;

  /// No description provided for @finAddIncome.
  ///
  /// In en, this message translates to:
  /// **'Add income'**
  String get finAddIncome;

  /// No description provided for @finAddRefund.
  ///
  /// In en, this message translates to:
  /// **'Add refund'**
  String get finAddRefund;

  /// No description provided for @finAddTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get finAddTransfer;

  /// No description provided for @finEditTransaction.
  ///
  /// In en, this message translates to:
  /// **'Edit transaction'**
  String get finEditTransaction;

  /// No description provided for @finEditTransfer.
  ///
  /// In en, this message translates to:
  /// **'Edit transfer'**
  String get finEditTransfer;

  /// No description provided for @finAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get finAmount;

  /// No description provided for @finAmountRounded.
  ///
  /// In en, this message translates to:
  /// **'Rounded to what {currency} allows'**
  String finAmountRounded(String currency);

  /// No description provided for @finAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get finAccount;

  /// No description provided for @finChooseAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose an account'**
  String get finChooseAccount;

  /// No description provided for @finCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get finCategory;

  /// No description provided for @finNoCategory.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get finNoCategory;

  /// No description provided for @finDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get finDate;

  /// No description provided for @finTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get finTime;

  /// No description provided for @finDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get finDescription;

  /// No description provided for @finNotReceived.
  ///
  /// In en, this message translates to:
  /// **'Not received yet'**
  String get finNotReceived;

  /// No description provided for @finNotReceivedHint.
  ///
  /// In en, this message translates to:
  /// **'Pending income doesn\'t count in balances'**
  String get finNotReceivedHint;

  /// No description provided for @finAllocate.
  ///
  /// In en, this message translates to:
  /// **'Split into buckets'**
  String get finAllocate;

  /// No description provided for @finAllocateNoRate.
  ///
  /// In en, this message translates to:
  /// **'Set a {currency} rate first to split this income'**
  String finAllocateNoRate(String currency);

  /// No description provided for @finAllocatePending.
  ///
  /// In en, this message translates to:
  /// **'Only received income can be split'**
  String get finAllocatePending;

  /// No description provided for @finUnallocated.
  ///
  /// In en, this message translates to:
  /// **'Not split'**
  String get finUnallocated;

  /// No description provided for @finOverAllocated.
  ///
  /// In en, this message translates to:
  /// **'Over by'**
  String get finOverAllocated;

  /// No description provided for @finBucketTag.
  ///
  /// In en, this message translates to:
  /// **'Paid from bucket'**
  String get finBucketTag;

  /// No description provided for @finBucketNone.
  ///
  /// In en, this message translates to:
  /// **'Normal spending'**
  String get finBucketNone;

  /// No description provided for @finClearAllocationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear the bucket split?'**
  String get finClearAllocationsTitle;

  /// No description provided for @finClearAllocationsBody.
  ///
  /// In en, this message translates to:
  /// **'This income is split into buckets. Changing its money clears the split; you can split it again afterwards.'**
  String get finClearAllocationsBody;

  /// No description provided for @finClearAndSave.
  ///
  /// In en, this message translates to:
  /// **'Clear and save'**
  String get finClearAndSave;

  /// No description provided for @finFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get finFrom;

  /// No description provided for @finTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get finTo;

  /// No description provided for @finToAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount received'**
  String get finToAmount;

  /// No description provided for @finRateField.
  ///
  /// In en, this message translates to:
  /// **'{quote} per 1 {base}'**
  String finRateField(String quote, String base);

  /// No description provided for @finTwoOfThree.
  ///
  /// In en, this message translates to:
  /// **'Type any two; the third is worked out'**
  String get finTwoOfThree;

  /// No description provided for @finOwnerDraw.
  ///
  /// In en, this message translates to:
  /// **'Owner draw (salary)'**
  String get finOwnerDraw;

  /// No description provided for @finOwnerDrawHint.
  ///
  /// In en, this message translates to:
  /// **'Counts as an expense of the business and income of the person'**
  String get finOwnerDrawHint;

  /// No description provided for @finSameAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose two different accounts'**
  String get finSameAccount;

  /// No description provided for @finSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get finSaved;

  /// No description provided for @finBuckets.
  ///
  /// In en, this message translates to:
  /// **'Buckets'**
  String get finBuckets;

  /// No description provided for @finBudgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get finBudgets;

  /// No description provided for @finDebts.
  ///
  /// In en, this message translates to:
  /// **'Debts'**
  String get finDebts;

  /// No description provided for @finAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get finAvailable;

  /// No description provided for @finAllocated.
  ///
  /// In en, this message translates to:
  /// **'Split in'**
  String get finAllocated;

  /// No description provided for @finSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get finSpent;

  /// No description provided for @finTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get finTarget;

  /// No description provided for @finSetTarget.
  ///
  /// In en, this message translates to:
  /// **'Set target'**
  String get finSetTarget;

  /// No description provided for @finTargetHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for no target'**
  String get finTargetHint;

  /// No description provided for @finEditPercentages.
  ///
  /// In en, this message translates to:
  /// **'Edit percentages'**
  String get finEditPercentages;

  /// No description provided for @finPercentagesNote.
  ///
  /// In en, this message translates to:
  /// **'Must add up to 100%. Only income you split after saving uses the new percentages.'**
  String get finPercentagesNote;

  /// No description provided for @finPercentTotal.
  ///
  /// In en, this message translates to:
  /// **'Total {percent}%'**
  String finPercentTotal(String percent);

  /// No description provided for @finBucketsUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Set your own percentages before splitting income into buckets.'**
  String get finBucketsUnconfirmed;

  /// No description provided for @finExpensesMonthly.
  ///
  /// In en, this message translates to:
  /// **'Resets every month'**
  String get finExpensesMonthly;

  /// No description provided for @finCarriesOver.
  ///
  /// In en, this message translates to:
  /// **'Carries over'**
  String get finCarriesOver;

  /// No description provided for @finAddBudget.
  ///
  /// In en, this message translates to:
  /// **'Add budget'**
  String get finAddBudget;

  /// No description provided for @finEditBudget.
  ///
  /// In en, this message translates to:
  /// **'Edit budget'**
  String get finEditBudget;

  /// No description provided for @finBudgetNeedsScope.
  ///
  /// In en, this message translates to:
  /// **'Choose a category, a workspace or both'**
  String get finBudgetNeedsScope;

  /// No description provided for @finAnyWorkspace.
  ///
  /// In en, this message translates to:
  /// **'All workspaces'**
  String get finAnyWorkspace;

  /// No description provided for @finAnyCategory.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get finAnyCategory;

  /// No description provided for @finRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get finRemaining;

  /// No description provided for @finOfBudget.
  ///
  /// In en, this message translates to:
  /// **'of {amount}'**
  String finOfBudget(String amount);

  /// No description provided for @finMissingRatesNote.
  ///
  /// In en, this message translates to:
  /// **'Left out: {currencies} (no rate on those dates)'**
  String finMissingRatesNote(String currencies);

  /// No description provided for @finNoBudgets.
  ///
  /// In en, this message translates to:
  /// **'No budgets yet'**
  String get finNoBudgets;

  /// No description provided for @finOwedToMe.
  ///
  /// In en, this message translates to:
  /// **'Owed to me'**
  String get finOwedToMe;

  /// No description provided for @finOwedByMe.
  ///
  /// In en, this message translates to:
  /// **'I owe'**
  String get finOwedByMe;

  /// No description provided for @finAddDebt.
  ///
  /// In en, this message translates to:
  /// **'Add debt'**
  String get finAddDebt;

  /// No description provided for @finCounterparty.
  ///
  /// In en, this message translates to:
  /// **'Person or company'**
  String get finCounterparty;

  /// No description provided for @finStartDate.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get finStartDate;

  /// No description provided for @finRecordMoveNow.
  ///
  /// In en, this message translates to:
  /// **'Record the money now'**
  String get finRecordMoveNow;

  /// No description provided for @finRecordMoveGiven.
  ///
  /// In en, this message translates to:
  /// **'Money left this account'**
  String get finRecordMoveGiven;

  /// No description provided for @finRecordMoveReceived.
  ///
  /// In en, this message translates to:
  /// **'Money came into this account'**
  String get finRecordMoveReceived;

  /// No description provided for @finInstallments.
  ///
  /// In en, this message translates to:
  /// **'Installments'**
  String get finInstallments;

  /// No description provided for @finInstallmentCount.
  ///
  /// In en, this message translates to:
  /// **'Number of monthly installments (optional)'**
  String get finInstallmentCount;

  /// No description provided for @finFirstDue.
  ///
  /// In en, this message translates to:
  /// **'First due'**
  String get finFirstDue;

  /// No description provided for @finNextDue.
  ///
  /// In en, this message translates to:
  /// **'Next due {date}'**
  String finNextDue(String date);

  /// No description provided for @finOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get finOverdue;

  /// No description provided for @finPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get finPaid;

  /// No description provided for @finNoDebts.
  ///
  /// In en, this message translates to:
  /// **'Nothing here'**
  String get finNoDebts;

  /// No description provided for @finRecordRepayment.
  ///
  /// In en, this message translates to:
  /// **'Record repayment'**
  String get finRecordRepayment;

  /// No description provided for @finRepaymentTooBig.
  ///
  /// In en, this message translates to:
  /// **'Up to {amount}'**
  String finRepaymentTooBig(String amount);

  /// No description provided for @finWrongCurrency.
  ///
  /// In en, this message translates to:
  /// **'Choose an account in {currency}'**
  String finWrongCurrency(String currency);

  /// No description provided for @finPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get finPayments;

  /// No description provided for @finPrincipal.
  ///
  /// In en, this message translates to:
  /// **'Principal'**
  String get finPrincipal;

  /// No description provided for @finRepayment.
  ///
  /// In en, this message translates to:
  /// **'Repayment'**
  String get finRepayment;

  /// No description provided for @finClosed.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get finClosed;

  /// No description provided for @finNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get finNotes;

  /// No description provided for @finReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get finReports;

  /// No description provided for @repRange.
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get repRange;

  /// No description provided for @repThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get repThisMonth;

  /// No description provided for @repLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get repLastMonth;

  /// No description provided for @repLastMonths.
  ///
  /// In en, this message translates to:
  /// **'Last {count} months'**
  String repLastMonths(int count);

  /// No description provided for @repCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom dates'**
  String get repCustom;

  /// No description provided for @repGroupBy.
  ///
  /// In en, this message translates to:
  /// **'Group by'**
  String get repGroupBy;

  /// No description provided for @repDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get repDaily;

  /// No description provided for @repWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get repWeekly;

  /// No description provided for @repMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get repMonthly;

  /// No description provided for @repAllWorkspaces.
  ///
  /// In en, this message translates to:
  /// **'All workspaces'**
  String get repAllWorkspaces;

  /// No description provided for @repTabIncomeExpense.
  ///
  /// In en, this message translates to:
  /// **'Income vs expenses'**
  String get repTabIncomeExpense;

  /// No description provided for @repTabCategory.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get repTabCategory;

  /// No description provided for @repTabWorkspace.
  ///
  /// In en, this message translates to:
  /// **'By workspace'**
  String get repTabWorkspace;

  /// No description provided for @repTabCashFlow.
  ///
  /// In en, this message translates to:
  /// **'Cash flow'**
  String get repTabCashFlow;

  /// No description provided for @repTabBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance over time'**
  String get repTabBalance;

  /// No description provided for @repTabDebts.
  ///
  /// In en, this message translates to:
  /// **'Outstanding debts'**
  String get repTabDebts;

  /// No description provided for @repShowTable.
  ///
  /// In en, this message translates to:
  /// **'Show as table'**
  String get repShowTable;

  /// No description provided for @repShowChart.
  ///
  /// In en, this message translates to:
  /// **'Show as chart'**
  String get repShowChart;

  /// No description provided for @repSkipped.
  ///
  /// In en, this message translates to:
  /// **'{count} left out: no {currencies} rate on their dates'**
  String repSkipped(int count, String currencies);

  /// No description provided for @repMoneyIn.
  ///
  /// In en, this message translates to:
  /// **'Money in'**
  String get repMoneyIn;

  /// No description provided for @repMoneyOut.
  ///
  /// In en, this message translates to:
  /// **'Money out'**
  String get repMoneyOut;

  /// No description provided for @repNet.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get repNet;

  /// No description provided for @repOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get repOther;

  /// No description provided for @repPeriodColumn.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get repPeriodColumn;

  /// No description provided for @repBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get repBalance;

  /// No description provided for @repNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this range'**
  String get repNothing;

  /// No description provided for @repBucketsMonth.
  ///
  /// In en, this message translates to:
  /// **'{month}, in {currency}'**
  String repBucketsMonth(String month, String currency);

  /// No description provided for @repExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get repExport;

  /// No description provided for @repExportCsv.
  ///
  /// In en, this message translates to:
  /// **'Transactions as CSV'**
  String get repExportCsv;

  /// No description provided for @repExportPdf.
  ///
  /// In en, this message translates to:
  /// **'Report as PDF'**
  String get repExportPdf;

  /// No description provided for @repNotEncrypted.
  ///
  /// In en, this message translates to:
  /// **'This file is not encrypted. Anyone who gets it can read it.'**
  String get repNotEncrypted;

  /// No description provided for @repExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the file'**
  String get repExportFailed;

  /// No description provided for @setFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get setFinance;

  /// No description provided for @setFinanceSettings.
  ///
  /// In en, this message translates to:
  /// **'Currency and rates'**
  String get setFinanceSettings;

  /// No description provided for @setFinanceSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Base currency, USD rate, alerts'**
  String get setFinanceSettingsHint;

  /// No description provided for @setCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get setCategories;

  /// No description provided for @setCategoriesHint.
  ///
  /// In en, this message translates to:
  /// **'Names and the words that pick them'**
  String get setCategoriesHint;

  /// No description provided for @setWorkspaces.
  ///
  /// In en, this message translates to:
  /// **'Workspaces'**
  String get setWorkspaces;

  /// No description provided for @setWorkspacesHint.
  ///
  /// In en, this message translates to:
  /// **'Names, aliases, buckets'**
  String get setWorkspacesHint;

  /// No description provided for @setBaseCurrency.
  ///
  /// In en, this message translates to:
  /// **'Base currency'**
  String get setBaseCurrency;

  /// No description provided for @setBaseCurrencyHint.
  ///
  /// In en, this message translates to:
  /// **'Totals, buckets and reports use it unless you pick another.'**
  String get setBaseCurrencyHint;

  /// No description provided for @setRateDate.
  ///
  /// In en, this message translates to:
  /// **'From {date}'**
  String setRateDate(String date);

  /// No description provided for @setRateHistory.
  ///
  /// In en, this message translates to:
  /// **'Rate history'**
  String get setRateHistory;

  /// No description provided for @setNoRates.
  ///
  /// In en, this message translates to:
  /// **'No rate yet. USD and IQD stay apart until you add one.'**
  String get setNoRates;

  /// No description provided for @setRateSaved.
  ///
  /// In en, this message translates to:
  /// **'Rate saved'**
  String get setRateSaved;

  /// No description provided for @setAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get setAlerts;

  /// No description provided for @setUnallocatedAlert.
  ///
  /// In en, this message translates to:
  /// **'Remind me about income not split into buckets'**
  String get setUnallocatedAlert;

  /// No description provided for @setUnallocatedAlertHint.
  ///
  /// In en, this message translates to:
  /// **'Shows on the Finance screen'**
  String get setUnallocatedAlertHint;

  /// No description provided for @setIncomeCategories.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get setIncomeCategories;

  /// No description provided for @setExpenseCategories.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get setExpenseCategories;

  /// No description provided for @setAddCategory.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get setAddCategory;

  /// No description provided for @setEditCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get setEditCategory;

  /// No description provided for @setKeywords.
  ///
  /// In en, this message translates to:
  /// **'Words that pick this category'**
  String get setKeywords;

  /// No description provided for @setBuiltInWords.
  ///
  /// In en, this message translates to:
  /// **'Built in'**
  String get setBuiltInWords;

  /// No description provided for @setYourWords.
  ///
  /// In en, this message translates to:
  /// **'Your words'**
  String get setYourWords;

  /// No description provided for @setAddWord.
  ///
  /// In en, this message translates to:
  /// **'Add a word'**
  String get setAddWord;

  /// No description provided for @setRemoveWord.
  ///
  /// In en, this message translates to:
  /// **'Remove {word}'**
  String setRemoveWord(String word);

  /// No description provided for @setArchiveCategory.
  ///
  /// In en, this message translates to:
  /// **'Archive {name}? Old entries keep it.'**
  String setArchiveCategory(String name);

  /// No description provided for @setAddWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Add workspace'**
  String get setAddWorkspace;

  /// No description provided for @setEditWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Edit workspace'**
  String get setEditWorkspace;

  /// No description provided for @setIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get setIcon;

  /// No description provided for @setColour.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get setColour;

  /// No description provided for @setAliases.
  ///
  /// In en, this message translates to:
  /// **'Other names you say'**
  String get setAliases;

  /// No description provided for @setAliasesHint.
  ///
  /// In en, this message translates to:
  /// **'Voice and quick capture match these too'**
  String get setAliasesHint;

  /// No description provided for @setAddAlias.
  ///
  /// In en, this message translates to:
  /// **'Add a name'**
  String get setAddAlias;

  /// No description provided for @setCountsInBuckets.
  ///
  /// In en, this message translates to:
  /// **'Counts in buckets'**
  String get setCountsInBuckets;

  /// No description provided for @setCountsInBucketsHint.
  ///
  /// In en, this message translates to:
  /// **'Its expenses come out of the Expenses bucket'**
  String get setCountsInBucketsHint;

  /// No description provided for @setArchiveWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Archive {name}? Its history stays.'**
  String setArchiveWorkspace(String name);

  /// No description provided for @setArchiveBlocked.
  ///
  /// In en, this message translates to:
  /// **'Archive or move its accounts first. {name} still has accounts in use.'**
  String setArchiveBlocked(String name);

  /// No description provided for @setArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get setArchived;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @impTitle.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get impTitle;

  /// No description provided for @impEntry.
  ///
  /// In en, this message translates to:
  /// **'Import a sheet'**
  String get impEntry;

  /// No description provided for @impStepFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get impStepFile;

  /// No description provided for @impStepColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get impStepColumns;

  /// No description provided for @impStepDefaults.
  ///
  /// In en, this message translates to:
  /// **'Defaults'**
  String get impStepDefaults;

  /// No description provided for @impStepValues.
  ///
  /// In en, this message translates to:
  /// **'Match values'**
  String get impStepValues;

  /// No description provided for @impStepPreview.
  ///
  /// In en, this message translates to:
  /// **'Check and import'**
  String get impStepPreview;

  /// No description provided for @impStepOpening.
  ///
  /// In en, this message translates to:
  /// **'Balances today'**
  String get impStepOpening;

  /// No description provided for @impStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {n} of {total}'**
  String impStepOf(int n, int total);

  /// No description provided for @impPickHint.
  ///
  /// In en, this message translates to:
  /// **'An .xlsx or .csv from your bank or an old sheet. Nothing is saved until you tap Import.'**
  String get impPickHint;

  /// No description provided for @impPick.
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get impPick;

  /// No description provided for @impPickAnother.
  ///
  /// In en, this message translates to:
  /// **'Choose another file'**
  String get impPickAnother;

  /// No description provided for @impTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This file is too big: over 50,000 rows or 64 columns.'**
  String get impTooLarge;

  /// No description provided for @impUnreadable.
  ///
  /// In en, this message translates to:
  /// **'This file could not be read as .xlsx or .csv.'**
  String get impUnreadable;

  /// No description provided for @impSheet.
  ///
  /// In en, this message translates to:
  /// **'Sheet'**
  String get impSheet;

  /// No description provided for @impHeaderRow.
  ///
  /// In en, this message translates to:
  /// **'Which row has the column names?'**
  String get impHeaderRow;

  /// No description provided for @impRowN.
  ///
  /// In en, this message translates to:
  /// **'Row {n}'**
  String impRowN(int n);

  /// No description provided for @impColDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get impColDate;

  /// No description provided for @impDateOrder.
  ///
  /// In en, this message translates to:
  /// **'Date order'**
  String get impDateOrder;

  /// No description provided for @impDayFirst.
  ///
  /// In en, this message translates to:
  /// **'Day first (31/12)'**
  String get impDayFirst;

  /// No description provided for @impMonthFirst.
  ///
  /// In en, this message translates to:
  /// **'Month first (12/31)'**
  String get impMonthFirst;

  /// No description provided for @impYearFirst.
  ///
  /// In en, this message translates to:
  /// **'Year first (2025-12-31)'**
  String get impYearFirst;

  /// No description provided for @impAmountMode.
  ///
  /// In en, this message translates to:
  /// **'How amounts are written'**
  String get impAmountMode;

  /// No description provided for @impSigned.
  ///
  /// In en, this message translates to:
  /// **'One column, minus means expense'**
  String get impSigned;

  /// No description provided for @impTypeColumn.
  ///
  /// In en, this message translates to:
  /// **'One column plus a type column'**
  String get impTypeColumn;

  /// No description provided for @impSplit.
  ///
  /// In en, this message translates to:
  /// **'Separate income and expense columns'**
  String get impSplit;

  /// No description provided for @impColAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get impColAmount;

  /// No description provided for @impColIncome.
  ///
  /// In en, this message translates to:
  /// **'Income column'**
  String get impColIncome;

  /// No description provided for @impColExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense column'**
  String get impColExpense;

  /// No description provided for @impColType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get impColType;

  /// No description provided for @impColCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get impColCurrency;

  /// No description provided for @impColCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get impColCategory;

  /// No description provided for @impColWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get impColWorkspace;

  /// No description provided for @impColAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get impColAccount;

  /// No description provided for @impColDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get impColDescription;

  /// No description provided for @impNone.
  ///
  /// In en, this message translates to:
  /// **'Not in the file'**
  String get impNone;

  /// No description provided for @impColumnLetter.
  ///
  /// In en, this message translates to:
  /// **'Column {letter}'**
  String impColumnLetter(String letter);

  /// No description provided for @impNeedDateAmount.
  ///
  /// In en, this message translates to:
  /// **'Pick the date and amount columns to go on.'**
  String get impNeedDateAmount;

  /// No description provided for @impDefaultsHint.
  ///
  /// In en, this message translates to:
  /// **'Used for rows that do not say.'**
  String get impDefaultsHint;

  /// No description provided for @impNoValues.
  ///
  /// In en, this message translates to:
  /// **'Nothing to match: the file has no type, category, workspace or account column.'**
  String get impNoValues;

  /// No description provided for @impCreateNew.
  ///
  /// In en, this message translates to:
  /// **'Create new'**
  String get impCreateNew;

  /// No description provided for @impSkipRow.
  ///
  /// In en, this message translates to:
  /// **'Skip these rows'**
  String get impSkipRow;

  /// No description provided for @impLeaveEmpty.
  ///
  /// In en, this message translates to:
  /// **'Leave empty'**
  String get impLeaveEmpty;

  /// No description provided for @impUseDefault.
  ///
  /// In en, this message translates to:
  /// **'Use the default'**
  String get impUseDefault;

  /// No description provided for @impReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get impReady;

  /// No description provided for @impDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Already in the app'**
  String get impDuplicates;

  /// No description provided for @impProblems.
  ///
  /// In en, this message translates to:
  /// **'Can\'t read'**
  String get impProblems;

  /// No description provided for @impSkipDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Skip rows already in the app'**
  String get impSkipDuplicates;

  /// No description provided for @impProblemDate.
  ///
  /// In en, this message translates to:
  /// **'no date'**
  String get impProblemDate;

  /// No description provided for @impProblemAmount.
  ///
  /// In en, this message translates to:
  /// **'no amount'**
  String get impProblemAmount;

  /// No description provided for @impProblemType.
  ///
  /// In en, this message translates to:
  /// **'unknown type'**
  String get impProblemType;

  /// No description provided for @impProblemAccount.
  ///
  /// In en, this message translates to:
  /// **'no account'**
  String get impProblemAccount;

  /// No description provided for @impDuplicateTag.
  ///
  /// In en, this message translates to:
  /// **'already there'**
  String get impDuplicateTag;

  /// No description provided for @impFirstRows.
  ///
  /// In en, this message translates to:
  /// **'First {count} rows'**
  String impFirstRows(int count);

  /// No description provided for @impImport.
  ///
  /// In en, this message translates to:
  /// **'Import {count} rows'**
  String impImport(int count);

  /// No description provided for @impImported.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} rows'**
  String impImported(int count);

  /// No description provided for @impOpeningHint.
  ///
  /// In en, this message translates to:
  /// **'Type what each account really holds today. A difference is saved as an adjustment.'**
  String get impOpeningHint;

  /// No description provided for @impComputed.
  ///
  /// In en, this message translates to:
  /// **'In the app: {amount}'**
  String impComputed(String amount);

  /// No description provided for @impActual.
  ///
  /// In en, this message translates to:
  /// **'Actual today'**
  String get impActual;

  /// No description provided for @impSaveBalances.
  ///
  /// In en, this message translates to:
  /// **'Save balances'**
  String get impSaveBalances;

  /// No description provided for @impDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get impDone;

  /// No description provided for @impNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get impNext;

  /// No description provided for @impBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get impBack;

  /// No description provided for @impPastImports.
  ///
  /// In en, this message translates to:
  /// **'Past imports'**
  String get impPastImports;

  /// No description provided for @impUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get impUndo;

  /// No description provided for @impUndoConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove the {count} rows imported from {name}?'**
  String impUndoConfirm(int count, String name);

  /// No description provided for @impUndone.
  ///
  /// In en, this message translates to:
  /// **'Undone'**
  String get impUndone;

  /// No description provided for @impBatchLine.
  ///
  /// In en, this message translates to:
  /// **'{count} rows · {date}'**
  String impBatchLine(int count, String date);

  /// No description provided for @setAi.
  ///
  /// In en, this message translates to:
  /// **'Online AI'**
  String get setAi;

  /// No description provided for @setAiHint.
  ///
  /// In en, this message translates to:
  /// **'Groq key, models and what is sent'**
  String get setAiHint;

  /// No description provided for @aiOnline.
  ///
  /// In en, this message translates to:
  /// **'Use online AI'**
  String get aiOnline;

  /// No description provided for @aiOnlineHint.
  ///
  /// In en, this message translates to:
  /// **'When off, everything is understood on the phone, a little less accurately.'**
  String get aiOnlineHint;

  /// No description provided for @aiKey.
  ///
  /// In en, this message translates to:
  /// **'Groq API key'**
  String get aiKey;

  /// No description provided for @aiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Free from console.groq.com. Kept encrypted on this phone only.'**
  String get aiKeyHint;

  /// No description provided for @aiKeySaved.
  ///
  /// In en, this message translates to:
  /// **'Saved key ••••{last4}'**
  String aiKeySaved(String last4);

  /// No description provided for @aiKeyRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get aiKeyRemove;

  /// No description provided for @aiKeyPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get aiKeyPaste;

  /// No description provided for @aiKeySave.
  ///
  /// In en, this message translates to:
  /// **'Save key'**
  String get aiKeySave;

  /// No description provided for @aiTest.
  ///
  /// In en, this message translates to:
  /// **'Test key'**
  String get aiTest;

  /// No description provided for @aiTestOk.
  ///
  /// In en, this message translates to:
  /// **'The key works.'**
  String get aiTestOk;

  /// No description provided for @aiTestUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Groq refused this key. Check it and save it again.'**
  String get aiTestUnauthorized;

  /// No description provided for @aiTestOffline.
  ///
  /// In en, this message translates to:
  /// **'Could not reach Groq. Check the internet.'**
  String get aiTestOffline;

  /// No description provided for @aiTestBusy.
  ///
  /// In en, this message translates to:
  /// **'Groq is busy. Try again in a minute.'**
  String get aiTestBusy;

  /// No description provided for @aiTestOther.
  ///
  /// In en, this message translates to:
  /// **'Groq did not answer as expected. Try again later.'**
  String get aiTestOther;

  /// No description provided for @aiModels.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get aiModels;

  /// No description provided for @aiSttModel.
  ///
  /// In en, this message translates to:
  /// **'Speech-to-text model'**
  String get aiSttModel;

  /// No description provided for @aiLlmModel.
  ///
  /// In en, this message translates to:
  /// **'Understanding model'**
  String get aiLlmModel;

  /// No description provided for @aiModelsSave.
  ///
  /// In en, this message translates to:
  /// **'Save models'**
  String get aiModelsSave;

  /// No description provided for @aiModelsSaved.
  ///
  /// In en, this message translates to:
  /// **'Models saved'**
  String get aiModelsSaved;

  /// No description provided for @aiConsents.
  ///
  /// In en, this message translates to:
  /// **'What is sent to Groq'**
  String get aiConsents;

  /// No description provided for @aiConsentVoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice to text'**
  String get aiConsentVoiceTitle;

  /// No description provided for @aiConsentParseTitle.
  ///
  /// In en, this message translates to:
  /// **'Filling in the form'**
  String get aiConsentParseTitle;

  /// No description provided for @aiConsentVoice.
  ///
  /// In en, this message translates to:
  /// **'Your voice recording is sent to Groq to turn it into text.'**
  String get aiConsentVoice;

  /// No description provided for @aiConsentParse.
  ///
  /// In en, this message translates to:
  /// **'The text of what you said, today\'s date and time, and the names of your accounts, workspaces, categories and buckets are sent to Groq to fill in the form. Balances, past transactions and the vault are never sent.'**
  String get aiConsentParse;

  /// No description provided for @aiConsentGranted.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get aiConsentGranted;

  /// No description provided for @aiConsentDeclined.
  ///
  /// In en, this message translates to:
  /// **'Not allowed'**
  String get aiConsentDeclined;

  /// No description provided for @aiConsentUnset.
  ///
  /// In en, this message translates to:
  /// **'Not asked yet'**
  String get aiConsentUnset;

  /// No description provided for @aiConsentReset.
  ///
  /// In en, this message translates to:
  /// **'Ask again'**
  String get aiConsentReset;

  /// No description provided for @aiOfflineModel.
  ///
  /// In en, this message translates to:
  /// **'Offline speech model'**
  String get aiOfflineModel;

  /// No description provided for @aiOfflineModelHint.
  ///
  /// In en, this message translates to:
  /// **'Turns speech into text on the phone when online AI is off or unreachable.'**
  String get aiOfflineModelHint;

  /// No description provided for @consentTitle.
  ///
  /// In en, this message translates to:
  /// **'Send this to Groq?'**
  String get consentTitle;

  /// No description provided for @consentWho.
  ///
  /// In en, this message translates to:
  /// **'Groq, Inc. processes it on servers in the United States.'**
  String get consentWho;

  /// No description provided for @consentNever.
  ///
  /// In en, this message translates to:
  /// **'Never sent: your balances, past transactions, PIN, backups or the vault.'**
  String get consentNever;

  /// No description provided for @consentOff.
  ///
  /// In en, this message translates to:
  /// **'You can turn this off any time in Settings → Online AI.'**
  String get consentOff;

  /// No description provided for @consentAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get consentAllow;

  /// No description provided for @consentDecline.
  ///
  /// In en, this message translates to:
  /// **'No, keep it on the phone'**
  String get consentDecline;

  /// No description provided for @aiModelSmall.
  ///
  /// In en, this message translates to:
  /// **'Small: more accurate'**
  String get aiModelSmall;

  /// No description provided for @aiModelBase.
  ///
  /// In en, this message translates to:
  /// **'Base: faster'**
  String get aiModelBase;

  /// No description provided for @aiModelSize.
  ///
  /// In en, this message translates to:
  /// **'{mb} MB'**
  String aiModelSize(int mb);

  /// No description provided for @aiModelInstall.
  ///
  /// In en, this message translates to:
  /// **'Download ({mb} MB)'**
  String aiModelInstall(int mb);

  /// No description provided for @aiModelInstalled.
  ///
  /// In en, this message translates to:
  /// **'Downloaded and checked'**
  String get aiModelInstalled;

  /// No description provided for @aiModelNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded'**
  String get aiModelNotInstalled;

  /// No description provided for @aiModelDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get aiModelDelete;

  /// No description provided for @aiModelCancel.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get aiModelCancel;

  /// No description provided for @aiModelProgress.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String aiModelProgress(int percent);

  /// No description provided for @aiModelVerifying.
  ///
  /// In en, this message translates to:
  /// **'Checking the file…'**
  String get aiModelVerifying;

  /// No description provided for @aiModelFailed.
  ///
  /// In en, this message translates to:
  /// **'The download stopped. Try again, ideally on Wi-Fi.'**
  String get aiModelFailed;

  /// No description provided for @aiModelMismatch.
  ///
  /// In en, this message translates to:
  /// **'The file did not match and was deleted. Try again.'**
  String get aiModelMismatch;

  /// No description provided for @aiModelSorani.
  ///
  /// In en, this message translates to:
  /// **'Offline, Kurdish (Sorani) is recognised less accurately than Arabic and English.'**
  String get aiModelSorani;

  /// No description provided for @capMicTooltip.
  ///
  /// In en, this message translates to:
  /// **'Capture by voice (hold to type)'**
  String get capMicTooltip;

  /// No description provided for @capListening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get capListening;

  /// No description provided for @capCapHint.
  ///
  /// In en, this message translates to:
  /// **'Up to 2 minutes'**
  String get capCapHint;

  /// No description provided for @capStop.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get capStop;

  /// No description provided for @capProcessing.
  ///
  /// In en, this message translates to:
  /// **'Working it out…'**
  String get capProcessing;

  /// No description provided for @capMicDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is off. Allow it in Android settings.'**
  String get capMicDenied;

  /// No description provided for @capTypeHint.
  ///
  /// In en, this message translates to:
  /// **'Type what happened'**
  String get capTypeHint;

  /// No description provided for @capSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get capSend;

  /// No description provided for @capManual.
  ///
  /// In en, this message translates to:
  /// **'Or add by hand'**
  String get capManual;

  /// No description provided for @capNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get capNote;

  /// No description provided for @capVaultItem.
  ///
  /// In en, this message translates to:
  /// **'Vault item'**
  String get capVaultItem;

  /// No description provided for @capSavedToInbox.
  ///
  /// In en, this message translates to:
  /// **'Saved to Inbox'**
  String get capSavedToInbox;

  /// No description provided for @capOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get capOpen;

  /// No description provided for @capReason_noSpeechEngine.
  ///
  /// In en, this message translates to:
  /// **'Not turned into text yet.'**
  String get capReason_noSpeechEngine;

  /// No description provided for @capReason_noSpeechOnlineOff.
  ///
  /// In en, this message translates to:
  /// **'Online AI is off and no offline speech model is installed. Turn on online AI or download the model in Settings → Online AI.'**
  String get capReason_noSpeechOnlineOff;

  /// No description provided for @capReason_noSpeechNoKey.
  ///
  /// In en, this message translates to:
  /// **'No Groq key is saved. Add it in Settings → Online AI, or download the offline speech model there.'**
  String get capReason_noSpeechNoKey;

  /// No description provided for @capReason_noSpeechNotAsked.
  ///
  /// In en, this message translates to:
  /// **'Voice isn\'t allowed to go to Groq yet. Tap the mic and choose Allow, or download the offline speech model in Settings → Online AI.'**
  String get capReason_noSpeechNotAsked;

  /// No description provided for @capReason_noSpeechDeclined.
  ///
  /// In en, this message translates to:
  /// **'You chose not to send voice to Groq. Tap Ask again in Settings → Online AI, or download the offline speech model there.'**
  String get capReason_noSpeechDeclined;

  /// No description provided for @capReason_noSpeechOffline.
  ///
  /// In en, this message translates to:
  /// **'No offline speech model is installed. Download it in Settings → Online AI.'**
  String get capReason_noSpeechOffline;

  /// No description provided for @capReason_sttFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t turn the recording into text. It is kept in the Inbox.'**
  String get capReason_sttFailed;

  /// No description provided for @capReason_empty.
  ///
  /// In en, this message translates to:
  /// **'Nothing was heard.'**
  String get capReason_empty;

  /// No description provided for @capReason_lowConfidence.
  ///
  /// In en, this message translates to:
  /// **'Not sure what you meant. It is kept in the Inbox.'**
  String get capReason_lowConfidence;

  /// No description provided for @capReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get capReviewTitle;

  /// No description provided for @capTranscript.
  ///
  /// In en, this message translates to:
  /// **'What you said'**
  String get capTranscript;

  /// No description provided for @capParseAgain.
  ///
  /// In en, this message translates to:
  /// **'Read again'**
  String get capParseAgain;

  /// No description provided for @capByAi.
  ///
  /// In en, this message translates to:
  /// **'Filled by online AI'**
  String get capByAi;

  /// No description provided for @capByRules.
  ///
  /// In en, this message translates to:
  /// **'Filled offline on this phone'**
  String get capByRules;

  /// No description provided for @capKeepCard.
  ///
  /// In en, this message translates to:
  /// **'Save this'**
  String get capKeepCard;

  /// No description provided for @capCheckThis.
  ///
  /// In en, this message translates to:
  /// **'Check this one'**
  String get capCheckThis;

  /// No description provided for @capMissingFields.
  ///
  /// In en, this message translates to:
  /// **'Fill in the highlighted fields or turn this one off'**
  String get capMissingFields;

  /// No description provided for @capKeepInInbox.
  ///
  /// In en, this message translates to:
  /// **'Keep in Inbox'**
  String get capKeepInInbox;

  /// No description provided for @capInboxUntil.
  ///
  /// In en, this message translates to:
  /// **'Kept in the Inbox until phase {phase}'**
  String capInboxUntil(int phase);

  /// No description provided for @capDebt.
  ///
  /// In en, this message translates to:
  /// **'Debt'**
  String get capDebt;

  /// No description provided for @capNewDebt.
  ///
  /// In en, this message translates to:
  /// **'New debt'**
  String get capNewDebt;

  /// No description provided for @capWhichDebt.
  ///
  /// In en, this message translates to:
  /// **'Which debt'**
  String get capWhichDebt;

  /// No description provided for @capDrop.
  ///
  /// In en, this message translates to:
  /// **'Dropped'**
  String get capDrop;

  /// No description provided for @capNothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing to save was found. Edit the text and read it again.'**
  String get capNothingFound;

  /// No description provided for @capAlreadyHandled.
  ///
  /// In en, this message translates to:
  /// **'This capture was already saved or discarded.'**
  String get capAlreadyHandled;

  /// No description provided for @capDone.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get capDone;

  /// No description provided for @capInbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get capInbox;

  /// No description provided for @capInboxEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing waiting. Anything you say or type and don\'t save lands here.'**
  String get capInboxEmpty;

  /// No description provided for @capNotTranscribed.
  ///
  /// In en, this message translates to:
  /// **'Voice, not transcribed yet'**
  String get capNotTranscribed;

  /// No description provided for @capTranscribe.
  ///
  /// In en, this message translates to:
  /// **'Transcribe'**
  String get capTranscribe;

  /// No description provided for @capFinishAi.
  ///
  /// In en, this message translates to:
  /// **'Finish with AI'**
  String get capFinishAi;

  /// No description provided for @capFinishAllAi.
  ///
  /// In en, this message translates to:
  /// **'Finish all with AI'**
  String get capFinishAllAi;

  /// No description provided for @capFinishing.
  ///
  /// In en, this message translates to:
  /// **'Finishing {n} of {total}…'**
  String capFinishing(int n, int total);

  /// No description provided for @capOpenReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get capOpenReview;

  /// No description provided for @capDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get capDiscard;

  /// No description provided for @capDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this capture?'**
  String get capDiscardTitle;

  /// No description provided for @capDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'Its text and recording are deleted. Nothing saved from it changes.'**
  String get capDiscardBody;

  /// No description provided for @capWillBecomeTask.
  ///
  /// In en, this message translates to:
  /// **'Will become a task in phase {phase}'**
  String capWillBecomeTask(int phase);

  /// No description provided for @capWillBecomeNote.
  ///
  /// In en, this message translates to:
  /// **'Will become a note in phase {phase}'**
  String capWillBecomeNote(int phase);

  /// No description provided for @showAmounts.
  ///
  /// In en, this message translates to:
  /// **'Show amounts'**
  String get showAmounts;

  /// No description provided for @hideAmounts.
  ///
  /// In en, this message translates to:
  /// **'Hide amounts'**
  String get hideAmounts;

  /// No description provided for @lockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get lockedTitle;

  /// No description provided for @lockedHint.
  ///
  /// In en, this message translates to:
  /// **'Use your face, fingerprint or screen lock'**
  String get lockedHint;

  /// No description provided for @unlockButton.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlockButton;

  /// No description provided for @noScreenLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Your phone has no screen lock'**
  String get noScreenLockTitle;

  /// No description provided for @noScreenLockBody.
  ///
  /// In en, this message translates to:
  /// **'This app protects your money and notes with your phone\'s own lock. Turn on a PIN, pattern, fingerprint or face unlock first.'**
  String get noScreenLockBody;

  /// No description provided for @openSecuritySettings.
  ///
  /// In en, this message translates to:
  /// **'Open security settings'**
  String get openSecuritySettings;

  /// No description provided for @sensitiveLocked.
  ///
  /// In en, this message translates to:
  /// **'This section asks for your face or fingerprint again'**
  String get sensitiveLocked;

  /// No description provided for @faceUnlockNote.
  ///
  /// In en, this message translates to:
  /// **'If face unlock isn\'t offered, your phone doesn\'t share it with apps; fingerprint and screen lock still work.'**
  String get faceUnlockNote;

  /// No description provided for @lockSection.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get lockSection;

  /// No description provided for @lockAfterSeconds.
  ///
  /// In en, this message translates to:
  /// **'After {seconds} seconds'**
  String lockAfterSeconds(int seconds);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @finDeletedMany.
  ///
  /// In en, this message translates to:
  /// **'{count} transactions deleted'**
  String finDeletedMany(int count);

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @chatExpense.
  ///
  /// In en, this message translates to:
  /// **'I\'ll record {amount} spent on «{category}» from «{account}».'**
  String chatExpense(String amount, String category, String account);

  /// No description provided for @chatIncome.
  ///
  /// In en, this message translates to:
  /// **'I\'ll record {amount} income «{category}» into «{account}».'**
  String chatIncome(String amount, String category, String account);

  /// No description provided for @chatTransfer.
  ///
  /// In en, this message translates to:
  /// **'I\'ll move {amount} from «{from}» to «{to}».'**
  String chatTransfer(String amount, String from, String to);

  /// No description provided for @chatDebtOwedToMe.
  ///
  /// In en, this message translates to:
  /// **'I\'ll record that {who} owes you {amount}.'**
  String chatDebtOwedToMe(String who, String amount);

  /// No description provided for @chatDebtOwedByMe.
  ///
  /// In en, this message translates to:
  /// **'I\'ll record that you owe {who} {amount}.'**
  String chatDebtOwedByMe(String who, String amount);

  /// No description provided for @chatDebtRepay.
  ///
  /// In en, this message translates to:
  /// **'I\'ll record a repayment of {amount} with {who}.'**
  String chatDebtRepay(String who, String amount);

  /// No description provided for @chatLater.
  ///
  /// In en, this message translates to:
  /// **'«{text}» — I\'ll keep this in the Inbox until that part of the app is ready.'**
  String chatLater(String text);

  /// No description provided for @chatNoCategory.
  ///
  /// In en, this message translates to:
  /// **'no category'**
  String get chatNoCategory;

  /// No description provided for @chatConfirm.
  ///
  /// In en, this message translates to:
  /// **'OK?'**
  String get chatConfirm;

  /// No description provided for @chatSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get chatSaved;

  /// No description provided for @chatDroppedAll.
  ///
  /// In en, this message translates to:
  /// **'OK, nothing saved.'**
  String get chatDroppedAll;

  /// No description provided for @chatUndone.
  ///
  /// In en, this message translates to:
  /// **'Undone. Nothing from that message is saved now.'**
  String get chatUndone;

  /// No description provided for @chatNotUnderstood.
  ///
  /// In en, this message translates to:
  /// **'I didn\'t get that. I\'ve kept it in the Inbox so you can come back to it.'**
  String get chatNotUnderstood;

  /// No description provided for @chatAskAmount.
  ///
  /// In en, this message translates to:
  /// **'How much?'**
  String get chatAskAmount;

  /// No description provided for @chatAskAccount.
  ///
  /// In en, this message translates to:
  /// **'From which account?'**
  String get chatAskAccount;

  /// No description provided for @chatAskToAccount.
  ///
  /// In en, this message translates to:
  /// **'To which account?'**
  String get chatAskToAccount;

  /// No description provided for @chatAskCounterparty.
  ///
  /// In en, this message translates to:
  /// **'Who is it with?'**
  String get chatAskCounterparty;

  /// No description provided for @chatAskDirection.
  ///
  /// In en, this message translates to:
  /// **'Do they owe you, or do you owe them?'**
  String get chatAskDirection;

  /// No description provided for @chatAskLeg.
  ///
  /// In en, this message translates to:
  /// **'Is this a new debt or a repayment?'**
  String get chatAskLeg;

  /// No description provided for @chatOwedToMe.
  ///
  /// In en, this message translates to:
  /// **'They owe me'**
  String get chatOwedToMe;

  /// No description provided for @chatOwedByMe.
  ///
  /// In en, this message translates to:
  /// **'I owe them'**
  String get chatOwedByMe;

  /// No description provided for @chatNewDebt.
  ///
  /// In en, this message translates to:
  /// **'New debt'**
  String get chatNewDebt;

  /// No description provided for @chatRepayment.
  ///
  /// In en, this message translates to:
  /// **'Repayment'**
  String get chatRepayment;

  /// No description provided for @chatHandedToForm.
  ///
  /// In en, this message translates to:
  /// **'Opened in the full form.'**
  String get chatHandedToForm;

  /// No description provided for @chatOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get chatOk;

  /// No description provided for @chatEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get chatEdit;

  /// No description provided for @chatDrop.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get chatDrop;

  /// No description provided for @navProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get navProjects;

  /// No description provided for @composerHint.
  ///
  /// In en, this message translates to:
  /// **'Write anything… an expense, a task, an idea'**
  String get composerHint;

  /// No description provided for @composerSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get composerSend;

  /// No description provided for @composerMic.
  ///
  /// In en, this message translates to:
  /// **'Hold to talk, or tap to start and stop'**
  String get composerMic;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get chatTitle;

  /// No description provided for @chatUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get chatUndo;

  /// No description provided for @chatVoiceKept.
  ///
  /// In en, this message translates to:
  /// **'I kept your voice note in the Inbox. {reason}'**
  String chatVoiceKept(String reason);

  /// No description provided for @chatEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tell me what happened, in your own words. I\'ll show you what I understood before saving anything.'**
  String get chatEmpty;

  /// No description provided for @chatStateSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get chatStateSaved;

  /// No description provided for @chatStateDropped.
  ///
  /// In en, this message translates to:
  /// **'Not saved'**
  String get chatStateDropped;

  /// No description provided for @chatStateUndone.
  ///
  /// In en, this message translates to:
  /// **'Undone'**
  String get chatStateUndone;

  /// No description provided for @chatStateEdited.
  ///
  /// In en, this message translates to:
  /// **'Opened in the form'**
  String get chatStateEdited;

  /// No description provided for @chatDeleteEntry.
  ///
  /// In en, this message translates to:
  /// **'I\'ll delete «{entry}».'**
  String chatDeleteEntry(String entry);

  /// No description provided for @chatEditAmount.
  ///
  /// In en, this message translates to:
  /// **'I\'ll change the amount of «{entry}» to {amount}.'**
  String chatEditAmount(String entry, String amount);

  /// No description provided for @chatEditCategory.
  ///
  /// In en, this message translates to:
  /// **'I\'ll move «{entry}» to «{category}».'**
  String chatEditCategory(String entry, String category);

  /// No description provided for @chatEditDescription.
  ///
  /// In en, this message translates to:
  /// **'I\'ll rename «{entry}» to «{text}».'**
  String chatEditDescription(String entry, String text);

  /// No description provided for @chatEntryLabel.
  ///
  /// In en, this message translates to:
  /// **'{what} on {date}'**
  String chatEntryLabel(String what, String date);

  /// No description provided for @chatNoEntry.
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t find that entry. Open Finance to pick it yourself.'**
  String get chatNoEntry;

  /// No description provided for @chatAskNewAmount.
  ///
  /// In en, this message translates to:
  /// **'What should the new amount be?'**
  String get chatAskNewAmount;

  /// No description provided for @tipAllClear.
  ///
  /// In en, this message translates to:
  /// **'All clear today. Write anything above and I\'ll sort it.'**
  String get tipAllClear;

  /// No description provided for @tipBudgetNear.
  ///
  /// In en, this message translates to:
  /// **'The «{name}» budget is almost used up this month.'**
  String tipBudgetNear(String name);

  /// No description provided for @tipEmergencyLow.
  ///
  /// In en, this message translates to:
  /// **'The Emergency fund is below its target. A small top-up helps.'**
  String get tipEmergencyLow;

  /// No description provided for @tipOverdue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task is overdue.} other{{count} tasks are overdue.}}'**
  String tipOverdue(int count);

  /// No description provided for @tipProjectStepSoon.
  ///
  /// In en, this message translates to:
  /// **'«{step}» in «{project}» is due this week.'**
  String tipProjectStepSoon(String step, String project);

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'What\'s on your mind?'**
  String get homeGreeting;

  /// No description provided for @homeToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get homeToday;

  /// No description provided for @homeTodayEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing due today.'**
  String get homeTodayEmpty;

  /// No description provided for @homeRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent entries'**
  String get homeRecent;

  /// No description provided for @homeRecentEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet.'**
  String get homeRecentEmpty;

  /// No description provided for @homeProjects.
  ///
  /// In en, this message translates to:
  /// **'Active projects'**
  String get homeProjects;

  /// No description provided for @homeProjectsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No projects yet. Tell me about one and I\'ll help you plan it.'**
  String get homeProjectsEmpty;

  /// No description provided for @homeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get homeIncome;

  /// No description provided for @homeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get homeExpense;

  /// No description provided for @setupAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Your first account'**
  String get setupAccountTitle;

  /// No description provided for @setupAccountBody.
  ///
  /// In en, this message translates to:
  /// **'Where does your money sit? A wallet, a bank, a card. You can add more later, or just tell the assistant.'**
  String get setupAccountBody;

  /// No description provided for @setupAccountName.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get setupAccountName;

  /// No description provided for @setupAccountHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Cash wallet'**
  String get setupAccountHint;

  /// No description provided for @setupAccountCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get setupAccountCurrency;

  /// No description provided for @chatAskCreateCategory.
  ///
  /// In en, this message translates to:
  /// **'There is no «{name}» category yet. Shall I create it?'**
  String chatAskCreateCategory(String name);

  /// No description provided for @chatAskCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have an account yet. Which currency should the first one use?'**
  String get chatAskCreateAccount;

  /// No description provided for @chatDefaultAccountName.
  ///
  /// In en, this message translates to:
  /// **'Cash {currency}'**
  String chatDefaultAccountName(String currency);

  /// No description provided for @chatYesCreate.
  ///
  /// In en, this message translates to:
  /// **'Yes, create it'**
  String get chatYesCreate;

  /// No description provided for @chatNoThanks.
  ///
  /// In en, this message translates to:
  /// **'No, leave it'**
  String get chatNoThanks;

  /// No description provided for @chatAskRate.
  ///
  /// In en, this message translates to:
  /// **'What\'s the {currency} rate today? (IQD for 1 {currency}, or for 100)'**
  String chatAskRate(String currency);

  /// No description provided for @finRateToday.
  ///
  /// In en, this message translates to:
  /// **'Today\'s rate for 1 {currency}'**
  String finRateToday(String currency);

  /// No description provided for @finRateSave.
  ///
  /// In en, this message translates to:
  /// **'Save rate'**
  String get finRateSave;

  /// No description provided for @finSuggestGoal.
  ///
  /// In en, this message translates to:
  /// **'Your goal (optional)'**
  String get finSuggestGoal;

  /// No description provided for @finSuggestGoalHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. a car in two years, a small shop'**
  String get finSuggestGoalHint;

  /// No description provided for @finSuggestSplit.
  ///
  /// In en, this message translates to:
  /// **'Suggest a split'**
  String get finSuggestSplit;

  /// No description provided for @finSuggestFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get a suggestion. Try again.'**
  String get finSuggestFailed;

  /// No description provided for @aiConsentReceiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipt photos'**
  String get aiConsentReceiptTitle;

  /// No description provided for @aiConsentReceipt.
  ///
  /// In en, this message translates to:
  /// **'A photo of a receipt is sent to Groq so it can read the total. Nothing else from the app goes with it.'**
  String get aiConsentReceipt;

  /// No description provided for @aiVisionModel.
  ///
  /// In en, this message translates to:
  /// **'Receipt model (photos)'**
  String get aiVisionModel;

  /// No description provided for @capReason_receiptKept.
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t read this receipt. Reading photos needs online AI, a saved key and your OK for receipt photos.'**
  String get capReason_receiptKept;

  /// No description provided for @composerCamera.
  ///
  /// In en, this message translates to:
  /// **'Scan a receipt'**
  String get composerCamera;

  /// No description provided for @chatReceiptSent.
  ///
  /// In en, this message translates to:
  /// **'Receipt photo'**
  String get chatReceiptSent;

  /// No description provided for @chatReceiptKept.
  ///
  /// In en, this message translates to:
  /// **'I kept the receipt photo in the Inbox. {reason}'**
  String chatReceiptKept(String reason);

  /// No description provided for @tasksToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tasksToday;

  /// No description provided for @tasksUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get tasksUpcoming;

  /// No description provided for @tasksOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get tasksOverdue;

  /// No description provided for @tasksNoDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get tasksNoDate;

  /// No description provided for @tasksDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get tasksDone;

  /// No description provided for @tasksCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get tasksCalendar;

  /// No description provided for @tasksNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get tasksNotes;

  /// No description provided for @tasksEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get tasksEmpty;

  /// No description provided for @tasksAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a task'**
  String get tasksAdd;

  /// No description provided for @taskNew.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get taskNew;

  /// No description provided for @taskEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit task'**
  String get taskEdit;

  /// No description provided for @taskTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get taskTitleLabel;

  /// No description provided for @taskKindTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get taskKindTask;

  /// No description provided for @taskKindAppointment.
  ///
  /// In en, this message translates to:
  /// **'Appointment'**
  String get taskKindAppointment;

  /// No description provided for @taskKindReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get taskKindReminder;

  /// No description provided for @taskDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get taskDate;

  /// No description provided for @taskTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get taskTime;

  /// No description provided for @taskNoDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get taskNoDate;

  /// No description provided for @taskNoTime.
  ///
  /// In en, this message translates to:
  /// **'No time'**
  String get taskNoTime;

  /// No description provided for @taskPlace.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get taskPlace;

  /// No description provided for @taskNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get taskNotesLabel;

  /// No description provided for @taskPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get taskPriority;

  /// No description provided for @taskPrioLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get taskPrioLow;

  /// No description provided for @taskPrioNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get taskPrioNormal;

  /// No description provided for @taskPrioHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get taskPrioHigh;

  /// No description provided for @taskRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get taskRepeat;

  /// No description provided for @taskRepeatNone.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get taskRepeatNone;

  /// No description provided for @taskRepeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get taskRepeatDaily;

  /// No description provided for @taskRepeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get taskRepeatWeekly;

  /// No description provided for @taskRepeatMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get taskRepeatMonthly;

  /// No description provided for @taskDeleted.
  ///
  /// In en, this message translates to:
  /// **'Task deleted'**
  String get taskDeleted;

  /// No description provided for @taskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Marked done'**
  String get taskCompleted;

  /// No description provided for @noteDeleted.
  ///
  /// In en, this message translates to:
  /// **'Note deleted'**
  String get noteDeleted;

  /// No description provided for @noteNew.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get noteNew;

  /// No description provided for @noteEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get noteEdit;

  /// No description provided for @noteHint.
  ///
  /// In en, this message translates to:
  /// **'Write the note'**
  String get noteHint;

  /// No description provided for @calendarNoTasks.
  ///
  /// In en, this message translates to:
  /// **'Nothing on this day.'**
  String get calendarNoTasks;

  /// No description provided for @notifChannelName.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get notifChannelName;

  /// No description provided for @notifChannelDesc.
  ///
  /// In en, this message translates to:
  /// **'Reminders for your tasks and appointments'**
  String get notifChannelDesc;

  /// No description provided for @notifDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get notifDone;

  /// No description provided for @notifSnooze1h.
  ///
  /// In en, this message translates to:
  /// **'In 1 hour'**
  String get notifSnooze1h;

  /// No description provided for @notifTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow 9:00'**
  String get notifTomorrow;

  /// No description provided for @exactAlarmWarning.
  ///
  /// In en, this message translates to:
  /// **'Exact alarms are off, so reminders may come a few minutes late.'**
  String get exactAlarmWarning;

  /// No description provided for @exactAlarmAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get exactAlarmAllow;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'ckb', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'ckb':
      return AppLocalizationsCkb();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
