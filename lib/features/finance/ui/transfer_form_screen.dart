import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/money/conversion.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/money/rounding.dart';
import '../../../core/theme/tokens.dart';
import '../../capture/domain/proposal.dart';
import '../data/finance_providers.dart';
import '../data/rates_repository.dart';
import 'ui_format.dart';
import 'widgets/account_picker.dart';
import 'widgets/amount_field.dart';

/// Which currency of a pair is the base (1 base = rate quote). The app's base
/// currency is always the quote, so IQD/USD reads "IQD per 1 USD".
(String base, String quote) ratePair(String a, String b, String appBase) =>
    b == appBase ? (a, b) : (a == appBase ? (b, a) : (a, b));

/// quote per 1 base × 10⁶, from the two legs of an exchange.
int rateFromAmounts({required int baseMinor, required String base, required int quoteMinor, required String quote}) =>
    divRoundHalfEven(
      BigInt.from(quoteMinor) * BigInt.from(1000000) * pow10(currencyExponent(base)),
      BigInt.from(baseMinor) * pow10(currencyExponent(quote)),
    ).toInt();

enum _Field { from, to, rate }

class TransferFormScreen extends ConsumerStatefulWidget {
  const TransferFormScreen({super.key, this.initial, this.editId});

  final TransferDraft? initial;
  final int? editId;

  @override
  ConsumerState<TransferFormScreen> createState() => _TransferFormScreenState();
}

class _TransferFormScreenState extends ConsumerState<TransferFormScreen> {
  bool _loaded = false;
  Transaction? _editing;
  List<Account> _accounts = const [];
  int? _from;
  int? _to;
  int? _fromMinor;
  int? _toMinor;
  int? _rateE6;
  bool _ownerDraw = false;
  late DateTime _at;
  final _description = TextEditingController();
  final _fromCtl = TextEditingController();
  final _toCtl = TextEditingController();
  final _rateCtl = TextEditingController();

