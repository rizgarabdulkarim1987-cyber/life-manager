import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../data/categories_repository.dart';
import '../data/finance_providers.dart';
import '../data/transactions_repository.dart';
import 'ui_format.dart';
import 'widgets/transaction_list.dart';

const _types = ['income', 'expense', 'refund', 'adjustment', 'transfer', 'debt_payment'];

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, this.accountId, this.workspaceId, this.categoryId, this.type});

  final int? accountId;
  final int? workspaceId;
  final int? categoryId;
  final String? type;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTimeRange? _range;
  int? _account;
  int? _workspace;
  int? _category;
  String? _type;
  String _text = '';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _account = widget.accountId;
    _workspace = widget.workspaceId;
    _category = widget.categoryId;
    _type = _types.contains(widget.type) ? widget.type : null;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _filtered =>
      _range != null ||
      _account != null ||
      _workspace != null ||
      _category != null ||
      _type != null ||
      _text.isNotEmpty;

  TxFilter get _filter => TxFilter(
    from: _range?.start.toUtc(),
    to: _range == null ? null : DateTime(_range!.end.year, _range!.end.month, _range!.end.day + 1).toUtc(),
    accountIds: _account == null ? null : {_account!},
    workspaceIds: _workspace == null ? null : {_workspace!},
    categoryIds: _category == null ? null : {_category!},
    types: _type == null ? null : {_type!},
    text: _text.isEmpty ? null : _text,
  );

  String get _filterKey => '$_range|$_account|$_workspace|$_category|$_type|$_text';

  String _typeLabel(String type, AppLocalizations l) => switch (type) {
    'income' => l.typeIncome,
    'expense' => l.typeExpense,
    'refund' => l.typeRefund,
    'adjustment' => l.typeAdjustment,
    'transfer' => l.typeTransfer,
    _ => l.typeDebtPayment,
  };

  /// A bottom sheet of options; returns the picked value, or `null` for "All".
  Future<void> _pick<T>(String title, List<(T, String)> options, T? current, void Function(T?) apply) async {
    final l = context.l10n;
    final k = context.tokens;
    final picked = await showModalBottomSheet<(bool, T?)>(
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
              ListTile(
                key: const ValueKey('option-all'),
                title: Text(l.filterAll),
                trailing: current == null ? Icon(Icons.check_rounded, color: k.accent) : null,
                onTap: () => Navigator.pop(context, (true, null)),
              ),
              for (final (value, label) in options)
                ListTile(
                  key: ValueKey('option-$value'),
                  title: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: current == value ? Icon(Icons.check_rounded, color: k.accent) : null,
                  onTap: () => Navigator.pop(context, (true, value)),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => apply(picked.$2));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final workspaces = ref.watch(workspacesProvider).value ?? const <Workspace>[];
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    String wsName(int id) => workspaces.where((w) => w.id == id).firstOrNull?.name ?? '';
    String accName(Account a) => '${shortAccountName(a.name, wsName(a.workspaceId))} · ${wsName(a.workspaceId)}';

    Widget chip(String key, String label, String? value, VoidCallback onTap) => Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: FilterChip(
        key: ValueKey(key),
        selected: value != null,
        showCheckmark: false,
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(value ?? label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        avatar: value == null ? null : Icon(Icons.filter_alt_rounded, size: 16, color: k.accent),
        onSelected: (_) => onTap(),
      ),
    );

    final rangeLabel = _range == null
        ? null
        : '${formatDate(context, _range!.start)} – ${formatDate(context, _range!.end)}';

    return Scaffold(
      appBar: AppBar(title: Text(l.finHistory)),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                key: const ValueKey('history-search'),
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l.finSearch,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l.clearFilters,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() {
                            _search.clear();
                            _text = '';
                          }),
                        ),
                ),
                onChanged: (v) => setState(() => _text = v.trim()),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  chip('filter-dates', l.filterDates, rangeLabel, () async {
                    final now = DateTime.now();
                    final r = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(now.year + 1, 12, 31),
                      initialDateRange: _range,
                    );
                    if (r != null) setState(() => _range = r);
                  }),
                  chip(
                    'filter-workspace',
                    l.finWorkspace,
                    _workspace == null ? null : wsName(_workspace!),
                    () => _pick(
                      l.finWorkspace,
                      [for (final w in workspaces) (w.id, w.name)],
                      _workspace,
                      (v) => _workspace = v,
                    ),
                  ),
                  chip(
                    'filter-account',
                    l.filterAccount,
                    _account == null ? null : accounts.where((a) => a.id == _account).map(accName).firstOrNull,
                    () => _pick(
                      l.filterAccount,
                      [for (final a in accounts) (a.id, accName(a))],
                      _account,
                      (v) => _account = v,
                    ),
                  ),
                  chip(
                    'filter-category',
                    l.filterCategory,
                    _category == null
                        ? null
                        : categories.where((c) => c.id == _category).map((c) => categoryLabel(c, l)).firstOrNull,
                    () => _pick(
                      l.filterCategory,
                      [for (final c in categories) (c.id, categoryLabel(c, l))],
                      _category,
                      (v) => _category = v,
                    ),
                  ),
                  chip(
                    'filter-type',
                    l.filterType,
                    _type == null ? null : _typeLabel(_type!, l),
                    () => _pick(l.filterType, [for (final t in _types) (t, _typeLabel(t, l))], _type, (v) => _type = v),
                  ),
                  if (_filtered)
                    TextButton(
                      key: const ValueKey('clear-filters'),
                      onPressed: () => setState(() {
                        _range = null;
                        _account = _workspace = _category = null;
                        _type = null;
                        _search.clear();
                        _text = '';
                      }),
                      child: Text(l.clearFilters),
                    ),
                ],
              ),
            ),
          ),
          TransactionSliverList(filter: _filter, filterKey: _filterKey, filtered: _filtered, accountId: _account),
          const SliverToBoxAdapter(child: SizedBox(height: 112)),
        ],
      ),
    );
  }
}
