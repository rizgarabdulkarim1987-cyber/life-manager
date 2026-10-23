import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/finance_ui.dart';

void main() {
  testWidgets('adding the alias بز to Buzzify persists it', (t) async {
    final c = await pumpApp(t, locale: 'en');
    final id = await workspaceId(c, 'Buzzify');
    await pushRoute(t, c, '/settings/workspaces');
    await t.tap(find.byKey(ValueKey('workspace-$id')));
    await settle(t);
    await t.ensureVisible(find.byKey(const ValueKey('alias-input')));
    await t.enterText(find.byKey(const ValueKey('alias-input')), 'بز');
    await settle(t);
    await t.tap(find.byKey(const ValueKey('alias-add')));
    await settle(t);
    await t.ensureVisible(find.byKey(const ValueKey('workspace-save')));
    await t.tap(find.byKey(const ValueKey('workspace-save')));
    await settle(t);
    final db = dbOf(c);
    final w = await t.runAsync(() => (db.select(db.workspaces)..where((x) => x.id.equals(id))).getSingle());
    expect(w!.aliases, 'بز');
  });

  testWidgets('archiving a workspace with active accounts shows the blocking message', (t) async {
    final c = await pumpApp(t, locale: 'en');
    final id = await workspaceId(c, 'Personal');
    await pushRoute(t, c, '/settings/workspaces');
    await t.tap(find.byKey(ValueKey('workspace-$id')));
    await settle(t);
    await t.ensureVisible(find.byKey(const ValueKey('workspace-archive')));
    await t.tap(find.byKey(const ValueKey('workspace-archive')));
    await settle(t);
    expect(find.byKey(const ValueKey('archive-blocked')), findsOneWidget);
    final db = dbOf(c);
    final w = await t.runAsync(() => (db.select(db.workspaces)..where((x) => x.id.equals(id))).getSingle());
    expect(w!.isArchived, isFalse);
  });

  testWidgets('add a workspace with an icon and colour', (t) async {
    final c = await pumpApp(t, locale: 'en');
    await pushRoute(t, c, '/settings/workspaces');
    await t.tap(find.byKey(const ValueKey('add-workspace')));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('workspace-name')), 'Studio');
    await t.tap(find.byKey(const ValueKey('icon-store')));
    await settle(t);
    await t.ensureVisible(find.byKey(const ValueKey('workspace-save')));
    await t.tap(find.byKey(const ValueKey('workspace-save')));
    await settle(t);
    final db = dbOf(c);
    final w = (await t.runAsync(() => (db.select(db.workspaces)..where((x) => x.name.equals('Studio'))).get()))!;
    expect(w.single.iconKey, 'store');
  });
}
