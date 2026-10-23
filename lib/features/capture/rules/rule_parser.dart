import '../../../core/money/amount_parse.dart';
import '../../finance/ui/transfer_form_screen.dart' show rateFromAmounts, ratePair;
import '../domain/lexicon.dart';
import '../domain/proposal.dart';
import 'dates.dart';
import 'keywords.dart';
import 'numbers.dart';

/// Turns what the owner said into proposals for Capture Review.
abstract interface class IntentParser {
  Future<List<Proposal>> parse(String transcript, Lexicon lex, DateTime now);
}

final _clauseMarks = RegExp(r'\n|(?<!\d)\.|\.(?!\d)|[،؛;!?؟]');
final _clauseWords = phrases(['وبعدين', 'وبعدها', 'ثم', 'and then', 'پاشان']);
final _fromWords = phrases(['من', 'from', 'لە']);

/// Offline parser: keyword cues, number words and the owner's own names.
/// It never sends anything anywhere.
class RuleParser implements IntentParser {
  const RuleParser();

  @override
  Future<List<Proposal>> parse(String transcript, Lexicon lex, DateTime now) async {
    final text = transcript.trim();
    final toks = tokenize(text);
    if (toks.isEmpty) return const [];
    // A note that opens with «ملاحظة» keeps everything after it, full stops included.
    if (findPhrases(toks, kNoteCues).any((h) => h.$1 == 0)) {
      return [NoteProposal(text: _after(text, toks[0]), workspaceId: _Clause(text, lex, now).workspace?.id)];
    }
    return [for (final c in splitClauses(text)) ?_Clause(c, lex, now).proposal()];
  }
}

/// Splits on line breaks, full stops (not decimal points), Arabic commas and «وبعدين».
List<String> splitClauses(String text) {
  final out = <String>[];
  for (final part in text.split(_clauseMarks)) {
    final toks = tokenize(part);
    var from = 0;
    for (final (i, n) in findPhrases(toks, _clauseWords)) {
      out.add(part.substring(from, toks[i].start));
      from = toks[i + n - 1].end;
    }
    out.add(part.substring(from));
  }
  return [
    for (final c in out)
      if (tokenize(c).isNotEmpty) c.trim(),
  ];
}

String _after(String text, Tok cue) {
  final rest = text.substring(cue.end).replaceFirst(RegExp(r'^[\s:：\-–—]+'), '').trim();
  return rest.isEmpty ? text : rest;
}

class _Hit<T> {
  const _Hit(this.item, this.first, this.words, this.chars);

  final T item;
  final int first;
  final int words;
  final int chars;

  bool longerThan(_Hit<Object?> o) => words != o.words ? words > o.words : chars > o.chars;
  bool sameLength(_Hit<Object?> o) => words == o.words && chars == o.chars;
}

class _Clause {
  _Clause(this.text, this.lex, this.now) : toks = tokenize(text) {
    final w = whenInTokens(toks, now);
    when = w.when;
    dateIdx = w.used;
    amounts = amountsInTokens(toks, skip: dateIdx);
    amountIdx = {
      for (final a in amounts)
        for (var i = a.first; i <= a.last; i++) i,
    };
    used = {...dateIdx, ...amountIdx};
  }

  final String text;
  final Lexicon lex;
  final DateTime now;
  final List<Tok> toks;
  late final When when;
  late final Set<int> dateIdx;
  late final List<TokenAmount> amounts;
  late final Set<int> amountIdx;
  late final Set<int> used;

  bool has(List<List<String>> cues) => hasPhrase(toks, cues, skip: used);

  List<_Hit<T>> _hits<T>(Iterable<T> items, List<String> Function(T) terms) => [
    for (final item in items)
      for (final term in terms(item))
        if (phraseWords(term) case final words when words.isNotEmpty)
          for (var i = 0; i < toks.length; i++)
            if (matchesAt(toks, i, words, skip: used)) _Hit(item, i, words.length, term.length),
  ];

  /// The longest hit, and how many other items hit just as long.
  (T?, int) _best<T>(List<_Hit<T>> hits) {
    if (hits.isEmpty) return (null, 0);
    var best = hits.first;
    for (final h in hits) {
      if (h.longerThan(best)) best = h;
    }
    final rivals = {
      for (final h in hits)
        if (h.sameLength(best) && h.item != best.item) h.item,
    };
    return (best.item, rivals.length);
  }

  late final List<_Hit<LexWorkspace>> workspaceHits = _hits(lex.workspaces, (w) => w.terms);
  late final (LexWorkspace?, int) _ws = _best(workspaceHits);
  LexWorkspace? get workspace => _ws.$1;
  late final LexAccount? namedAccount = _best(_hits(lex.accounts, (a) => a.terms)).$1;

  int get workspaceId => workspace?.id ?? namedAccount?.workspaceId ?? lex.personalWorkspaceId;

