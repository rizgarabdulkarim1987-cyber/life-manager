import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/money/amount_parse.dart';
import '../../../core/money/money.dart';
import '../../../core/text/digits.dart';
import '../../../core/theme/tokens.dart';
import '../data/categories_repository.dart';
import '../data/finance_providers.dart';
import '../domain/buckets_math.dart';
import 'widgets/money_text.dart';
import 'widgets/month_switcher.dart';
import 'widgets/panel.dart';
import 'widgets/text_prompt_dialog.dart';
import 'widgets/usage_bar.dart';

/// "70", "12.5", "٢٠" → basis points, or null when it isn't 0–100 with at most two decimals.
int? parsePercentBp(String s) {
  final t = normalizeDigits(s.trim()).replaceAll('٫', '.');
  if (!RegExp(r'^\d{1,3}(\.\d{1,2})?$').hasMatch(t)) return null;
  final bp = decimalToMinor(t, 2)?.minor;
  return bp != null && bp <= 10000 ? bp : null;
}

String formatBp(int bp) => bp % 100 == 0 ? '${bp ~/ 100}' : '${bp ~/ 100}.${(bp % 100).toString().padLeft(2, '0')}';

class BucketsScreen extends ConsumerStatefulWidget {
  const BucketsScreen({super.key});

  @override
  ConsumerState<BucketsScreen> createState() => _BucketsScreenState();
}

class _BucketsScreenState extends ConsumerState<BucketsScreen> {
  DateTime _month = thisMonth();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final settings = ref.watch(settingsProvider).value;
    final confirmed = settings?.bucketsConfirmed ?? true;
    final base = settings?.baseCurrency ?? 'IQD';
    final status = ref.watch(bucketStatusForMonthProvider(_month)).value ?? const <BucketStatus>[];

    return Scaffold(
      key: const ValueKey('buckets-screen'),
      appBar: AppBar(
        title: Text(l.finBuckets),
        actions: [
          IconButton(
            key: const ValueKey('edit-percentages-action'),
            tooltip: l.finEditPercentages,
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => showPercentagesSheet(context, ref),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
        children: [
          MonthSwitcher(month: _month, onChanged: (m) => setState(() => _month = m)),
          const SizedBox(height: 8),
          if (!confirmed)
            Panel(
              key: const ValueKey('buckets-unconfirmed'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: k.warning, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(l.finBucketsUnconfirmed, style: text.bodyMedium?.copyWith(color: k.text)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton(
                      key: const ValueKey('edit-percentages'),
                      onPressed: () => showPercentagesSheet(context, ref),
                      child: Text(l.finEditPercentages),
                    ),
                  ),
                ],
              ),
            ),
          for (final s in status) _BucketCard(s: s, base: base, confirmed: confirmed),
        ],
      ),
    );
  }
}

class _BucketCard extends ConsumerWidget {
  const _BucketCard({required this.s, required this.base, required this.confirmed});

  final BucketStatus s;
  final String base;
  final bool confirmed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final b = s.bucket;
    final monthly = b.systemKey == 'expenses';
    final used = s.usedBp;
    final muted = text.bodySmall?.copyWith(color: k.textMuted);

