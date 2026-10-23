import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../finance/data/categories_repository.dart';
import '../../finance/data/finance_providers.dart';
import '../../finance/ui/buckets_screen.dart' show showPercentagesSheet;
import '../../finance/ui/transfer_form_screen.dart' show rateFromAmounts, ratePair;
import '../../finance/ui/ui_format.dart';
import '../../finance/ui/widgets/account_picker.dart';
import '../../finance/ui/widgets/allocation_editor.dart';
import '../../finance/ui/widgets/amount_field.dart';
import '../ai/ai_config.dart';
import '../capture_pipeline.dart';
import '../data/capture_committer.dart';
import '../data/capture_repository.dart';
import '../domain/proposal.dart';
import 'capture_sheet.dart' show askCaptureConsents;

/// What the owner is changing on one proposal before saving it.
sealed class _Edit {
  _Edit(this.confidence);

  final int confidence;
  bool keep = true;

  Proposal build();

  /// Every field a save needs is filled in.
  bool complete(List<Account> accounts);
}

class _MoneyEdit extends _Edit {
  _MoneyEdit(MoneyProposal p)
    : type = p.type,
      amount = p.amountMinor,
      currency = p.currency,
      accountId = p.accountId,
      workspaceId = p.workspaceId,
      categoryId = p.categoryId,
      at = p.occurredAt,
      description = p.description ?? '',
      bucketTag = p.bucketTag,
      super(p.confidence);

  IntentType type;
  int? amount;
  String? currency;
  int? accountId;
  int? workspaceId;
  int? categoryId;
  DateTime? at;
  String description;
  String? bucketTag;
  bool allocate = false;
  Map<int, int> allocation = const {};

  @override
  MoneyProposal build() => MoneyProposal(
    type: type,
    confidence: confidence,
    amountMinor: amount,
    currency: currency,
    accountId: accountId,
    workspaceId: workspaceId,
    categoryId: categoryId,
    occurredAt: at,
    description: description.trim().isEmpty ? null : description.trim(),
    bucketTag: type == IntentType.expense ? bucketTag : null,
  );

  @override
  bool complete(List<Account> accounts) {
    if (amount == null || amount! <= 0 || !accounts.any((a) => a.id == accountId)) return false;
    return !allocate || allocation.values.fold<int>(0, (s, x) => s + x) <= amount!;
  }
}

class _TransferEdit extends _Edit {
  _TransferEdit(TransferProposal p)
    : from = p.fromAccountId,
      to = p.toAccountId,
      amount = p.amountMinor,
      toAmount = p.toAmountMinor,
      kind = p.transferKind,
      at = p.occurredAt,
      super(p.confidence);

  int? from;
  int? to;
  int? amount;
  int? toAmount;
  String? kind;
  DateTime? at;
  String? appBase;
  List<Account> accounts = const [];

  Account? _acc(int? id) => accounts.where((a) => a.id == id).firstOrNull;

  bool get cross {
    final a = _acc(from), b = _acc(to);
    return a != null && b != null && a.currencyCode != b.currencyCode;
  }

  int? get rateE6 {
    final a = _acc(from), b = _acc(to);
    if (!cross || amount == null || toAmount == null || amount! <= 0 || toAmount! <= 0) return null;
    final (base, _) = ratePair(a!.currencyCode, b!.currencyCode, appBase ?? 'IQD');
    final fromIsBase = base == a.currencyCode;
    return rateFromAmounts(
      baseMinor: fromIsBase ? amount! : toAmount!,
      base: fromIsBase ? a.currencyCode : b.currencyCode,
      quoteMinor: fromIsBase ? toAmount! : amount!,
      quote: fromIsBase ? b.currencyCode : a.currencyCode,
    );
  }

  @override
  TransferProposal build() => TransferProposal(
    confidence: confidence,
    fromAccountId: from,
    toAccountId: to,
    amountMinor: amount,
    toAmountMinor: cross ? toAmount : null,
    rateE6: rateE6,
    transferKind: kind,
    occurredAt: at,
  );

  @override
  bool complete(List<Account> all) {
    accounts = all;
    if (_acc(from) == null || _acc(to) == null || from == to || amount == null || amount! <= 0) return false;
    return !cross || (toAmount != null && toAmount! > 0);
  }
}

