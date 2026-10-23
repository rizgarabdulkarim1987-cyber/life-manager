import '../../../core/money/amount_parse.dart';
import '../../../core/text/digits.dart';
import '../../finance/ui/transfer_form_screen.dart' show rateFromAmounts, ratePair;
import 'lexicon.dart';
import 'proposal.dart';

/// The model's reply broke the schema. Carries a short field code only,
/// never the model's text, so it is safe to log.
class InvalidAiOutput implements Exception {
  const InvalidAiOutput(this.code);

  final String code;

  @override
  String toString() => 'InvalidAiOutput($code)';
}

/// The JSON the model must answer with (also quoted in the prompt).
const kIntentSchema =
    '{"intents":[{"type":"expense|income|transfer|task|reminder|appointment|project_idea|debt_payment|note|edit|delete",'
    '"amount":"<decimal string>|null","currency":"IQD|USD|null",'
    '"to_amount":"<decimal string>|null","to_currency":"IQD|USD|null",'
    '"workspace":"<name>|null","account":"<name>|null","to_account":"<name>|null",'
    '"category":"<name>|null","date":"YYYY-MM-DD|null","time":"HH:MM|null",'
    '"description":"<text>|null","title":"<text>|null","place":"<text>|null",'
    '"counterparty":"<text>|null","debt_direction":"owed_to_me|owed_by_me|null",'
    '"debt_leg":"principal|repayment|null",'
    '"target":"last|last_expense|last_income|<words of the saved entry>|null"}]}';

const kMaxIntents = 10;
const kMaxAiString = 300;

const _types = {
  'expense',
  'income',
  'transfer',
  'task',
  'reminder',
  'appointment',
  'project_idea',
  'debt_payment',
  'note',
  'edit',
  'delete',
};
const _currencies = {'IQD', 'USD'};
const _keys = {
  'type',
  'amount',
  'currency',
  'to_amount',
  'to_currency',
  'workspace',
  'account',
  'to_account',
  'category',
  'date',
  'time',
  'description',
  'title',
  'place',
  'counterparty',
  'debt_direction',
  'debt_leg',
  'target',
};
const _enums = {
  'type': _types,
  'currency': _currencies,
  'to_currency': _currencies,
  'debt_direction': {'owed_to_me', 'owed_by_me'},
  'debt_leg': {'principal', 'repayment'},
};
final _amount = RegExp(r'^\d{1,15}(\.\d{1,6})?$');
final _date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final _time = RegExp(r'^(\d{2}):(\d{2})$');

/// Checks the model's reply against [kIntentSchema] and resolves names to ids.
/// A name that matches nothing becomes a null field for the owner to fill in
/// review; anything off-schema throws [InvalidAiOutput].
List<Proposal> validateIntents(Object? json, Lexicon lex, DateTime now) {
  if (json is! Map || json.length != 1 || json['intents'] is! List) throw const InvalidAiOutput('root');
  final list = json['intents'] as List;
  if (list.length > kMaxIntents) throw const InvalidAiOutput('count');
  return [for (final raw in list) _Resolver(_check(raw), lex, now).proposal()];
}

Map<String, String> _check(Object? raw) {
  if (raw is! Map) throw const InvalidAiOutput('intent');
  final out = <String, String>{};
  for (final MapEntry(:key, :value) in raw.entries) {
    if (key is! String || !_keys.contains(key)) throw const InvalidAiOutput('key');
    if (value == null) continue;
    if (value is! String) throw InvalidAiOutput(key);
    if (value.length > kMaxAiString) throw InvalidAiOutput(key);
    final allowed = _enums[key];
    if (allowed != null && !allowed.contains(value)) throw InvalidAiOutput(key);
    if ((key == 'amount' || key == 'to_amount') && !_amount.hasMatch(value)) throw InvalidAiOutput(key);
    if (key == 'date' && _parseDate(value) == null) throw const InvalidAiOutput('date');
    if (key == 'time' && _parseTime(value) == null) throw const InvalidAiOutput('time');
    out[key] = value;
  }
  if (out['type'] == null) throw const InvalidAiOutput('type');
  return out;
}

