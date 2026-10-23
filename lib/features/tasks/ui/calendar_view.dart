import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../finance/ui/ui_format.dart';
import '../data/tasks_providers.dart';
import 'tasks_screen.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// A month grid (weeks start on Saturday) with a dot on days that have tasks, and the picked day's list.
class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({super.key});

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime _selected = _day(DateTime.now());

  void _shift(int by) => setState(() {
    _month = DateTime(_month.year, _month.month + by);
    _selected = _month.year == DateTime.now().year && _month.month == DateTime.now().month
        ? _day(DateTime.now())
        : _month;
  });

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final locale = dateLocaleOf(context);
    final tasks = ref.watch(taskMonthProvider(_month)).value ?? const <Task>[];
    final byDay = <DateTime, List<Task>>{};
    for (final t in tasks) {
      byDay.putIfAbsent(_day(t.dueAt!.toLocal()), () => []).add(t);
    }
    // Saturday = 6 in DateTime.weekday terms; offset of the 1st from the Saturday column.
    final lead = (_month.weekday + 1) % 7;
    final daysIn = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = lead + daysIn;
    final rows = (cells / 7).ceil();
    final today = _day(DateTime.now());
    final saturday = DateTime(2026, 10, 24);

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('cal-prev'),
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => _shift(-1),
            ),
            Expanded(
              child: Text(
                DateFormat.yMMMM(locale).format(_month),
                key: const ValueKey('cal-title'),
                textAlign: TextAlign.center,
                style: text.titleMedium,
              ),
            ),
            IconButton(
              key: const ValueKey('cal-next'),
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => _shift(1),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Center(
                        child: Text(
                          DateFormat.E(locale).format(saturday.add(Duration(days: i))),
                          style: text.labelSmall?.copyWith(color: k.textMuted),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              for (var r = 0; r < rows; r++)
                Row(
                  children: [
                    for (var c = 0; c < 7; c++)
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final n = r * 7 + c - lead + 1;
                            if (n < 1 || n > daysIn) return const SizedBox(height: 40);
                            final d = DateTime(_month.year, _month.month, n);
                            final picked = d == _selected;
                            return InkWell(
                              key: ValueKey('cal-day-$n'),
                              borderRadius: BorderRadius.circular(22),
                              onTap: () => setState(() => _selected = d),
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: picked ? k.accent : null,
                                  border: d == today && !picked ? Border.all(color: k.accent) : null,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      DateFormat.d('en').format(d),
                                      style: text.bodyMedium?.copyWith(color: picked ? k.onAccent : k.text),
                                    ),
                                    Container(
                                      key: byDay.containsKey(d) ? ValueKey('cal-dot-$n') : null,
                                      width: 5,
                                      height: 5,
                                      margin: const EdgeInsets.only(top: 2),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: byDay.containsKey(d)
                                            ? (picked ? k.onAccent : k.accent)
                                            : Colors.transparent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const Divider(height: 24),
        Expanded(
          child: byDay[_selected] == null
              ? Center(
                  child: Text(
                    context.l10n.calendarNoTasks,
                    key: const ValueKey('cal-empty'),
                    style: text.bodyMedium?.copyWith(color: k.textMuted),
                  ),
                )
              : TaskRows(tasks: byDay[_selected]!),
        ),
      ],
    );
  }
}
