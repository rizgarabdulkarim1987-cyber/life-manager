import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/finance_ui.dart';

void main() {
  testWidgets('adding the keyword سمون to Food persists it in extraKeywords', (t) async {
    final c = await pumpApp(t, locale: 'en');
    final db = dbOf(c);
    final food = (await (db.select(db.categories)..where((x) => x.systemKey.equals('food'))).getSingle()).id;
    await pushRoute(t, c, '/settings/categories');
    await t.tap(find.byKey(ValueKey('category-$food')));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('keyword-input')), 'سمون');
    await settle(t);
    await t.tap(find.byKey(const ValueKey('keyword-add')));
    await settle(t);
    await t.ensureVisible(find.byKey(const ValueKey('category-save')));
    await t.tap(find.byKey(const ValueKey('category-save')));
    await settle(t);
    final row = await t.runAsync(() => (db.select(db.categories)..where((x) => x.id.equals(food))).getSingle());
    expect(row!.extraKeywords, 'سمون');
  });

  testWidgets('add an expense category', (t) async {
    final c = await pumpApp(t, locale: 'en');
    final db = dbOf(c);
    await pushRoute(t, c, '/settings/categories');
    await t.tap(find.byKey(const ValueKey('add-category')));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('category-name')), 'Gym');
    await settle(t);
    await t.ensureVisible(find.byKey(const ValueKey('category-save')));
    await t.tap(find.byKey(const ValueKey('category-save')));
    await settle(t);
    final rows = (await t.runAsync(() => (db.select(db.categories)..where((x) => x.name.equals('Gym'))).get()))!;
    expect(rows.single.kind, 'expense');
  });

  testWidgets('the Food sheet with all its built-in words fits a small phone in Arabic', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = await pumpApp(t);
    final db = dbOf(c);
    final food = (await (db.select(db.categories)..where((x) => x.systemKey.equals('food'))).getSingle()).id;
    await pushRoute(t, c, '/settings/categories');
    await t.tap(find.byKey(ValueKey('category-$food')));
    await settle(t);
    await t.ensureVisible(find.byKey(const ValueKey('category-archive')));
    await settle(t);
    expect(t.takeException(), isNull);
  });
}
