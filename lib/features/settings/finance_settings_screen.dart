import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/ckb_fallback_localizations.dart';
import '../../core/money/conversion.dart';
import '../../core/theme/tokens.dart';
import '../finance/data/finance_providers.dart';
import '../finance/data/rates_repository.dart';
import '../finance/ui/ui_format.dart';
import 'settings_section.dart';

/// USD ↔ IQD rates, newest first.
final usdIqdHistoryProvider = StreamProvider<List<RateValue>>(
  (ref) => ref.watch(ratesRepositoryProvider).watchHistory('USD', 'IQD'),
);

/// Shows a rate as "1 USD = 1,310 IQD" whichever way round it was stored.
String rateText(RateValue r) => '1 ${r.base} = ${formatRateE6(r.rateE6)} ${r.quote}';

class FinanceSettingsScreen extends ConsumerWidget {
  const FinanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final settings = ref.watch(settingsProvider).value;
    final history = ref.watch(usdIqdHistoryProvider).value ?? const <RateValue>[];
    final muted = text.bodySmall?.copyWith(color: k.textMuted);
    return Scaffold(
      appBar: AppBar(title: Text(l.setFinanceSettings)),
      body: settings == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                SettingsSection(
                  title: l.setBaseCurrency,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: SegmentedButton<String>(
                        key: const ValueKey('base-currency'),
                        segments: const [
                          ButtonSegment(value: 'IQD', label: Text('IQD')),
                          ButtonSegment(value: 'USD', label: Text('USD')),
                        ],
                        selected: {settings.baseCurrency},
                        showSelectedIcon: false,
                        onSelectionChanged: (s) => ref.read(settingsRepositoryProvider).setBaseCurrency(s.first),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(l.setBaseCurrencyHint, style: muted),
                    ),
                  ],
                ),
                SettingsSection(
                  title: l.finRateTitle,
                  children: [
                    const _RateEntry(),
                    if (history.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text(l.setNoRates, style: muted),
                      )
                    else ...[
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
                        child: Text(l.setRateHistory, style: text.labelMedium?.copyWith(color: k.textMuted)),
                      ),
                      for (final (i, r) in history.indexed)
                        ListTile(
                          key: ValueKey('rate-history-$i'),
                          dense: true,
                          title: Text(
                            rateText(r),
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.start,
                            style: text.bodyMedium?.copyWith(
                              color: k.text,
                              fontWeight: i == 0 ? FontWeight.w600 : null,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          trailing: Text(formatDate(context, r.effectiveFrom.toLocal()), style: muted),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
                SettingsSection(
                  title: l.setAlerts,
                  children: [
                    SwitchListTile(
                      key: const ValueKey('unallocated-alert'),
                      title: Text(l.setUnallocatedAlert),
                      subtitle: Text(l.setUnallocatedAlertHint),
                      value: settings.unallocatedIncomeAlert,
                      onChanged: (v) => ref.read(settingsRepositoryProvider).setUnallocatedIncomeAlert(v),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// Rate field plus its effective date (today unless changed).
class _RateEntry extends ConsumerStatefulWidget {
  const _RateEntry();

  @override
  ConsumerState<_RateEntry> createState() => _RateEntryState();
}

class _RateEntryState extends ConsumerState<_RateEntry> {
  final _rate = TextEditingController();
  DateTime _day = DateTime.now();

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  int? get _rateE6 => parseRateE6(_rate.text);

  Future<void> _save() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(ratesRepositoryProvider)
        .setRate(
          base: 'USD',
          quote: 'IQD',
          rateE6: _rateE6!,
          effectiveFrom: DateTime.utc(_day.year, _day.month, _day.day),
        );
    if (!mounted) return;
    _rate.clear();
    setState(() {});
    FocusScope.of(context).unfocus();
    messenger.showSnackBar(SnackBar(content: Text(l.setRateSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final invalid = _rate.text.trim().isNotEmpty && _rateE6 == null;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('rate-field'),
            controller: _rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: l.finRateLabel,
              suffixText: 'IQD',
              errorText: invalid ? l.finRateInvalid : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('rate-date'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _day,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _day = d);
                  },
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text(l.setRateDate(formatDate(context, _day)), overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                key: const ValueKey('rate-save'),
                style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
                onPressed: _rateE6 == null ? null : _save,
                child: Text(l.save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