    Widget figure(String label, int minor) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: muted),
          FittedMoney(
            Money(minor, base),
            alignment: AlignmentDirectional.centerStart,
            style: text.bodyLarge?.copyWith(color: k.text),
          ),
        ],
      ),
    );

    return Panel(
      key: ValueKey('bucket-${b.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  bucketLabel(b, l),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(color: k.text),
                ),
              ),
              if (confirmed) Text('${formatBp(b.percentBp)}%', style: text.labelLarge?.copyWith(color: k.textMuted)),
            ],
          ),
          Text(monthly ? l.finExpensesMonthly : l.finCarriesOver, style: muted),
          const SizedBox(height: 12),
          Text(l.finAvailable, style: muted),
          FittedMoney(
            Money(s.availableMinor, base),
            alignment: AlignmentDirectional.centerStart,
            style: text.headlineSmall?.copyWith(
              color: s.availableMinor < 0 ? k.danger : k.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          UsageBar(barKey: ValueKey('bucket-bar-${b.id}'), valueBp: used ?? 0, color: usageColor(k, used)),
          const SizedBox(height: 10),
          Row(
            children: [
              figure(l.finAllocated, s.allocatedMinor),
              const SizedBox(width: 12),
              figure(l.finSpent, s.spentMinor),
            ],
          ),
          if (!monthly) ...[
            Divider(color: k.border, height: 24),
            if (s.targetMinor != null) ...[
              Row(
                children: [
                  Text(l.finTarget, style: muted),
                  const SizedBox(width: 12),
                  Expanded(child: FittedMoney(Money(s.targetMinor!, base), style: text.bodyMedium)),
                ],
              ),
              const SizedBox(height: 8),
              UsageBar(
                barKey: ValueKey('bucket-target-bar-${b.id}'),
                valueBp: s.targetMinor! <= 0 ? 0 : s.availableMinor * 10000 ~/ s.targetMinor!,
                color: s.availableMinor >= s.targetMinor! ? k.success : k.accent,
              ),
            ],
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: ValueKey('bucket-target-${b.id}'),
                onPressed: () => _editTarget(context, ref, b),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text(l.finSetTarget),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editTarget(BuildContext context, WidgetRef ref, Bucket b) async {
    final l = context.l10n;
    // The sentinel -1 means "cleared", since null means "cancelled".
    final v = await showDialog<int>(
      context: context,
      builder: (_) => TextPromptDialog<int>(
        title: l.finSetTarget,
        message: l.finTargetHint,
        label: l.finTarget,
        suffix: base,
        numeric: true,
        parse: (t) {
          if (t.trim().isEmpty) return -1;
          final m = parseDecimalToMinor(t, base)?.minor;
          return m != null && m > 0 ? m : null;
        },
        invalidText: l.finAmountInvalid,
        fieldKey: const ValueKey('target-amount'),
        saveKey: const ValueKey('target-save'),
      ),
    );
    if (v == null) return;
    await ref.read(bucketsRepositoryProvider).setTarget(b.id, v < 0 ? null : v);
  }
}

/// Percent per bucket; Save stays off until they add up to exactly 100%.
/// Starts empty until the owner has saved their own split once.
Future<void> showPercentagesSheet(BuildContext context, WidgetRef ref) async {
  final buckets = await ref.read(bucketsRepositoryProvider).watch().first;
  final confirmed = ref.read(settingsProvider).value?.bucketsConfirmed ?? false;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PercentagesSheet(buckets: buckets, prefill: confirmed),
  );
}

class _PercentagesSheet extends ConsumerStatefulWidget {
  const _PercentagesSheet({required this.buckets, required this.prefill});

  final List<Bucket> buckets;
  final bool prefill;

  @override
  ConsumerState<_PercentagesSheet> createState() => _PercentagesSheetState();
}

class _PercentagesSheetState extends ConsumerState<_PercentagesSheet> {
  late final _ctl = {
    for (final b in widget.buckets) b.id: TextEditingController(text: widget.prefill ? formatBp(b.percentBp) : ''),
  };

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<int, int?> get _values => {for (final e in _ctl.entries) e.key: parsePercentBp(e.value.text)};

  Future<void> _save() async {
    await ref.read(bucketsRepositoryProvider).setPercents({for (final e in _values.entries) e.key: e.value!});
    await ref.read(settingsRepositoryProvider).setBucketsConfirmed();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final values = _values;
    final complete = values.values.every((v) => v != null);
    final sum = values.values.fold<int>(0, (s, v) => s + (v ?? 0));
    final ok = complete && sum == 10000;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.finEditPercentages, style: text.titleLarge),
              const SizedBox(height: 6),
              Text(l.finPercentagesNote, style: text.bodyMedium?.copyWith(color: k.textMuted)),
              const SizedBox(height: 16),
              for (final b in widget.buckets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(child: Text(bucketLabel(b, l), style: text.bodyLarge)),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          key: ValueKey('pct-${b.id}'),
                          controller: _ctl[b.id],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.end,
                          decoration: const InputDecoration(suffixText: '%', hintText: '0'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                l.finPercentTotal(formatBp(sum)),
                key: const ValueKey('pct-total'),
                textAlign: TextAlign.end,
                style: text.titleSmall?.copyWith(color: ok ? k.success : k.warning),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('pct-save'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: ok ? _save : null,
                child: Text(l.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
