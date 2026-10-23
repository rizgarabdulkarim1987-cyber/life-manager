import '../../../core/db/app_database.dart';
import '../../../core/money/conversion.dart';
import '../../../core/money/money.dart';
import 'installments.dart';
import 'ledger.dart';

enum Period { day, week, month }

/// Start of the period containing [local]. Weeks start on Saturday (Iraq).
DateTime periodStart(DateTime local, Period p) => switch (p) {
  Period.day => DateTime(local.year, local.month, local.day),
  Period.week => DateTime(local.year, local.month, local.day - (local.weekday - DateTime.saturday) % 7),
  Period.month => DateTime(local.year, local.month),
};

DateTime _next(DateTime start, Period p) => switch (p) {
  Period.day => DateTime(start.year, start.month, start.day + 1),
  Period.week => DateTime(start.year, start.month, start.day + 7),
  Period.month => DateTime(start.year, start.month + 1),
};

typedef RateLookup = RateValue? Function(String from, String to, DateTime day);

/// What the pure report functions need besides the rows.
class ReportContext {
  const ReportContext({
    required this.rates,
    required this.workspaceOfAccount,
    required this.currencyOfAccount,
    required this.debtDirection,
  });

  final RateLookup rates;
  final Map<int, int> workspaceOfAccount;
  final Map<int, String> currencyOfAccount;
  final Map<int, String> debtDirection;
}

/// [from] inclusive, [to] exclusive, local time. Every figure is in [currency].
class ReportScope {
  const ReportScope({required this.from, required this.to, this.workspaceIds, required this.currency});

  final DateTime from;
  final DateTime to;
  final Set<int>? workspaceIds;
  final String currency;

  bool includes(int workspaceId) => workspaceIds == null || workspaceIds!.contains(workspaceId);
}

/// A report plus what it had to leave out: rows in a currency with no rate
/// are counted here instead of guessed.
class ReportResult<T> {
  const ReportResult(this.data, {this.skippedCount = 0, this.missingRates = const {}});

  final T data;
  final int skippedCount;
  final Set<String> missingRates;
}

class IncomeExpense {
  const IncomeExpense(this.period, this.income, this.expense);

  final DateTime period;
  final int income;
  final int expense;

  int get surplus => income - expense;
}

class CashFlowPoint {
  const CashFlowPoint(this.period, this.inflow, this.outflow);

  final DateTime period;
  final int inflow;
  final int outflow;

  int get net => inflow - outflow;
}

class Series {
  const Series(this.points);

  final List<(DateTime, int)> points;
}

/// Converts amounts into the scope currency and tracks what it could not.
class _Converter {
  _Converter(this.scope, this.ctx);

  final ReportScope scope;
  final ReportContext ctx;
  int skipped = 0;
  final missing = <String>{};

  int? call(int minor, String currency, DateTime at) {
    if (currency == scope.currency) return minor;
    final r = ctx.rates(currency, scope.currency, at);
    if (r == null) {
      skipped++;
      missing.add(currency);
      return null;
    }
    return convert(Money(minor, currency), scope.currency, r).minor;
  }

  ReportResult<T> result<T>(T data) => ReportResult(data, skippedCount: skipped, missingRates: missing);
}

bool _inRange(Transaction t, ReportScope s) {
  final l = t.occurredAt.toLocal();
  return !l.isBefore(s.from) && l.isBefore(s.to);
}

List<DateTime> _periods(ReportScope s, Period p) {
  final out = <DateTime>[];
  for (var d = periodStart(s.from, p); d.isBefore(s.to); d = _next(d, p)) {
    out.add(d);
  }
  return out;
}

/// (workspaceId, income, expense) entries one transaction contributes, in its
/// own currency. Owner draws are an expense of the source workspace and income
/// of the target (spec §10.2); other transfers, adjustments, debt payments and
/// pending income are neither.
Iterable<(int ws, int income, int expense, int minor, String currency)> _ie(Transaction t, ReportContext c) sync* {
  switch (t.type) {
    case 'income' when t.paymentStatus == 'paid':
      yield (t.workspaceId, 1, 0, t.amountMinor, t.currencyCode);
    case 'expense':
      yield (t.workspaceId, 0, 1, t.amountMinor, t.currencyCode);
    case 'refund':
      yield (t.workspaceId, 0, 1, -t.amountMinor, t.currencyCode);
    case 'transfer' when t.transferKind == 'owner_draw':
      yield (t.workspaceId, 0, 1, t.amountMinor, t.currencyCode);
      final to = t.toAccountId!;
      yield (c.workspaceOfAccount[to]!, 1, 0, t.toAmountMinor!, c.currencyOfAccount[to]!);
  }
}

ReportResult<List<IncomeExpense>> incomeVsExpense(List<Transaction> txs, ReportScope s, Period p, ReportContext c) {
  final conv = _Converter(s, c);
  final income = <DateTime, int>{};
  final expense = <DateTime, int>{};
  for (final t in txs.where((t) => _inRange(t, s))) {
    final key = periodStart(t.occurredAt.toLocal(), p);
    for (final (ws, isIncome, _, minor, currency) in _ie(t, c)) {
      if (!s.includes(ws)) continue;
      final v = conv(minor, currency, t.occurredAt);
      if (v == null) continue;
      final m = isIncome == 1 ? income : expense;
      m[key] = (m[key] ?? 0) + v;
    }
  }
  return conv.result([for (final d in _periods(s, p)) IncomeExpense(d, income[d] ?? 0, expense[d] ?? 0)]);
}

