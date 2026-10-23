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
}
