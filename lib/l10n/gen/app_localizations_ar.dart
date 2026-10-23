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
      'بياناتك تبقى على هذا التلفون. بس إذا شغّلت الذكاء الاصطناعي عبر الإنترنت ووافقت، ينرسل صوت أو نص التسجيل إلى Groq. الخزنة ما تطلع من التلفون أبداً.';

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
  String get passwordStrengthWeak =>
      'ضعيفة: اجعلها أطول، أو امزج حروفاً وأرقاماً ورموزاً';

  @override
  String get passwordStrengthFair => 'متوسطة';

  @override
  String get passwordStrengthStrong => 'قوية';

  @override
  String get backupPasswordHint =>
      'ستحتاج كلمة المرور هذه عند الاسترجاع. إذا نسيتها فلا يمكن استعادتها. مفتاح Groq المحفوظ يُحفظ أيضاً داخل النسخة المشفّرة.';

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

  @override
  String get impTitle => 'استيراد';

  @override
  String get impEntry => 'استيراد ملف';

  @override
  String get impStepFile => 'اختار الملف';

  @override
  String get impStepColumns => 'الأعمدة';

  @override
  String get impStepDefaults => 'الافتراضي';

  @override
  String get impStepValues => 'طابق القيم';

  @override
  String get impStepPreview => 'راجع واستورد';

  @override
  String get impStepOpening => 'الأرصدة اليوم';

  @override
  String impStepOf(int n, int total) {
    return 'الخطوة $n من $total';
  }

  @override
  String get impPickHint =>
      'ملف ‎.xlsx‎ أو ‎.csv‎ من البنك أو من جدول قديم. ما ينحفظ شي لحد ما تدوس استيراد.';

  @override
  String get impPick => 'اختار ملف';

  @override
  String get impPickAnother => 'اختار ملف ثاني';

  @override
  String get impTooLarge => 'الملف كلش كبير: أكثر من 50,000 سطر أو 64 عمود.';

  @override
  String get impUnreadable => 'ما گدرنا نقرا الملف كـ ‎.xlsx‎ أو ‎.csv‎.';

  @override
  String get impSheet => 'الورقة';

  @override
  String get impHeaderRow => 'يا سطر بيه أسماء الأعمدة؟';

  @override
  String impRowN(int n) {
    return 'السطر $n';
  }

  @override
  String get impColDate => 'التاريخ';

  @override
  String get impDateOrder => 'ترتيب التاريخ';

  @override
  String get impDayFirst => 'اليوم أول (31/12)';

  @override
  String get impMonthFirst => 'الشهر أول (12/31)';

  @override
  String get impYearFirst => 'السنة أول (2025-12-31)';

  @override
  String get impAmountMode => 'شلون مكتوبة المبالغ';

  @override
  String get impSigned => 'عمود واحد، السالب مصروف';

  @override
  String get impTypeColumn => 'عمود واحد ويّا عمود للنوع';

  @override
  String get impSplit => 'عمود للوارد وعمود للصادر';

  @override
  String get impColAmount => 'المبلغ';

  @override
  String get impColIncome => 'عمود الوارد';

  @override
  String get impColExpense => 'عمود الصادر';

  @override
  String get impColType => 'النوع';

  @override
  String get impColCurrency => 'العملة';

  @override
  String get impColCategory => 'الفئة';

  @override
  String get impColWorkspace => 'مساحة العمل';

  @override
  String get impColAccount => 'الحساب';

  @override
  String get impColDescription => 'الوصف';

  @override
  String get impNone => 'مو موجود بالملف';

  @override
  String impColumnLetter(String letter) {
    return 'العمود $letter';
  }

  @override
  String get impNeedDateAmount => 'اختار عمود التاريخ والمبلغ حتى تكمل.';

  @override
  String get impDefaultsHint => 'تنستخدم للأسطر اللي ما بيها هالمعلومة.';

  @override
  String get impNoValues =>
      'ماكو شي للمطابقة: الملف ما بيه عمود نوع أو فئة أو مساحة أو حساب.';

  @override
  String get impCreateNew => 'سوّي جديد';

  @override
  String get impSkipRow => 'تجاهل هالأسطر';

  @override
  String get impLeaveEmpty => 'خليها فارغة';

  @override
  String get impUseDefault => 'استخدم الافتراضي';

  @override
  String get impReady => 'جاهزة';

  @override
  String get impDuplicates => 'موجودة أصلاً';

  @override
  String get impProblems => 'ما انقرت';

  @override
  String get impSkipDuplicates => 'تجاهل الأسطر الموجودة أصلاً';

  @override
  String get impProblemDate => 'ماكو تاريخ';

  @override
  String get impProblemAmount => 'ماكو مبلغ';

  @override
  String get impProblemType => 'نوع مو معروف';

  @override
  String get impProblemAccount => 'ماكو حساب';

  @override
  String get impDuplicateTag => 'موجودة';

  @override
  String impFirstRows(int count) {
    return 'أول $count أسطر';
  }

  @override
  String impImport(int count) {
    return 'استورد $count سطر';
  }

  @override
  String impImported(int count) {
    return 'انستوردت $count سطر';
  }

  @override
  String get impOpeningHint =>
      'اكتب شگد بكل حساب فعلاً اليوم. الفرق ينحفظ كتسوية.';

  @override
  String impComputed(String amount) {
    return 'بالتطبيق: $amount';
  }

  @override
  String get impActual => 'الفعلي اليوم';

  @override
  String get impSaveBalances => 'احفظ الأرصدة';

  @override
  String get impDone => 'خلصت';

  @override
  String get impNext => 'التالي';

  @override
  String get impBack => 'رجوع';

  @override
  String get impPastImports => 'الاستيرادات السابقة';

  @override
  String get impUndo => 'تراجع';

  @override
  String impUndoConfirm(int count, String name) {
    return 'تحذف الـ $count سطر اللي انستوردت من $name؟';
  }

  @override
  String get impUndone => 'انلغى';

  @override
  String impBatchLine(int count, String date) {
    return '$count سطر · $date';
  }

  @override
  String get setAi => 'الذكاء الاصطناعي عبر الإنترنت';

  @override
  String get setAiHint => 'مفتاح Groq، النماذج، وشنو ينرسل';

  @override
  String get aiOnline => 'استخدم الذكاء الاصطناعي عبر الإنترنت';

  @override
  String get aiOnlineHint =>
      'إذا طفيته، كلشي يتفهم على التلفون، بدقة أقل شوية.';

  @override
  String get aiKey => 'مفتاح Groq API';

  @override
  String get aiKeyHint =>
      'مجاني من console.groq.com. ينحفظ مشفّر على هذا التلفون بس.';

  @override
  String aiKeySaved(String last4) {
    return 'المفتاح المحفوظ ••••$last4';
  }

  @override
  String get aiKeyRemove => 'احذف';

  @override
  String get aiKeyPaste => 'لصق';

  @override
  String get aiKeySave => 'احفظ المفتاح';

  @override
  String get aiTest => 'جرّب المفتاح';

  @override
  String get aiTestOk => 'المفتاح يشتغل.';

  @override
  String get aiTestUnauthorized =>
      'Groq رفض هذا المفتاح. تأكد منه واحفظه مرة ثانية.';

  @override
  String get aiTestOffline => 'ما گدرنا نوصل لـ Groq. تأكد من الإنترنت.';

  @override
  String get aiTestBusy => 'Groq مشغول هسه. جرّب بعد دقيقة.';

  @override
  String get aiTestOther => 'Groq ما جاوب مثل المتوقع. جرّب بعدين.';

  @override
  String get aiModels => 'النماذج';

  @override
  String get aiSttModel => 'نموذج تحويل الصوت لنص';

  @override
  String get aiLlmModel => 'نموذج الفهم';

  @override
  String get aiModelsSave => 'احفظ النماذج';

  @override
  String get aiModelsSaved => 'انحفظت النماذج';

  @override
  String get aiConsents => 'شنو ينرسل لـ Groq';

  @override
  String get aiConsentVoiceTitle => 'الصوت إلى نص';

  @override
  String get aiConsentParseTitle => 'تعبئة الاستمارة';

  @override
  String get aiConsentVoice => 'تسجيل صوتك ينرسل إلى Groq حتى يتحول لنص.';

  @override
  String get aiConsentParse =>
      'نص الحچيته، وتاريخ ووقت اليوم، وأسماء حساباتك ومساحات العمل والفئات والصناديق تنرسل إلى Groq حتى تتعبى الاستمارة. الأرصدة والمعاملات السابقة والخزنة ما تنرسل أبداً.';

  @override
  String get aiConsentGranted => 'مسموح';

  @override
  String get aiConsentDeclined => 'مو مسموح';

  @override
  String get aiConsentUnset => 'بعد ما انسأل';

  @override
  String get aiConsentReset => 'اسألني مرة ثانية';

  @override
  String get aiOfflineModel => 'نموذج الكلام بدون إنترنت';

  @override
  String get aiOfflineModelHint =>
      'يحوّل الكلام لنص على التلفون إذا الذكاء الاصطناعي طافي أو ما يوصل.';

  @override
  String get consentTitle => 'نرسل هذا إلى Groq؟';

  @override
  String get consentWho => 'شركة Groq تعالجه على سيرفرات بالولايات المتحدة.';

  @override
  String get consentNever =>
      'ما ينرسل أبداً: أرصدتك، معاملاتك السابقة، الرمز، النسخ الاحتياطية أو الخزنة.';

  @override
  String get consentOff =>
      'تگدر تطفيه بأي وقت من الإعدادات ← الذكاء الاصطناعي عبر الإنترنت.';

  @override
  String get consentAllow => 'اسمح';

  @override
  String get consentDecline => 'لا، خلّيه على التلفون';

  @override
  String get aiModelSmall => 'صغير: أدق';

  @override
  String get aiModelBase => 'أساسي: أسرع';

  @override
  String aiModelSize(int mb) {
    return '$mb ميغابايت';
  }

  @override
  String aiModelInstall(int mb) {
    return 'نزّل ($mb ميغابايت)';
  }

  @override
  String get aiModelInstalled => 'منزّل ومفحوص';

  @override
  String get aiModelNotInstalled => 'مو منزّل';

  @override
  String get aiModelDelete => 'احذف';

  @override
  String get aiModelCancel => 'وقّف';

  @override
  String aiModelProgress(int percent) {
    return 'دا ينزل… $percent٪';
  }

  @override
  String get aiModelVerifying => 'دا نفحص الملف…';

  @override
  String get aiModelFailed =>
      'التنزيل توقف. جرّب مرة ثانية، والأحسن على الواي فاي.';

  @override
  String get aiModelMismatch => 'الملف ما طابق وانحذف. جرّب مرة ثانية.';

  @override
  String get aiModelSorani =>
      'بدون إنترنت، الكردي (السوراني) يتعرّف بدقة أقل من العربي والإنگليزي.';

  @override
  String get capMicTooltip => 'سجّل بصوتك (اضغط مطوّلاً للكتابة)';

  @override
  String get capListening => 'دا أسمعك…';

  @override
  String get capCapHint => 'لحد دقيقتين';

  @override
  String get capStop => 'خلصت';

  @override
  String get capProcessing => 'دا أفهم شنو گلت…';

  @override
  String get capMicDenied => 'المايك مو مسموح. اسمح بيه من إعدادات أندرويد.';

  @override
  String get capTypeHint => 'اكتب شنو صار';

  @override
  String get capSend => 'إرسال';

  @override
  String get capManual => 'أو أضف يدوياً';

  @override
  String get capNote => 'ملاحظة';

  @override
  String get capVaultItem => 'عنصر بالخزنة';

  @override
  String get capSavedToInbox => 'انحفظ بالوارد';

  @override
  String get capOpen => 'افتح';

  @override
  String get capReason_noSpeechEngine => 'بعد ما تحوّل لنص.';

  @override
  String get capReason_noSpeechOnlineOff =>
      'الذكاء الاصطناعي عبر الإنترنت مطفي وماكو نموذج كلام بدون إنترنت. شغّله أو نزّل النموذج من الإعدادات ← الذكاء الاصطناعي عبر الإنترنت.';

  @override
  String get capReason_noSpeechNoKey =>
      'ماكو مفتاح Groq محفوظ. ضيفه من الإعدادات ← الذكاء الاصطناعي عبر الإنترنت، أو نزّل نموذج الكلام بدون إنترنت من نفس المكان.';

  @override
  String get capReason_noSpeechNotAsked =>
      'بعد ما سمحت يروح الصوت لـ Groq. اضغط المايك واختار «اسمح»، أو نزّل نموذج الكلام بدون إنترنت من الإعدادات ← الذكاء الاصطناعي عبر الإنترنت.';

  @override
  String get capReason_noSpeechDeclined =>
      'اخترت ما ترسل الصوت لـ Groq. اضغط «اسألني مرة ثانية» بالإعدادات ← الذكاء الاصطناعي عبر الإنترنت، أو نزّل نموذج الكلام بدون إنترنت من نفس المكان.';

  @override
  String get capReason_noSpeechOffline =>
      'ماكو نموذج كلام بدون إنترنت. نزّله من الإعدادات ← الذكاء الاصطناعي عبر الإنترنت.';

  @override
  String get capReason_sttFailed => 'ما گدرت أحوّل التسجيل لنص. انحفظ بالوارد.';

  @override
  String get capReason_empty => 'ما انسمع شي.';

  @override
  String get capReason_lowConfidence => 'ما متأكد شنو قصدك. انحفظ بالوارد.';

  @override
  String get capReviewTitle => 'مراجعة';

  @override
  String get capTranscript => 'اللي گلته';

  @override
  String get capParseAgain => 'اقرأه مرة ثانية';

  @override
  String get capByAi => 'عبّاه الذكاء الاصطناعي';

  @override
  String get capByRules => 'انعبّى على الموبايل بدون إنترنت';

  @override
  String get capKeepCard => 'احفظ هذا';

  @override
  String get capCheckThis => 'تأكد من هذا';

  @override
  String get capMissingFields => 'عبّي الحقول المؤشّرة أو طفّي هذا';

  @override
  String get capKeepInInbox => 'خلّيه بالوارد';

  @override
  String capInboxUntil(int phase) {
    return 'يبقى بالوارد لحد المرحلة $phase';
  }

  @override
  String get capDebt => 'دين';

  @override
  String get capNewDebt => 'دين جديد';

  @override
  String get capWhichDebt => 'أي دين';

  @override
  String get capDrop => 'منشال';

  @override
  String get capNothingFound => 'ما لگيت شي ينحفظ. عدّل النص واقرأه مرة ثانية.';

  @override
  String get capAlreadyHandled =>
      'تمت معالجة هذا الإدخال سابقاً (حُفظ أو حُذف).';

  @override
  String get capDone => 'انحفظ';

  @override
  String get capInbox => 'الوارد';

  @override
  String get capInboxEmpty =>
      'ماكو شي ينتظر. أي شي تگوله أو تكتبه وما تحفظه يجي هنا.';

  @override
  String get capNotTranscribed => 'تسجيل صوتي، بعده ما تحوّل لنص';

  @override
  String get capTranscribe => 'حوّله لنص';

  @override
  String get capFinishAi => 'كمّله بالذكاء الاصطناعي';

  @override
  String get capFinishAllAi => 'كمّل الكل بالذكاء الاصطناعي';

  @override
  String capFinishing(int n, int total) {
    return 'دا أكمّل $n من $total…';
  }

  @override
  String get capOpenReview => 'راجع';

  @override
  String get capDiscard => 'احذف';

  @override
  String get capDiscardTitle => 'تحذف هذا التسجيل؟';

  @override
  String get capDiscardBody => 'ينحذف نصه وتسجيله. أي شي انحفظ منه ما يتغير.';

  @override
  String capWillBecomeTask(int phase) {
    return 'يصير مهمة بالمرحلة $phase';
  }

  @override
  String capWillBecomeNote(int phase) {
    return 'يصير ملاحظة بالمرحلة $phase';
  }

  @override
  String get showAmounts => 'إظهار المبالغ';

  @override
  String get hideAmounts => 'إخفاء المبالغ';

  @override
  String get lockedTitle => 'التطبيق مقفول';

  @override
  String get lockedHint => 'افتح بالوجه أو البصمة أو رمز الموبايل';

  @override
  String get unlockButton => 'افتح';

  @override
  String get noScreenLockTitle => 'موبايلك ما بي قفل شاشة';

  @override
  String get noScreenLockBody =>
      'التطبيق يحمي فلوسك وملاحظاتك بقفل موبايلك نفسه. فعّل رمز أو نمط أو بصمة أو بصمة وجه أول شي.';

  @override
  String get openSecuritySettings => 'افتح إعدادات الحماية';

  @override
  String get sensitiveLocked => 'هذا القسم يطلب بصمتك مرة ثانية';

  @override
  String get faceUnlockNote =>
      'إذا بصمة الوجه ما تطلع، فموبايلك ما يسمح بيها للتطبيقات. البصمة ورمز الموبايل يشتغلون.';

  @override
  String get lockSection => 'القفل';

  @override
  String lockAfterSeconds(int seconds) {
    return 'بعد $seconds ثانية';
  }

  @override
  String get delete => 'حذف';

  @override
  String finDeletedMany(int count) {
    return 'انحذفت $count معاملات';
  }

  @override
  String selectedCount(int count) {
    return '$count مختارة';
  }

  @override
  String chatExpense(String amount, String category, String account) {
    return 'أسجّل $amount مصروف «$category» من «$account».';
  }

  @override
  String chatIncome(String amount, String category, String account) {
    return 'أسجّل $amount مدخول «$category» على «$account».';
  }

  @override
  String chatTransfer(String amount, String from, String to) {
    return 'أحوّل $amount من «$from» إلى «$to».';
  }

  @override
  String chatDebtOwedToMe(String who, String amount) {
    return 'أسجّل إن $who مطلوبلك $amount.';
  }

  @override
  String chatDebtOwedByMe(String who, String amount) {
    return 'أسجّل إنك مطلوب لـ $who $amount.';
  }

  @override
  String chatDebtRepay(String who, String amount) {
    return 'أسجّل تسديد $amount ويا $who.';
  }

  @override
  String chatLater(String text) {
    return '«$text» — أحفظها بالوارد لحد ما يجهز هذا القسم.';
  }

  @override
  String get chatNoCategory => 'بدون فئة';

  @override
  String get chatConfirm => 'تمام؟';

  @override
  String get chatSaved => 'تم الحفظ.';

  @override
  String get chatDroppedAll => 'تمام، ما سجلت شي.';

  @override
  String get chatUndone => 'رجعتها. هسه ماكو شي محفوظ من ذيك الرسالة.';

  @override
  String get chatNotUnderstood => 'ما فهمت قصدك. حفظتها بالوارد حتى ترجعلها.';

  @override
  String get chatAskAmount => 'شكد المبلغ؟';

  @override
  String get chatAskAccount => 'من أي حساب؟';

  @override
  String get chatAskToAccount => 'لأي حساب؟';

  @override
  String get chatAskCounterparty => 'منو الشخص؟';

  @override
  String get chatAskDirection => 'هو مطلوبلك، لو إنت مطلوب إله؟';

  @override
  String get chatAskLeg => 'هذا دين جديد لو تسديد؟';

  @override
  String get chatOwedToMe => 'هو مطلوبلي';

  @override
  String get chatOwedByMe => 'آني مطلوب إله';

  @override
  String get chatNewDebt => 'دين جديد';

  @override
  String get chatRepayment => 'تسديد';

  @override
  String get chatHandedToForm => 'فتحتها بالفورم الكامل.';

  @override
  String get chatOk => 'تمام';

  @override
  String get chatEdit => 'عدّل';

  @override
  String get chatDrop => 'لا';

  @override
  String get navProjects => 'المشاريع';

  @override
  String get composerHint => 'اكتب أي شي… صرفية، مهمة، فكرة';

  @override
  String get composerSend => 'إرسال';

  @override
  String get composerMic => 'دوس وطوّل حتى تحچي، أو دوس مرة للبدء ومرة للإيقاف';

  @override
  String get chatTitle => 'المساعد';

  @override
  String get chatUndo => 'تراجع';

  @override
  String chatVoiceKept(String reason) {
    return 'حفظت التسجيل بالوارد. $reason';
  }

  @override
  String get chatEmpty =>
      'گلّي شنو صار بكلامك. راح أراويك شنو فهمت قبل ما أحفظ أي شي.';

  @override
  String get chatStateSaved => 'انحفظت';

  @override
  String get chatStateDropped => 'ما انحفظت';

  @override
  String get chatStateUndone => 'انلغت';

  @override
  String get chatStateEdited => 'انفتحت بالفورم';

  @override
  String chatDeleteEntry(String entry) {
    return 'أحذف «$entry».';
  }

  @override
  String chatEditAmount(String entry, String amount) {
    return 'أغيّر مبلغ «$entry» إلى $amount.';
  }

  @override
  String chatEditCategory(String entry, String category) {
    return 'أنقل «$entry» إلى «$category».';
  }

  @override
  String chatEditDescription(String entry, String text) {
    return 'أغيّر وصف «$entry» إلى «$text».';
  }

  @override
  String chatEntryLabel(String what, String date) {
    return '$what بتاريخ $date';
  }

  @override
  String get chatNoEntry => 'ما لگيت هذا القيد. افتح المالية واختاره بنفسك.';

  @override
  String get chatAskNewAmount => 'شكد يصير المبلغ الجديد؟';

  @override
  String get tipAllClear => 'كلشي تمام اليوم. اكتب أي شي فوك وآني أرتبه.';

  @override
  String tipBudgetNear(String name) {
    return 'ميزانية «$name» قربت تخلص هذا الشهر.';
  }

  @override
  String get tipEmergencyLow =>
      'صندوق الطوارئ أقل من هدفه. حتى مبلغ صغير يفيد.';

  @override
  String tipOverdue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'عندك $count مهام متأخرة.',
      one: 'عندك مهمة متأخرة.',
    );
    return '$_temp0';
  }

  @override
  String tipProjectStepSoon(String step, String project) {
    return 'خطوة «$step» بمشروع «$project» موعدها هذا الأسبوع.';
  }

  @override
  String get homeGreeting => 'شنو ببالك؟';

  @override
  String get homeToday => 'اليوم';

  @override
  String get homeTodayEmpty => 'ماكو شي مطلوب اليوم.';

  @override
  String get homeRecent => 'آخر القيود';

  @override
  String get homeRecentEmpty => 'بعد ما مسجل شي.';

  @override
  String get homeProjects => 'المشاريع الفعالة';

  @override
  String get homeProjectsEmpty =>
      'ماكو مشاريع بعد. احچيلي عن مشروع وأساعدك تخطط إله.';

  @override
  String get homeIncome => 'دخل';

  @override
  String get homeExpense => 'صرف';

  @override
  String get setupAccountTitle => 'أول حساب إلك';

  @override
  String get setupAccountBody =>
      'وين فلوسك؟ جزدان، مصرف، كارت. تگدر تضيف غيره بعدين، أو بس گول للمساعد.';

  @override
  String get setupAccountName => 'اسم الحساب';

  @override
  String get setupAccountHint => 'مثلاً: جزدان كاش';

  @override
  String get setupAccountCurrency => 'العملة';

  @override
  String chatAskCreateCategory(String name) {
    return 'ماكو فئة «$name» بعد. أسوي فئة جديدة؟';
  }

  @override
  String get chatAskCreateAccount => 'بعد ما عندك حساب. أول حساب بأي عملة؟';

  @override
  String chatDefaultAccountName(String currency) {
    return 'كاش $currency';
  }

  @override
  String get chatYesCreate => 'إي، سوّيها';

  @override
  String get chatNoThanks => 'لا، خليها';

  @override
  String chatAskRate(String currency) {
    return 'شكد سعر $currency اليوم؟ (بالدينار لـ 1 $currency أو لـ 100)';
  }

  @override
  String finRateToday(String currency) {
    return 'سعر 1 $currency اليوم';
  }

  @override
  String get finRateSave => 'احفظ السعر';
}
