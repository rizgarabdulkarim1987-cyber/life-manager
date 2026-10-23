import 'package:flutter/material.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/tokens.dart';
import '../../data/categories_repository.dart';
import '../../domain/buckets_math.dart';
import 'amount_field.dart';
import 'money_text.dart';

/// Splits an income (already in the base [currency]) across buckets. Starts
/// from the owner's percentages; every share is editable. The parent blocks
/// saving while the shares add up to more than [totalBaseMinor].
class AllocationEditor extends StatefulWidget {
  const AllocationEditor({
    super.key,
    required this.totalBaseMinor,
    required this.buckets,
    required this.onChanged,
    this.currency = 'IQD',
  });

  final int totalBaseMinor;
  final List<Bucket> buckets;
  final ValueChanged<Map<int, int>> onChanged;
  final String currency;

  @override
  State<AllocationEditor> createState() => _AllocationEditorState();
}

class _AllocationEditorState extends State<AllocationEditor> {
  late Map<int, int> _shares;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void didUpdateWidget(AllocationEditor old) {
    super.didUpdateWidget(old);
    if (old.totalBaseMinor != widget.totalBaseMinor || old.buckets.length != widget.buckets.length) _prefill();
  }

  void _prefill() {
    final split = defaultSplit(widget.totalBaseMinor, [for (final b in widget.buckets) b.percentBp]);
    _shares = {for (var i = 0; i < widget.buckets.length; i++) widget.buckets[i].id: split[i]};
    final copy = Map.of(_shares);
    WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? widget.onChanged(copy) : null);
  }

  void _set(int bucketId, int? minor) {
    setState(() => _shares[bucketId] = minor ?? 0);
    widget.onChanged(Map.of(_shares));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final rest = widget.totalBaseMinor - _shares.values.fold<int>(0, (s, x) => s + x);
    return Column(
      key: const ValueKey('allocation-editor'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in widget.buckets)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    '${bucketLabel(b, l)} · ${b.percentBp ~/ 100}%',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(color: k.text),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: AmountField(
                    key: ValueKey('alloc-row-${b.id}-${widget.totalBaseMinor}'),
                    fieldKey: ValueKey('alloc-${b.id}'),
                    currency: widget.currency,
                    initialMinor: _shares[b.id],
                    onMinor: (v) => _set(b.id, v),
                  ),
                ),
              ],
            ),
          ),
        Row(
          key: const ValueKey('allocation-rest'),
          children: [
            Expanded(
              child: Text(
                rest < 0 ? l.finOverAllocated : l.finUnallocated,
                style: text.bodyMedium?.copyWith(color: rest < 0 ? k.danger : k.textMuted),
              ),
            ),
            Flexible(
              child: FittedMoney(
                Money(rest.abs(), widget.currency),
                style: text.bodyMedium?.copyWith(color: rest < 0 ? k.danger : k.textMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
