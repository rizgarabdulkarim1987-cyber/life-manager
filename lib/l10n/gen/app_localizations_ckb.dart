// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Central Kurdish (`ckb`).
class AppLocalizationsCkb extends AppLocalizations {
  AppLocalizationsCkb([String locale = 'ckb']) : super(locale);

  @override
  String get appTitle => 'بەڕێوەبەری ژیانم';

  @override
  String get navHome => 'سەرەکی';

  @override
  String get navFinance => 'دارایی';

  @override
  String get navTasks => 'ئەرکەکان';

  @override
  String get navVault => 'گەنجینە';

  @override
  String get settings => 'ڕێکخستنەکان';

  @override
  String get language => 'زمان';

  @override
  String get theme => 'ڕووکار';

  @override
  String get themeDark => 'تاریک';

  @override
  String get themeLight => 'ڕووناک';

  @override
  String get appLock => 'قوفڵی ئەپ';

  @override
  String get biometrics => 'کردنەوە بە پەنجەمۆر';

  @override
  String get biometricsUnavailable => 'هیچ پەنجەمۆر یان ناسینەوەی ڕوو لەسەر ئەم مۆبایلە چالاک نییە';

  @override
  String get changePin => 'گۆڕینی PIN';

  @override
  String get currentPin => 'PINی ئێستا';

  @override
  String get newPin => 'PINی نوێ';

  @override
  String get pinChanged => 'PIN گۆڕدرا';

  @override
  String get lockTimeout => 'قوفڵکردن دوای چوونە دەرەوە لە ئەپ';

  @override
  String get lockImmediately => 'یەکسەر';

  @override
  String lockAfterMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'دوای $minutes خولەک',
      one: 'دوای ١ خولەک',
    );
    return '$_temp0';
  }

  @override
  String get backupRestore => 'پاشەکەوت و گەڕاندنەوە';

  @override
  String lastBackup(String date) {
    return 'دوایین پاشەکەوت: $date';
  }

  @override
  String get neverBackedUp => 'هێشتا هیچ پاشەکەوتێک نەکراوە';

  @override
  String get createBackup => 'دروستکردنی پاشەکەوت';

  @override
  String get restoreBackup => 'گەڕاندنەوە لە پاشەکەوت';

  @override
  String get backupPassword => 'وشەی نهێنی پاشەکەوت';

  @override
  String get confirmPassword => 'دووپاتکردنەوەی وشەی نهێنی';

  @override
  String get passwordTooShort => 'لانیکەم ٨ پیت بەکاربهێنە';

  @override
  String get passwordsDontMatch => 'وشە نهێنییەکان وەک یەک نین';

  @override
  String get backupWarning =>
      'داتاکانت تەنها لەسەر ئەم مۆبایلەن. ئەگەر مۆبایلەکە ون بێت یان ئەپەکە بسڕیتەوە بێ پاشەکەوت، هەمووی لەدەست دەچێت. پاشەکەوتەکان لە شوێنێکی دەرەوەی مۆبایل هەڵبگرە.';

  @override
  String get backupCreated => 'پاشەکەوت هەڵگیرا';

  @override
  String get restoreConfirmTitle => 'هەموو داتای ئێستا بگۆڕدرێت؟';

  @override
  String restoreConfirmBody(String date, String version) {
    return 'پاشەکەوتی $date، وەشانی $version. هەموو ئەوەی ئێستا لە ئەپەکەدایە دەگۆڕدرێت.';
  }

  @override
  String get replace => 'گۆڕین';

  @override
  String get cancel => 'هەڵوەشاندنەوە';

  @override
  String get enterPin => 'PINەکەت بنووسە';

  @override
  String get wrongPin => 'PIN هەڵەیە';

  @override
  String attemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count هەوڵ ماوە پێش وەستان',
      one: '١ هەوڵ ماوە پێش وەستان',
    );
    return '$_temp0';
  }

  @override
  String tryAgainIn(String time) {
    return 'هەوڵی زۆر. دوای $time دووبارە هەوڵ بدەرەوە';
  }

  @override
  String get unlockReason => 'کردنەوەی بەڕێوەبەری ژیانم';

  @override
  String get useFingerprint => 'پەنجەمۆر بەکاربهێنە';

  @override
  String get setupWelcome => 'بەخێربێیت';

  @override
  String get setupWelcomeBody => 'هەموو شتێک لەسەر ئەم مۆبایلە دەمێنێتەوە، لەژێر قوفڵی خۆت.';

  @override
  String get setupChooseLanguage => 'زمانەکەت هەڵبژێرە';

  @override
  String get setupCreatePin => 'PINێکی ٦ ژمارەیی دروست بکە';

  @override
  String get setupConfirmPin => 'PINەکە دووبارە بنووسەوە';

  @override
  String get pinMismatch => 'PINەکان وەک یەک نین. لە سەرەتاوە دەست پێبکەرەوە.';

  @override
  String get setupEnableBiometrics => 'کردنەوە بە پەنجەمۆریش چالاک بکرێت؟';

  @override
  String get setupEnableBiometricsBody => 'PINەکەت هەمیشە وەک بەدیل کار دەکات.';

  @override
  String get enable => 'چالاککردن';

  @override
  String get setupBackupWarning => 'یەک شتی گرنگ';

  @override
  String get iUnderstand => 'تێگەیشتم';

  @override
  String get continueLabel => 'بەردەوامبە';

  @override
  String get skip => 'تێپەڕاندن';

  @override
  String get finish => 'دەستپێبکە';

  @override
  String comingInPhase(int phase) {
    return 'لە قۆناغی $phase دێت';
  }

  @override
  String get seedPersonal => 'کەسی';

  @override
  String get seedBuzzify => 'Buzzify';

  @override
  String get seedEo => 'Related / EO';

  @override
  String get seedOtherProjects => 'پڕۆژەکانی تر';

  @override
  String get seedCashIqd => 'کاشی دینار';

  @override
  String get seedCashUsd => 'کاشی دۆلار';

  @override
  String get accounts => 'هەژمارەکان';

  @override
  String get homeMonthSummary => 'ئەم مانگە';

  @override
  String get homeChart => 'داهات بەرامبەر خەرجی';

  @override
  String get homeBuckets => 'سندووقەکان';

  @override
  String get homeTasks => 'ئەرکەکان';

  @override
  String get privacy => 'تایبەتمەندی';

  @override
  String get privacyPhase1 => 'هیچ شتێک لەم مۆبایلە دەرناچێت. ئەپەکە هێشتا دەسەڵاتی ئینتەرنێتی نییە.';

  @override
  String get restoreTooNew => 'ئەم پاشەکەوتە لە وەشانێکی نوێتری ئەپەکە دروستکراوە. سەرەتا ئەپەکە نوێ بکەرەوە.';

  @override
  String get restoreWrongPassword => 'وشەی نهێنی هەڵەیە، یان فایلەکە تێکچووە.';

  @override
  String get restoreCorrupt => 'ئەم فایلە تێکچووە یان پاشەکەوتی ئەم ئەپە نییە.';

  @override
  String get restoreSuccess => 'گەڕێندرایەوە. دووبارە دەستپێدەکاتەوە…';

  @override
  String get micSoon => 'تۆمارکردنی دەنگی لە قۆناغی ٢ دێت';
}
