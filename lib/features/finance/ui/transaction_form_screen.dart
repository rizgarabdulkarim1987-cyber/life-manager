import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/money/conversion.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/tokens.dart';
import '../../capture/domain/proposal.dart';
import '../data/categories_repository.dart';
import '../data/finance_providers.dart';
import '../data/transactions_repository.dart';
import 'ui_format.dart';
import 'widgets/account_picker.dart';
import 'widgets/allocation_editor.dart';
import 'widgets/amount_field.dart';
import 'widgets/money_text.dart';

const kFormTypes = ['expense', 'income', 'refund'];

/// Add or edit an income, expense or refund. [editId] loads an existing row;
/// otherwise [initial] pre-fills a new one.
class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key, this.initial, this.editId});

  final TransactionDraft? initial;
  final int? editId;

  @override
  ConsumerState<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  bool _loaded = false;
  Transaction? _editing;
  bool _hasAllocations = false;

  late String _type;
  int? _accountId;
  int? _amount;
  int? _categoryId;
  late DateTime _at;
  final _description = TextEditingController();
  bool _pending = false;
  String? _bucketTag;

  bool _allocate = false;
  Map<int, int> _allocation = const {};

  /// The amount in the base currency, or null when it has no rate.
  int? _baseTotal;
  bool _rateMissing = false;
  int _baseSeq = 0;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _type = kFormTypes.contains(d?.type) ? d!.type! : 'expense';
    _accountId = d?.accountId;
    _amount = d?.amountMinor;
    _categoryId = d?.categoryId;
    _at = (d?.occurredAt ?? DateTime.now()).toLocal();
    _description.text = d?.description ?? '';
    _bucketTag = d?.bucketTag;
    _load();
  }

  Future<void> _load() async {
    if (widget.editId != null) {
      final db = ref.read(appDatabaseProvider);
      final t = await ref.read(transactionsRepositoryProvider).get(widget.editId!);
      if (t != null) {
        _editing = t;
        _type = kFormTypes.contains(t.type) ? t.type : 'expense';
        _accountId = t.accountId;
        _amount = t.amountMinor;
        _categoryId = t.categoryId;
        _at = t.occurredAt.toLocal();
        _description.text = t.description ?? '';
        _pending = t.paymentStatus == 'pending';
        _bucketTag = t.bucketTag;
        _hasAllocations = (await (db.select(
          db.bucketAllocations,
        )..where((a) => a.transactionId.equals(t.id))).get()).isNotEmpty;
      }
    }
    if (_accountId == null) {
      final accounts = await ref.read(accountsRepositoryProvider).watchAll().first;
      _accountId = accounts.firstOrNull?.id;
    }
    if (!mounted) return;
    setState(() => _loaded = true);
    _refreshBase();
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Account? get _account =>
      (ref.read(accountsProvider).value ?? const <Account>[]).where((a) => a.id == _accountId).firstOrNull;

  /// Converts the amount to the base currency at the transaction's date.
  Future<void> _refreshBase() async {
    final seq = ++_baseSeq;
    final account = _account;
    final base = ref.read(settingsProvider).value?.baseCurrency ?? 'IQD';
    int? total;
    var missing = false;
    if (account != null && _amount != null && _amount! > 0) {
      if (account.currencyCode == base) {
        total = _amount;
      } else {
        final r = await ref.read(ratesRepositoryProvider).rateOn(account.currencyCode, base, _at.toUtc());
        if (r == null) {
          missing = true;
        } else {
          total = convert(Money(_amount!, account.currencyCode), base, r).minor;
        }
      }
    } else if (account != null && account.currencyCode != base) {
      missing = await ref.read(ratesRepositoryProvider).rateOn(account.currencyCode, base, _at.toUtc()) == null;
    }
    if (!mounted || seq != _baseSeq) return;
    setState(() {
      _baseTotal = total;
      _rateMissing = missing;
      if (missing || total == null) _allocate = false;
    });
  }

  bool get _canAllocate =>
      _type == 'income' && !_pending && !_rateMissing && _baseTotal != null && _baseTotal! > 0 && !_hasAllocations;

  bool get _valid {
    if (_accountId == null || _amount == null || _amount! <= 0) return false;
    if (_allocate) {
      final sum = _allocation.values.fold<int>(0, (s, x) => s + x);
      if (_baseTotal == null || sum > _baseTotal!) return false;
    }
    return true;
  }

  TransactionsCompanion _changes() => TransactionsCompanion(
    type: Value(_type),
    accountId: Value(_accountId!),
    amountMinor: Value(_amount!),
    categoryId: Value(_categoryId),
    occurredAt: Value(_at.toUtc()),
    description: Value(_description.text.trim().isEmpty ? null : _description.text.trim()),
    bucketTag: Value(_type == 'expense' ? _bucketTag : null),
    paymentStatus: Value(_type == 'income' && _pending ? 'pending' : 'paid'),
  );

  Future<void> _save() async {
    final repo = ref.read(transactionsRepositoryProvider);
    final buckets = ref.read(bucketsRepositoryProvider);
    final db = ref.read(appDatabaseProvider);
    final allocate = _allocate && _canAllocate;
    if (_editing == null) {
      await db.transaction(() async {
        final id = await repo.addSimple(
          type: _type,
          accountId: _accountId!,
          amountMinor: _amount!,
          occurredAt: _at.toUtc(),
          categoryId: _categoryId,
          description: _description.text,
          bucketTag: _type == 'expense' ? _bucketTag : null,
          paymentStatus: _type == 'income' && _pending ? 'pending' : 'paid',
        );
        if (allocate) await buckets.allocate(id, _allocation);
      });
    } else {
      final id = _editing!.id;
      try {
        await repo.update(id, _changes());
      } on AllocationsLocked {
        if (!mounted || !await _confirmClear()) return;
        await repo.update(id, _changes(), clearAllocations: true);
      }
      if (allocate) await buckets.allocate(id, _allocation);
    }
    if (mounted) context.pop();
  }

  Future<bool> _confirmClear() async {
    final l = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            key: const ValueKey('clear-allocations-dialog'),
            title: Text(l.finClearAllocationsTitle),
            content: Text(l.finClearAllocationsBody),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
              FilledButton(
                key: const ValueKey('clear-allocations'),
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.finClearAndSave),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (d == null) return;
    setState(() => _at = DateTime(d.year, d.month, d.day, _at.hour, _at.minute));
    _refreshBase();
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_at));
    if (t == null) return;
    setState(() => _at = DateTime(_at.year, _at.month, _at.day, t.hour, t.minute));
  }

  String _title(AppLocalizations l) => _editing != null
      ? l.finEditTransaction
      : switch (_type) {
          'income' => l.finAddIncome,
          'refund' => l.finAddRefund,
          _ => l.finAddExpense,
        };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    // Watched before the loading check so the providers run while the row loads.
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final base = ref.watch(settingsProvider).value?.baseCurrency ?? 'IQD';
    if (!_loaded) return Scaffold(appBar: AppBar());

    final account = accounts.where((a) => a.id == _accountId).firstOrNull;
    final currency = account?.currencyCode ?? 'IQD';
    final kind = _type == 'income' ? 'income' : 'expense';
    final categories = (ref.watch(categoriesProvider).value ?? const <Category>[])
        .where((c) => c.kind == kind)
        .toList();
    final buckets = ref.watch(bucketsProvider).value ?? const <Bucket>[];
    final locale = dateLocaleOf(context);

    return Scaffold(
      appBar: AppBar(title: Text(_title(l))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SegmentedButton<String>(
            key: const ValueKey('tx-type'),
            segments: [
              ButtonSegment(value: 'expense', label: Text(l.typeExpense, maxLines: 1)),
              ButtonSegment(value: 'income', label: Text(l.typeIncome, maxLines: 1)),
              ButtonSegment(value: 'refund', label: Text(l.typeRefund, maxLines: 1)),
            ],
            selected: {_type},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              final next = s.first;
              final nextKind = next == 'income' ? 'income' : 'expense';
              if (nextKind != kind) _categoryId = null;
              if (next != 'expense') _bucketTag = null;
              if (next != 'income') _allocate = false;
              _type = next;
            }),
          ),
          const SizedBox(height: 20),
          AmountField(
            key: const ValueKey('amount-field'),
            fieldKey: const ValueKey('amount'),
            currency: currency,
            initialMinor: _amount,
            large: true,
            label: l.finAmount,
            onMinor: (v) {
              setState(() => _amount = v);
              _refreshBase();
            },
          ),
          const SizedBox(height: 16),
          AccountPicker(
            fieldKey: const ValueKey('tx-account'),
            label: l.finAccount,
            value: _accountId,
            onChanged: (id) {
              setState(() => _accountId = id);
              _refreshBase();
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            key: ValueKey('tx-category-$kind'),
            initialValue: categories.any((c) => c.id == _categoryId) ? _categoryId : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.finCategory),
            items: [
              DropdownMenuItem<int?>(value: null, child: Text(l.finNoCategory)),
              for (final c in categories)
                DropdownMenuItem<int?>(
                  value: c.id,
                  child: Text(categoryLabel(c, l), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('tx-date'),
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text(DateFormat.yMMMd(locale).format(_at), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('tx-time'),
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text(DateFormat.Hm('en').format(_at), textDirection: TextDirection.ltr),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('tx-description'),
            controller: _description,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(labelText: l.finDescription),
          ),
          if (_type == 'income') ...[
            const SizedBox(height: 8),
            SwitchListTile(
              key: const ValueKey('tx-pending'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.finNotReceived),
              subtitle: Text(l.finNotReceivedHint),
              value: _pending,
              onChanged: (v) => setState(() {
                _pending = v;
                if (v) _allocate = false;
              }),
            ),
            if (!_hasAllocations)
              SwitchListTile(
                key: const ValueKey('tx-allocate'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.finAllocate),
                subtitle: _rateMissing
                    ? Text(l.finAllocateNoRate(currency), style: TextStyle(color: k.warning))
                    : _pending
                    ? Text(l.finAllocatePending)
                    : _baseTotal != null && currency != base
                    ? MoneyText(Money(_baseTotal!, base), style: text.bodyMedium?.copyWith(color: k.textMuted))
                    : null,
                value: _allocate && _canAllocate,
                onChanged: _canAllocate ? (v) => setState(() => _allocate = v) : null,
              ),
            if (_allocate && _canAllocate) ...[
              const SizedBox(height: 8),
              AllocationEditor(
                totalBaseMinor: _baseTotal!,
                buckets: buckets,
                currency: base,
                onChanged: (m) => setState(() => _allocation = m),
              ),
            ],
          ],
          if (_type == 'expense') ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              key: const ValueKey('tx-bucket-tag'),
              initialValue: _bucketTag,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.finBucketTag),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(l.finBucketNone)),
                DropdownMenuItem<String?>(value: 'emergency', child: Text(l.bucket_emergency)),
                DropdownMenuItem<String?>(value: 'investment', child: Text(l.bucket_investment)),
              ],
              onChanged: (v) => setState(() => _bucketTag = v),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            key: const ValueKey('tx-save'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _valid ? _save : null,
            child: Text(l.save),
          ),
        ),
      ),
    );
  }
}
