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
  String get biometricsUnavailable =>
      'هیچ پەنجەمۆر یان ناسینەوەی ڕوو لەسەر ئەم مۆبایلە چالاک نییە';

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
      one: 'دوای 1 خولەک',
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
  String get passwordTooShort => 'لانیکەم 8 پیت بەکاربهێنە';

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
      one: '1 هەوڵ ماوە پێش وەستان',
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
  String get setupWelcomeBody =>
      'هەموو شتێک لەسەر ئەم مۆبایلە دەمێنێتەوە، لەژێر قوفڵی خۆت.';

  @override
  String get setupChooseLanguage => 'زمانەکەت هەڵبژێرە';

  @override
  String get setupCreatePin => 'PINێکی 6 ژمارەیی دروست بکە';

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
  String get privacyPhase1 =>
      'هیچ شتێک لەم مۆبایلە دەرناچێت. ئەپەکە هێشتا دەسەڵاتی ئینتەرنێتی نییە.';

  @override
  String get restoreTooNew =>
      'ئەم پاشەکەوتە لە وەشانێکی نوێتری ئەپەکە دروستکراوە. سەرەتا ئەپەکە نوێ بکەرەوە.';

  @override
  String get restoreWrongPassword => 'وشەی نهێنی هەڵەیە، یان فایلەکە تێکچووە.';

  @override
  String get restoreCorrupt => 'ئەم فایلە تێکچووە یان پاشەکەوتی ئەم ئەپە نییە.';

  @override
  String get restoreSuccess => 'گەڕێندرایەوە. دووبارە دەستپێدەکاتەوە…';

  @override
  String get micSoon => 'تۆمارکردنی دەنگی لە قۆناغی 2 دێت';

  @override
  String get passwordStrengthWeak =>
      'لاواز: درێژتری بکە، یان پیت و ژمارە و هێما تێکەڵ بکە';

  @override
  String get passwordStrengthFair => 'مامناوەند';

  @override
  String get passwordStrengthStrong => 'بەهێز';

  @override
  String get backupPasswordHint =>
      'بۆ گەڕاندنەوە پێویستت بەم وشەی نهێنییە دەبێت. ئەگەر لەبیرت بچێت، ناگەڕێتەوە.';

  @override
  String get somethingWentWrong => 'هەڵەیەک ڕوویدا. دووبارە هەوڵ بدەرەوە.';

  @override
  String get backupFailed => 'پاشەکەوت دروست نەکرا. داتاکانت نەگۆڕاون.';

  @override
  String get startupFailed => 'داتاکانت نەکرانەوە. هیچ شتێک نەسڕایەوە.';

  @override
  String get retry => 'دووبارە هەوڵ بدەرەوە';

  @override
  String get cat_food => 'خواردن';

  @override
  String get cat_transport => 'گواستنەوە';

  @override
  String get cat_rent => 'کرێ';

  @override
  String get cat_bills => 'پسوڵەکان';

  @override
  String get cat_family => 'خێزان';

  @override
  String get cat_shopping => 'بازاڕکردن';

  @override
  String get cat_health => 'تەندروستی';

  @override
  String get cat_business => 'کار';

  @override
  String get cat_marketing => 'بازاڕگەری';

  @override
  String get cat_subscriptions => 'بەشدارییەکان';

  @override
  String get cat_other_expense => 'خەرجی تر';

  @override
  String get cat_salary => 'مووچە';

  @override
  String get cat_business_income => 'داهاتی کار';

  @override
  String get cat_freelance => 'کاری ئازاد';

  @override
  String get cat_client_payment => 'پارەی کڕیار';

  @override
  String get cat_other_income => 'داهاتی تر';

  @override
  String get bucket_expenses => 'خەرجییەکان';

  @override
  String get bucket_emergency => 'فریاکەوتن';

  @override
  String get bucket_investment => 'وەبەرهێنان';

  @override
  String get finIncome => 'داهات';

  @override
  String get finExpense => 'خەرجی';

  @override
  String get finSurplus => 'زیادە';

  @override
  String get finAllAccounts => 'هەموو هەژمارەکان';

  @override
  String get finHowConvertedHint => 'دەست لێبدە بۆ بینینی گۆڕینەکە';

  @override
  String finNoTotal(String currencies) {
    return 'هێشتا نرخی $currencies نییە، بۆیە کۆی گشتی نییە';
  }

  @override
  String get finSetRate => 'نرخ دابنێ';

  @override
  String get finRateTitle => 'نرخی گۆڕینەوە';

  @override
  String get finRateLabel => '١ دۆلار بە دینار';

  @override
  String get finRateInvalid => 'نرخێک بنووسە وەک 1310';

  @override
  String get save => 'پاشەکەوت';

  @override
  String get finHowConverted => 'چۆن گۆڕدرا';

  @override
  String get finSameCurrency => 'هەمان دراو';

  @override
  String get finNoRate => 'نرخ نییە';

  @override
  String finRateLine(String base, String rate, String quote, String date) {
    return '1 $base = $rate $quote · لە $date';
  }

  @override
  String get finPerCurrency => 'بەپێی دراو';

  @override
  String get finTotal => 'کۆ';

  @override
  String alertExpensesBucket(int percent) {
    return 'سەبەتەی خەرجی گەیشتە $percent% ئەم مانگە';
  }

  @override
  String get alertEmergencyReached => 'سندوقی فریاکەوتن گەیشتە ئامانج';

  @override
  String get alertEmergencyBelow => 'سندوقی فریاکەوتن لە خوار ئامانجە';

  @override
  String alertUnallocated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count داهات دابەش نەکراون',
      one: '1 داهات دابەش نەکراوە',
    );
    return '$_temp0';
  }

  @override
  String alertBudget(String name, int percent) {
    return 'بودجەی $name گەیشتە $percent%';
  }

  @override
  String alertDebtSoon(String name, String date) {
    return '$name: پارەدان لە $date';
  }

  @override
  String alertDebtOverdue(String name) {
    return '$name: پارەدان دواکەوتووە';
  }

  @override
  String get finHistory => 'مێژوو';

  @override
  String get finAddAccount => 'زیادکردنی هەژمار';

  @override
  String get finAccountName => 'ناو';

  @override
  String get finNameRequired => 'ناوێک بنووسە';

  @override
  String get finWorkspace => 'شوێنی کار';

  @override
  String get finCurrency => 'دراو';

  @override
  String get finKind => 'جۆر';

  @override
  String get kindCash => 'نەختینە';

  @override
  String get kindBank => 'بانک';

  @override
  String get kindSavings => 'پاشەکەوت';

  @override
  String get kindCustom => 'تر';

  @override
  String get rename => 'ناوگۆڕین';

  @override
  String get archive => 'ئەرشیف';

  @override
  String finArchiveAccount(String name) {
    return '$name ئەرشیف بکرێت؟ مێژووەکەی دەمێنێت.';
  }

  @override
  String get finBalance => 'باڵانس';

  @override
  String get finAdjustBalance => 'ڕێکخستنی باڵانس';

  @override
  String get finAdjustHint =>
      'بڕی ڕاستەقینەی ئەم هەژمارە بنووسە. جیاوازییەکە وەک ڕێکخستن پاشەکەوت دەکرێت.';

  @override
  String get finActualAmount => 'بڕی ڕاستەقینە';

  @override
  String get finAmountInvalid => 'بڕێک بنووسە وەک 25000';

  @override
  String get finSearch => 'گەڕان لە وەسفدا';

  @override
  String get filterAll => 'هەموو';

  @override
  String get filterDates => 'بەروار';

  @override
  String get filterAccount => 'هەژمار';

  @override
  String get filterCategory => 'پۆل';

  @override
  String get filterType => 'جۆر';

  @override
  String get clearFilters => 'پاککردنەوەی فلتەر';

  @override
  String get typeIncome => 'داهات';

  @override
  String get typeExpense => 'خەرجی';

  @override
  String get typeRefund => 'گەڕاندنەوە';

  @override
  String get typeAdjustment => 'ڕێکخستن';

  @override
  String get typeTransfer => 'گواستنەوە';

  @override
  String get typeOwnerDraw => 'کێشانی خاوەن';

  @override
  String get typeDebtPayment => 'پارەدانی قەرز';

  @override
  String get finPending => 'چاوەڕوان';

  @override
  String get finUncategorised => 'بێ پۆل';

  @override
  String get finNoTransactions => 'هێشتا هیچ مامەڵەیەک نییە';

  @override
  String get finNoMatches => 'هیچ مامەڵەیەک لەگەڵ فلتەرەکان ناگونجێت';

  @override
  String get finDeleted => 'مامەڵەکە سڕایەوە';

  @override
  String get undo => 'گەڕانەوە';

  @override
  String get finToday => 'ئەمڕۆ';

  @override
  String get finAddExpense => 'زیادکردنی خەرجی';

  @override
  String get finAddIncome => 'زیادکردنی داهات';

  @override
  String get finAddRefund => 'زیادکردنی گەڕاندنەوە';

  @override
  String get finAddTransfer => 'گواستنەوە';

  @override
  String get finEditTransaction => 'دەستکاری مامەڵە';

  @override
  String get finEditTransfer => 'دەستکاری گواستنەوە';

  @override
  String get finAmount => 'بڕ';

  @override
  String finAmountRounded(String currency) {
    return 'بەپێی $currency خڕکرایەوە';
  }

  @override
  String get finAccount => 'هەژمار';

  @override
  String get finChooseAccount => 'هەژمارێک هەڵبژێرە';

  @override
  String get finCategory => 'پۆل';

  @override
  String get finNoCategory => 'بێ پۆل';

  @override
  String get finDate => 'بەروار';

  @override
  String get finTime => 'کات';

  @override
  String get finDescription => 'وەسف';

  @override
  String get finNotReceived => 'هێشتا وەرنەگیراوە';

  @override
  String get finNotReceivedHint => 'داهاتی چاوەڕوان لە باڵانسدا ناژمێردرێت';

  @override
  String get finAllocate => 'دابەشکردن بۆ سەبەتەکان';

  @override
  String finAllocateNoRate(String currency) {
    return 'سەرەتا نرخی $currency دابنێ بۆ دابەشکردن';
  }

  @override
  String get finAllocatePending => 'تەنها داهاتی وەرگیراو دابەش دەکرێت';

  @override
  String get finUnallocated => 'دابەش نەکراو';

  @override
  String get finOverAllocated => 'زیادە بە';

  @override
  String get finBucketTag => 'لە سەبەتە دراوە';

  @override
  String get finBucketNone => 'خەرجی ئاسایی';

  @override
  String get finClearAllocationsTitle => 'دابەشکردنی سەبەتەکان بسڕدرێتەوە؟';

  @override
  String get finClearAllocationsBody =>
      'ئەم داهاتە دابەش کراوە. گۆڕینی بڕەکە دابەشکردنەکە دەسڕێتەوە؛ دواتر دەتوانیت دووبارە دابەشی بکەیت.';

  @override
  String get finClearAndSave => 'بیسڕەوە و پاشەکەوت بکە';

  @override
  String get finFrom => 'لە';

  @override
  String get finTo => 'بۆ';

  @override
  String get finToAmount => 'بڕی وەرگیراو';

  @override
  String finRateField(String quote, String base) {
    return '$quote بۆ هەر 1 $base';
  }

  @override
  String get finTwoOfThree => 'هەر دوانیان بنووسە؛ سێیەم دەژمێردرێت';

  @override
  String get finOwnerDraw => 'کێشانی خاوەن (مووچە)';

  @override
  String get finOwnerDrawHint => 'وەک خەرجی کار و داهاتی کەسی دەژمێردرێت';

  @override
  String get finSameAccount => 'دوو هەژماری جیاواز هەڵبژێرە';

  @override
  String get finSaved => 'پاشەکەوت کرا';
}
