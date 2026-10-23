import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/finance_seed.dart';
import '../../../core/text/digits.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../finance/data/categories_repository.dart';

List<String> _aliases(Workspace w) => [
  for (final a in w.aliases.split(','))
    if (a.trim().isNotEmpty) a.trim(),
];

List<String> _terms(Iterable<String> raw) =>
    {for (final r in raw) normalizeForMatch(r.trim())}.where((t) => t.isNotEmpty).toList();

class LexWorkspace {
  const LexWorkspace(this.id, this.name, this.terms, {this.aliases = const []});

  final int id;
  final String name;
  final List<String> terms;

  /// As the owner typed them.
  final List<String> aliases;
}

class LexAccount {
  const LexAccount(this.id, this.name, this.terms, {required this.workspaceId, required this.currency});

  final int id;
  final String name;
  final List<String> terms;
  final int workspaceId;
  final String currency;
}

class LexCategory {
  const LexCategory(this.id, this.name, this.terms, {required this.kind});

  final int id;
  final String name;
  final List<String> terms;

  /// `income` or `expense`.
  final String kind;
}

class LexBucket {
  const LexBucket(this.id, this.name, this.terms, {this.systemKey});

  final int id;
  final String name;
  final List<String> terms;
  final String? systemKey;
}

/// The owner's own names the parser matches against, folded once.
class Lexicon {
  const Lexicon({
    required this.workspaces,
    required this.accounts,
    required this.categories,
    required this.buckets,
    required this.personalWorkspaceId,
    required this.baseCurrency,
  });

  final List<LexWorkspace> workspaces;
  final List<LexAccount> accounts;
  final List<LexCategory> categories;
  final List<LexBucket> buckets;
  final int personalWorkspaceId;
  final String baseCurrency;
}

Future<Lexicon> loadLexicon(AppDatabase db, AppLocalizations l10n) async {
  final ws =
      await (db.select(db.workspaces)
            ..where((w) => w.isArchived.equals(false))
            ..orderBy([(w) => OrderingTerm.asc(w.sortOrder)]))
          .get();
  final accounts =
      await (db.select(db.accounts)
            ..where((a) => a.isArchived.equals(false))
            ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
          .get();
  final cats = await (db.select(db.categories)..where((c) => c.isArchived.equals(false))).get();
  final buckets = await db.select(db.buckets).get();
  final settings = await db.select(db.appSettingsTable).getSingleOrNull();
  return Lexicon(
    workspaces: [
      for (final w in ws) LexWorkspace(w.id, w.name, _terms([w.name, ..._aliases(w)]), aliases: _aliases(w)),
    ],
    accounts: [
      for (final a in accounts)
        LexAccount(a.id, a.name, _terms([a.name]), workspaceId: a.workspaceId, currency: a.currencyCode),
    ],
    categories: [
      for (final c in cats)
        LexCategory(
          c.id,
          categoryLabel(c, l10n),
          _terms([categoryLabel(c, l10n), ...?kDefaultCategoryKeywords[c.systemKey], ...extraKeywords(c)]),
          kind: c.kind,
        ),
    ],
    buckets: [
      for (final b in buckets)
        LexBucket(b.id, bucketLabel(b, l10n), _terms([bucketLabel(b, l10n), ?b.systemKey]), systemKey: b.systemKey),
    ],
    // The seed puts Personal first; it is where anything unassigned goes.
    personalWorkspaceId: ws.first.id,
    baseCurrency: settings?.baseCurrency ?? 'IQD',
  );
}
