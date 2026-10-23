import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_format.dart';
import '../../../core/theme/tokens.dart';
import '../../backup/backup_screen.dart' show backupFilesProvider;
import '../data/categories_repository.dart' show bucketLabel, categoryLabel;
import '../data/finance_providers.dart';
import '../data/reports_query.dart';
import '../domain/buckets_math.dart';
import '../domain/installments.dart';
import '../domain/reports.dart';
import '../export/csv_export.dart';
import '../export/pdf_export.dart';
import 'charts/balance_chart.dart';
import 'charts/bucket_chart.dart';
import 'charts/category_chart.dart';
import 'charts/income_expense_chart.dart';
import 'ui_format.dart';
import 'widgets/money_text.dart';
import 'widgets/panel.dart';

enum ReportRange { thisMonth, lastMonth, last3, last6, last12, custom }

/// [from] inclusive, [to] exclusive, local midnight.
(DateTime, DateTime) rangeBounds(ReportRange r, DateTime now, DateTimeRange? custom) {
  DateTime month(int back) => DateTime(now.year, now.month - back);
  return switch (r) {
    ReportRange.thisMonth => (month(0), month(-1)),
    ReportRange.lastMonth => (month(1), month(0)),
    ReportRange.last3 => (month(2), month(-1)),
    ReportRange.last6 => (month(5), month(-1)),
    ReportRange.last12 => (month(11), month(-1)),
    ReportRange.custom => (
      DateTime(custom!.start.year, custom.start.month, custom.start.day),
      DateTime(custom.end.year, custom.end.month, custom.end.day + 1),
    ),
  };
}

/// File names like `life-manager-transactions-2026-10-23.csv`.
String exportFileName(String report, DateTime day, String ext) {
  String two(int v) => v.toString().padLeft(2, '0');
  return 'life-manager-$report-${day.year}-${two(day.month)}-${two(day.day)}.$ext';
}

