import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../finance/ui/ui_format.dart';
import '../domain/task_views.dart';

String formatTime(BuildContext context, DateTime d) => DateFormat.jm(dateLocaleOf(context)).format(d);

String formatDateTime(BuildContext context, DateTime d, {required bool allDay}) =>
    allDay ? formatDate(context, d) : '${formatDate(context, d)} · ${formatTime(context, d)}';

String priorityLabel(AppLocalizations l, String p) => switch (p) {
  'low' => l.tskPriorityLow,
  'high' => l.tskPriorityHigh,
  'urgent' => l.tskPriorityUrgent,
  _ => l.tskPriorityNormal,
};

Color priorityColor(AppTokens k, String p) => switch (p) {
  'urgent' => k.danger,
  'high' => k.warning,
  'low' => k.textMuted,
  _ => k.accent,
};

String recurrenceLabel(AppLocalizations l, String rule, int interval) {
  final unit = switch (rule) {
    'daily' => l.tskRepeatDaily,
    'weekly' => l.tskRepeatWeekly,
    'monthly' => l.tskRepeatMonthly,
    _ => l.tskRepeatYearly,
  };
  return interval <= 1 ? unit : l.tskRepeatEveryN(interval, unit);
}

String viewLabel(AppLocalizations l, TaskView v) => switch (v) {
  TaskView.inbox => l.tskViewInbox,
  TaskView.today => l.tskViewToday,
  TaskView.tomorrow => l.tskViewTomorrow,
  TaskView.week => l.tskViewWeek,
  TaskView.upcoming => l.tskViewUpcoming,
  TaskView.overdue => l.tskViewOverdue,
  TaskView.completed => l.tskViewCompleted,
  TaskView.all => l.tskViewAll,
};
