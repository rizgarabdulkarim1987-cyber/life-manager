import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/theme/tokens.dart';
import '../ui_format.dart';

/// Previous / next month around the month's name. [month] is its first day.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key, required this.month, required this.onChanged});

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    final now = DateTime.now();
    final isCurrent = month.year == now.year && month.month == now.month;
    final m = MaterialLocalizations.of(context);
    return Row(
      children: [
        IconButton(
          key: const ValueKey('month-prev'),
          tooltip: m.previousMonthTooltip,
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
        ),
        Expanded(
          child: Text(
            DateFormat.yMMMM(dateLocaleOf(context)).format(month),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: k.text),
          ),
        ),
        IconButton(
          key: const ValueKey('month-next'),
          tooltip: m.nextMonthTooltip,
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: isCurrent ? null : () => onChanged(DateTime(month.year, month.month + 1)),
        ),
      ],
    );
  }
}

DateTime thisMonth() {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
}