/// Category rows: the top eight, then everything else summed as "other".
List<(String, int)> topCategories(List<(int, int)> rows, String Function(int id) name, String other) {
  final top = [for (final (id, v) in rows.take(8)) (name(id), v)];
  final rest = rows.skip(8).fold<int>(0, (s, r) => s + r.$2);
  return [...top, if (rows.length > 8) (other, rest)];
}

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportRange _range = ReportRange.thisMonth;
  DateTimeRange? _custom;
  Period _period = Period.month;
  int? _workspace;
  String? _currency;
  bool _table = false;

  String _rangeLabel(AppLocalizations l, ReportRange r) => switch (r) {
    ReportRange.thisMonth => l.repThisMonth,
    ReportRange.lastMonth => l.repLastMonth,
    ReportRange.last3 => l.repLastMonths(3),
    ReportRange.last6 => l.repLastMonths(6),
    ReportRange.last12 => l.repLastMonths(12),
    ReportRange.custom =>
      _custom == null ? l.repCustom : '${formatDate(context, _custom!.start)} – ${formatDate(context, _custom!.end)}',
  };

  String _periodLabel(AppLocalizations l, Period p) => switch (p) {
    Period.day => l.repDaily,
    Period.week => l.repWeekly,
    Period.month => l.repMonthly,
  };

  /// A bottom sheet of options; `null` from [allLabel] means "every workspace".
  Future<(bool, T?)?> _pick<T>(String title, List<(T, String)> options, T? current, {String? allLabel}) {
    final k = context.tokens;
    Widget tile(Key key, String label, bool selected, (bool, T?) result) => ListTile(
      key: key,
      title: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: selected ? Icon(Icons.check_rounded, color: k.accent) : null,
      onTap: () => Navigator.pop(context, result),
    );
    return showModalBottomSheet<(bool, T?)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(title, style: Theme.of(context).textTheme.titleMedium),
              ),
              if (allLabel != null) tile(const ValueKey('option-all'), allLabel, current == null, (true, null)),
              for (final (value, label) in options)
                tile(ValueKey('option-${value is Enum ? value.name : value}'), label, current == value, (true, value)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickRange() async {
    final l = context.l10n;
    final picked = await _pick(l.repRange, [
      for (final r in ReportRange.values) (r, r == ReportRange.custom ? l.repCustom : _rangeLabel(l, r)),
    ], _range);
    if (picked == null || !mounted) return;
    if (picked.$2 == ReportRange.custom) {
      final now = DateTime.now();
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(now.year + 1, 12, 31),
        initialDateRange: _custom ?? DateTimeRange(start: DateTime(now.year, now.month), end: now),
      );
      if (range == null) return;
      setState(() {
        _custom = range;
        _range = ReportRange.custom;
      });
    } else {
      setState(() => _range = picked.$2!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final base = ref.watch(settingsProvider).value?.baseCurrency ?? 'IQD';
    final currency = _currency ?? base;
    final workspaces = ref.watch(workspacesProvider).value ?? const <Workspace>[];
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final debts = ref.watch(debtSummariesProvider).value ?? const <DebtSummary>[];
    final (from, to) = rangeBounds(_range, DateTime.now(), _custom);
    final lastMonth = DateTime(to.subtract(const Duration(days: 1)).year, to.subtract(const Duration(days: 1)).month);
    final buckets = ref.watch(bucketStatusForMonthProvider(lastMonth)).value ?? const <BucketStatus>[];
    final data = ref.watch(reportDataProvider(to)).value;
    final scope = ReportScope(
      from: from,
      to: to,
      currency: currency,
      workspaceIds: _workspace == null ? null : {_workspace!},
    );
    String wsName(int id) => workspaces.where((w) => w.id == id).firstOrNull?.name ?? '';
    String catName(int id) => id == 0
        ? l.finUncategorised
        : categories.where((c) => c.id == id).map((c) => categoryLabel(c, l)).firstOrNull ?? '?';
    final scopedDebts = outstandingDebts(debts).where((d) => scope.includes(d.debt.workspaceId)).toList();

    Widget chip(String key, String label, VoidCallback onTap) => Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ActionChip(
        key: ValueKey(key),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        avatar: Icon(Icons.expand_more_rounded, size: 18, color: k.textMuted),
        onPressed: onTap,
      ),
    );

    final tabs = [
      (l.repTabIncomeExpense, true),
      (l.repTabCategory, true),
      (l.repTabWorkspace, true),
      (l.repTabCashFlow, true),
      (l.repTabBalance, true),
      (l.finBuckets, true),
      (l.repTabDebts, false),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.finReports),
          actions: [
            PopupMenuButton<String>(
              key: const ValueKey('report-export'),
              tooltip: l.repExport,
              icon: const Icon(Icons.ios_share_rounded),
              enabled: data != null,
              onSelected: (kind) => _export(kind, data!, scope, scopedDebts, catName, wsName),
              itemBuilder: (_) => [
                PopupMenuItem(
                  key: const ValueKey('export-csv'),
                  value: 'csv',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.table_chart_outlined),
                    title: Text(l.repExportCsv),
                  ),
                ),
                PopupMenuItem(
                  key: const ValueKey('export-pdf'),
                  value: 'pdf',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.picture_as_pdf_outlined),
                    title: Text(l.repExportPdf),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final (label, _) in tabs) Tab(text: label)],
          ),
        ),
        body: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
              child: Row(
                children: [
                  chip('report-range', _rangeLabel(l, _range), _pickRange),
                  chip('report-period', _periodLabel(l, _period), () async {
                    final p = await _pick(l.repGroupBy, [
                      for (final p in Period.values) (p, _periodLabel(l, p)),
                    ], _period);
                    if (p != null) setState(() => _period = p.$2!);
                  }),
                  chip('report-workspace', _workspace == null ? l.repAllWorkspaces : wsName(_workspace!), () async {
                    final w = await _pick(
                      l.finWorkspace,
                      [for (final w in workspaces) (w.id, w.name)],
                      _workspace,
                      allLabel: l.repAllWorkspaces,
                    );
                    if (w != null) setState(() => _workspace = w.$2);
                  }),
                  chip('report-currency', currency, () async {
                    final c = await _pick(l.finCurrency, [
                      for (final c in {'IQD', 'USD', base}) (c, c),
                    ], currency);
                    if (c != null) setState(() => _currency = c.$2);
                  }),
                ],
              ),
            ),
            Expanded(
              child: data == null
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _incomeExpense(data, scope),
                        _category(data, scope, catName),
                        _workspaceTab(data, scope, wsName),
                        _cashFlow(data, scope),
                        _balance(data, scope),
                        _buckets(buckets, base, lastMonth),
                        _debtsTab(scopedDebts),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- tabs ----

  String _periodName(DateTime d, {bool short = false}) => switch (_period) {
    Period.month => (short ? DateFormat.MMM : DateFormat.yMMM)(dateLocaleOf(context)).format(d),
    _ => short ? '${d.day}/${d.month}' : formatDate(context, d),
  };

  Widget _incomeExpense(ReportData data, ReportScope scope) {
    final l = context.l10n;
    final r = incomeVsExpense(data.transactions, scope, _period, data.context);
    final income = r.data.fold<int>(0, (s, p) => s + p.income);
    final expense = r.data.fold<int>(0, (s, p) => s + p.expense);
    final c = scope.currency;
    return _TabBody(
      header: _Totals([
        ('total-income', l.finIncome, Money(income, c), false),
        ('total-expense', l.finExpense, Money(expense, c), false),
        ('total-surplus', l.finSurplus, Money(income - expense, c), true),
      ]),
      result: r,
      showTable: _table,
      onToggle: _toggle,
      empty: r.data.every((p) => p.income == 0 && p.expense == 0),
      chart: PairBarChart(
        labels: [for (final p in r.data) _periodName(p.period, short: true)],
        first: [for (final p in r.data) p.income],
        second: [for (final p in r.data) p.expense],
        net: [for (final p in r.data) p.surplus],
        currency: c,
        firstName: l.finIncome,
        secondName: l.finExpense,
        netName: l.finSurplus,
      ),
      table: _DataTable(
        headers: [l.repPeriodColumn, l.finIncome, l.finExpense, l.finSurplus],
        rows: [
          for (final p in r.data)
            (_periodName(p.period), [Money(p.income, c), Money(p.expense, c), Money(p.surplus, c)]),
        ],
      ),
    );
  }

  Widget _category(ReportData data, ReportScope scope, String Function(int) catName) {
    final l = context.l10n;
    final r = byCategory(data.transactions, scope, data.context);
    final rows = topCategories(r.data, catName, l.repOther);
    return _TabBody(
      result: r,
      showTable: _table,
      onToggle: _toggle,
      empty: rows.isEmpty,
      chart: RankedBars(rows: rows, currency: scope.currency),
      table: _DataTable(
        headers: [l.finCategory, l.finExpense],
        rows: [
          for (final (name, v) in rows) (name, [Money(v, scope.currency)]),
        ],
      ),
    );
  }

  Widget _workspaceTab(ReportData data, ReportScope scope, String Function(int) wsName) {
    final l = context.l10n;
    final r = byWorkspace(data.transactions, scope, data.context);
    final c = scope.currency;
    return _TabBody(
      result: r,
      showTable: _table,
      onToggle: _toggle,
      empty: r.data.isEmpty,
      chart: PairBarChart(
        labels: [for (final (id, _, _) in r.data) wsName(id)],
        first: [for (final (_, i, _) in r.data) i],
        second: [for (final (_, _, e) in r.data) e],
        net: [for (final (_, i, e) in r.data) i - e],
        currency: c,
        firstName: l.finIncome,
        secondName: l.finExpense,
        netName: l.finSurplus,
      ),
      table: _DataTable(
        headers: [l.finWorkspace, l.finIncome, l.finExpense, l.finSurplus],
        rows: [
          for (final (id, i, e) in r.data) (wsName(id), [Money(i, c), Money(e, c), Money(i - e, c)]),
        ],
      ),
    );
  }

  Widget _cashFlow(ReportData data, ReportScope scope) {
    final l = context.l10n;
    final r = cashFlow(data.transactions, scope, _period, data.context);
    final c = scope.currency;
    return _TabBody(
      result: r,
      showTable: _table,
      onToggle: _toggle,
      empty: r.data.every((p) => p.inflow == 0 && p.outflow == 0),
      chart: PairBarChart(
        labels: [for (final p in r.data) _periodName(p.period, short: true)],
        first: [for (final p in r.data) p.inflow],
        second: [for (final p in r.data) p.outflow],
        net: [for (final p in r.data) p.net],
        currency: c,
        firstName: l.repMoneyIn,
        secondName: l.repMoneyOut,
        netName: l.repNet,
      ),
      table: _DataTable(
        headers: [l.repPeriodColumn, l.repMoneyIn, l.repMoneyOut, l.repNet],
        rows: [
          for (final p in r.data) (_periodName(p.period), [Money(p.inflow, c), Money(p.outflow, c), Money(p.net, c)]),
        ],
      ),
    );
  }

  Widget _balance(ReportData data, ReportScope scope) {
    final l = context.l10n;
    final accounts = {
      for (final e in data.context.workspaceOfAccount.entries)
        if (scope.includes(e.value)) e.key,
    };
    final r = balanceOverTime(data.transactions, data.openingByAccount, accounts, scope, data.context);
    return _TabBody(
      result: r,
      showTable: _table,
      onToggle: _toggle,
      empty: r.data.points.isEmpty,
      chart: BalanceLineChart(points: r.data.points, currency: scope.currency),
      table: _DataTable(
        headers: [l.finDate, l.repBalance],
        rows: [
          for (final (d, v) in r.data.points) (formatDate(context, d), [Money(v, scope.currency)]),
        ],
      ),
    );
  }

  Widget _buckets(List<BucketStatus> buckets, String base, DateTime month) {
    final l = context.l10n;
    final name = DateFormat.yMMMM(dateLocaleOf(context)).format(month);
    return _TabBody(
      note: l.repBucketsMonth(name, base),
      showTable: _table,
      onToggle: _toggle,
      empty: buckets.isEmpty,
      chart: BucketBars(statuses: buckets, currency: base),
      table: _DataTable(
        headers: [l.finBuckets, l.finAllocated, l.finSpent, l.finAvailable],
        rows: [
          for (final s in buckets)
            (
              bucketLabel(s.bucket, l),
              [Money(s.allocatedMinor, base), Money(s.spentMinor, base), Money(s.availableMinor, base)],
            ),
        ],
      ),
    );
  }

  Widget _debtsTab(List<DebtSummary> debts) {
    final l = context.l10n;
    return _TabBody(
      showTable: true,
      empty: debts.isEmpty,
      chart: const SizedBox.shrink(),
      table: _DataTable(
        headers: [l.finCounterparty, l.finRemaining],
        rows: [
          for (final d in debts)
            (
              '${d.debt.counterparty} · ${d.debt.direction == 'owed_to_me' ? l.finOwedToMe : l.finOwedByMe}',
              [Money(d.remainingMinor, d.debt.currencyCode)],
            ),
        ],
      ),
    );
  }

  void _toggle() => setState(() => _table = !_table);

  // ---- export ----

  Future<void> _export(
    String kind,
    ReportData data,
    ReportScope scope,
    List<DebtSummary> debts,
    String Function(int) catName,
    String Function(int) wsName,
  ) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('export-notice'),
        icon: const Icon(Icons.lock_open_rounded),
        title: Text(kind == 'csv' ? l.repExportCsv : l.repExportPdf),
        content: Text(l.repNotEncrypted),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('export-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final today = DateTime.now();
      final Uint8List bytes;
      final String name;
      if (kind == 'csv') {
        bytes = utf8.encode(_csv(data, scope, wsName, catName));
        name = exportFileName('transactions', today, 'csv');
      } else {
        bytes = await reportPdf(_pdfData(data, scope, debts, catName, wsName));
        name = exportFileName('report', today, 'pdf');
      }
      final saved = await ref.read(backupFilesProvider).save(name, bytes);
      if (saved) messenger.showSnackBar(SnackBar(content: Text(l.finSaved)));
    } catch (e) {
      AppLogger.error('report export failed', e.runtimeType);
      messenger.showSnackBar(SnackBar(content: Text(l.repExportFailed)));
    }
  }

  String _csv(ReportData data, ReportScope scope, String Function(int) wsName, String Function(int) catName) {
    final l = context.l10n;
    final txs = [
      for (final t in data.transactions)
        if (!t.occurredAt.toLocal().isBefore(scope.from) &&
            t.occurredAt.toLocal().isBefore(scope.to) &&
            (scope.includes(t.workspaceId) ||
                (t.toAccountId != null && scope.includes(data.context.workspaceOfAccount[t.toAccountId] ?? -1))))
          t,
    ]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return transactionsCsv(
      txs,
      CsvLabels(
        type: (t) => txTypeLabel(t, l),
        workspaces: {for (final id in data.context.workspaceOfAccount.values.toSet()) id: wsName(id)},
        accounts: {for (final a in data.accounts) a.id: shortAccountName(a.name, wsName(a.workspaceId))},
        accountCurrencies: data.context.currencyOfAccount,
        categories: {for (final t in txs) ?t.categoryId: catName(t.categoryId ?? 0)},
      ),
    );
  }

  ReportPdfData _pdfData(
    ReportData data,
    ReportScope scope,
    List<DebtSummary> debts,
    String Function(int) catName,
    String Function(int) wsName,
  ) {
    final l = context.l10n;
    final lang = langOf(context);
    String money(Money m) => formatMoney(m, localeCode: lang);
    final ie = incomeVsExpense(data.transactions, scope, Period.month, data.context);
    final cats = byCategory(data.transactions, scope, data.context);
    final income = ie.data.fold<int>(0, (s, p) => s + p.income);
    final expense = ie.data.fold<int>(0, (s, p) => s + p.expense);
    final c = scope.currency;
    final skipped = ie.skippedCount + cats.skippedCount;
    final missing = {...ie.missingRates, ...cats.missingRates};
    final last = scope.to.subtract(const Duration(days: 1));
    return ReportPdfData(
      localeCode: lang,
      title: l.finReports,
      range: '${formatDate(context, scope.from)} – ${formatDate(context, last)}',
      scope: '${scope.workspaceIds == null ? l.repAllWorkspaces : wsName(scope.workspaceIds!.single)} · $c',
      note: skipped == 0 ? null : l.repSkipped(skipped, missing.join(', ')),
      summaryTitle: l.repTabIncomeExpense,
      summary: [
        (l.finIncome, money(Money(income, c))),
        (l.finExpense, money(Money(expense, c))),
        (l.finSurplus, money(Money(income - expense, c))),
      ],
      categoryTitle: l.repTabCategory,
      categories: [for (final (n, v) in topCategories(cats.data, catName, l.repOther)) (n, money(Money(v, c)))],
      debtsTitle: l.repTabDebts,
      debts: [for (final d in debts) (d.debt.counterparty, money(Money(d.remainingMinor, d.debt.currencyCode)))],
    );
  }
}