class _DebtEdit extends _Edit {
  _DebtEdit(DebtProposal p)
    : counterparty = p.counterparty ?? '',
      direction = p.direction,
      leg = p.leg ?? 'principal',
      amount = p.amountMinor,
      currency = p.currency,
      accountId = p.accountId,
      at = p.occurredAt,
      super(p.confidence);

  String counterparty;
  String? direction;
  String leg;
  int? amount;
  String? currency;
  int? accountId;
  DateTime? at;
  int? debtId;

  @override
  DebtProposal build() => DebtProposal(
    confidence: confidence,
    counterparty: counterparty.trim().isEmpty ? null : counterparty.trim(),
    direction: direction,
    leg: leg,
    amountMinor: amount,
    currency: currency,
    accountId: accountId,
    occurredAt: at,
  );

  @override
  bool complete(List<Account> accounts) {
    if (amount == null || amount! <= 0 || !accounts.any((a) => a.id == accountId)) return false;
    return leg == 'repayment' ? debtId != null : direction != null && counterparty.trim().isNotEmpty;
  }
}

/// Tasks and notes: saved for their phase, never lost.
class _LaterEdit extends _Edit {
  _LaterEdit(this.p) : super(p.confidence);

  final Proposal p;

  @override
  Proposal build() => p;

  @override
  bool complete(List<Account> accounts) => true;
}

_Edit _edit(Proposal p) => switch (p) {
  MoneyProposal() => _MoneyEdit(p),
  TransferProposal() => _TransferEdit(p),
  DebtProposal() => _DebtEdit(p),
  TaskProposal() || NoteProposal() => _LaterEdit(p),
};

class CaptureReviewScreen extends ConsumerStatefulWidget {
  const CaptureReviewScreen({super.key, required this.captureId});

  final int captureId;

  @override
  ConsumerState<CaptureReviewScreen> createState() => _CaptureReviewScreenState();
}

class _CaptureReviewScreenState extends ConsumerState<CaptureReviewScreen> {
  final _transcript = TextEditingController();
  bool _loaded = false;
  bool _missing = false;
  bool _busy = false;
  String? _by;
  List<_Edit> _items = const [];

  /// Bumped on every load so the fields rebuild with the new values.
  int _gen = 0;

  CaptureRepository get _repo => CaptureRepository(ref.read(appDatabaseProvider));

  @override
  void initState() {
    super.initState();
    _load(firstTime: true);
  }

  @override
  void dispose() {
    _transcript.dispose();
    super.dispose();
  }