  /// Most recently typed fields, newest last; the third is computed.
  final _typed = <_Field>[];

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _from = d?.fromAccountId;
    _to = d?.toAccountId;
    _fromMinor = d?.amountMinor;
    _toMinor = d?.toAmountMinor;
    _rateE6 = d?.rateE6;
    _ownerDraw = d?.transferKind == 'owner_draw';
    _at = DateTime.now();
    _load();
  }

  Future<void> _load() async {
    if (widget.editId != null) {
      final t = await ref.read(transactionsRepositoryProvider).get(widget.editId!);
      if (t != null && t.type == 'transfer') {
        _editing = t;
        _from = t.accountId;
        _to = t.toAccountId;
        _fromMinor = t.amountMinor;
        _toMinor = t.toAmountMinor;
        _rateE6 = t.rateE6;
        _ownerDraw = t.transferKind == 'owner_draw';
        _at = t.occurredAt.toLocal();
        _description.text = t.description ?? '';
      }
    }
    // An unlistened provider is paused in Riverpod 3; read the repository directly.
    _accounts = await ref.read(accountsRepositoryProvider).watchAll().first;
    if (!mounted) return;
    final from = _account(_from);
    final to = _account(_to);
    if (_fromMinor != null && from != null) _fromCtl.text = minorToPlain(_fromMinor!, from.currencyCode);
    if (_toMinor != null && to != null) _toCtl.text = minorToPlain(_toMinor!, to.currencyCode);
    if (_rateE6 != null) _rateCtl.text = formatRateE6(_rateE6!);
    if (_fromMinor != null) _typed.add(_Field.from);
    if (_toMinor != null) _typed.add(_Field.to);
    setState(() => _loaded = true);
    await _prefillRate();
  }

  @override
  void dispose() {
    for (final c in [_description, _fromCtl, _toCtl, _rateCtl]) {
      c.dispose();
    }
    super.dispose();
  }

  Account? _account(int? id) => _accounts.where((a) => a.id == id).firstOrNull;

  String get _appBase => ref.read(settingsProvider).value?.baseCurrency ?? 'IQD';

  bool get _crossCurrency {
    final a = _account(_from), b = _account(_to);
    return a != null && b != null && a.currencyCode != b.currencyCode;
  }

  bool get _crossWorkspace {
    final a = _account(_from), b = _account(_to);
    return a != null && b != null && a.workspaceId != b.workspaceId;
  }

  /// A stored rate for the pair counts as typed, so one amount fills the other.
  Future<void> _prefillRate() async {
    if (!_crossCurrency || _rateE6 != null) return;
    final a = _account(_from)!.currencyCode, b = _account(_to)!.currencyCode;
    final (base, quote) = ratePair(a, b, _appBase);
    final r = await ref.read(ratesRepositoryProvider).rateOn(base, quote, _at.toUtc());
    if (r == null || !mounted || _typed.contains(_Field.rate)) return;
    setState(() {
      _rateE6 = r.rateE6;
      _rateCtl.text = formatRateE6(r.rateE6);
      _typed.insert(0, _Field.rate);
      _recompute();
    });
  }

  _Field? get _computed {
    if (!_crossCurrency || _typed.length < 2) return null;
    final last = _typed.sublist(_typed.length - 2);
    return _Field.values.firstWhere((f) => !last.contains(f));
  }

  void _typedField(_Field f) {
    _typed
      ..remove(f)
      ..add(f);
    _recompute();
  }

  /// Fills the field that wasn't among the last two typed.
  void _recompute() {
    final target = _computed;
    if (target == null) return;
    final fromCur = _account(_from)!.currencyCode, toCur = _account(_to)!.currencyCode;
    final (base, quote) = ratePair(fromCur, toCur, _appBase);
    final fromIsBase = base == fromCur;
    switch (target) {
      case _Field.rate:
        if (_fromMinor == null || _toMinor == null || _fromMinor! <= 0 || _toMinor! <= 0) return;
        _rateE6 = rateFromAmounts(
          baseMinor: fromIsBase ? _fromMinor! : _toMinor!,
          base: base,
          quoteMinor: fromIsBase ? _toMinor! : _fromMinor!,
          quote: quote,
        );
        _rateCtl.text = formatRateE6(_rateE6!);
      case _Field.to:
        if (_fromMinor == null || _rateE6 == null) return;
        _toMinor = convert(Money(_fromMinor!, fromCur), toCur, _rate(base, quote)).minor;
        _toCtl.text = minorToPlain(_toMinor!, toCur);
      case _Field.from:
        if (_toMinor == null || _rateE6 == null) return;
        _fromMinor = convert(Money(_toMinor!, toCur), fromCur, _rate(base, quote)).minor;
        _fromCtl.text = minorToPlain(_fromMinor!, fromCur);
    }
  }

  RateValue _rate(String base, String quote) =>
      RateValue(base: base, quote: quote, rateE6: _rateE6!, effectiveFrom: DateTime.utc(2000));

  void _accountsChanged() {
    if (!_crossWorkspace) _ownerDraw = false;
    if (!_crossCurrency) {
      _typed.removeWhere((f) => f != _Field.from);
      _toMinor = null;
      _rateE6 = null;
      _toCtl.clear();
      _rateCtl.clear();
    }
    _prefillRate();
  }

  bool get _valid {
    if (_from == null || _to == null || _from == _to) return false;
    if (_fromMinor == null || _fromMinor! <= 0) return false;
    if (_crossCurrency && (_toMinor == null || _toMinor! <= 0 || _rateE6 == null || _rateE6! <= 0)) return false;
    return true;
  }

  Future<void> _save() async {
    final repo = ref.read(transactionsRepositoryProvider);
    final cross = _crossCurrency;
    final kind = _ownerDraw && _crossWorkspace ? 'owner_draw' : 'transfer';
    final description = _description.text.trim().isEmpty ? null : _description.text.trim();
    if (_editing == null) {
      await repo.addTransfer(
        fromAccountId: _from!,
        toAccountId: _to!,
        amountMinor: _fromMinor!,
        toAmountMinor: cross ? _toMinor : null,
        rateE6: cross ? _rateE6 : null,
        transferKind: kind,
        occurredAt: _at.toUtc(),
        description: description,
      );
    } else {
      await repo.update(
        _editing!.id,
        TransactionsCompanion(
          accountId: Value(_from!),
          toAccountId: Value(_to),
          amountMinor: Value(_fromMinor!),
          toAmountMinor: Value(cross ? _toMinor : null),
          rateE6: Value(cross ? _rateE6 : null),
          transferKind: Value(kind),
          occurredAt: Value(_at.toUtc()),
          description: Value(description),
        ),
      );
    }
    if (mounted) context.pop();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (d != null) setState(() => _at = DateTime(d.year, d.month, d.day, _at.hour, _at.minute));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    _accounts = ref.watch(accountsProvider).value ?? _accounts;
    if (!_loaded) return Scaffold(appBar: AppBar());
    final from = _account(_from), to = _account(_to);
    final cross = _crossCurrency;
    final computed = _computed;
    final pair = cross ? ratePair(from!.currencyCode, to!.currencyCode, _appBase) : null;

    return Scaffold(
      appBar: AppBar(title: Text(_editing == null ? l.finAddTransfer : l.finEditTransfer)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AccountPicker(
            fieldKey: const ValueKey('tr-from'),
            label: l.finFrom,
            value: _from,
            onChanged: (id) => setState(() {
              _from = id;
              _accountsChanged();
            }),
          ),
          const SizedBox(height: 12),
          AccountPicker(
            fieldKey: const ValueKey('tr-to'),
            label: l.finTo,
            value: _to,
            onChanged: (id) => setState(() {
              _to = id;
              _accountsChanged();
            }),
          ),
          if (_from != null && _from == _to)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l.finSameAccount, style: text.bodySmall?.copyWith(color: k.danger)),
            ),
          const SizedBox(height: 16),
          AmountField(
            key: const ValueKey('tr-amount-field'),
            fieldKey: const ValueKey('tr-amount'),
            controller: _fromCtl,
            currency: from?.currencyCode ?? 'IQD',
            label: l.finAmount,
            large: !cross,
            readOnly: computed == _Field.from,
            onMinor: (v) => setState(() {
              _fromMinor = v;
              _typedField(_Field.from);
            }),
          ),
          if (cross) ...[
            const SizedBox(height: 12),
            AmountField(
              key: const ValueKey('tr-to-amount-field'),
              fieldKey: const ValueKey('tr-to-amount'),
              controller: _toCtl,
              currency: to!.currencyCode,
              label: l.finToAmount,
              readOnly: computed == _Field.to,
              onMinor: (v) => setState(() {
                _toMinor = v;
                _typedField(_Field.to);
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('tr-rate'),
              controller: _rateCtl,
              readOnly: computed == _Field.rate,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: l.finRateField(pair!.$2, pair.$1),
                filled: computed == _Field.rate ? true : null,
                helperText: l.finTwoOfThree,
              ),
              onChanged: (s) => setState(() {
                _rateE6 = parseRateE6(s);
                _typedField(_Field.rate);
              }),
            ),
          ],
          if (_crossWorkspace) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              key: const ValueKey('tr-owner-draw'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.finOwnerDraw),
              subtitle: Text(l.finOwnerDrawHint),
              value: _ownerDraw,
              onChanged: (v) => setState(() => _ownerDraw = v),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('tr-date'),
            onPressed: _pickDate,
            icon: const Icon(Icons.event_rounded, size: 18),
            label: Text(DateFormat.yMMMd(dateLocaleOf(context)).format(_at)),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('tr-description'),
            controller: _description,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(labelText: l.finDescription),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            key: const ValueKey('tr-save'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _valid ? _save : null,
            child: Text(l.save),
          ),
        ),
      ),
    );
  }
}
