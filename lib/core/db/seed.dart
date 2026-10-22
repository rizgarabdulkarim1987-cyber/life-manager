import 'dart:ui' show Color;


import '../theme/tokens.dart';
import 'app_database.dart';

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

/// Creates the four workspaces and six cash accounts from spec §10.1.
/// Does nothing once any workspace exists.
Future<void> seedInitialData(AppDatabase db, SeedNames n) async {
  await db.transaction(() async {
    final existing = await (db.select(db.workspaces)..limit(1)).get();
    if (existing.isNotEmpty) return;

    final now = DateTime.now().toUtc();
    final dark = AppTokens.dark;
    final workspaces = [
      (n.personal, 'person', dark.accent, true),
      (n.buzzify, 'campaign', const Color(0xFF8B5CF6), true),
      (n.eo, 'handshake', dark.warning, true),
      (n.otherProjects, 'folder', dark.textMuted, false),
    ];

    var order = 0;
    for (final (name, icon, color, hasCash) in workspaces) {
      final wsId = await db.into(db.workspaces).insert(WorkspacesCompanion.insert(
            name: name,
            iconKey: icon,
            colorArgb: color.toARGB32(),
            sortOrder: order,
            createdAt: now,
          ));
      if (hasCash) {
        for (final (currency, label) in [('IQD', n.cashIqd), ('USD', n.cashUsd)]) {
          await db.into(db.accounts).insert(AccountsCompanion.insert(
                workspaceId: wsId,
                name: '$name · $label',
                kind: 'cash',
                currencyCode: currency,
                sortOrder: order * 2 + (currency == 'USD' ? 1 : 0),
                createdAt: now,
              ));
        }
      }
      order++;
    }
  });
}

Future<bool> isSetupCompleted(AppDatabase db) async =>
    (await db.select(db.appSettingsTable).getSingle()).setupCompleted;