  Future<void> _load({bool firstTime = false}) async {
    final c = await _repo.get(widget.captureId);
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _missing = c == null;
      if (c == null) return;
      if (firstTime) _transcript.text = c.transcript ?? '';
      _by = c.parsedBy;
      _items = c.parsedJson == null ? const [] : [for (final p in decodeProposals(c.parsedJson!)) _edit(p)];
      _gen++;
    });
  }

  Future<void> _reparse() async {
    setState(() => _busy = true);
    try {
      await _repo.setTranscript(widget.captureId, _transcript.text.trim());
      if (mounted) await askCaptureConsents(context, const [AiFeature.parse]);
      await ref.read(capturePipelineProvider).reparse(widget.captureId);
      await _load();
    } on Exception catch (e) {
      AppLogger.warn('reparse failed', e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  CommitItem _commitItem(_Edit e) => switch (e) {
    _MoneyEdit() => MoneyCommit(e.build(), e.type == IntentType.income && e.allocate ? e.allocation : null),
    _TransferEdit() => TransferCommit(e.build()),
    _DebtEdit() => DebtCommit(e.build(), e.leg == 'repayment' ? e.debtId : null),
    _LaterEdit() => KeepInInbox(e.p),
  };

  Future<void> _save() async {
    setState(() => _busy = true);
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await CaptureCommitter(ref.read(appDatabaseProvider)).commit(widget.captureId, [
        for (final e in _items)
          if (e.keep) _commitItem(e),
      ]);
      messenger.showSnackBar(SnackBar(content: Text(l.capDone)));
      if (mounted) context.pop();
    } on Exception catch (e) {
      AppLogger.warn('capture save failed', e);
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Leaves the capture pending with what the owner has edited so far.
  Future<void> _keepInInbox() async {
    setState(() => _busy = true);
    await _repo.setTranscript(widget.captureId, _transcript.text.trim());
    if (_items.isNotEmpty) {
      await _repo.setParsed(widget.captureId, [for (final e in _items) e.build()], by: _by ?? 'rules');
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    // Watched up front so the pickers have their data when the cards appear.
    ref.watch(accountGroupsProvider);
    ref.watch(categoriesProvider);
    ref.watch(bucketsProvider);
    final debts = ref.watch(debtSummariesProvider).value ?? const [];
    // A repayment goes on the open debt with the name the owner said, when there is one.
    for (final e in _items.whereType<_DebtEdit>()) {
      final name = e.counterparty.trim();
      if (e.leg != 'repayment' || e.debtId != null || name.isEmpty) continue;
      e.debtId = debts
          .where((s) => s.debt.counterparty.trim() == name && (e.direction == null || s.debt.direction == e.direction))
          .firstOrNull
          ?.debt
          .id;
    }
    if (!_loaded) return Scaffold(key: const ValueKey('capture-review'), appBar: AppBar());
    if (_missing) {
      return Scaffold(
        key: const ValueKey('capture-review'),
        appBar: AppBar(title: Text(l.capReviewTitle)),
        body: Center(child: Text(l.capNothingFound)),
      );
    }
    final canSave = !_busy && _items.every((e) => !e.keep || e.complete(accounts));

    return Scaffold(
      key: const ValueKey('capture-review'),
      appBar: AppBar(title: Text(l.capReviewTitle)),
      body: ListView(
        key: const ValueKey('cap-list'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          TextField(
            key: const ValueKey('cap-transcript'),
            controller: _transcript,
            minLines: 2,
            maxLines: 6,
            enabled: !_busy,
            decoration: InputDecoration(labelText: l.capTranscript),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_by != null) _Badge(by: _by!),
              const Spacer(),
              TextButton.icon(
                key: const ValueKey('cap-reparse'),
                onPressed: _busy || _transcript.text.trim().isEmpty ? null : _reparse,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l.capParseAgain),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                l.capNothingFound,
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: k.textMuted),
              ),
            ),
          for (final (i, e) in _items.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ProposalCard(
                key: ValueKey('cap-card-$i'),
                index: i,
                gen: _gen,
                edit: e,
                accounts: accounts,
                onChanged: () => setState(() {}),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('cap-keep-inbox'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: _busy ? null : _keepInInbox,
                  child: Text(l.capKeepInInbox, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('cap-save'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: canSave ? _save : null,
                  child: Text(l.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.by});

  final String by;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final ai = by == 'ai';
    return Container(
      key: ValueKey('cap-badge-$by'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (ai ? k.accent : k.textMuted).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ai ? Icons.cloud_outlined : Icons.phone_android_rounded, size: 14, color: ai ? k.accent : k.textMuted),
          const SizedBox(width: 6),
          Text(
            ai ? l.capByAi : l.capByRules,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: ai ? k.accent : k.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ProposalCard extends ConsumerWidget {
  const _ProposalCard({
    super.key,
    required this.index,
    required this.gen,
    required this.edit,
    required this.accounts,
    required this.onChanged,
  });

  final int index;
  final int gen;
  final _Edit edit;
  final List<Account> accounts;
  final VoidCallback onChanged;

  String _kind(AppLocalizations l) => switch (edit) {
    _MoneyEdit(:final type) => type == IntentType.income ? l.typeIncome : l.typeExpense,
    _TransferEdit() => l.typeTransfer,
    _DebtEdit() => l.capDebt,
    _LaterEdit(:final p) => p is TaskProposal ? l.navTasks : l.capNote,
  };

  IconData get _icon => switch (edit) {
    _MoneyEdit(:final type) => type == IntentType.income ? Icons.north_east_rounded : Icons.south_west_rounded,
    _TransferEdit() => Icons.swap_horiz_rounded,
    _DebtEdit() => Icons.handshake_outlined,
    _LaterEdit(:final p) => p is TaskProposal ? Icons.task_alt_outlined : Icons.sticky_note_2_outlined,
  };

  Future<DateTime?> _pickDate(BuildContext context, DateTime? at) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: at ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (d == null) return null;
    final t = at ?? now;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Widget _date(BuildContext context, DateTime? at, ValueChanged<DateTime> set) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: OutlinedButton.icon(
      key: ValueKey('cap-date-$index'),
      onPressed: () async {
        final d = await _pickDate(context, at);
        if (d != null) set(d);
      },
      icon: const Icon(Icons.event_rounded, size: 18),
      label: Text(formatDate(context, at ?? DateTime.now()), maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final incomplete = edit.keep && !edit.complete(accounts);
    final unsure = edit.confidence < kLowConfidence;

    return AnimatedContainer(
      duration: reduceMotion(context) ? Duration.zero : kDurationBase,
      curve: kEaseOut,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      decoration: BoxDecoration(
        color: edit.keep ? k.surface : k.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: incomplete ? k.danger : k.border, width: incomplete ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_icon, size: 20, color: edit.keep ? k.accent : k.textMuted),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _kind(l),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(color: edit.keep ? k.text : k.textMuted),
                ),
              ),
              if (unsure && edit.keep) ...[
                const SizedBox(width: 8),
                Container(
                  key: ValueKey('cap-check-$index'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: k.warning.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(l.capCheckThis, style: text.labelSmall?.copyWith(color: k.warning)),
                ),
              ],
              const Spacer(),
              Semantics(
                label: l.capKeepCard,
                child: Switch(
                  key: ValueKey('cap-keep-$index'),
                  value: edit.keep,
                  onChanged: (v) {
                    edit.keep = v;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          if (incomplete)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8, bottom: 4),
              child: Text(
                l.capMissingFields,
                key: ValueKey('cap-missing-$index'),
                style: text.bodySmall?.copyWith(color: k.danger),
              ),
            ),
          AnimatedSize(
            duration: reduceMotion(context) ? Duration.zero : kDurationBase,
            curve: kEaseOut,
            alignment: AlignmentDirectional.topStart,
            child: edit.keep
                ? Padding(padding: const EdgeInsetsDirectional.only(end: 8, top: 8), child: _fields(context, ref))
                : Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(l.capDrop, style: text.bodySmall?.copyWith(color: k.textMuted)),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _fields(BuildContext context, WidgetRef ref) => switch (edit) {
    final _MoneyEdit e => _money(context, ref, e),
    final _TransferEdit e => _transfer(context, ref, e),
    final _DebtEdit e => _debt(context, ref, e),
    final _LaterEdit e => _later(context, e),
  };

  Account? _acc(int? id) => accounts.where((a) => a.id == id).firstOrNull;

  Widget _money(BuildContext context, WidgetRef ref, _MoneyEdit e) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider).value;
    final base = settings?.baseCurrency ?? 'IQD';
    final account = _acc(e.accountId);
    final currency = account?.currencyCode ?? e.currency ?? base;
    final kind = e.type == IntentType.income ? 'income' : 'expense';
    final categories = (ref.watch(categoriesProvider).value ?? const <Category>[])
        .where((c) => c.kind == kind)
        .toList();
    final buckets = ref.watch(bucketsProvider).value ?? const <Bucket>[];
    // Allocation needs the amount in the base currency; other currencies are allocated from History.
    final canAllocate = e.type == IntentType.income && currency == base && (e.amount ?? 0) > 0;
    void set(void Function() f) {
      f();
      onChanged();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<IntentType>(
          key: ValueKey('cap-type-$index'),
          segments: [
            ButtonSegment(value: IntentType.expense, label: Text(l.typeExpense, maxLines: 1)),
            ButtonSegment(value: IntentType.income, label: Text(l.typeIncome, maxLines: 1)),
          ],
          selected: {e.type},
          showSelectedIcon: false,
          onSelectionChanged: (s) => set(() {
            if (s.first != e.type) e.categoryId = null;
            e.type = s.first;
            if (e.type != IntentType.income) e.allocate = false;
          }),
        ),
        const SizedBox(height: 14),
        AmountField(
          key: ValueKey('cap-amount-$index-$gen-$currency'),
          fieldKey: ValueKey('cap-amount-field-$index'),
          currency: currency,
          initialMinor: e.amount,
          label: l.finAmount,
          onMinor: (v) => set(() => e.amount = v),
        ),
        const SizedBox(height: 14),
        AccountPicker(
          fieldKey: ValueKey('cap-account-$index'),
          label: l.finAccount,
          value: e.accountId,
          onChanged: (id) => set(() {
            e.accountId = id;
            e.currency = _acc(id)?.currencyCode;
            e.allocate = false;
          }),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<int?>(
          key: ValueKey('cap-category-$index-$kind-$gen'),
          initialValue: categories.any((c) => c.id == e.categoryId) ? e.categoryId : null,
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
          onChanged: (v) => set(() => e.categoryId = v),
        ),
        const SizedBox(height: 14),
        _date(context, e.at, (d) => set(() => e.at = d)),
        const SizedBox(height: 14),
        TextFormField(
          key: ValueKey('cap-desc-$index-$gen'),
          initialValue: e.description,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(labelText: l.finDescription),
          onChanged: (v) => e.description = v,
        ),
        if (e.type == IntentType.expense) ...[
          const SizedBox(height: 14),
          DropdownButtonFormField<String?>(
            key: ValueKey('cap-bucket-$index-$gen'),
            initialValue: e.bucketTag,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.finBucketTag),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text(l.finBucketNone)),
              DropdownMenuItem<String?>(value: 'emergency', child: Text(l.bucket_emergency)),
              DropdownMenuItem<String?>(value: 'investment', child: Text(l.bucket_investment)),
            ],
            onChanged: (v) => set(() => e.bucketTag = v),
          ),
        ],
        if (e.type == IntentType.income) ...[
          const SizedBox(height: 4),
          SwitchListTile(
            key: ValueKey('cap-allocate-$index'),
            contentPadding: EdgeInsets.zero,
            title: Text(l.finAllocate),
            value: e.allocate && canAllocate,
            onChanged: !canAllocate
                ? null
                : (v) => settings?.bucketsConfirmed ?? false
                      ? set(() => e.allocate = v)
                      : showPercentagesSheet(context, ref),
          ),
          if (e.allocate && canAllocate)
            AllocationEditor(
              key: ValueKey('cap-allocation-$index-${e.amount}'),
              totalBaseMinor: e.amount!,
              buckets: buckets,
              currency: base,
              onChanged: (m) => set(() => e.allocation = m),
            ),
        ],
      ],
    );
  }

  Widget _transfer(BuildContext context, WidgetRef ref, _TransferEdit e) {
    final l = context.l10n;
    final k = context.tokens;
    e.accounts = accounts;
    e.appBase = ref.watch(settingsProvider).value?.baseCurrency ?? 'IQD';
    final from = _acc(e.from), to = _acc(e.to);
    void set(void Function() f) {
      f();
      onChanged();
    }

    final rate = e.rateE6;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccountPicker(
          fieldKey: ValueKey('cap-from-$index'),
          label: l.finFrom,
          value: e.from,
          onChanged: (id) => set(() => e.from = id),
        ),
        const SizedBox(height: 14),
        AccountPicker(
          fieldKey: ValueKey('cap-to-$index'),
          label: l.finTo,
          value: e.to,
          onChanged: (id) => set(() => e.to = id),
        ),
        if (from != null && from.id == e.to)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(l.finSameAccount, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: k.danger)),
          ),
        const SizedBox(height: 14),
        AmountField(
          key: ValueKey('cap-amount-$index-$gen-${from?.currencyCode}'),
          fieldKey: ValueKey('cap-amount-field-$index'),
          currency: from?.currencyCode ?? 'IQD',
          initialMinor: e.amount,
          label: l.finAmount,
          onMinor: (v) => set(() => e.amount = v),
        ),
        if (e.cross) ...[
          const SizedBox(height: 14),
          AmountField(
            key: ValueKey('cap-to-amount-$index-$gen-${to!.currencyCode}'),
            fieldKey: ValueKey('cap-to-amount-field-$index'),
            currency: to.currencyCode,
            initialMinor: e.toAmount,
            label: l.finToAmount,
            onMinor: (v) => set(() => e.toAmount = v),
          ),
          if (rate != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${l.finRateField}: ${formatRateE6(rate)}',
                key: ValueKey('cap-rate-$index'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: k.textMuted),
              ),
            ),
        ],
        const SizedBox(height: 14),
        _date(context, e.at, (d) => set(() => e.at = d)),
      ],
    );
  }

  Widget _debt(BuildContext context, WidgetRef ref, _DebtEdit e) {
    final l = context.l10n;
    final debts = [
      for (final s in ref.watch(debtSummariesProvider).value ?? const [])
        if (e.direction == null || s.debt.direction == e.direction) s.debt,
    ];
    final account = _acc(e.accountId);
    void set(void Function() f) {
      f();
      onChanged();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<String>(
          key: ValueKey('cap-leg-$index'),
          segments: [
            ButtonSegment(value: 'principal', label: Text(l.capNewDebt, maxLines: 1)),
            ButtonSegment(value: 'repayment', label: Text(l.finRepayment, maxLines: 1)),
          ],
          selected: {e.leg},
          showSelectedIcon: false,
          onSelectionChanged: (s) => set(() {
            e.leg = s.first;
            e.debtId = null;
          }),
        ),
        const SizedBox(height: 14),
        SegmentedButton<String>(
          key: ValueKey('cap-direction-$index'),
          segments: [
            ButtonSegment(value: 'owed_to_me', label: Text(l.finOwedToMe, maxLines: 1)),
            ButtonSegment(value: 'owed_by_me', label: Text(l.finOwedByMe, maxLines: 1)),
          ],
          selected: {?e.direction},
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          onSelectionChanged: (s) => set(() {
            e.direction = s.firstOrNull;
            e.debtId = null;
          }),
        ),
        const SizedBox(height: 14),
        if (e.leg == 'repayment')
          DropdownButtonFormField<int>(
            key: ValueKey('cap-debt-$index-$gen-${e.direction}'),
            initialValue: debts.any((d) => d.id == e.debtId) ? e.debtId : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.capWhichDebt),
            items: [
              for (final d in debts)
                DropdownMenuItem<int>(
                  value: d.id,
                  child: Text('${d.counterparty} · ${d.currencyCode}', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => set(() => e.debtId = v),
          )
        else
          TextFormField(
            key: ValueKey('cap-counterparty-$index-$gen'),
            initialValue: e.counterparty,
            decoration: InputDecoration(labelText: l.finCounterparty),
            onChanged: (v) => set(() => e.counterparty = v),
          ),
        const SizedBox(height: 14),
        AmountField(
          key: ValueKey('cap-amount-$index-$gen-${account?.currencyCode}'),
          fieldKey: ValueKey('cap-amount-field-$index'),
          currency: account?.currencyCode ?? e.currency ?? 'IQD',
          initialMinor: e.amount,
          label: l.finAmount,
          onMinor: (v) => set(() => e.amount = v),
        ),
        const SizedBox(height: 14),
        AccountPicker(
          fieldKey: ValueKey('cap-account-$index'),
          label: l.finAccount,
          value: e.accountId,
          onChanged: (id) => set(() {
            e.accountId = id;
            e.currency = _acc(id)?.currencyCode;
          }),
        ),
        const SizedBox(height: 14),
        _date(context, e.at, (d) => set(() => e.at = d)),
      ],
    );
  }

  Widget _later(BuildContext context, _LaterEdit e) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final p = e.p;
    final (title, due, phase) = switch (p) {
      TaskProposal(:final title, :final due) => (title, due, 4),
      NoteProposal(:final text) => (text, null, 4),
      _ => ('', null, 4),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.bodyLarge),
        if (due != null) ...[
          const SizedBox(height: 4),
          Text(formatDate(context, due), style: text.bodySmall?.copyWith(color: k.textMuted)),
        ],
        const SizedBox(height: 8),
        Text(
          l.capInboxUntil(phase),
          key: ValueKey('cap-later-$index'),
          style: text.bodySmall?.copyWith(color: k.textMuted),
        ),
      ],
    );
  }
}
