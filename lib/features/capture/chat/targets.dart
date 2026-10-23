import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/text/digits.dart';
import '../domain/lexicon.dart';
import '../domain/proposal.dart';

/// The saved income or expense [target] names: the newest one of that kind,
/// or the newest whose description or category holds every word of it.
Future<Transaction?> resolveTarget(AppDatabase db, String target, Lexicon lex) async {
  final types = switch (target) {
    'last_expense' => const ['expense'],
    'last_income' => const ['income'],
    _ => const ['expense', 'income', 'refund'],
  };
  final q = db.select(db.transactions)
    ..where((t) => t.type.isIn(types))
    ..orderBy([(t) => OrderingTerm.desc(t.createdAt), (t) => OrderingTerm.desc(t.id)]);
  if (target == kTargetLast || target == 'last_expense' || target == 'last_income') {
    return (q..limit(1)).getSingleOrNull();
  }
  final words = normalizeForMatch(target).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return null;
  final categories = {for (final c in lex.categories) c.id: c.terms.join(' ')};
  for (final t in await (q..limit(500)).get()) {
    final hay = '${normalizeForMatch(t.description ?? '')} ${categories[t.categoryId] ?? ''}';
    if (words.every(hay.contains)) return t;
  }
  return null;
}