/// One tab: optional header, then a panel with the chart or its table.
class _TabBody extends StatelessWidget {
  const _TabBody({
    this.header,
    this.result,
    this.note,
    required this.showTable,
    this.onToggle,
    required this.empty,
    required this.chart,
    required this.table,
  });

  final Widget? header;
  final ReportResult<Object?>? result;
  final String? note;
  final bool showTable;
  final VoidCallback? onToggle;
  final bool empty;
  final Widget chart;
  final Widget table;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: k.textMuted);
    final skipped = result?.skippedCount ?? 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 112),
      children: [
        ?header,
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (onToggle != null)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    key: const ValueKey('table-toggle'),
                    onPressed: onToggle,
                    icon: Icon(showTable ? Icons.bar_chart_rounded : Icons.table_rows_outlined, size: 18),
                    label: Text(showTable ? l.repShowChart : l.repShowTable),
                  ),
                ),
              if (note != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(note!, style: muted),
                ),
              if (skipped > 0)
                Padding(
                  key: const ValueKey('report-skipped'),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: k.warning),
                      const SizedBox(width: 6),
                      Expanded(child: Text(l.repSkipped(skipped, result!.missingRates.join(', ')), style: muted)),
                    ],
                  ),
                ),
              if (empty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(l.repNothing, textAlign: TextAlign.center, style: muted),
                )
              else
                AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: showTable ? table : chart),
            ],
          ),
        ),
      ],
    );
  }
}