  LexAccount? accountFor(int workspaceId, String currency) {
    final named = namedAccount;
    if (named != null && named.workspaceId == workspaceId && named.currency == currency) return named;
    return lex.accounts.where((a) => a.workspaceId == workspaceId && a.currency == currency).firstOrNull;
  }

  int? minor(TokenAmount? a, String currency) => a == null ? null : parseDecimalToMinor(a.digitsText, currency)?.minor;

  DateTime get at {
    if (when.date == null && when.hour == null) return now;
    final d = when.date ?? now;
    return DateTime(d.year, d.month, d.day, when.hour ?? now.hour, when.minute ?? (when.hour == null ? now.minute : 0));
  }

  /// The words as said, minus the ones in [drop].
  String? words(Set<int> drop) {
    final kept = [
      for (var i = 0; i < toks.length; i++)
        if (!drop.contains(i)) toks[i].text,
    ].join(' ');
    return kept.isEmpty ? null : kept;
  }

  Set<int> phraseIdx(List<List<String>> list) => {
    for (final (i, n) in findPhrases(toks, list, skip: used))
      for (var k = i; k < i + n; k++) k,
  };

  Proposal? proposal() {
    if (toks.isEmpty) return null;
    final note = findPhrases(toks, kNoteCues).firstOrNull;
    if (note != null) return NoteProposal(text: _after(text, toks[note.$1]), workspaceId: workspace?.id);
    if (has(kDeleteCues)) return DeleteProposal(confidence: 90, target: _target(kDeleteCues));
    if (has(kEditCues)) return _edit();
    if (has(kDebtCues)) return _debt();
    if (has(kExchangeCues) && amounts.length >= 2) {
      final x = _exchange();
      if (x != null) return x;
    }
    if (has(kTransferCues)) return _transfer();
    if (has(kIncomeCues)) return _money(IntentType.income);
    if (has(kTaskCues)) return _task(100);
    if (has(kExpenseCues) || amounts.isNotEmpty) return _money(IntentType.expense);
    return _task(70);
  }

  /// Which saved entry the owner means, from what is left once the cue and filler go.
  String _target(List<List<String>> cue) {
    if (has(kExpenseNouns)) return 'last_expense';
    if (has(kIncomeNouns)) return 'last_income';
    final drop = {...used, ...phraseIdx(cue), ...phraseIdx(kTargetFiller)};
    final rest = [
      for (var i = 0; i < toks.length; i++)
        if (!drop.contains(i))
          toks[i].text.startsWith('ال') && toks[i].text.length > 3 ? toks[i].text.substring(2) : toks[i].text,
    ].join(' ');
    return rest.isEmpty ? kTargetLast : rest;
  }

  EditProposal _edit() {
    final amount = amounts.firstOrNull;
    final category = _best(_hits(lex.categories, (c) => c.terms)).$1;
    final newAmount = minor(amount, amount?.currency ?? lex.baseCurrency);
    // «غير المبلغ لـ 30 الف»: an amount alone means the last entry.
    final target = newAmount != null || category != null ? _kindTarget() : _target(kEditCues);
    return EditProposal(confidence: 90, target: target, newAmountMinor: newAmount, newCategoryId: category?.id);
  }

  String _kindTarget() => has(kExpenseNouns)
      ? 'last_expense'
      : has(kIncomeNouns)
      ? 'last_income'
      : kTargetLast;

  MoneyProposal _money(IntentType type) {
    final amount = amounts.firstOrNull;
    final ws = workspaceId;
    final currency = amount?.currency ?? namedAccount?.currency ?? lex.baseCurrency;
    final account = accountFor(ws, currency);
    final kind = type == IntentType.income ? 'income' : 'expense';
    final (category, rivals) = _best(_hits(lex.categories.where((c) => c.kind == kind), (c) => c.terms));
    final bucket = _best(
      _hits(lex.buckets.where((b) => b.systemKey == 'emergency' || b.systemKey == 'investment'), (b) => b.terms),
    ).$1;
    final amountMinor = minor(amount, currency);
    var confidence = 100;
    if (amountMinor == null) confidence -= 40;
    if (category == null) confidence -= 20;
    if (account == null) confidence -= 20;
    confidence -= 10 * (rivals + _ws.$2 + (amounts.length > 1 ? 1 : 0));
    return MoneyProposal(
      type: type,
      confidence: confidence.clamp(0, 100),
      amountMinor: amountMinor,
      currency: currency,
      accountId: account?.id,
      workspaceId: ws,
      categoryId: category?.id,
      occurredAt: at,
      description: words(used),
      bucketTag: type == IntentType.expense ? bucket?.systemKey : null,
    );
  }

