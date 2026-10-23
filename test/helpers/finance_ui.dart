import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/providers.dart';
import 'package:life_manager/app/router.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/features/finance/data/transactions_repository.dart';

/// Account id by workspace name and currency, in the app harness seed.
Future<int> accountId(ProviderContainer c, String workspace, String currency) async {
  final db = c.read(appDatabaseProvider);
  final ws = await (db.select(db.workspaces)..where((w) => w.name.equals(workspace))).getSingle();
  final a = await (db.select(
    db.accounts,
  )..where((a) => a.workspaceId.equals(ws.id) & a.currencyCode.equals(currency))).getSingle();
  return a.id;
}

Future<int> workspaceId(ProviderContainer c, String name) async {
  final db = c.read(appDatabaseProvider);
  return (await (db.select(db.workspaces)..where((w) => w.name.equals(name))).getSingle()).id;
}

TransactionsRepository txRepo(ProviderContainer c) => TransactionsRepository(c.read(appDatabaseProvider));

/// Opens the Finance tab and lets the streams settle.
Future<void> openFinance(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('nav-1')));
  await t.pumpAndSettle();
}

AppDatabase dbOf(ProviderContainer c) => c.read(appDatabaseProvider);

/// Pushes a finance route directly (tiles low on the overview can sit under the mic button).
Future<void> pushRoute(WidgetTester t, ProviderContainer c, String location) async {
  c.read(routerProvider).push(location);
  await settle(t);
}

/// Lets real database work finish (screens that load in initState), then settles.
Future<void> settle(WidgetTester t) async {
  await t.pumpAndSettle();
  for (var i = 0; i < 8; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await t.pumpAndSettle();
  }
}

Future<void> pickAccount(WidgetTester t, String field, int id) async {
  await t.tap(find.byKey(ValueKey(field)));
  await settle(t);
  await t.tap(find.byKey(ValueKey('account-option-$id')).last);
  await settle(t);
}

bool saveEnabled(WidgetTester t, String key) => t.widget<FilledButton>(find.byKey(ValueKey(key))).onPressed != null;

/// Scrolls the topmost route's list until [f] is built and visible.
Future<void> revealInForm(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).last);
  await settle(t);
}

/// One database write at a time. A write run inside `runAsync` can wait on the screen's stream refetch, which
/// is queued in the test's fake-async zone, so each write is followed by a pump that lets that refetch run.
Future<T> dbWrite<T>(WidgetTester t, Future<T> Function() f) async {
  final r = await t.runAsync(f);
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
  await t.pump();
  return r as T;
}
