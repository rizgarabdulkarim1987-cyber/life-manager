import 'dart:ui' show Color;

import '../theme/tokens.dart';

import 'package:drift/drift.dart' show Value;

import 'app_database.dart';
import 'finance_seed.dart';

/// Localized names for the seeded workspaces and accounts.
class SeedNames {
  const SeedNames({
    required this.personal,
    required this.buzzify,
    required this.eo,
    required this.otherProjects,
    required this.cashIqd,
    required this.cashUsd,
  });

  final String personal;
  final String buzzify;
  final String eo;
  final String otherProjects;
  final String cashIqd;
  final String cashUsd;
}

/// First run (redesign §11.1): the Personal workspace and the three buckets.
/// The owner adds the first account in setup and their own categories later.
/// Does nothing once any workspace exists.
Future<void> seedInitialData(AppDatabase db, SeedNames n) async {
  await db.transaction(() async {
    await seedBuckets(db);
    if ((await (db.select(db.workspaces)..limit(1)).get()).isNotEmpty) return;
    await db
        .into(db.workspaces)
        .insert(
          WorkspacesCompanion.insert(
            name: n.personal,
            iconKey: 'person',
            colorArgb: AppTokens.light.accent.toARGB32(),
            sortOrder: 0,
            createdAt: DateTime.now().toUtc(),
            countsInBuckets: const Value(true),
          ),
        );
  });
}

/// Tests and screenshots: the phase 1 workspaces and six cash accounts, and
/// the default categories. Run after [seedInitialData]; does nothing twice.
Future<void> seedDemoData(AppDatabase db, SeedNames n) async {
  await db.transaction(() async {
    await seedDefaultCategories(db);
    if ((await (db.select(db.accounts)..limit(1)).get()).isNotEmpty) return;

    final now = DateTime.now().toUtc();
    final dark = AppTokens.dark;
    final workspaces = [
      (n.personal, 'person', dark.accent, true),
      (n.buzzify, 'campaign', const Color(0xFF8B5CF6), true),
      (n.eo, 'handshake', dark.warning, true),
      (n.otherProjects, 'folder', dark.textMuted, false),
    ];

    var order = 0;
    final personal = (await (db.select(db.workspaces)..where((w) => w.sortOrder.equals(0))).getSingleOrNull())?.id;
    for (final (name, icon, color, hasCash) in workspaces) {
      final wsId = order == 0 && personal != null
          ? personal
          : await db
                .into(db.workspaces)
                .insert(
                  WorkspacesCompanion.insert(
                    name: name,
                    iconKey: icon,
                    colorArgb: color.toARGB32(),
                    sortOrder: order,
                    createdAt: now,
                    countsInBuckets: Value(order == 0),
                  ),
                );
      if (hasCash) {
        for (final (currency, label) in [('IQD', n.cashIqd), ('USD', n.cashUsd)]) {
          await db
              .into(db.accounts)
              .insert(
                AccountsCompanion.insert(
                  workspaceId: wsId,
                  name: '$name · $label',
                  kind: 'cash',
                  currencyCode: currency,
                  sortOrder: order * 2 + (currency == 'USD' ? 1 : 0),
                  createdAt: now,
                ),
              );
        }
      }
      order++;
    }
  });
}

Future<bool> isSetupCompleted(AppDatabase db) async =>
    (await db.select(db.appSettingsTable).getSingle()).setupCompleted;
