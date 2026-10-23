import 'package:drift/drift.dart' show OrderingTerm, innerJoin;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/db/app_database.dart';
import '../../core/l10n/ckb_fallback_localizations.dart';
import '../../core/theme/tokens.dart';
import '../capture/data/capture_providers.dart';
import '../finance/data/finance_providers.dart';
import '../finance/ui/widgets/alerts_banner.dart';
import '../../core/money/money.dart';
import '../finance/ui/widgets/money_text.dart';
import 'home_cards.dart';

/// Seeded accounts grouped by workspace, in workspace then account order.
final accountsByWorkspaceProvider = StreamProvider<List<(Workspace, List<Account>)>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.accounts).join([
    innerJoin(db.workspaces, db.workspaces.id.equalsExp(db.accounts.workspaceId)),
  ])..orderBy([OrderingTerm.asc(db.workspaces.sortOrder), OrderingTerm.asc(db.accounts.sortOrder)]);
  return query.watch().map((rows) {
    final groups = <int, (Workspace, List<Account>)>{};
    for (final row in rows) {
      final ws = row.readTable(db.workspaces);
      groups.putIfAbsent(ws.id, () => (ws, <Account>[])).$2.add(row.readTable(db.accounts));
    }
    return groups.values.toList();
  });
});

/// Layout B: alerts, month numbers, chart, buckets, balance and tasks, then accounts.
/// The tasks card is still a placeholder for its phase.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final month = DateFormat.yMMMM(DateFormat.localeExists(locale) ? locale : 'ar').format(DateTime.now());
    final alerts = ref.watch(financeAlertsProvider).value ?? const [];
    final waiting = ref.watch(pendingCapturesProvider).value?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(month),
        actions: [
          IconButton(
            key: const ValueKey('open-inbox'),
            tooltip: l10n.capInbox,
            icon: Badge(isLabelVisible: waiting > 0, label: Text('$waiting'), child: const Icon(Icons.inbox_outlined)),
            onPressed: () => context.push('/inbox'),
          ),
          IconButton(
            key: const ValueKey('open-settings'),
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
        children: [
          AlertsBanner(alerts, keyPrefix: 'home-'),
          const HomeMonthCard(),
          const HomeChartCard(),
          const HomeBucketsCard(),
          const HomeConsolidatedCard(),
          _UpcomingSlot(icon: Icons.task_alt_rounded, title: l10n.homeTasks, phase: 4),
          const SizedBox(height: 4),
          const _AccountsCard(),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: padding,
      decoration: BoxDecoration(
        color: k.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(color: k.border),
      ),
      child: child,
    );
  }
}

class _UpcomingSlot extends StatelessWidget {
  const _UpcomingSlot({required this.icon, required this.title, required this.phase});

  final IconData icon;
  final String title;
  final int phase;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    return _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: k.surfaceHigh, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: k.textMuted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall?.copyWith(color: k.text)),
                const SizedBox(height: 2),
                Text(context.l10n.comingInPhase(phase), style: text.bodySmall?.copyWith(color: k.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountsCard extends ConsumerWidget {
  const _AccountsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final groups = ref.watch(accountsByWorkspaceProvider).value ?? const [];
    final balances = ref.watch(balancesProvider).value ?? const {};

    return _Panel(
      key: const ValueKey('accounts-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.l10n.accounts, style: text.titleMedium?.copyWith(color: k.text)),
          for (final (ws, accounts) in groups) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: Color(ws.colorArgb), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(ws.name, style: text.labelLarge?.copyWith(color: k.textMuted)),
                ),
              ],
            ),
            for (final a in accounts)
              Padding(
                key: ValueKey('account-${a.id}'),
                padding: const EdgeInsetsDirectional.only(start: 16, top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _shortName(a.name, ws.name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(color: k.text),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedMoney(
                        balances[a.id] ?? Money(a.openingBalanceMinor, a.currencyCode),
                        style: text.bodyMedium?.copyWith(color: k.text),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Seeded names are `<workspace> · <label>`; under the workspace header only the label is needed.
  static String _shortName(String name, String workspace) {
    final prefix = '$workspace · ';
    return name.startsWith(prefix) ? name.substring(prefix.length) : name;
  }
}