DateTime? _parseDate(String s) {
  final m = _date.firstMatch(s);
  if (m == null) return null;
  final (y, mo, d) = (int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  final dt = DateTime(y, mo, d);
  return dt.year == y && dt.month == mo && dt.day == d ? dt : null;
}

(int, int)? _parseTime(String s) {
  final m = _time.firstMatch(s);
  if (m == null) return null;
  final (h, min) = (int.parse(m[1]!), int.parse(m[2]!));
  return h < 24 && min < 60 ? (h, min) : null;
}

class _Resolver {
  _Resolver(this.f, this.lex, this.now);

  final Map<String, String> f;
  final Lexicon lex;
  final DateTime now;

  T? _named<T>(String? name, Iterable<T> items, List<String> Function(T) terms) {
    if (name == null) return null;
    final n = normalizeForMatch(name.trim());
    return items.where((i) => terms(i).contains(n)).firstOrNull;
  }

  /// Not said → Personal; said but unknown → null, for the owner to pick.
  late final int? workspaceId = f['workspace'] == null
      ? (_named(f['account'], lex.accounts, (a) => a.terms)?.workspaceId ?? lex.personalWorkspaceId)
      : _named(f['workspace'], lex.workspaces, (w) => w.terms)?.id;

  LexAccount? _account(String? name, String? currency) {
    if (name != null) {
      final inWs = lex.accounts.where((a) => a.workspaceId == workspaceId);
      return _named(name, inWs, (a) => a.terms) ?? _named(name, lex.accounts, (a) => a.terms);
    }
    if (workspaceId == null) return null;
    final cur = currency ?? lex.baseCurrency;
    return lex.accounts.where((a) => a.workspaceId == workspaceId && a.currency == cur).firstOrNull;
  }

  int? _minor(String? amount, String currency) => amount == null ? null : parseDecimalToMinor(amount, currency)?.minor;

  DateTime get at {
    final d = f['date'] == null ? null : _parseDate(f['date']!);
    final t = f['time'] == null ? null : _parseTime(f['time']!);
    if (d == null && t == null) return now;
    final day = d ?? now;
    return DateTime(day.year, day.month, day.day, t?.$1 ?? now.hour, t?.$2 ?? now.minute);
  }

  Proposal proposal() => switch (f['type']!) {
    'expense' => _money(IntentType.expense),
    'income' => _money(IntentType.income),
    'transfer' => _transfer(),
    'debt_payment' => _debt(),
    'task' || 'reminder' || 'appointment' => _task(f['type']!),
    'project_idea' => ProjectIdeaProposal(
      title: (f['title'] ?? f['description'] ?? '').trim(),
      description: f['description'],
    ),
    'edit' => EditProposal(
      confidence: 90,
      target: f['target'] ?? kTargetLast,
      newAmountMinor: _minor(f['amount'], f['currency'] ?? lex.baseCurrency),
      newCategoryId: _named(f['category'], lex.categories, (c) => c.terms)?.id,
      newDescription: f['description'],
    ),
    'delete' => DeleteProposal(confidence: 90, target: f['target'] ?? kTargetLast),
    _ => NoteProposal(text: f['description'] ?? f['title'] ?? '', workspaceId: workspaceId),
  };

  MoneyProposal _money(IntentType type) {
    final account = _account(f['account'], f['currency']);
    final currency = f['currency'] ?? account?.currency ?? lex.baseCurrency;
    final kind = type == IntentType.income ? 'income' : 'expense';
    final category = _named(f['category'], lex.categories.where((c) => c.kind == kind), (c) => c.terms);
    final amount = _minor(f['amount'], currency);
    var confidence = 100;
    if (amount == null) confidence -= 40;
    if (category == null) confidence -= 20;
    if (account == null) confidence -= 20;
    return MoneyProposal(
      type: type,
      confidence: confidence,
      amountMinor: amount,
      currency: currency,
      accountId: account?.id,
      workspaceId: workspaceId,
      categoryId: category?.id,
      occurredAt: at,
      description: f['description'],
      // Said but unknown: kept so the chat can offer to create it.
      newCategoryName: category == null ? f['category']?.trim() : null,
      newAccountName: account == null ? f['account']?.trim() : null,
    );
  }

  TransferProposal _transfer() {
    final from = _account(f['account'], f['currency']);
    final fromCur = f['currency'] ?? from?.currency ?? lex.baseCurrency;
    final toCur = f['to_currency'] ?? fromCur;
    final to = f['to_account'] != null
        ? _named(f['to_account'], lex.accounts, (a) => a.terms)
        : (toCur != fromCur ? _account(null, toCur) : null);
    final amount = _minor(f['amount'], fromCur);
    final toAmount = toCur == fromCur ? amount : _minor(f['to_amount'], toCur);
    int? rate;
    if (toCur != fromCur && amount != null && toAmount != null && amount > 0 && toAmount > 0) {
      final (base, quote) = ratePair(fromCur, toCur, lex.baseCurrency);
      final fromIsBase = base == fromCur;
      rate = rateFromAmounts(
        baseMinor: fromIsBase ? amount : toAmount,
        base: base,
        quoteMinor: fromIsBase ? toAmount : amount,
        quote: quote,
      );
    }
    var confidence = 100;
    if (amount == null) confidence -= 40;
    if (from == null) confidence -= 20;
    if (to == null) confidence -= 20;
    return TransferProposal(
      confidence: confidence,
      fromAccountId: from?.id,
      toAccountId: to?.id,
      amountMinor: amount,
      toAmountMinor: toAmount,
      rateE6: rate,
      transferKind: 'transfer',
      occurredAt: at,
    );
  }

  DebtProposal _debt() {
    final account = _account(f['account'], f['currency']);
    final currency = f['currency'] ?? account?.currency ?? lex.baseCurrency;
    final amount = _minor(f['amount'], currency);
    var confidence = 100;
    if (amount == null) confidence -= 40;
    if (f['counterparty'] == null) confidence -= 20;
    if (f['debt_direction'] == null) confidence -= 20;
    if (account == null) confidence -= 20;
    return DebtProposal(
      confidence: confidence.clamp(0, 100),
      counterparty: f['counterparty'],
      direction: f['debt_direction'],
      leg: f['debt_leg'],
      amountMinor: amount,
      currency: currency,
      accountId: account?.id,
      occurredAt: at,
    );
  }

  TaskProposal _task(String kind) {
    final d = f['date'] == null ? null : _parseDate(f['date']!);
    final t = f['time'] == null ? null : _parseTime(f['time']!);
    DateTime? due;
    if (d != null) {
      due = DateTime(d.year, d.month, d.day, t?.$1 ?? 0, t?.$2 ?? 0);
    } else if (t != null) {
      due = DateTime(now.year, now.month, now.day, t.$1, t.$2);
      if (due.isBefore(now)) due = due.add(const Duration(days: 1));
    }
    final title = f['title'] ?? f['description'] ?? '';
    return TaskProposal(
      title: title,
      confidence: title.isEmpty ? 40 : 100,
      due: due,
      workspaceId: f['workspace'] == null ? null : workspaceId,
      kind: kind,
      place: f['place'],
      hasTime: t != null,
    );
  }
}
