import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/db/finance_seed.dart';

void main() {
  test('every seeded category has default keywords in Arabic and English', () {
    for (final key in [...kExpenseCategoryKeys, ...kIncomeCategoryKeys]) {
      final words = kDefaultCategoryKeywords[key];
      expect(words, isNotNull, reason: key);
      expect(words!.any((w) => RegExp('[؀-ۿ]').hasMatch(w)), isTrue, reason: key);
      expect(words.any((w) => RegExp('[a-z]').hasMatch(w)), isTrue, reason: key);
    }
  });

  test('seed category keys are in spec order', () {
    expect(kExpenseCategoryKeys, [
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
    ]);
    expect(kIncomeCategoryKeys, ['salary', 'business_income', 'freelance', 'client_payment', 'other_income']);
  });
}
