import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/finance/data/categories_repository.dart';
import 'package:life_manager/l10n/gen/app_localizations.dart';

import '../../../helpers/finance_fixtures.dart';

void main() {
  late FinanceFixture f;
  late CategoriesRepository cats;
  setUp(() async {
    f = await financeFixture();
    cats = CategoriesRepository(f.db);
  });
  tearDown(() => f.db.close());

  test('watch by kind', () async {
    expect(await cats.watch(kind: 'expense').first, hasLength(11));
    expect(await cats.watch(kind: 'income').first, hasLength(5));
  });

  test('categoryLabel uses the localized systemKey until renamed', () async {
    final en = lookupAppLocalizations(const Locale('en'));
    final ar = lookupAppLocalizations(const Locale('ar'));
    final food = (await cats.watch(kind: 'expense').first).first;
    expect(categoryLabel(food, en), 'Food');
    expect(categoryLabel(food, ar), 'أكل');
    await cats.rename(food.id, 'Eating out');
    final renamed = (await cats.watch(kind: 'expense').first).first;
    expect(categoryLabel(renamed, ar), 'Eating out');
  });

  test('extra keywords round-trip, trimmed and deduplicated', () async {
    await cats.setExtraKeywords(f.cat('food'), [' سمون ', 'سمون', '', 'kebab']);
    final food = (await cats.watch(kind: 'expense').first).firstWhere((c) => c.id == f.cat('food'));
    expect(extraKeywords(food), ['سمون', 'kebab']);
  });

  test('create and archive', () async {
    final id = await cats.create(kind: 'expense', name: 'Pets');
    expect((await cats.watch(kind: 'expense').first).any((c) => c.id == id), isTrue);
    await cats.archive(id);
    expect((await cats.watch(kind: 'expense').first).any((c) => c.id == id), isFalse);
    expect((await cats.watch(kind: 'expense', includeArchived: true).first).any((c) => c.id == id), isTrue);
  });
}
