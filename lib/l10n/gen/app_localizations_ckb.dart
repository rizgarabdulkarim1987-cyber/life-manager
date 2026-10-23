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
  String get setupWelcomeBody => 'هەموو شتێک لەسەر ئەم مۆبایلە دەمێنێتەوە، لەژێر قوفڵی خۆت.';

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
  String get restoreTooNew => 'ئەم پاشەکەوتە لە وەشانێکی نوێتری ئەپەکە دروستکراوە. سەرەتا ئەپەکە نوێ بکەرەوە.';

  @override
  String get restoreWrongPassword => 'وشەی نهێنی هەڵەیە، یان فایلەکە تێکچووە.';

  @override
  String get restoreCorrupt => 'ئەم فایلە تێکچووە یان پاشەکەوتی ئەم ئەپە نییە.';

  @override
  String get restoreSuccess => 'گەڕێندرایەوە. دووبارە دەستپێدەکاتەوە…';

  @override
  String get passwordStrengthWeak => 'لاواز: درێژتری بکە، یان پیت و ژمارە و هێما تێکەڵ بکە';

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
  String get finAdjustHint => 'بڕی ڕاستەقینەی ئەم هەژمارە بنووسە. جیاوازییەکە وەک ڕێکخستن پاشەکەوت دەکرێت.';

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
  String get finBucketsUnconfirmed => 'پێش دابەشکردنی داهات، ڕێژەکانی خۆت دابنێ.';

  @override
  String get finExpensesMonthly => 'هەموو مانگێک سفر دەبێتەوە';

  @override
  String get finCarriesOver => 'کۆدەبێتەوە';

  @override
  String get finAddBudget => 'زیادکردنی بودجە';

  @override
  String get finEditBudget => 'دەستکاری بودجە';

  @override
  String get finBudgetNeedsScope => 'پۆلێک یان شوێنی کارێک یان هەردووکیان هەڵبژێرە';

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
  String get repNotEncrypted => 'ئەم فایلە نهێنی نەکراوە. هەر کەسێک دەستی بکەوێت دەتوانێت بیخوێنێتەوە.';

  @override
  String get repExportFailed => 'نەتوانرا فایلەکە پاشەکەوت بکرێت';

  @override
  String get setFinance => 'دارایی';

  @override
  String get setFinanceSettings => 'دراو و نرخەکان';

  @override
  String get setFinanceSettingsHint => 'دراوی بنەڕەت، نرخی دۆلار، ئاگادارکردنەوە';

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
  String get setBaseCurrencyHint => 'کۆکان و سندوقەکان و ڕاپۆرتەکان بەکاری دەهێنن مەگەر یەکێکی تر هەڵبژێریت.';

  @override
  String setRateDate(String date) {
    return 'لە $dateەوە';
  }

  @override
  String get setRateHistory => 'مێژووی نرخەکان';

  @override
  String get setNoRates => 'هێشتا نرخ نییە. دۆلار و دینار جیا دەمێننەوە تا نرخێک زیاد دەکەیت.';

  @override
  String get setRateSaved => 'نرخەکە پاشەکەوت کرا';

  @override
  String get setAlerts => 'ئاگادارکردنەوەکان';

  @override
  String get setUnallocatedAlert => 'بیرم بخەرەوە بە داهاتێک کە دابەش نەکراوە بۆ سندوقەکان';

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
  String get impTooLarge => 'فایلەکە زۆر گەورەیە: زیاتر لە 50,000 ڕیز یان 64 ستوون.';

  @override
  String get impUnreadable => 'نەتوانرا فایلەکە وەک ‎.xlsx‎ یان ‎.csv‎ بخوێنرێتەوە.';

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
  String get impNeedDateAmount => 'ستوونی بەروار و بڕ هەڵبژێرە بۆ بەردەوامبوون.';

  @override
  String get impDefaultsHint => 'بۆ ئەو ڕیزانە بەکاردێت کە ئەمەیان تێدا نییە.';

  @override
  String get impNoValues => 'هیچ بۆ گونجاندن نییە: فایلەکە ستوونی جۆر، پۆل، شوێن یان هەژماری تێدا نییە.';

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
  String get aiOnlineHint => 'کاتێک کوژاوەیە، هەموو شتێک لەسەر مۆبایلەکە تێدەگات، کەمێک بە وردی کەمتر.';

  @override
  String get aiKey => 'کلیلی Groq API';

  @override
  String get aiKeyHint => 'بەخۆڕایی لە console.groq.com. تەنها لەسەر ئەم مۆبایلە بە نهێنی هەڵدەگیرێت.';

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
  String get aiTestUnauthorized => 'Groq ئەم کلیلەی ڕەتکردەوە. بیپشکنە و دووبارە هەڵیبگرەوە.';

  @override
  String get aiTestOffline => 'نەتوانرا بگەینە Groq. ئینتەرنێتەکە بپشکنە.';

  @override
  String get aiTestBusy => 'Groq سەرقاڵە. دوای خولەکێک دووبارە هەوڵ بدەرەوە.';

  @override
  String get aiTestOther => 'Groq وەک چاوەڕوانکراو وەڵامی نەدایەوە. دواتر هەوڵ بدەرەوە.';

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
  String get aiConsentVoice => 'تۆماری دەنگەکەت بۆ Groq دەنێردرێت بۆ ئەوەی بکرێتە دەق.';

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
  String get aiOfflineModelHint => 'قسە دەکاتە دەق لەسەر مۆبایلەکە کاتێک زیرەکی ئۆنلاین کوژاوەیە یان ناگات.';

  @override
  String get consentTitle => 'ئەمە بنێرین بۆ Groq؟';

  @override
  String get consentWho => 'کۆمپانیای Groq لەسەر سێرڤەرەکانی ویلایەتە یەکگرتووەکان چارەسەری دەکات.';

  @override
  String get consentNever => 'هەرگیز نانێردرێت: باڵانسەکانت، مامەڵە کۆنەکان، PIN، پاشەکەوتەکان یان گەنجینەکە.';

  @override
  String get consentOff => 'هەر کاتێک دەتوانیت لە ڕێکخستنەکان ← زیرەکی دەستکردی ئۆنلاین بیکوژێنیتەوە.';

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
  String get aiModelFailed => 'دابەزاندنەکە وەستا. دووبارە هەوڵ بدەرەوە، باشترە لەسەر Wi-Fi.';

  @override
  String get aiModelMismatch => 'فایلەکە یەکی نەگرتەوە و سڕایەوە. دووبارە هەوڵ بدەرەوە.';

  @override
  String get aiModelSorani => 'بێ ئینتەرنێت، کوردی (سۆرانی) بە وردی کەمتر لە عەرەبی و ئینگلیزی دەناسرێتەوە.';

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
  String get capMicDenied => 'مایکرۆفۆن ڕێگەپێنەدراوە. لە ڕێکخستنەکانی ئەندرۆید ڕێگەی پێبدە.';

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
  String get capReason_noSpeechEngine => 'هێشتا نەکراوەتە دەق.';

  @override
  String get capReason_noSpeechOnlineOff =>
      'زیرەکی دەستکردی ئۆنلاین کوژاوەیە و مۆدێلی قسەکردن بێ ئینتەرنێت دانەبەزێنراوە. لە ڕێکخستنەکان ← زیرەکی دەستکردی ئۆنلاین هەڵیبکە یان مۆدێلەکە دابەزێنە.';

  @override
  String get capReason_noSpeechNoKey =>
      'هیچ کلیلێکی Groq هەڵنەگیراوە. لە ڕێکخستنەکان ← زیرەکی دەستکردی ئۆنلاین زیادی بکە، یان مۆدێلی قسەکردن بێ ئینتەرنێت لەوێ دابەزێنە.';

  @override
  String get capReason_noSpeechNotAsked =>
      'هێشتا ڕێگە نەدراوە دەنگ بۆ Groq بنێردرێت. مایکەکە دابگرە و «ڕێگە بدە» هەڵبژێرە، یان مۆدێلی قسەکردن بێ ئینتەرنێت لە ڕێکخستنەکان ← زیرەکی دەستکردی ئۆنلاین دابەزێنە.';

  @override
  String get capReason_noSpeechDeclined =>
      'هەڵتبژارد دەنگ بۆ Groq نەنێردرێت. لە ڕێکخستنەکان ← زیرەکی دەستکردی ئۆنلاین «دووبارە بپرسە» دابگرە، یان مۆدێلی قسەکردن بێ ئینتەرنێت لەوێ دابەزێنە.';

  @override
  String get capReason_noSpeechOffline =>
      'مۆدێلی قسەکردن بێ ئینتەرنێت دانەبەزێنراوە. لە ڕێکخستنەکان ← زیرەکی دەستکردی ئۆنلاین دایبەزێنە.';

  @override
  String get capReason_sttFailed => 'نەمتوانی تۆمارەکە بکەمە دەق. لە سندوقی هاتوو هەڵگیرا.';

  @override
  String get capReason_empty => 'هیچ نەبیسترا.';

  @override
  String get capReason_lowConfidence => 'دڵنیا نیم مەبەستت چییە. لە سندوقی هاتوو هەڵگیرا.';

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
  String get capMissingFields => 'خانە دیاریکراوەکان پڕبکەوە یان ئەمە بکوژێنەوە';

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
  String get capNothingFound => 'هیچ شتێک بۆ پاشەکەوتکردن نەدۆزرایەوە. دەقەکە دەستکاری بکە و دووبارە بیخوێنەوە.';

  @override
  String get capAlreadyHandled => 'ئەم تۆمارە پێشتر پاشەکەوت یان سڕاوەتەوە.';

  @override
  String get capDone => 'پاشەکەوت کرا';

  @override
  String get capInbox => 'سندوقی هاتوو';

  @override
  String get capInboxEmpty => 'هیچ شتێک چاوەڕێ نییە. هەر شتێک بڵێیت یان بینووسیت و پاشەکەوتی نەکەیت دێتە ئێرە.';

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
  String get capDiscardBody => 'دەق و دەنگەکەی دەسڕێتەوە. هیچ شتێکی پاشەکەوتکراو لێی ناگۆڕێت.';

  @override
  String capWillBecomeTask(int phase) {
    return 'دەبێتە ئەرک لە قۆناغی $phase';
  }

  @override
  String capWillBecomeNote(int phase) {
    return 'دەبێتە تێبینی لە قۆناغی $phase';
  }

  @override
  String get showAmounts => 'پیشاندانی بڕەکان';

  @override
  String get hideAmounts => 'شاردنەوەی بڕەکان';

  @override
  String get lockedTitle => 'داخراوە';

  @override
  String get lockedHint => 'بە ڕووخسار، پەنجەمۆر یان قوفڵی شاشە بیکەرەوە';

  @override
  String get unlockButton => 'کردنەوە';

  @override
  String get noScreenLockTitle => 'مۆبایلەکەت قوفڵی شاشەی نییە';

  @override
  String get noScreenLockBody =>
      'ئەم ئەپە پارە و تێبینییەکانت بە قوفڵی مۆبایلەکەت دەپارێزێت. سەرەتا PIN، شێوە، پەنجەمۆر یان ڕووخسار چالاک بکە.';

  @override
  String get openSecuritySettings => 'ڕێکخستنەکانی ئاسایش بکەرەوە';

  @override
  String get sensitiveLocked => 'ئەم بەشە دووبارە پەنجەمۆر یان ڕووخسار دەخوازێت';

  @override
  String get faceUnlockNote =>
      'ئەگەر ڕووخسار پیشان نەدرا، مۆبایلەکەت ڕێگەی پێ نادات بۆ ئەپەکان؛ پەنجەمۆر و قوفڵی شاشە کار دەکەن.';

  @override
  String get lockSection => 'قوفڵ';

  @override
  String lockAfterSeconds(int seconds) {
    return 'دوای $seconds چرکە';
  }

  @override
  String get delete => 'سڕینەوە';

  @override
  String finDeletedMany(int count) {
    return '$count مامەڵە سڕایەوە';
  }

  @override
  String selectedCount(int count) {
    return '$count هەڵبژێردراو';
  }

  @override
  String chatExpense(String amount, String category, String account) {
    return '$amount وەک خەرجی «$category» لە «$account» تۆمار دەکەم.';
  }

  @override
  String chatIncome(String amount, String category, String account) {
    return '$amount وەک داهاتی «$category» بۆ «$account» تۆمار دەکەم.';
  }

  @override
  String chatTransfer(String amount, String from, String to) {
    return '$amount لە «$from» بۆ «$to» دەگوازمەوە.';
  }

  @override
  String chatDebtOwedToMe(String who, String amount) {
    return 'تۆمار دەکەم کە $who $amountی قەرزارە بۆت.';
  }

  @override
  String chatDebtOwedByMe(String who, String amount) {
    return 'تۆمار دەکەم کە تۆ $amount قەرزاری $whoیت.';
  }

  @override
  String chatDebtRepay(String who, String amount) {
    return 'دانەوەی $amount لەگەڵ $who تۆمار دەکەم.';
  }

  @override
  String chatLater(String text) {
    return '«$text» — لە هاتووەکان هەڵیدەگرم تا ئەو بەشە ئامادە دەبێت.';
  }

  @override
  String get chatNoCategory => 'بێ پۆل';

  @override
  String get chatConfirm => 'باشە؟';

  @override
  String get chatSaved => 'پاشەکەوت کرا.';

  @override
  String get chatDroppedAll => 'باشە، هیچ تۆمار نەکرا.';

  @override
  String get chatUndone => 'گەڕێندرایەوە. ئێستا هیچ لەو نامەیە پاشەکەوت نییە.';

  @override
  String get chatNotUnderstood => 'تێنەگەیشتم. لە هاتووەکان هەڵمگرت تا بگەڕێیتەوە بۆی.';

  @override
  String get chatAskAmount => 'چەندە؟';

  @override
  String get chatAskAccount => 'لە کام هەژمار؟';

  @override
  String get chatAskToAccount => 'بۆ کام هەژمار؟';

  @override
  String get chatAskCounterparty => 'لەگەڵ کێ؟';

  @override
  String get chatAskDirection => 'ئەو قەرزارتە یان تۆ قەرزاری ئەویت؟';

  @override
  String get chatAskLeg => 'ئەمە قەرزێکی نوێیە یان دانەوە؟';

  @override
  String get chatOwedToMe => 'ئەو قەرزارمە';

  @override
  String get chatOwedByMe => 'من قەرزاریم';

  @override
  String get chatNewDebt => 'قەرزی نوێ';

  @override
  String get chatRepayment => 'دانەوە';

  @override
  String get chatHandedToForm => 'لە فۆرمی تەواودا کرایەوە.';

  @override
  String get chatOk => 'باشە';

  @override
  String get chatEdit => 'دەستکاری';

  @override
  String get chatDrop => 'نەخێر';

  @override
  String get navProjects => 'پڕۆژەکان';

  @override
  String get composerHint => 'هەرچی بنووسە… خەرجی، ئەرک، بیرۆکە';

  @override
  String get composerSend => 'ناردن';

  @override
  String get composerMic => 'پەنجە دابگرە بۆ قسەکردن، یان جارێک بۆ دەستپێک و جارێک بۆ وەستان';

  @override
  String get chatTitle => 'یاریدەدەر';

  @override
  String get chatUndo => 'گەڕاندنەوە';

  @override
  String chatVoiceKept(String reason) {
    return 'دەنگەکەتم لە هاتووەکان هەڵگرت. $reason';
  }

  @override
  String get chatEmpty => 'بە قسەی خۆت بڵێ چی ڕوویدا. پێش پاشەکەوتکردن پیشانت دەدەم چیم تێگەیشت.';

  @override
  String get chatStateSaved => 'پاشەکەوت کرا';

  @override
  String get chatStateDropped => 'پاشەکەوت نەکرا';

  @override
  String get chatStateUndone => 'گەڕێندرایەوە';

  @override
  String get chatStateEdited => 'لە فۆرم کرایەوە';
}
