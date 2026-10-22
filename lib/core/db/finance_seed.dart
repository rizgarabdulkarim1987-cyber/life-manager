import 'package:drift/drift.dart';

import 'app_database.dart';

const kExpenseCategoryKeys = [
  'food',
  'transport',
  'rent',
  'bills',
  'family',
  'shopping',
  'health',
  'business',
  'marketing',
  'subscriptions',
  'other_expense',
];

const kIncomeCategoryKeys = ['salary', 'business_income', 'freelance', 'client_payment', 'other_income'];

const kBucketKeys = ['expenses', 'emergency', 'investment'];

/// Placeholders the owner confirms in the Buckets screen before the first
/// allocation; the app never suggests numbers (spec §10.3).
const _bucketPlaceholderBp = [7000, 2000, 1000];

const _icons = {
  'food': 'restaurant',
  'transport': 'directions_car',
  'rent': 'home',
  'bills': 'receipt',
  'family': 'family',
  'shopping': 'shopping_bag',
  'health': 'health',
  'business': 'work',
  'marketing': 'campaign',
  'subscriptions': 'autorenew',
  'other_expense': 'tag',
  'salary': 'payments',
  'business_income': 'work',
  'freelance': 'laptop',
  'client_payment': 'handshake',
  'other_income': 'tag',
};

const _palette = [0xFF3B82FF, 0xFF8B5CF6, 0xFFF5B544, 0xFF3DDC97, 0xFFFF6B7A, 0xFF22C3E6, 0xFFE879F9, 0xFFA3ADC2];

/// Default keywords per category for the rule parser: Arabic (with Iraqi
/// words), Kurdish Sorani and English. The owner adds more per category.
const Map<String, List<String>> kDefaultCategoryKeywords = {
  'food': [
    'اكل', 'أكل', 'غدا', 'غداء', 'عشا', 'عشاء', 'فطور', 'ريوك', 'مطعم', 'لفة', 'لفه', 'سمون', 'صمون', 'كباب', 'تكة', //
    'شاورما', 'قهوة', 'گهوة', 'جاي', 'چاي', 'خضرة', 'خضار', 'لحم', 'دجاج', 'مسواك', 'خواردن', 'نان', 'چێشتخانە', //
    'food', 'lunch', 'dinner', 'breakfast', 'restaurant', 'coffee', 'groceries',
  ],
  'transport': [
    'تكسي', 'تاكسي', 'بانزين', 'بنزين', 'كروة', 'گروة', 'باص', 'كيا', 'مواصلات', 'تصليح السيارة', 'سيارة', 'كراج', //
    'تاکسی', 'بەنزین', 'ئۆتۆمبێل', 'taxi', 'fuel', 'gas', 'uber', 'careem', 'bus', 'car',
  ],
  'rent': ['ايجار', 'إيجار', 'اجار', 'كرا', 'كراء', 'کرێ', 'rent'],
  'bills': [
    'فاتورة', 'كهرباء', 'كهربا', 'مولدة', 'امبير', 'ماي', 'ماء', 'انترنت', 'نت', 'رصيد', 'كارت', 'غاز', //
    'کارەبا', 'ئینتەرنێت', 'bill', 'electricity', 'generator', 'internet', 'water', 'phone credit',
  ],
  'family': ['عائلة', 'العائلة', 'اهل', 'الأهل', 'امي', 'ابوي', 'الولد', 'الاطفال', 'خێزان', 'family', 'kids'],
  'shopping': ['تسوق', 'ملابس', 'هدوم', 'حذاء', 'قندرة', 'مول', 'سوق', 'بازاڕ', 'جل', 'shopping', 'clothes', 'mall'],
  'health': [
    'دوا',
    'دواء',
    'صيدلية',
    'طبيب',
    'دكتور',
    'مستشفى',
    'تحليل',
    'دەرمان',
    'پزیشک',
    'health',
    'doctor',
    'pharmacy',
    'medicine',
  ],
  'business': ['شغل', 'مكتب', 'معدات', 'كاميرا', 'لابتوب', 'business', 'office', 'equipment'],
  'marketing': [
    'اعلان',
    'إعلان',
    'اعلانات',
    'تمويل',
    'سبونسر',
    'ممول',
    'رسائل',
    'sms',
    'ڕیکلام',
    'ads',
    'marketing',
    'boost',
    'campaign',
  ],
  'subscriptions': ['اشتراك', 'اشتراكات', 'تجديد', 'بەشداریکردن', 'subscription', 'renewal', 'netflix', 'spotify'],
  'other_expense': ['متفرقات', 'غيرها', 'other', 'misc'],
  'salary': ['راتب', 'معاش', 'مووچە', 'salary', 'paycheck'],
  'business_income': ['مبيعات', 'ارباح', 'أرباح', 'قازانج', 'sales', 'profit', 'revenue'],
  'freelance': ['فريلانس', 'مشروع حر', 'شغل حر', 'freelance', 'gig'],
  'client_payment': ['عميل', 'العميل', 'زبون', 'دفعة', 'كلاينت', 'کڕیار', 'client', 'customer', 'invoice'],
  'other_income': ['هدية', 'عيدية', 'دخل', 'دیاری', 'gift', 'income'],
};

/// Seeds the categories and buckets. Idempotent; runs on create, on the v1→v2
/// upgrade, and from [seedInitialData].
Future<void> seedFinanceDefaults(AppDatabase db) async {
  await db.transaction(() async {
    final existing = (await db.select(db.categories).get()).map((c) => c.systemKey).toSet();
    var order = 0;
    for (final (kind, keys) in [('expense', kExpenseCategoryKeys), ('income', kIncomeCategoryKeys)]) {
      for (final key in keys) {
        if (!existing.contains(key)) {
          await db
              .into(db.categories)
              .insert(
                CategoriesCompanion.insert(
                  kind: kind,
                  systemKey: Value(key),
                  iconKey: _icons[key] ?? 'tag',
                  colorArgb: _palette[order % _palette.length],
                  sortOrder: order,
                ),
              );
        }
        order++;
      }
    }
    final buckets = (await db.select(db.buckets).get()).map((b) => b.systemKey).toSet();
    for (var i = 0; i < kBucketKeys.length; i++) {
      if (buckets.contains(kBucketKeys[i])) continue;
      await db
          .into(db.buckets)
          .insert(
            BucketsCompanion.insert(systemKey: Value(kBucketKeys[i]), percentBp: _bucketPlaceholderBp[i], sortOrder: i),
          );
    }
  });
}

/// The seeded Personal workspace is the one whose expenses count in buckets.
Future<void> markPersonalCountsInBuckets(AppDatabase db) =>
    (db.update(db.workspaces)..where((w) => w.sortOrder.equals(0) & w.iconKey.equals('person'))).write(
      const WorkspacesCompanion(countsInBuckets: Value(true)),
    );