  /// «صرفت 100 دولار ب 131 الف»: dollars out, dinars in, at the rate the two amounts imply.
  TransferProposal? _exchange() {
    final (a, b) = (amounts[0], amounts[1]);
    String other(String c) => c == 'USD' ? 'IQD' : 'USD';
    var (from, to) = (a.currency, b.currency);
    from ??= to == null ? 'USD' : other(to);
    to ??= other(from);
    if (from == to) return null;
    final ws = workspaceId;
    final fromAcc = accountFor(ws, from), toAcc = accountFor(ws, to);
    final m1 = minor(a, from), m2 = minor(b, to);
    int? rate;
    if (m1 != null && m2 != null && m1 > 0 && m2 > 0) {
      final (base, quote) = ratePair(from, to, lex.baseCurrency);
      final fromIsBase = base == from;
      rate = rateFromAmounts(
        baseMinor: fromIsBase ? m1 : m2,
        base: base,
        quoteMinor: fromIsBase ? m2 : m1,
        quote: quote,
      );
    }
    var confidence = 100;
    if (fromAcc == null) confidence -= 20;
    if (toAcc == null) confidence -= 20;
    if (rate == null) confidence -= 40;
    return TransferProposal(
      confidence: confidence.clamp(0, 100),
      fromAccountId: fromAcc?.id,
      toAccountId: toAcc?.id,
      amountMinor: m1,
      toAmountMinor: m2,
      rateE6: rate,
      transferKind: 'transfer',
      occurredAt: at,
    );
  }

  /// «حولت 100 الف من بزفاي لشخصي»: «من» marks the source; the other side
  /// defaults to Personal.
  TransferProposal _transfer() {
    LexWorkspace? from, to;
    final seen = <LexWorkspace>{};
    for (final h in [...workspaceHits]..sort((x, y) => x.first.compareTo(y.first))) {
      if (!seen.add(h.item)) continue;
      final afterFrom = h.first > 0 && _fromWords.any((w) => matchesAt(toks, h.first - 1, w));
      if (afterFrom && from == null) {
        from = h.item;
      } else {
        to ??= h.item;
      }
    }
    final personal = lex.personalWorkspaceId;
    final fromWs = from?.id ?? (to != null && to.id != personal ? personal : null);
    final toWs = to?.id ?? (from != null && from.id != personal ? personal : null);
    final amount = amounts.firstOrNull;
    final currency = amount?.currency ?? lex.baseCurrency;
    final fromAcc = fromWs == null ? null : accountFor(fromWs, currency);
    final toAcc = toWs == null ? null : accountFor(toWs, currency);
    final amountMinor = minor(amount, currency);
    var confidence = 100;
    if (amountMinor == null) confidence -= 40;
    if (fromAcc == null) confidence -= 20;
    if (toAcc == null) confidence -= 20;
    if (fromAcc != null && fromAcc == toAcc) confidence -= 10;
    return TransferProposal(
      confidence: confidence.clamp(0, 100),
      fromAccountId: fromAcc?.id,
      toAccountId: toAcc?.id,
      amountMinor: amountMinor,
      toAmountMinor: amountMinor,
      transferKind: 'transfer',
      occurredAt: at,
    );
  }

  DebtProposal _debt() {
    final (direction, leg) = has(kOwedToMeRepayment)
        ? ('owed_to_me', 'repayment')
        : has(kOwedByMePrincipal)
        ? ('owed_by_me', 'principal')
        : has(kOwedToMePrincipal)
        ? ('owed_to_me', 'principal')
        : has(kOwedByMeRepayment)
        ? ('owed_by_me', 'repayment')
        : (null, null);
    final amount = amounts.firstOrNull;
    final currency = amount?.currency ?? lex.baseCurrency;
    final account = accountFor(workspaceId, currency);
    final amountMinor = minor(amount, currency);
    final drop = {
      ...used,
      ...phraseIdx(kDebtCues),
      ...phraseIdx([...kOwedToMeRepayment, ...kOwedToMePrincipal, ...kOwedByMePrincipal, ...kOwedByMeRepayment]),
      ...phraseIdx(kStopWords),
      for (final h in workspaceHits) h.first,
    };
    final counterparty = words(drop);
    var confidence = 100;
    if (amountMinor == null) confidence -= 40;
    if (counterparty == null) confidence -= 20;
    if (direction == null) confidence -= 20;
    if (account == null) confidence -= 20;
    return DebtProposal(
      confidence: confidence.clamp(0, 100),
      counterparty: counterparty,
      direction: direction,
      leg: leg,
      amountMinor: amountMinor,
      currency: currency,
      accountId: account?.id,
      occurredAt: at,
    );
  }

  TaskProposal _task(int confidence) {
    DateTime? due;
    final d = when.date;
    if (d != null) {
      due = DateTime(d.year, d.month, d.day, when.hour ?? 0, when.minute ?? 0);
    } else if (when.hour != null) {
      due = DateTime(now.year, now.month, now.day, when.hour!, when.minute ?? 0);
      if (due.isBefore(now)) due = due.add(const Duration(days: 1));
    }
    final title = words({...dateIdx, ...phraseIdx(kTaskFraming)}) ?? text;
    return TaskProposal(title: title, confidence: confidence, due: due, workspaceId: workspace?.id);
  }
}