/// Expenses net of refunds per category (0 = uncategorised), largest first.
ReportResult<List<(int, int)>> byCategory(List<Transaction> txs, ReportScope s, ReportContext c) {
  final conv = _Converter(s, c);
  final sums = <int, int>{};
  for (final t in txs.where((t) => _inRange(t, s) && s.includes(t.workspaceId))) {
    if (t.type != 'expense' && t.type != 'refund') continue;
    final v = conv(t.amountMinor, t.currencyCode, t.occurredAt);
    if (v == null) continue;
    final k = t.categoryId ?? 0;
    sums[k] = (sums[k] ?? 0) + (t.type == 'refund' ? -v : v);
  }
  final list = sums.entries.map((e) => (e.key, e.value)).toList()..sort((a, b) => b.$2.compareTo(a.$2));
  return conv.result(list);
}

/// (workspaceId, income, expense) per workspace, ordered by workspace id.
ReportResult<List<(int, int, int)>> byWorkspace(List<Transaction> txs, ReportScope s, ReportContext c) {
  final conv = _Converter(s, c);
  final income = <int, int>{};
  final expense = <int, int>{};
  for (final t in txs.where((t) => _inRange(t, s))) {
    for (final (ws, isIncome, _, minor, currency) in _ie(t, c)) {
      if (!s.includes(ws)) continue;
      final v = conv(minor, currency, t.occurredAt);
      if (v == null) continue;
      final m = isIncome == 1 ? income : expense;
      m[ws] = (m[ws] ?? 0) + v;
    }
  }
  final ids = {...income.keys, ...expense.keys}.toList()..sort();
  return conv.result([for (final id in ids) (id, income[id] ?? 0, expense[id] ?? 0)]);
}

/// Every cash movement of the scoped workspaces' accounts, including debt
/// payments. A transfer with both ends inside the scope is left out.
ReportResult<List<CashFlowPoint>> cashFlow(List<Transaction> txs, ReportScope s, Period p, ReportContext c) {
  final conv = _Converter(s, c);
  final inflow = <DateTime, int>{};
  final outflow = <DateTime, int>{};
  for (final t in txs.where((t) => _inRange(t, s))) {
    final accounts = [t.accountId, if (t.type == 'transfer') t.toAccountId!];
    final inScope = accounts.where((a) => s.includes(c.workspaceOfAccount[a]!)).toList();
    if (inScope.isEmpty || (t.type == 'transfer' && inScope.length == 2)) continue;
    final key = periodStart(t.occurredAt.toLocal(), p);
    for (final a in inScope) {
      final effect = balanceEffect(t, a, debtDirection: t.debtId == null ? null : c.debtDirection[t.debtId]);
      if (effect == 0) continue;
      final v = conv(effect.abs(), c.currencyOfAccount[a]!, t.occurredAt);
      if (v == null) continue;
      final m = effect > 0 ? inflow : outflow;
      m[key] = (m[key] ?? 0) + v;
    }
  }
  return conv.result([for (final d in _periods(s, p)) CashFlowPoint(d, inflow[d] ?? 0, outflow[d] ?? 0)]);
}

/// Daily closing balance of [accountIds], converted at each day's rate.
/// [txs] must include everything before the scope too, for the running total.
ReportResult<Series> balanceOverTime(
  List<Transaction> txs,
  Map<int, int> openingByAccount,
  Set<int> accountIds,
  ReportScope s,
  ReportContext c,
) {
  final conv = _Converter(s, c);
  final sorted = [...txs]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
  final running = {for (final a in accountIds) a: openingByAccount[a] ?? 0};
  var i = 0;
  final points = <(DateTime, int)>[];
  for (final day in _periods(s, Period.day)) {
    final end = _next(day, Period.day);
    while (i < sorted.length && sorted[i].occurredAt.toLocal().isBefore(end)) {
      final t = sorted[i++];
      for (final a in accountIds) {
        running[a] =
            running[a]! + balanceEffect(t, a, debtDirection: t.debtId == null ? null : c.debtDirection[t.debtId]);
      }
    }
    var total = 0;
    for (final a in accountIds) {
      total += conv(running[a]!, c.currencyOfAccount[a]!, day.toUtc()) ?? 0;
    }
    points.add((day, total));
  }
  return conv.result(Series(points));
}

/// Open debts, overdue first, then by next due date (undated last).
List<DebtSummary> outstandingDebts(List<DebtSummary> all) {
  final open = all.where((d) => d.remainingMinor > 0).toList();
  open.sort((a, b) {
    if (a.overdue != b.overdue) return a.overdue ? -1 : 1;
    if (a.nextDue == null || b.nextDue == null) return a.nextDue == null ? (b.nextDue == null ? 0 : 1) : -1;
    return a.nextDue!.compareTo(b.nextDue!);
  });
  return open;
}
