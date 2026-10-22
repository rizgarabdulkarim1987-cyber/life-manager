// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'مدير حياتي';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navFinance => 'المالية';

  @override
  String get navTasks => 'المهام';

  @override
  String get navVault => 'الخزنة';

  @override
  String get settings => 'الإعدادات';

  @override
  String get language => 'اللغة';

  @override
  String get theme => 'المظهر';

  @override
  String get themeDark => 'داكن';

  @override
  String get themeLight => 'فاتح';

  @override
  String get appLock => 'قفل التطبيق';

  @override
  String get biometrics => 'الفتح بالبصمة';

  @override
  String get biometricsUnavailable =>
      'لا توجد بصمة أو فتح بالوجه مفعّل على هذا الهاتف';

  @override
  String get changePin => 'تغيير رمز PIN';

  @override
  String get currentPin => 'الرمز الحالي';

  @override
  String get newPin => 'الرمز الجديد';

  @override
  String get pinChanged => 'تم تغيير الرمز';

  @override
  String get lockTimeout => 'القفل بعد الخروج من التطبيق';

  @override
  String get lockImmediately => 'فوراً';

  @override
  String lockAfterMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'بعد $minutes دقيقة',
      few: 'بعد $minutes دقائق',
      two: 'بعد دقيقتين',
      one: 'بعد دقيقة',
    );
    return '$_temp0';
  }

  @override
  String get backupRestore => 'النسخ الاحتياطي والاسترجاع';

  @override
  String lastBackup(String date) {
    return 'آخر نسخة: $date';
  }

  @override
  String get neverBackedUp => 'لم تُنشأ أي نسخة احتياطية بعد';

  @override
  String get createBackup => 'إنشاء نسخة احتياطية';

  @override
  String get restoreBackup => 'الاسترجاع من نسخة احتياطية';

  @override
  String get backupPassword => 'كلمة مرور النسخة';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get passwordTooShort => 'استخدم 8 أحرف على الأقل';

  @override
  String get passwordsDontMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get backupWarning =>
      'بياناتك موجودة على هذا الهاتف فقط. إذا ضاع الهاتف أو حذفت التطبيق دون نسخة احتياطية، تضيع كلها. احفظ النسخ في مكان خارج الهاتف.';

  @override
  String get backupCreated => 'تم حفظ النسخة الاحتياطية';

  @override
  String get restoreConfirmTitle => 'استبدال كل البيانات الحالية؟';

  @override
  String restoreConfirmBody(String date, String version) {
    return 'نسخة بتاريخ $date، من إصدار $version. كل ما في التطبيق الآن سيُستبدل بها.';
  }

  @override
  String get replace => 'استبدال';

  @override
  String get cancel => 'إلغاء';

  @override
  String get enterPin => 'أدخل رمز PIN';

  @override
  String get wrongPin => 'الرمز غير صحيح';

  @override
  String attemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بقيت $count محاولة قبل الإيقاف المؤقت',
      few: 'بقيت $count محاولات قبل الإيقاف المؤقت',
      two: 'بقيت محاولتان قبل الإيقاف المؤقت',
      one: 'بقيت محاولة واحدة قبل الإيقاف المؤقت',
    );
    return '$_temp0';
  }

  @override
  String tryAgainIn(String time) {
    return 'محاولات كثيرة. حاول مجدداً بعد $time';
  }

  @override
  String get unlockReason => 'افتح مدير حياتي';

  @override
  String get useFingerprint => 'استخدم البصمة';

  @override
  String get setupWelcome => 'أهلاً بك';

  @override
  String get setupWelcomeBody => 'كل شيء يبقى على هذا الهاتف، تحت قفلك.';

  @override
  String get setupChooseLanguage => 'اختر لغتك';

  @override
  String get setupCreatePin => 'أنشئ رمز PIN من 6 أرقام';

  @override
  String get setupConfirmPin => 'أدخل الرمز مرة أخرى';

  @override
  String get pinMismatch => 'الرمزان غير متطابقين. ابدأ من جديد.';

  @override
  String get setupEnableBiometrics => 'تفعيل الفتح بالبصمة أيضاً؟';

  @override
  String get setupEnableBiometricsBody => 'رمز PIN يعمل دائماً كبديل.';

  @override
  String get enable => 'تفعيل';

  @override
  String get setupBackupWarning => 'أمر مهم واحد';

  @override
  String get iUnderstand => 'فهمت';

  @override
  String get continueLabel => 'متابعة';

  @override
  String get skip => 'تخطٍّ';

  @override
  String get finish => 'ابدأ';

  @override
  String comingInPhase(int phase) {
    return 'يأتي في المرحلة $phase';
  }

  @override
  String get seedPersonal => 'شخصي';

  @override
  String get seedBuzzify => 'Buzzify';

  @override
  String get seedEo => 'Related / EO';

  @override
  String get seedOtherProjects => 'مشاريع أخرى';

  @override
  String get seedCashIqd => 'كاش دينار';

  @override
  String get seedCashUsd => 'كاش دولار';

  @override
  String get accounts => 'الحسابات';

  @override
  String get homeMonthSummary => 'هذا الشهر';

  @override
  String get homeChart => 'الدخل مقابل المصروف';

  @override
  String get homeBuckets => 'الصناديق';

  @override
  String get homeTasks => 'المهام';

  @override
  String get privacy => 'الخصوصية';

  @override
  String get privacyPhase1 =>
      'لا يخرج شيء من هذا الهاتف. التطبيق لا يملك صلاحية الإنترنت بعد.';

  @override
  String get restoreTooNew =>
      'هذه النسخة من إصدار أحدث للتطبيق. حدّث التطبيق أولاً.';

  @override
  String get restoreWrongPassword => 'كلمة المرور خاطئة، أو الملف تالف.';

  @override
  String get restoreCorrupt =>
      'الملف تالف أو ليس نسخة احتياطية من هذا التطبيق.';

  @override
  String get restoreSuccess => 'تم الاسترجاع. جارٍ إعادة التشغيل…';

  @override
  String get micSoon => 'الإدخال الصوتي يأتي في المرحلة 2';

  @override
  String get passwordStrengthWeak =>
      'ضعيفة: اجعلها أطول، أو امزج حروفاً وأرقاماً ورموزاً';

  @override
  String get passwordStrengthFair => 'متوسطة';

  @override
  String get passwordStrengthStrong => 'قوية';

  @override
  String get backupPasswordHint =>
      'ستحتاج كلمة المرور هذه عند الاسترجاع. إذا نسيتها فلا يمكن استعادتها.';

  @override
  String get somethingWentWrong => 'حدث خطأ. حاول مرة أخرى.';

  @override
  String get backupFailed => 'تعذّر إنشاء النسخة الاحتياطية. بياناتك لم تتغير.';

  @override
  String get startupFailed => 'تعذّر فتح بياناتك. لم يُحذف أي شيء.';

  @override
  String get retry => 'حاول مرة أخرى';

  @override
  String get cat_food => 'أكل';

  @override
  String get cat_transport => 'مواصلات';

  @override
  String get cat_rent => 'إيجار';

  @override
  String get cat_bills => 'فواتير';

  @override
  String get cat_family => 'العائلة';

  @override
  String get cat_shopping => 'تسوّق';

  @override
  String get cat_health => 'صحة';

  @override
  String get cat_business => 'شغل';

  @override
  String get cat_marketing => 'تسويق';

  @override
  String get cat_subscriptions => 'اشتراكات';

  @override
  String get cat_other_expense => 'مصروف آخر';

  @override
  String get cat_salary => 'راتب';

  @override
  String get cat_business_income => 'دخل الشغل';

  @override
  String get cat_freelance => 'عمل حر';

  @override
  String get cat_client_payment => 'دفعة عميل';

  @override
  String get cat_other_income => 'دخل آخر';

  @override
  String get bucket_expenses => 'المصاريف';

  @override
  String get bucket_emergency => 'الطوارئ';

  @override
  String get bucket_investment => 'الاستثمار';

  @override
  String get finIncome => 'الدخل';

  @override
  String get finExpense => 'المصاريف';

  @override
  String get finSurplus => 'الفائض';

  @override
  String get finAllAccounts => 'كل الحسابات';

  @override
  String get finHowConvertedHint => 'اضغط حتى تشوف شلون انحسب';

  @override
  String finNoTotal(String currencies) {
    return 'ماكو سعر صرف لـ $currencies، فما نكدر نطلع مجموع واحد';
  }

  @override
  String get finSetRate => 'حدد سعر الصرف';

  @override
  String get finRateTitle => 'سعر الصرف';

  @override
  String get finRateLabel => 'الدولار الواحد بالدينار';

  @override
  String get finRateInvalid => 'اكتب سعر مثل 1310';

  @override
  String get save => 'حفظ';

  @override
  String get finHowConverted => 'شلون انحسب';

  @override
  String get finSameCurrency => 'نفس العملة';

  @override
  String get finNoRate => 'ماكو سعر';

  @override
  String finRateLine(String base, String rate, String quote, String date) {
    return '1 $base = $rate $quote · من $date';
  }

  @override
  String get finPerCurrency => 'حسب العملة';

  @override
  String get finTotal => 'المجموع';

  @override
  String alertExpensesBucket(int percent) {
    return 'سطل المصاريف وصل $percent% هذا الشهر';
  }

  @override
  String get alertEmergencyReached => 'صندوق الطوارئ وصل الهدف';

  @override
  String get alertEmergencyBelow => 'صندوق الطوارئ نازل عن الهدف';

  @override
  String alertUnallocated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دخل ما متوزعة على السطول',
      one: 'دخل واحد ما متوزع على السطول',
    );
    return '$_temp0';
  }

  @override
  String alertBudget(String name, int percent) {
    return 'ميزانية $name وصلت $percent%';
  }

  @override
  String alertDebtSoon(String name, String date) {
    return '$name: الدفعة مستحقة $date';
  }

  @override
  String alertDebtOverdue(String name) {
    return '$name: الدفعة متأخرة';
  }

  @override
  String get finHistory => 'السجل';

  @override
  String get finAddAccount => 'إضافة حساب';

  @override
  String get finAccountName => 'الاسم';

  @override
  String get finNameRequired => 'اكتب اسم';

  @override
  String get finWorkspace => 'مساحة العمل';

  @override
  String get finCurrency => 'العملة';

  @override
  String get finKind => 'النوع';

  @override
  String get kindCash => 'كاش';

  @override
  String get kindBank => 'بنك';

  @override
  String get kindSavings => 'توفير';

  @override
  String get kindCustom => 'غيره';

  @override
  String get rename => 'تغيير الاسم';

  @override
  String get archive => 'أرشفة';

  @override
  String finArchiveAccount(String name) {
    return 'تأرشف $name؟ السجل مالته يبقى.';
  }

  @override
  String get finBalance => 'الرصيد';

  @override
  String get finAdjustBalance => 'تعديل الرصيد';

  @override
  String get finAdjustHint =>
      'اكتب المبلغ الموجود فعلاً بالحساب. الفرق ينحفظ كتعديل.';

  @override
  String get finActualAmount => 'المبلغ الفعلي';

  @override
  String get finAmountInvalid => 'اكتب مبلغ مثل 25000';

  @override
  String get finSearch => 'دوّر بالوصف';

  @override
  String get filterAll => 'الكل';

  @override
  String get filterDates => 'التاريخ';

  @override
  String get filterAccount => 'الحساب';

  @override
  String get filterCategory => 'الفئة';

  @override
  String get filterType => 'النوع';

  @override
  String get clearFilters => 'امسح الفلاتر';

  @override
  String get typeIncome => 'دخل';

  @override
  String get typeExpense => 'مصروف';

  @override
  String get typeRefund => 'استرجاع';

  @override
  String get typeAdjustment => 'تعديل';

  @override
  String get typeTransfer => 'تحويل';

  @override
  String get typeOwnerDraw => 'سحب شخصي';

  @override
  String get typeDebtPayment => 'دفعة دين';

  @override
  String get finPending => 'معلّق';

  @override
  String get finUncategorised => 'بدون فئة';

  @override
  String get finNoTransactions => 'ماكو معاملات بعد';

  @override
  String get finNoMatches => 'ماكو معاملات تطابق الفلاتر';

  @override
  String get finDeleted => 'انحذفت المعاملة';

  @override
  String get undo => 'تراجع';

  @override
  String get finToday => 'اليوم';

  @override
  String get finAddExpense => 'إضافة مصروف';

  @override
  String get finAddIncome => 'إضافة دخل';

  @override
  String get finAddRefund => 'إضافة استرجاع';

  @override
  String get finAddTransfer => 'تحويل';

  @override
  String get finEditTransaction => 'تعديل المعاملة';

  @override
  String get finEditTransfer => 'تعديل التحويل';

  @override
  String get finAmount => 'المبلغ';

  @override
  String finAmountRounded(String currency) {
    return 'تقرّب حسب دقة $currency';
  }

  @override
  String get finAccount => 'الحساب';

  @override
  String get finChooseAccount => 'اختار حساب';

  @override
  String get finCategory => 'الفئة';

  @override
  String get finNoCategory => 'بدون فئة';

  @override
  String get finDate => 'التاريخ';

  @override
  String get finTime => 'الوقت';

  @override
  String get finDescription => 'الوصف';

  @override
  String get finNotReceived => 'بعد ما استلمته';

  @override
  String get finNotReceivedHint => 'الدخل المعلّق ما ينحسب بالرصيد';

  @override
  String get finAllocate => 'وزّع على السطول';

  @override
  String finAllocateNoRate(String currency) {
    return 'حدد سعر $currency أول حتى توزع هذا الدخل';
  }

  @override
  String get finAllocatePending => 'بس الدخل المستلم يتوزع';

  @override
  String get finUnallocated => 'غير موزع';

  @override
  String get finOverAllocated => 'زايد بمقدار';

  @override
  String get finBucketTag => 'مدفوع من سطل';

  @override
  String get finBucketNone => 'صرف عادي';

  @override
  String get finClearAllocationsTitle => 'تمسح توزيع السطول؟';

  @override
  String get finClearAllocationsBody =>
      'هذا الدخل متوزع على السطول. تغيير المبلغ يمسح التوزيع، وتكدر توزعه مرة ثانية بعدين.';

  @override
  String get finClearAndSave => 'امسح واحفظ';

  @override
  String get finFrom => 'من';

  @override
  String get finTo => 'إلى';

  @override
  String get finToAmount => 'المبلغ المستلم';

  @override
  String finRateField(String quote, String base) {
    return '$quote لكل 1 $base';
  }

  @override
  String get finTwoOfThree => 'اكتب أي اثنين والثالث ينحسب';

  @override
  String get finOwnerDraw => 'سحب شخصي (راتب)';

  @override
  String get finOwnerDrawHint => 'ينحسب مصروف على الشغل ودخل للشخص';

  @override
  String get finSameAccount => 'اختار حسابين مختلفين';

  @override
  String get finSaved => 'انحفظ';

  @override
  String get finBuckets => 'السطول';

  @override
  String get finBudgets => 'الميزانيات';

  @override
  String get finDebts => 'الديون';

  @override
  String get finAvailable => 'المتوفر';

  @override
  String get finAllocated => 'الموزع';

  @override
  String get finSpent => 'المصروف';

  @override
  String get finTarget => 'الهدف';

  @override
  String get finSetTarget => 'حدد الهدف';

  @override
  String get finTargetHint => 'اتركه فارغ إذا ما تريد هدف';

  @override
  String get finEditPercentages => 'تعديل النسب';

  @override
  String get finPercentagesNote =>
      'لازم مجموعها 100%. بس الدخل اللي توزعه بعد الحفظ ياخذ النسب الجديدة.';

  @override
  String finPercentTotal(String percent) {
    return 'المجموع $percent%';
  }

  @override
  String get finBucketsUnconfirmed => 'حدد نسبك قبل ما توزع الدخل على السطول.';

  @override
  String get finExpensesMonthly => 'يتصفر كل شهر';

  @override
  String get finCarriesOver => 'يتراكم';

  @override
  String get finAddBudget => 'إضافة ميزانية';

  @override
  String get finEditBudget => 'تعديل الميزانية';

  @override
  String get finBudgetNeedsScope => 'اختار فئة أو مساحة عمل أو الاثنين';

  @override
  String get finAnyWorkspace => 'كل مساحات العمل';

  @override
  String get finAnyCategory => 'كل الفئات';

  @override
  String get finRemaining => 'الباقي';

  @override
  String finOfBudget(String amount) {
    return 'من $amount';
  }

  @override
  String finMissingRatesNote(String currencies) {
    return 'ما انحسب: $currencies (ماكو سعر بهذيك التواريخ)';
  }

  @override
  String get finNoBudgets => 'ماكو ميزانيات بعد';

  @override
  String get finOwedToMe => 'إلي';

  @override
  String get finOwedByMe => 'علي';

  @override
  String get finAddDebt => 'إضافة دين';

  @override
  String get finCounterparty => 'الشخص أو الجهة';

  @override
  String get finStartDate => 'تاريخ البداية';

  @override
  String get finRecordMoveNow => 'سجّل حركة الفلوس هسه';

  @override
  String get finRecordMoveGiven => 'الفلوس طلعت من هذا الحساب';

  @override
  String get finRecordMoveReceived => 'الفلوس دخلت لهذا الحساب';

  @override
  String get finInstallments => 'الأقساط';

  @override
  String get finInstallmentCount => 'عدد الأقساط الشهرية (اختياري)';

  @override
  String get finFirstDue => 'أول قسط';

  @override
  String finNextDue(String date) {
    return 'القسط الجاي $date';
  }

  @override
  String get finOverdue => 'متأخر';

  @override
  String get finPaid => 'مدفوع';

  @override
  String get finNoDebts => 'ماكو شي';

  @override
  String get finRecordRepayment => 'سجّل تسديد';

  @override
  String finRepaymentTooBig(String amount) {
    return 'لحد $amount';
  }

  @override
  String finWrongCurrency(String currency) {
    return 'اختار حساب بـ $currency';
  }

  @override
  String get finPayments => 'الدفعات';

  @override
  String get finPrincipal => 'أصل الدين';

  @override
  String get finRepayment => 'تسديد';

  @override
  String get finClosed => 'مسدّد';

  @override
  String get finNotes => 'ملاحظات';

  @override
  String get finReports => 'التقارير';

  @override
  String get repRange => 'المدة';

  @override
  String get repThisMonth => 'هالشهر';

  @override
  String get repLastMonth => 'الشهر الماضي';

  @override
  String repLastMonths(int count) {
    return 'آخر $count أشهر';
  }

  @override
  String get repCustom => 'تواريخ أختارها';

  @override
  String get repGroupBy => 'التجميع';

  @override
  String get repDaily => 'يومي';

  @override
  String get repWeekly => 'أسبوعي';

  @override
  String get repMonthly => 'شهري';

  @override
  String get repAllWorkspaces => 'كل مساحات العمل';

  @override
  String get repTabIncomeExpense => 'الدخل والمصاريف';

  @override
  String get repTabCategory => 'حسب الفئة';

  @override
  String get repTabWorkspace => 'حسب مساحة العمل';

  @override
  String get repTabCashFlow => 'حركة الفلوس';

  @override
  String get repTabBalance => 'الرصيد عبر الوقت';

  @override
  String get repTabDebts => 'الديون الباقية';

  @override
  String get repShowTable => 'اعرضها جدول';

  @override
  String get repShowChart => 'اعرضها رسم';

  @override
  String repSkipped(int count, String currencies) {
    return '$count ما انحسبت: ماكو سعر $currencies بتواريخها';
  }

  @override
  String get repMoneyIn => 'الداخل';

  @override
  String get repMoneyOut => 'الطالع';

  @override
  String get repNet => 'الصافي';

  @override
  String get repOther => 'غيرها';

  @override
  String get repPeriodColumn => 'الفترة';

  @override
  String get repBalance => 'الرصيد';

  @override
  String get repNothing => 'ماكو شي بهالمدة';

  @override
  String repBucketsMonth(String month, String currency) {
    return '$month، بعملة $currency';
  }

  @override
  String get repExport => 'تصدير';

  @override
  String get repExportCsv => 'العمليات كملف CSV';

  @override
  String get repExportPdf => 'التقرير كملف PDF';

  @override
  String get repNotEncrypted => 'هالملف مو مشفّر. أي واحد يوصله يگدر يقراه.';

  @override
  String get repExportFailed => 'ما گدرنا نحفظ الملف';

  @override
  String get setFinance => 'المالية';

  @override
  String get setFinanceSettings => 'العملة وأسعار الصرف';

  @override
  String get setFinanceSettingsHint =>
      'العملة الأساسية، سعر الدولار، التنبيهات';

  @override
  String get setCategories => 'الفئات';

  @override
  String get setCategoriesHint => 'الأسماء والكلمات اللي تختارها';

  @override
  String get setWorkspaces => 'مساحات العمل';

  @override
  String get setWorkspacesHint => 'الأسماء، الأسماء الثانية، الصناديق';

  @override
  String get setBaseCurrency => 'العملة الأساسية';

  @override
  String get setBaseCurrencyHint =>
      'المجاميع والصناديق والتقارير تستخدمها إلا إذا اخترت غيرها.';

  @override
  String setRateDate(String date) {
    return 'من $date';
  }

  @override
  String get setRateHistory => 'سجل الأسعار';

  @override
  String get setNoRates =>
      'ماكو سعر بعد. الدولار والدينار يبقون منفصلين لحد ما تضيف سعر.';

  @override
  String get setRateSaved => 'انحفظ السعر';

  @override
  String get setAlerts => 'التنبيهات';

  @override
  String get setUnallocatedAlert => 'ذكّرني بالدخل اللي ما توزّع على الصناديق';

  @override
  String get setUnallocatedAlertHint => 'يطلع بشاشة المالية';

  @override
  String get setIncomeCategories => 'الدخل';

  @override
  String get setExpenseCategories => 'المصاريف';

  @override
  String get setAddCategory => 'أضف فئة';

  @override
  String get setEditCategory => 'عدّل الفئة';

  @override
  String get setKeywords => 'الكلمات اللي تختار هالفئة';

  @override
  String get setBuiltInWords => 'موجودة أصلاً';

  @override
  String get setYourWords => 'كلماتك';

  @override
  String get setAddWord => 'أضف كلمة';

  @override
  String setRemoveWord(String word) {
    return 'احذف $word';
  }

  @override
  String setArchiveCategory(String name) {
    return 'تأرشف $name؟ العمليات القديمة تبقى عليها.';
  }

  @override
  String get setAddWorkspace => 'أضف مساحة عمل';

  @override
  String get setEditWorkspace => 'عدّل مساحة العمل';

  @override
  String get setIcon => 'الأيقونة';

  @override
  String get setColour => 'اللون';

  @override
  String get setAliases => 'أسماء ثانية تگولها';

  @override
  String get setAliasesHint => 'التسجيل الصوتي والسريع يتعرف عليها هم';

  @override
  String get setAddAlias => 'أضف اسم';

  @override
  String get setCountsInBuckets => 'تنحسب بالصناديق';

  @override
  String get setCountsInBucketsHint => 'مصاريفها تنطلع من صندوق المصاريف';

  @override
  String setArchiveWorkspace(String name) {
    return 'تأرشف $name؟ سجلّها يبقى.';
  }

  @override
  String setArchiveBlocked(String name) {
    return 'أرشف حساباتها أول. $name بعدها بيها حسابات شغالة.';
  }

  @override
  String get setArchived => 'انأرشفت';

  @override
  String get ok => 'تمام';
}
