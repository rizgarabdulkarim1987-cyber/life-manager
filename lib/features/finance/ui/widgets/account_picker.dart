import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../data/finance_providers.dart';
import '../ui_format.dart';

/// Accounts grouped under workspace headers; each shows its currency.
class AccountPicker extends ConsumerWidget {
  const AccountPicker({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.onChanged,
    this.currency,
  });

  final Key fieldKey;
  final String label;
  final int? value;
  final ValueChanged<int> onChanged;

  /// When set, only accounts in this currency are offered.
  final String? currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final all = ref.watch(accountGroupsProvider).value ?? const [];
    final groups = [
      for (final (ws, accounts) in all)
        if (accounts.any((a) => currency == null || a.currencyCode == currency))
          (ws, accounts.where((a) => currency == null || a.currencyCode == currency).toList()),
    ];
    final exists = groups.any((g) => g.$2.any((a) => a.id == value));
    return DropdownButtonFormField<int>(
      key: fieldKey,
      initialValue: exists ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      selectedItemBuilder: (_) => [
        for (final (ws, accounts) in groups) ...[
          const SizedBox.shrink(),
          for (final a in accounts)
            Text(
              '${shortAccountName(a.name, ws.name)} · ${ws.name} · ${a.currencyCode}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ],
      items: [
        for (final (ws, accounts) in groups) ...[
          DropdownMenuItem<int>(
            value: -ws.id,
            enabled: false,
            child: Text(
              ws.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelLarge?.copyWith(color: k.textMuted),
            ),
          ),
          for (final a in accounts)
            DropdownMenuItem<int>(
              key: ValueKey('account-option-${a.id}'),
              value: a.id,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(shortAccountName(a.name, ws.name), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Text(a.currencyCode, style: text.labelMedium?.copyWith(color: k.textMuted)),
                  ],
                ),
              ),
            ),
        ],
      ],
      onChanged: (v) => v == null || v < 0 ? null : onChanged(v),
    );
  }
}
