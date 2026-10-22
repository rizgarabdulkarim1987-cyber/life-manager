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
  String get biometricsUnavailable => 'لا توجد بصمة أو فتح بالوجه مفعّل على هذا الهاتف';

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
  String get privacyPhase1 => 'لا يخرج شيء من هذا الهاتف. التطبيق لا يملك صلاحية الإنترنت بعد.';

  @override
  String get restoreTooNew => 'هذه النسخة من إصدار أحدث للتطبيق. حدّث التطبيق أولاً.';

  @override
  String get restoreWrongPassword => 'كلمة المرور خاطئة، أو الملف تالف.';

  @override
  String get restoreCorrupt => 'الملف تالف أو ليس نسخة احتياطية من هذا التطبيق.';

  @override
  String get restoreSuccess => 'تم الاسترجاع. جارٍ إعادة التشغيل…';

  @override
  String get micSoon => 'الإدخال الصوتي يأتي في المرحلة 2';

  @override
  String get passwordStrengthWeak => 'ضعيفة: اجعلها أطول، أو امزج حروفاً وأرقاماً ورموزاً';

  @override
  String get passwordStrengthFair => 'متوسطة';

  @override
  String get passwordStrengthStrong => 'قوية';

  @override
  String get backupPasswordHint => 'ستحتاج كلمة المرور هذه عند الاسترجاع. إذا نسيتها فلا يمكن استعادتها.';
}