/// The three headline totals above the income vs expense chart.
class _Totals extends StatelessWidget {
  const _Totals(this.items);

  final List<(String, String, Money, bool)> items;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    return Panel(
      child: Row(
        children: [
          for (final (key, label, m, signed) in items)
            Expanded(
              key: ValueKey(key),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: k.textMuted),
                  ),
                  const SizedBox(height: 4),
                  FittedMoney(
                    m,
                    signed: signed,
                    alignment: AlignmentDirectional.centerStart,
                    style: text.titleMedium?.copyWith(color: k.text, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The same figures as the chart, one row per bar or point.
class _DataTable extends StatelessWidget {
  const _DataTable({required this.headers, required this.rows});

  final List<String> headers;
  final List<(String, List<Money>)> rows;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final head = text.labelSmall?.copyWith(color: k.textMuted);
    final cell = text.bodySmall?.copyWith(color: k.text);
    Widget pad(Widget w) => Padding(padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2), child: w);
    return Table(
      key: const ValueKey('report-table'),
      columnWidths: {
        0: const FlexColumnWidth(1.4),
        for (var i = 1; i < headers.length; i++) i: const FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(horizontalInside: BorderSide(color: k.border)),
      children: [
        TableRow(
          children: [
            for (var i = 0; i < headers.length; i++)
              pad(Text(headers[i], style: head, maxLines: 2, textAlign: i == 0 ? TextAlign.start : TextAlign.end)),
          ],
        ),
        for (final (label, values) in rows)
          TableRow(
            children: [
              pad(Text(label, style: cell, maxLines: 2, overflow: TextOverflow.ellipsis)),
              for (final m in values) pad(FittedMoney(m, style: cell)),
            ],
          ),
      ],
    );
  }
}
