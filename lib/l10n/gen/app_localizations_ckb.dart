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
      'زانیارییەکانت لەسەر ئەم مۆبایلە دەمێننەوە. تەنها ئەگەر زیرەکی دەستکردی ئۆنلاین هەڵبکەیت و ڕازی بیت، دەنگ یان دەقی تۆمارەکە بۆ Groq دەنێردرێت. گەنجینەکە هەرگیز لە مۆبایلەکە دەرناچێت.';

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
  String get passwordStrengthWeak =>
      'لاواز: درێژتری بکە، یان پیت و ژمارە و هێما تێکەڵ بکە';

  @override
  String get passwordStrengthFair => 'مامناوەند';

  @override
  String get passwordStrengthStrong => 'بەهێز';

  @override
  String get backupPasswordHint =>
      'بۆ گەڕاندنەوە پێویستت بەم وشەی نهێنییە دەبێت. ئەگەر لەبیرت بچێت، ناگەڕێتەوە. کلیلی Groqی پاشەکەوتکراویش لەناو باکئەپە کۆدکراوەکەدایە.';

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

  @override
  String get finBuckets => 'سەبەتەکان';

  @override
  String get finBudgets => 'بودجەکان';

  @override
  String get finDebts => 'قەرزەکان';

  @override
  String get finAvailable => 'بەردەست';

  @override
  String get finAllocated => 'دابەشکراو';

  @override
  String get finSpent => 'خەرجکراو';

  @override
  String get finTarget => 'ئامانج';

  @override
  String get finSetTarget => 'ئامانج دابنێ';

  @override
  String get finTargetHint => 'بەتاڵی بهێڵە بۆ بێ ئامانج';

  @override
  String get finEditPercentages => 'دەستکاری ڕێژەکان';

  @override
  String get finPercentagesNote =>
      'دەبێت کۆیان 100% بێت. تەنها ئەو داهاتەی دوای پاشەکەوت دابەشی دەکەیت ڕێژە نوێیەکان وەردەگرێت.';

  @override
  String finPercentTotal(String percent) {
    return 'کۆ $percent%';
  }

  @override
  String get finBucketsUnconfirmed =>
      'پێش دابەشکردنی داهات، ڕێژەکانی خۆت دابنێ.';

  @override
  String get finExpensesMonthly => 'هەموو مانگێک سفر دەبێتەوە';

  @override
  String get finCarriesOver => 'کۆدەبێتەوە';

  @override
  String get finAddBudget => 'زیادکردنی بودجە';

  @override
  String get finEditBudget => 'دەستکاری بودجە';

  @override
  String get finBudgetNeedsScope =>
      'پۆلێک یان شوێنی کارێک یان هەردووکیان هەڵبژێرە';

  @override
  String get finAnyWorkspace => 'هەموو شوێنەکانی کار';

  @override
  String get finAnyCategory => 'هەموو پۆلەکان';

  @override
  String get finRemaining => 'ماوە';

  @override
  String finOfBudget(String amount) {
    return 'لە $amount';
  }

  @override
  String finMissingRatesNote(String currencies) {
    return 'نەژمێردرا: $currencies (لەو بەروارانەدا نرخ نییە)';
  }

  @override
  String get finNoBudgets => 'هێشتا بودجە نییە';

  @override
  String get finOwedToMe => 'قەرزی من لای خەڵک';

  @override
  String get finOwedByMe => 'قەرزی خەڵک لای من';

  @override
  String get finAddDebt => 'زیادکردنی قەرز';

  @override
  String get finCounterparty => 'کەس یان کۆمپانیا';

  @override
  String get finStartDate => 'دەستپێکردن';

  @override
  String get finRecordMoveNow => 'ئێستا جووڵەی پارەکە تۆمار بکە';

  @override
  String get finRecordMoveGiven => 'پارەکە لەم هەژمارە دەرچوو';

  @override
  String get finRecordMoveReceived => 'پارەکە هاتە ئەم هەژمارە';

  @override
  String get finInstallments => 'قیستەکان';

  @override
  String get finInstallmentCount => 'ژمارەی قیستی مانگانە (ئارەزوومەندانە)';

  @override
  String get finFirstDue => 'یەکەم قیست';

  @override
  String finNextDue(String date) {
    return 'داهاتوو $date';
  }

  @override
  String get finOverdue => 'دواکەوتوو';

  @override
  String get finPaid => 'دراوە';

  @override
  String get finNoDebts => 'هیچ نییە';

  @override
  String get finRecordRepayment => 'تۆمارکردنی گەڕاندنەوە';

  @override
  String finRepaymentTooBig(String amount) {
    return 'تا $amount';
  }

  @override
  String finWrongCurrency(String currency) {
    return 'هەژمارێک بە $currency هەڵبژێرە';
  }

  @override
  String get finPayments => 'پارەدانەکان';

  @override
  String get finPrincipal => 'بنەڕەت';

  @override
  String get finRepayment => 'گەڕاندنەوە';

  @override
  String get finClosed => 'تەواوبوو';

  @override
  String get finNotes => 'تێبینی';

  @override
  String get finReports => 'ڕاپۆرتەکان';

  @override
  String get repRange => 'ماوە';

  @override
  String get repThisMonth => 'ئەم مانگە';

  @override
  String get repLastMonth => 'مانگی ڕابردوو';

  @override
  String repLastMonths(int count) {
    return '$count مانگی ڕابردوو';
  }

  @override
  String get repCustom => 'بەرواری دیاریکراو';

  @override
  String get repGroupBy => 'کۆکردنەوە';

  @override
  String get repDaily => 'ڕۆژانە';

  @override
  String get repWeekly => 'هەفتانە';

  @override
  String get repMonthly => 'مانگانە';

  @override
  String get repAllWorkspaces => 'هەموو شوێنەکانی کار';

  @override
  String get repTabIncomeExpense => 'داهات و خەرجی';

  @override
  String get repTabCategory => 'بەپێی پۆل';

  @override
  String get repTabWorkspace => 'بەپێی شوێنی کار';

  @override
  String get repTabCashFlow => 'جووڵەی پارە';

  @override
  String get repTabBalance => 'باڵانس بە درێژایی کات';

  @override
  String get repTabDebts => 'قەرزە ماوەکان';

  @override
  String get repShowTable => 'وەک خشتە پیشانی بدە';

  @override
  String get repShowChart => 'وەک هێڵکاری پیشانی بدە';

  @override
  String repSkipped(int count, String currencies) {
    return '$count نەژمێردران: لە بەروارەکانیاندا نرخی $currencies نییە';
  }

  @override
  String get repMoneyIn => 'هاتوو';

  @override
  String get repMoneyOut => 'ڕۆیشتوو';

  @override
  String get repNet => 'پوخت';

  @override
  String get repOther => 'هیتر';

  @override
  String get repPeriodColumn => 'ماوە';

  @override
  String get repBalance => 'باڵانس';

  @override
  String get repNothing => 'لەم ماوەیەدا هیچ نییە';

  @override
  String repBucketsMonth(String month, String currency) {
    return '$month، بە $currency';
  }

  @override
  String get repExport => 'هەناردن';

  @override
  String get repExportCsv => 'مامەڵەکان وەک CSV';

  @override
  String get repExportPdf => 'ڕاپۆرت وەک PDF';

  @override
  String get repNotEncrypted =>
      'ئەم فایلە نهێنی نەکراوە. هەر کەسێک دەستی بکەوێت دەتوانێت بیخوێنێتەوە.';

  @override
  String get repExportFailed => 'نەتوانرا فایلەکە پاشەکەوت بکرێت';

  @override
  String get setFinance => 'دارایی';

  @override
  String get setFinanceSettings => 'دراو و نرخەکان';

  @override
  String get setFinanceSettingsHint =>
      'دراوی بنەڕەت، نرخی دۆلار، ئاگادارکردنەوە';

  @override
  String get setCategories => 'پۆلەکان';

  @override
  String get setCategoriesHint => 'ناوەکان و ئەو وشانەی هەڵیان دەبژێرن';

  @override
  String get setWorkspaces => 'شوێنەکانی کار';

  @override
  String get setWorkspacesHint => 'ناوەکان، ناوە دیکەکان، سندوقەکان';

  @override
  String get setBaseCurrency => 'دراوی بنەڕەت';

  @override
  String get setBaseCurrencyHint =>
      'کۆکان و سندوقەکان و ڕاپۆرتەکان بەکاری دەهێنن مەگەر یەکێکی تر هەڵبژێریت.';

  @override
  String setRateDate(String date) {
    return 'لە $dateەوە';
  }

  @override
  String get setRateHistory => 'مێژووی نرخەکان';

  @override
  String get setNoRates =>
      'هێشتا نرخ نییە. دۆلار و دینار جیا دەمێننەوە تا نرخێک زیاد دەکەیت.';

  @override
  String get setRateSaved => 'نرخەکە پاشەکەوت کرا';

  @override
  String get setAlerts => 'ئاگادارکردنەوەکان';

  @override
  String get setUnallocatedAlert =>
      'بیرم بخەرەوە بە داهاتێک کە دابەش نەکراوە بۆ سندوقەکان';

  @override
  String get setUnallocatedAlertHint => 'لە شاشەی دارایی دەردەکەوێت';

  @override
  String get setIncomeCategories => 'داهات';

  @override
  String get setExpenseCategories => 'خەرجی';

  @override
  String get setAddCategory => 'پۆل زیاد بکە';

  @override
  String get setEditCategory => 'پۆل دەستکاری بکە';

  @override
  String get setKeywords => 'ئەو وشانەی ئەم پۆلە هەڵدەبژێرن';

  @override
  String get setBuiltInWords => 'بنەڕەتی';

  @override
  String get setYourWords => 'وشەکانی تۆ';

  @override
  String get setAddWord => 'وشەیەک زیاد بکە';

  @override
  String setRemoveWord(String word) {
    return '$word لاببە';
  }

  @override
  String setArchiveCategory(String name) {
    return '$name ئەرشیف بکرێت؟ تۆمارە کۆنەکان دەیپارێزن.';
  }

  @override
  String get setAddWorkspace => 'شوێنی کار زیاد بکە';

  @override
  String get setEditWorkspace => 'شوێنی کار دەستکاری بکە';

  @override
  String get setIcon => 'ئایکۆن';

  @override
  String get setColour => 'ڕەنگ';

  @override
  String get setAliases => 'ناوە دیکەکان کە دەیڵێیت';

  @override
  String get setAliasesHint => 'تۆمارکردنی دەنگی و خێرا ئەمانەش دەناسێتەوە';

  @override
  String get setAddAlias => 'ناوێک زیاد بکە';

  @override
  String get setCountsInBuckets => 'لە سندوقەکاندا دەژمێردرێت';

  @override
  String get setCountsInBucketsHint => 'خەرجییەکانی لە سندوقی خەرجی دەبڕدرێن';

  @override
  String setArchiveWorkspace(String name) {
    return '$name ئەرشیف بکرێت؟ مێژووەکەی دەمێنێت.';
  }

  @override
  String setArchiveBlocked(String name) {
    return 'سەرەتا هەژمارەکانی ئەرشیف بکە. $name هێشتا هەژماری کارای هەیە.';
  }

  @override
  String get setArchived => 'ئەرشیف کرا';

  @override
  String get ok => 'باشە';

  @override
  String get impTitle => 'هاوردەکردن';

  @override
  String get impEntry => 'هاوردەکردنی فایل';

  @override
  String get impStepFile => 'فایل هەڵبژێرە';

  @override
  String get impStepColumns => 'ستوونەکان';

  @override
  String get impStepDefaults => 'بنەڕەتەکان';

  @override
  String get impStepValues => 'بەهاکان بگونجێنە';

  @override
  String get impStepPreview => 'پشکنین و هاوردە';

  @override
  String get impStepOpening => 'باڵانسی ئەمڕۆ';

  @override
  String impStepOf(int n, int total) {
    return 'هەنگاوی $n لە $total';
  }

  @override
  String get impPickHint =>
      'فایلێکی ‎.xlsx‎ یان ‎.csv‎ لە بانک یان خشتەیەکی کۆن. هیچ پاشەکەوت ناکرێت تا هاوردە دانەگریت.';

  @override
  String get impPick => 'فایل هەڵبژێرە';

  @override
  String get impPickAnother => 'فایلێکی تر هەڵبژێرە';

  @override
  String get impTooLarge =>
      'فایلەکە زۆر گەورەیە: زیاتر لە 50,000 ڕیز یان 64 ستوون.';

  @override
  String get impUnreadable =>
      'نەتوانرا فایلەکە وەک ‎.xlsx‎ یان ‎.csv‎ بخوێنرێتەوە.';

  @override
  String get impSheet => 'پەڕە';

  @override
  String get impHeaderRow => 'کام ڕیز ناوی ستوونەکانی تێدایە؟';

  @override
  String impRowN(int n) {
    return 'ڕیزی $n';
  }

  @override
  String get impColDate => 'بەروار';

  @override
  String get impDateOrder => 'ڕیزبەندی بەروار';

  @override
  String get impDayFirst => 'ڕۆژ سەرەتا (31/12)';

  @override
  String get impMonthFirst => 'مانگ سەرەتا (12/31)';

  @override
  String get impYearFirst => 'ساڵ سەرەتا (2025-12-31)';

  @override
  String get impAmountMode => 'بڕەکان چۆن نووسراون';

  @override
  String get impSigned => 'یەک ستوون، کەم واتە خەرجی';

  @override
  String get impTypeColumn => 'یەک ستوون لەگەڵ ستوونی جۆر';

  @override
  String get impSplit => 'ستوونی جیا بۆ داهات و خەرجی';

  @override
  String get impColAmount => 'بڕ';

  @override
  String get impColIncome => 'ستوونی داهات';

  @override
  String get impColExpense => 'ستوونی خەرجی';

  @override
  String get impColType => 'جۆر';

  @override
  String get impColCurrency => 'دراو';

  @override
  String get impColCategory => 'پۆل';

  @override
  String get impColWorkspace => 'شوێنی کار';

  @override
  String get impColAccount => 'هەژمار';

  @override
  String get impColDescription => 'وەسف';

  @override
  String get impNone => 'لە فایلەکەدا نییە';

  @override
  String impColumnLetter(String letter) {
    return 'ستوونی $letter';
  }

  @override
  String get impNeedDateAmount =>
      'ستوونی بەروار و بڕ هەڵبژێرە بۆ بەردەوامبوون.';

  @override
  String get impDefaultsHint => 'بۆ ئەو ڕیزانە بەکاردێت کە ئەمەیان تێدا نییە.';

  @override
  String get impNoValues =>
      'هیچ بۆ گونجاندن نییە: فایلەکە ستوونی جۆر، پۆل، شوێن یان هەژماری تێدا نییە.';

  @override
  String get impCreateNew => 'نوێ دروست بکە';

  @override
  String get impSkipRow => 'ئەم ڕیزانە بپەڕێنە';

  @override
  String get impLeaveEmpty => 'بەتاڵی بهێڵە';

  @override
  String get impUseDefault => 'بنەڕەت بەکاربهێنە';

  @override
  String get impReady => 'ئامادە';

  @override
  String get impDuplicates => 'پێشتر هەیە';

  @override
  String get impProblems => 'نەخوێندرایەوە';

  @override
  String get impSkipDuplicates => 'ئەو ڕیزانەی پێشتر هەن بپەڕێنە';

  @override
  String get impProblemDate => 'بەروار نییە';

  @override
  String get impProblemAmount => 'بڕ نییە';

  @override
  String get impProblemType => 'جۆری نەناسراو';

  @override
  String get impProblemAccount => 'هەژمار نییە';

  @override
  String get impDuplicateTag => 'هەیە';

  @override
  String impFirstRows(int count) {
    return 'یەکەم $count ڕیز';
  }

  @override
  String impImport(int count) {
    return '$count ڕیز هاوردە بکە';
  }

  @override
  String impImported(int count) {
    return '$count ڕیز هاوردە کرا';
  }

  @override
  String get impOpeningHint =>
      'بنووسە هەر هەژمارێک بەڕاستی ئەمڕۆ چەندی تێدایە. جیاوازییەکە وەک ڕێکخستن پاشەکەوت دەکرێت.';

  @override
  String impComputed(String amount) {
    return 'لە ئەپەکەدا: $amount';
  }

  @override
  String get impActual => 'ڕاستەقینەی ئەمڕۆ';

  @override
  String get impSaveBalances => 'باڵانسەکان پاشەکەوت بکە';

  @override
  String get impDone => 'تەواو';

  @override
  String get impNext => 'دواتر';

  @override
  String get impBack => 'گەڕانەوە';

  @override
  String get impPastImports => 'هاوردە پێشووەکان';

  @override
  String get impUndo => 'پاشگەزبوونەوە';

  @override
  String impUndoConfirm(int count, String name) {
    return 'ئەو $count ڕیزەی لە $name هاوردە کران لاببرێن؟';
  }

  @override
  String get impUndone => 'هەڵوەشێنرایەوە';

  @override
  String impBatchLine(int count, String date) {
    return '$count ڕیز · $date';
  }

  @override
  String get setAi => 'زیرەکی دەستکردی ئۆنلاین';

  @override
  String get setAiHint => 'کلیلی Groq، مۆدێلەکان و ئەوەی دەنێردرێت';

  @override
  String get aiOnline => 'زیرەکی دەستکردی ئۆنلاین بەکاربهێنە';

  @override
  String get aiOnlineHint =>
      'کاتێک کوژاوەیە، هەموو شتێک لەسەر مۆبایلەکە تێدەگات، کەمێک بە وردی کەمتر.';

  @override
  String get aiKey => 'کلیلی Groq API';

  @override
  String get aiKeyHint =>
      'بەخۆڕایی لە console.groq.com. تەنها لەسەر ئەم مۆبایلە بە نهێنی هەڵدەگیرێت.';

  @override
  String aiKeySaved(String last4) {
    return 'کلیلی هەڵگیراو ••••$last4';
  }

  @override
  String get aiKeyRemove => 'بیسڕەوە';

  @override
  String get aiKeyPaste => 'لکاندن';

  @override
  String get aiKeySave => 'کلیلەکە هەڵبگرە';

  @override
  String get aiTest => 'کلیلەکە تاقی بکەرەوە';

  @override
  String get aiTestOk => 'کلیلەکە کار دەکات.';

  @override
  String get aiTestUnauthorized =>
      'Groq ئەم کلیلەی ڕەتکردەوە. بیپشکنە و دووبارە هەڵیبگرەوە.';

  @override
  String get aiTestOffline => 'نەتوانرا بگەینە Groq. ئینتەرنێتەکە بپشکنە.';

  @override
  String get aiTestBusy => 'Groq سەرقاڵە. دوای خولەکێک دووبارە هەوڵ بدەرەوە.';

  @override
  String get aiTestOther =>
      'Groq وەک چاوەڕوانکراو وەڵامی نەدایەوە. دواتر هەوڵ بدەرەوە.';

  @override
  String get aiModels => 'مۆدێلەکان';

  @override
  String get aiSttModel => 'مۆدێلی دەنگ بۆ دەق';

  @override
  String get aiLlmModel => 'مۆدێلی تێگەیشتن';

  @override
  String get aiModelsSave => 'مۆدێلەکان هەڵبگرە';

  @override
  String get aiModelsSaved => 'مۆدێلەکان هەڵگیران';

  @override
  String get aiConsents => 'چی بۆ Groq دەنێردرێت';

  @override
  String get aiConsentVoiceTitle => 'دەنگ بۆ دەق';

  @override
  String get aiConsentParseTitle => 'پڕکردنەوەی فۆرمەکە';

  @override
  String get aiConsentVoice =>
      'تۆماری دەنگەکەت بۆ Groq دەنێردرێت بۆ ئەوەی بکرێتە دەق.';

  @override
  String get aiConsentParse =>
      'دەقی ئەوەی وتت، بەروار و کاتی ئەمڕۆ، و ناوی هەژمارەکان، شوێنەکانی کار، پۆلەکان و سندوقەکانت بۆ Groq دەنێردرێن بۆ پڕکردنەوەی فۆرمەکە. باڵانس، مامەڵە کۆنەکان و گەنجینەکە هەرگیز نانێردرێن.';

  @override
  String get aiConsentGranted => 'ڕێگەپێدراو';

  @override
  String get aiConsentDeclined => 'ڕێگەپێنەدراو';

  @override
  String get aiConsentUnset => 'هێشتا نەپرسراوە';

  @override
  String get aiConsentReset => 'دووبارە بپرسە';

  @override
  String get aiOfflineModel => 'مۆدێلی قسەکردن بێ ئینتەرنێت';

  @override
  String get aiOfflineModelHint =>
      'قسە دەکاتە دەق لەسەر مۆبایلەکە کاتێک زیرەکی ئۆنلاین کوژاوەیە یان ناگات.';

  @override
  String get consentTitle => 'ئەمە بنێرین بۆ Groq؟';

  @override
  String get consentWho =>
      'کۆمپانیای Groq لەسەر سێرڤەرەکانی ویلایەتە یەکگرتووەکان چارەسەری دەکات.';

  @override
  String get consentNever =>
      'هەرگیز نانێردرێت: باڵانسەکانت، مامەڵە کۆنەکان، PIN، پاشەکەوتەکان یان گەنجینەکە.';

  @override
  String get consentOff =>
      'هەر کاتێک دەتوانیت لە ڕێکخستنەکان ← زیرەکی دەستکردی ئۆنلاین بیکوژێنیتەوە.';

  @override
  String get consentAllow => 'ڕێگە بدە';

  @override
  String get consentDecline => 'نەخێر، با لەسەر مۆبایلەکە بمێنێت';

  @override
  String get aiModelSmall => 'بچووک: وردتر';

  @override
  String get aiModelBase => 'بنەڕەتی: خێراتر';

  @override
  String aiModelSize(int mb) {
    return '$mb مێگابایت';
  }

  @override
  String aiModelInstall(int mb) {
    return 'دابەزاندن ($mb مێگابایت)';
  }

  @override
  String get aiModelInstalled => 'دابەزێنراو و پشکنراو';

  @override
  String get aiModelNotInstalled => 'دانەبەزێنراوە';

  @override
  String get aiModelDelete => 'بیسڕەوە';

  @override
  String get aiModelCancel => 'ڕایگرە';

  @override
  String aiModelProgress(int percent) {
    return 'دادەبەزێت… $percent%';
  }

  @override
  String get aiModelVerifying => 'فایلەکە دەپشکنرێت…';

  @override
  String get aiModelFailed =>
      'دابەزاندنەکە وەستا. دووبارە هەوڵ بدەرەوە، باشترە لەسەر Wi-Fi.';

  @override
  String get aiModelMismatch =>
      'فایلەکە یەکی نەگرتەوە و سڕایەوە. دووبارە هەوڵ بدەرەوە.';

  @override
  String get aiModelSorani =>
      'بێ ئینتەرنێت، کوردی (سۆرانی) بە وردی کەمتر لە عەرەبی و ئینگلیزی دەناسرێتەوە.';

  @override
  String get capMicTooltip => 'بە دەنگ تۆمار بکە (بۆ نووسین دابگرە)';

  @override
  String get capListening => 'گوێ دەگرم…';

  @override
  String get capCapHint => 'تا دوو خولەک';

  @override
  String get capStop => 'تەواو';

  @override
  String get capProcessing => 'تێدەگەم…';

  @override
  String get capMicDenied =>
      'مایکرۆفۆن ڕێگەپێنەدراوە. لە ڕێکخستنەکانی ئەندرۆید ڕێگەی پێبدە.';

  @override
  String get capTypeHint => 'بنووسە چی ڕوویدا';

  @override
  String get capSend => 'ناردن';

  @override
  String get capManual => 'یان بە دەست زیاد بکە';

  @override
  String get capNote => 'تێبینی';

  @override
  String get capVaultItem => 'شتێک لە گەنجینە';

  @override
  String get capSavedToInbox => 'لە سندوقی هاتوو پاشەکەوت کرا';

  @override
  String get capOpen => 'بیکەرەوە';

  @override
  String get capReason_noSpeechEngine =>
      'هێشتا بزوێنەری دەنگ نییە. AI ی ئۆنلاین هەڵبکە یان مۆدێلێکی ئۆفلاین لە ڕێکخستنەکان دابەزێنە.';

  @override
  String get capReason_sttFailed =>
      'نەمتوانی تۆمارەکە بکەمە دەق. لە سندوقی هاتوو هەڵگیرا.';

  @override
  String get capReason_empty => 'هیچ نەبیسترا.';

  @override
  String get capReason_lowConfidence =>
      'دڵنیا نیم مەبەستت چییە. لە سندوقی هاتوو هەڵگیرا.';

  @override
  String get capReviewTitle => 'پێداچوونەوە';

  @override
  String get capTranscript => 'ئەوەی وتت';

  @override
  String get capParseAgain => 'دووبارە بیخوێنەوە';

  @override
  String get capByAi => 'AI ی ئۆنلاین پڕی کردەوە';

  @override
  String get capByRules => 'لەسەر ئەم مۆبایلە بەبێ ئینتەرنێت پڕکرایەوە';

  @override
  String get capKeepCard => 'ئەمە پاشەکەوت بکە';

  @override
  String get capCheckThis => 'ئەمە بپشکنە';

  @override
  String get capMissingFields =>
      'خانە دیاریکراوەکان پڕبکەوە یان ئەمە بکوژێنەوە';

  @override
  String get capKeepInInbox => 'لە سندوقی هاتوو بیهێڵەوە';

  @override
  String capInboxUntil(int phase) {
    return 'لە سندوقی هاتوو دەمێنێتەوە تا قۆناغی $phase';
  }

  @override
  String get capDebt => 'قەرز';

  @override
  String get capNewDebt => 'قەرزی نوێ';

  @override
  String get capWhichDebt => 'کام قەرز';

  @override
  String get capDrop => 'لابرا';

  @override
  String get capNothingFound =>
      'هیچ شتێک بۆ پاشەکەوتکردن نەدۆزرایەوە. دەقەکە دەستکاری بکە و دووبارە بیخوێنەوە.';

  @override
  String get capAlreadyHandled => 'ئەم تۆمارە پێشتر پاشەکەوت یان سڕاوەتەوە.';

  @override
  String get capDone => 'پاشەکەوت کرا';

  @override
  String get capInbox => 'سندوقی هاتوو';

  @override
  String get capInboxEmpty =>
      'هیچ شتێک چاوەڕێ نییە. هەر شتێک بڵێیت یان بینووسیت و پاشەکەوتی نەکەیت دێتە ئێرە.';

  @override
  String get capNotTranscribed => 'دەنگ، هێشتا نەکراوە بە دەق';

  @override
  String get capTranscribe => 'بیکە بە دەق';

  @override
  String get capFinishAi => 'بە AI تەواوی بکە';

  @override
  String get capFinishAllAi => 'هەمووی بە AI تەواو بکە';

  @override
  String capFinishing(int n, int total) {
    return 'تەواوکردنی $n لە $total…';
  }

  @override
  String get capOpenReview => 'پێداچوونەوە';

  @override
  String get capDiscard => 'لابردن';

  @override
  String get capDiscardTitle => 'ئەم تۆمارە لاببرێت؟';

  @override
  String get capDiscardBody =>
      'دەق و دەنگەکەی دەسڕێتەوە. هیچ شتێکی پاشەکەوتکراو لێی ناگۆڕێت.';

  @override
  String capWillBecomeTask(int phase) {
    return 'دەبێتە ئەرک لە قۆناغی $phase';
  }

  @override
  String capWillBecomeNote(int phase) {
    return 'دەبێتە تێبینی لە قۆناغی $phase';
  }

  @override
  String get vltLocked => 'گەنجینە داخراوە';

  @override
  String get vltLockedBody => 'وشەی نهێنیی سەرەکی بنووسە بۆ کردنەوەی.';

  @override
  String get vltMasterPassword => 'وشەی نهێنیی سەرەکی';

  @override
  String get vltUnlock => 'کردنەوە';

  @override
  String get vltUnlocking => 'گەنجینە دەکرێتەوە…';

  @override
  String get vltWrongSecret =>
      'ئەمە گەنجینەکە ناکاتەوە. بیپشکنە و دووبارە هەوڵ بدەرەوە.';

  @override
  String vltAttemptsLeft(int count) {
    return '$count هەوڵ ماوە پێش وەستان';
  }

  @override
  String get vltCorrupt =>
      'داتای گەنجینە تێکچووە. هیچ نەسڕایەوە؛ ئەگەر دووبارە بووەوە، باکئەپێک بگەڕێنەوە.';

  @override
  String get vltUseRecoveryKey => 'کلیلی گەڕاندنەوە بەکاربهێنە';

  @override
  String get vltUsePassword => 'وشەی نهێنیی سەرەکی بەکاربهێنە';

  @override
  String get vltRecoveryKey => 'کلیلی گەڕاندنەوە';

  @override
  String get vltRecoveryKeyHint => '32 پیت و ژمارە؛ هێڵ و بۆشایی گرنگ نین';

  @override
  String get vltUseFingerprint => 'بە پەنجەمۆر بیکەرەوە';

  @override
  String get vltBioTitle => 'کردنەوەی گەنجینە';

  @override
  String get vltBioSubtitle => 'دەست لە هەستەوەری پەنجەمۆر بدە';

  @override
  String get vltBioInvalidated =>
      'کردنەوە بە پەنجەمۆر ناچالاک کرا چونکە پەنجەمۆرەکانی مۆبایل گۆڕان یان باکئەپێک گەڕێندرایەوە. بە وشەی نهێنیی سەرەکی بیکەرەوە، پاشان لە ڕێکخستنەکانی گەنجینە دووبارە چالاکی بکە.';

  @override
  String get vltNewPasswordTitle => 'وشەی نهێنیی سەرەکیی نوێ دابنێ';

  @override
  String get vltNewPasswordBody =>
      'گەنجینەکەت بە کلیلی گەڕاندنەوە کردەوە. پێش بەردەوامبوون وشەی نهێنیی سەرەکیی نوێ هەڵبژێرە.';

  @override
  String get vltNewPassword => 'وشەی نهێنیی سەرەکیی نوێ';

  @override
  String vltPasswordTooShort(int min) {
    return 'لانیکەم $min پیت';
  }

  @override
  String get vltStrengthVeryStrong => 'زۆر بەهێز';

  @override
  String get vltSetupTitle => 'گەنجینەکەت ئامادە بکە';

  @override
  String get vltSetupIntro =>
      'گەنجینە وشە نهێنییەکان بە شێوەی کۆدکراو تەنها لەسەر ئەم مۆبایلە هەڵدەگرێت. وشەی نهێنیی سەرەکیی تایبەتی خۆی هەیە، جیا لە PINی ئەپەکە، و کلیلی گەڕاندنەوە بۆ کاتی لەبیرچوون. بەبێ یەکێکیان کەس ناتوانێت بیکاتەوە، تەنانەت خۆشت.';

  @override
  String get vltSetupTestFirst =>
      'تا پێداچوونەوەی ئاسایشی گەنجینە نەخوێنیتەوە، وشەی نهێنیی تاقیکاری بەکاربهێنە.';

  @override
  String get vltSetupStart => 'دەست پێبکە';

  @override
  String get vltSetupPasswordBody =>
      'لانیکەم 10 پیت. چەند وشەیەکی هەڕەمەکی ئاسانترن بۆ لەبەرکردن و قورسترن بۆ مەزەندەکردن لە وشەیەکی نهێنیی کورتی ئاڵۆز.';

  @override
  String get vltPreparing => 'کۆدکردن ئامادە دەکرێت… چەند چرکەیەک دەخایەنێت.';

  @override
  String get vltRecoveryTitle => 'کلیلی گەڕاندنەوەکەت';

  @override
  String get vltRecoveryBody =>
      'ئەم کلیلە لەسەر کاغەز بنووسە و لە شوێنێکی پارێزراو دایبنێ. تاکە ڕێگەیە بۆ چوونەژوورەوە ئەگەر وشەی نهێنیی سەرەکیت لەبیرچوو. جارێکی تر پیشان نادرێتەوە.';

  @override
  String get vltCopied =>
      'کۆپی کرا. دوای 30 چرکە لە کلیپبۆرد دەسڕدرێتەوە ئەگەر ئەندرۆید ڕێگە بدات.';

  @override
  String get vltCopiedPlain => 'کۆپی کرا';

  @override
  String get vltCopyFailed => 'کۆپی نەکرا';

  @override
  String get vltRecoveryConfirmTitle => 'کلیلی گەڕاندنەوە دووبارە بنووسە';

  @override
  String get vltRecoveryConfirmBody =>
      'ئەمە دڵنیا دەبێتەوە کە بە دروستی نووسیوتە.';

  @override
  String get vltRecoveryMismatch =>
      'ئەمە لەگەڵ ئەو کلیلەی پێشتر پیشاندرا یەک ناگرێتەوە.';

  @override
  String get vltSetupBioTitle => 'کردنەوە بە پەنجەمۆر؟';

  @override
  String get vltSetupBioBody =>
      'پەنجەمۆرەکەت دەتوانێت گەنجینە لەسەر ئەم مۆبایلە بکاتەوە. وشەی نهێنیی سەرەکی هەر کار دەکات، و PINی مۆبایل هەرگیز قبوڵ ناکرێت.';

  @override
  String get vltSetupDone => 'تەواو';

  @override
  String get vltNotNow => 'ئێستا نا';

  @override
  String get vltSearch => 'گەڕان لە ناونیشان، ماڵپەڕ و ناوی بەکارهێنەر';

  @override
  String get vltAll => 'هەموو';

  @override
  String get vltFavorites => 'دڵخوازەکان';

  @override
  String get vltEmpty => 'هێشتا هیچ وشەیەکی نهێنی نییە';

  @override
  String get vltEmptyBody =>
      'یەکێک زیاد بکە، یان لە تێبینییەکانتەوە هاوردەیان بکە.';

  @override
  String get vltNoMatches => 'هیچ شتێک نەدۆزرایەوە';

  @override
  String get vltAdd => 'زیادکردنی وشەی نهێنی';

  @override
  String get vltLock => 'داخستنی گەنجینە';

  @override
  String get vltGenerator => 'دروستکەری وشەی نهێنی';

  @override
  String get vltImport => 'هاوردەکردن لە تێبینییەکان';

  @override
  String get vltSettings => 'ڕێکخستنەکانی گەنجینە';

  @override
  String get vltSettingsHint =>
      'داخستنی خۆکار، پەنجەمۆر، وشەی نهێنیی سەرەکی، کلیلی گەڕاندنەوە';

  @override
  String get vltMore => 'زیاتر';

  @override
  String get vltSort => 'ڕیزکردن';

  @override
  String get vltSortTitle => 'بەپێی ناو';

  @override
  String get vltSortUpdated => 'دوایین گۆڕاو';

  @override
  String get vltSortCreated => 'دوایین زیادکراو';

  @override
  String get vltCatPersonal => 'کەسی';

  @override
  String get vltCatBusiness => 'بازرگانی';

  @override
  String get vltCatSocial => 'تۆڕی کۆمەڵایەتی';

  @override
  String get vltCatBanking => 'بانک';

  @override
  String get vltCatHosting => 'هۆستینگ';

  @override
  String get vltCatDomain => 'دۆمەین';

  @override
  String get vltCatEmail => 'ئیمەیڵ';

  @override
  String get vltCatMarketing => 'بازاڕکردن';

  @override
  String get vltCatDev => 'پەرەپێدان';

  @override
  String get vltCatOther => 'هیتر';

  @override
  String get vltTitle => 'ناونیشان';

  @override
  String get vltUrl => 'ماڵپەڕ';

  @override
  String get vltUsername => 'ناوی بەکارهێنەر';

  @override
  String get vltEmail => 'ئیمەیڵ';

  @override
  String get vltPassword => 'وشەی نهێنی';

  @override
  String get vltNotes => 'تێبینی';

  @override
  String get vltRecoveryCodes => 'کۆدەکانی گەڕاندنەوە';

  @override
  String get vltCategory => 'پۆل';

  @override
  String get vltWorkspace => 'شوێنی کار';

  @override
  String get vltNoWorkspace => 'هیچ';

  @override
  String get vltFavorite => 'دڵخواز';

  @override
  String get vltReveal => 'پیشاندان';

  @override
  String get vltHide => 'شاردنەوە';

  @override
  String get vltCopy => 'کۆپی';

  @override
  String vltPasswordChanged(String date) {
    return 'وشەی نهێنی گۆڕدرا $date';
  }

  @override
  String get vltEdit => 'دەستکاری';

  @override
  String get vltDelete => 'سڕینەوە';

  @override
  String get vltDeleteTitle => 'ئەم وشە نهێنییە بسڕیتەوە؟';

  @override
  String get vltDeleteBody => 'ناگەڕێتەوە، تەنها لە باکئەپەوە نەبێت.';

  @override
  String get vltConfirmIdentity => 'پشتڕاستی بکەرەوە کە خۆتی';

  @override
  String get vltConfirmIdentityBody =>
      'وشەی نهێنیی سەرەکی بنووسە بۆ پیشاندان یان کۆپیکردنی نهێنییەکان.';

  @override
  String get vltConfirm => 'پشتڕاستکردنەوە';

  @override
  String get vltNewItem => 'وشەی نهێنیی نوێ';

  @override
  String get vltEditItem => 'دەستکاریی وشەی نهێنی';

  @override
  String get vltGenerate => 'دروستکردن';

  @override
  String get vltDiscardTitle => 'گۆڕانکارییەکان فڕێبدرێن؟';

  @override
  String get vltDiscard => 'فڕێدان';

  @override
  String get vltKeepEditing => 'بەردەوامبوون لە دەستکاری';

  @override
  String vltLength(int n) {
    return 'درێژی: $n';
  }

  @override
  String get vltLower => 'پیتی بچووک (a–z)';

  @override
  String get vltUpper => 'پیتی گەورە (A–Z)';

  @override
  String get vltDigits => 'ژمارە (0–9)';

  @override
  String get vltSymbols => 'هێما (!@#)';

  @override
  String get vltAvoidLookAlikes => 'دوورکەوتنەوە لە هاوشێوەکان (I l 1 O 0)';

  @override
  String vltEntropy(int bits) {
    return 'نزیکەی $bits بیت هەڕەمەکی';
  }

  @override
  String get vltRegenerate => 'وشەیەکی تر';

  @override
  String get vltUseThis => 'ئەم وشە نهێنییە بەکاربهێنە';

  @override
  String get vltImportBody =>
      'دەقەکە لە تێبینییەکانتەوە بلکێنە. تەنها لەسەر ئەم مۆبایلە دەخوێندرێتەوە؛ بۆ هیچ شوێنێک نانێردرێت.';

  @override
  String get vltImportHint => 'تێبینییەکانت لێرە بلکێنە';

  @override
  String get vltFindItems => 'دۆزینەوەی بڕگەکان';

  @override
  String get vltFoundNone => 'هیچ وشەیەکی نهێنی لەم دەقەدا نەدۆزرایەوە.';

  @override
  String get vltImportTooLong => 'دەقەکە زۆر درێژە. بەشێکی بچووکتر بلکێنە.';

  @override
  String get vltKeep => 'هەڵگرتن';

  @override
  String vltSaveN(int count) {
    return 'پاشەکەوتکردنی $count';
  }

  @override
  String get vltImportDoneTitle => 'ئێستا تێبینییە ڕەسەنەکە بسڕەوە';

  @override
  String get vltImportDoneBody =>
      'وشە نهێنییەکان لە گەنجینەدان. ئەو تێبینییەی لێیەوە کۆپیت کردن هێشتا وەک دەقی ئاسایی لە ئەپی تێبینییەکاندایە؛ خۆت بیسڕەوە.';

  @override
  String get vltAutoLock => 'داخستنی خۆکار';

  @override
  String vltAutoLockAfter(int minutes) {
    return 'دوای $minutes خولەک بێ بەکارهێنان';
  }

  @override
  String get vltAutoLockNote =>
      'گەنجینە هەروەها دادەخرێت هەر کاتێک لە ئەپەکە دەرچیت یان ئەپەکە دابخرێت.';

  @override
  String get vltFingerprint => 'کردنەوە بە پەنجەمۆر';

  @override
  String get vltFingerprintUnavailable =>
      'هیچ پەنجەمۆرێکی بەهێز لەسەر ئەم مۆبایلە ڕێک نەخراوە.';

  @override
  String get vltChangePassword => 'گۆڕینی وشەی نهێنیی سەرەکی';

  @override
  String get vltCurrentPassword => 'وشەی نهێنیی سەرەکیی ئێستا';

  @override
  String get vltPasswordChangedOk => 'وشەی نهێنیی سەرەکی گۆڕدرا';

  @override
  String get vltNewRecoveryKey => 'کلیلی گەڕاندنەوەی نوێ';

  @override
  String get vltNewRecoveryKeyBody =>
      'کلیلی گەڕاندنەوەی کۆن کار ناکات کاتێک نوێکە پشتڕاست دەکەیتەوە.';

  @override
  String get vltRecoveryReplaced => 'کلیلی گەڕاندنەوەی نوێ پاشەکەوت کرا';

  @override
  String get vltHowProtected => 'گەنجینەکەت چۆن دەپارێزرێت';

  @override
  String get vltHowProtectedBody =>
      'هەر وشەیەکی نهێنی، تێبینی و کۆدی گەڕاندنەوە بە AES-256-GCM و کلیلێکی هەڕەمەکیی گەنجینە کۆد دەکرێت. ئەو کلیلە بە وشەی نهێنیی سەرەکیت (Argon2id)، بە کلیلی گەڕاندنەوە، و ئەگەر چالاکی بکەیت، بە کلیلێکی تەنها-پەنجەمۆر لەناو ڕەقەکاڵای پارێزراوی مۆبایل قفڵ دەکرێت. ناونیشان، ماڵپەڕ و ناوی بەکارهێنەر لە داتابەیسی کۆدکراوی ئەپەکەدا هەڵدەگیرێن بۆ ئەوەی بتوانیت تێیاندا بگەڕێیت. هیچ شتێکی گەنجینە بۆ ئینتەرنێت یان AI نانێردرێت. باکئەپەکان گەنجینە بە کۆدکراوی هەڵدەگرن؛ دوای گەڕاندنەوە دەبێت کردنەوە بە پەنجەمۆر دووبارە چالاک بکرێتەوە. نهێنییە کۆپیکراوەکان وەک هەستیار نیشانە دەکرێن و دوای 30 چرکە دەسڕدرێنەوە ئەگەر ئەندرۆید ڕێگە بدات.';

  @override
  String get vltFillIn => 'ئەم خانەیە پڕ بکەرەوە';

  @override
  String get backupVaultNote =>
      'گەنجینە بە کۆدکراوی بە وشەی نهێنیی سەرەکیت دەچێتە ناو باکئەپەکەوە. دوای گەڕاندنەوە، کردنەوە بە پەنجەمۆر لە ڕێکخستنەکانی گەنجینە دووبارە چالاک بکەرەوە.';

  @override
  String get tskAdd => 'زیادکردنی ئەرک';

  @override
  String get tskNew => 'ئەرکی نوێ';

  @override
  String get tskEdit => 'دەستکاریکردنی ئەرک';

  @override
  String get tskQuickHint => 'ئەرکێک زیاد بکە…';

  @override
  String get tskViewInbox => 'هاتوو';

  @override
  String get tskViewToday => 'ئەمڕۆ';

  @override
  String get tskViewTomorrow => 'سبەینێ';

  @override
  String get tskViewWeek => 'ئەم هەفتەیە';

  @override
  String get tskViewUpcoming => 'داهاتوو';

  @override
  String get tskViewOverdue => 'دواکەوتوو';

  @override
  String get tskViewCompleted => 'تەواوبوو';

  @override
  String get tskViewAll => 'هەموو';

  @override
  String get tskEmpty => 'لێرە هیچ نییە.';

  @override
  String get tskAllWorkspaces => 'هەموو شوێنەکانی کار';

  @override
  String get tskSort => 'ڕیزکردن';

  @override
  String get tskSortDue => 'بەپێی کات';

  @override
  String get tskSortPriority => 'بەپێی گرنگی';

  @override
  String get tskCalendar => 'ساڵنامە';

  @override
  String get tskCalendarEmpty => 'لەم ڕۆژەدا ئەرک نییە.';

  @override
  String get tskMeetings => 'تێبینییەکانی کۆبوونەوە';

  @override
  String get tskFieldTitle => 'ناونیشان';

  @override
  String get tskFieldNotes => 'تێبینی';

  @override
  String get tskFieldWorkspace => 'شوێنی کار';

  @override
  String get tskNoWorkspace => 'بێ شوێنی کار';

  @override
  String get tskFieldPriority => 'گرنگی';

  @override
  String get tskPriorityLow => 'کەم';

  @override
  String get tskPriorityNormal => 'ئاسایی';

  @override
  String get tskPriorityHigh => 'بەرز';

  @override
  String get tskPriorityUrgent => 'پەلەیی';

  @override
  String get tskDueDate => 'کاتی دیاریکراو';

  @override
  String get tskNoDate => 'بێ بەروار';

  @override
  String get tskAllDay => 'هەموو ڕۆژەکە';

  @override
  String get tskClearDate => 'لابردنی بەروار';

  @override
  String get tskReminder => 'بیرخستنەوە';

  @override
  String get tskRemindNone => 'بێ بیرخستنەوە';

  @override
  String get tskRemindAtDue => 'لە کاتی دیاریکراودا';

  @override
  String get tskRemind10 => '١٠ خولەک پێش کات';

  @override
  String get tskRemind1h => 'کاتژمێرێک پێش کات';

  @override
  String get tskRemind1d => 'ڕۆژێک پێش کات';

  @override
  String get tskRemindMorning => '٩ی بەیانی لەو ڕۆژەدا';

  @override
  String get tskRemindDayBefore => '٩ی بەیانی ڕۆژێک پێشتر';

  @override
  String get tskRemindCustom => 'کاتێک هەڵبژێرە…';

  @override
  String get tskRepeat => 'دووبارەبوونەوە';

  @override
  String get tskRepeatNone => 'دووبارە نابێتەوە';

  @override
  String get tskRepeatDaily => 'هەموو ڕۆژێک';

  @override
  String get tskRepeatWeekly => 'هەموو هەفتەیەک';

  @override
  String get tskRepeatMonthly => 'هەموو مانگێک';

  @override
  String get tskRepeatYearly => 'هەموو ساڵێک';

  @override
  String get tskTags => 'تاگەکان';

  @override
  String get tskTagsHint => 'کڕیار، پەلە';

  @override
  String get tskDiscardTitle => 'گۆڕانکارییەکان بسڕدرێنەوە؟';

  @override
  String get tskDiscardBody => 'ئەوەی نووسیوتە لەدەست دەچێت.';

  @override
  String get tskDiscard => 'فڕێدان';

  @override
  String get tskNotFound => 'ئەم ئەرکە ئیتر نەماوە.';

  @override
  String get tskStatusTodo => 'بۆ ئەنجامدان';

  @override
  String get tskStatusDoing => 'لە ئەنجامداندایە';

  @override
  String get tskStatusDone => 'تەواوبوو';

  @override
  String get tskMarkDone => 'تەواو بکە';

  @override
  String get tskReopen => 'کردنەوەی دووبارە';

  @override
  String get tskStart => 'دەستپێکردن';

  @override
  String get tskSnoozeTomorrow => 'سبەینێ ٩ی بەیانی بمخەرەوە بیر';

  @override
  String get tskSnoozedTomorrow =>
      'بیرخستنەوەکە گوازرایەوە بۆ سبەینێ ٩ی بەیانی';

  @override
  String get tskDelete => 'سڕینەوە';

  @override
  String get tskDeleteTitle => 'ئەم ئەرکە بسڕدرێتەوە؟';

  @override
  String get tskDeleteBody => 'هەنگاوەکانیشی لەگەڵ دەسڕدرێنەوە.';

  @override
  String get tskSteps => 'هەنگاوەکان';

  @override
  String get tskAddStep => 'هەنگاوێک زیاد بکە';

  @override
  String get tskWarnNotifications =>
      'ئاگادارکردنەوەکان کوژاونەتەوە، بۆیە بیرخستنەوە پیشان نادرێت. ڕێگەیان پێ بدە.';

  @override
  String get tskWarnExact =>
      'زەنگە وردەکان ڕێگەپێنەدراون، بۆیە بیرخستنەوە لەوانەیە چەند خولەکێک دوا بکەوێت. لە ڕێکخستنەکانی ئەندرۆید ڕێگەیان پێ بدە.';

  @override
  String get tskAllow => 'ڕێگەپێدان';

  @override
  String get tskOpenSettings => 'کردنەوەی ڕێکخستنەکان';

  @override
  String get tskMeetingNote => 'تێبینی کۆبوونەوە';

  @override
  String get tskMeetingNew => 'تێبینی کۆبوونەوەی نوێ';

  @override
  String get tskMeetingBody => 'ئەوەی گوترا';

  @override
  String get tskMeetingEmpty =>
      'هێشتا تێبینی کۆبوونەوە نییە. یەکێک بنووسە و خاڵەکانی کار وەک ئەرک دەربهێنە.';

  @override
  String get tskExtract => 'دەرهێنانی خاڵەکانی کار';

  @override
  String get tskExtractTitle => 'خاڵەکانی کار';

  @override
  String get tskExtractNone => 'لەم دەقەدا خاڵی کار نەدۆزرایەوە.';

  @override
  String get tskNotifDone => 'تەواو';

  @override
  String get tskNotifSnooze10 => '١٠ خولەک';

  @override
  String get tskNotifSnooze1h => 'کاتژمێر';

  @override
  String get tskNotifChannel => 'بیرخستنەوەی ئەرکەکان';

  @override
  String tskAddNTasks(int count) {
    return 'زیادکردنی $count ئەرک';
  }

  @override
  String tskRepeatEveryN(int n, String unit) {
    return 'هەر $n · $unit';
  }

  @override
  String tskNextCreated(String date) {
    return 'داهاتووی: $date';
  }
}
