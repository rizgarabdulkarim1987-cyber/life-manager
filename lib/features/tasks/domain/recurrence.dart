import 'dart:math' as math;

/// The next wall-clock time [rule] (`daily`, `weekly`, `monthly`, `yearly`)
/// repeating every [interval] after [from]. Month and year steps keep the day
/// of the month when it exists and otherwise take the month's last day.
DateTime nextOccurrence(DateTime from, String rule, int interval) {
  final n = math.max(1, interval);
  switch (rule) {
    case 'daily':
      return DateTime(from.year, from.month, from.day + n, from.hour, from.minute);
    case 'weekly':
      return DateTime(from.year, from.month, from.day + 7 * n, from.hour, from.minute);
    case 'monthly':
      return _addMonths(from, n);
    case 'yearly':
      return _addMonths(from, 12 * n);
  }
  throw ArgumentError.value(rule, 'rule', 'unknown recurrence');
}

DateTime _addMonths(DateTime from, int months) {
  final index = from.year * 12 + (from.month - 1) + months;
  final year = index ~/ 12;
  final month = index % 12 + 1;
  final last = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, math.min(from.day, last), from.hour, from.minute);
}

/// The first occurrence after [from] that is also after [now], so finishing a
/// task late doesn't create one that is already overdue several times over.
DateTime nextOccurrenceAfter(DateTime from, String rule, int interval, DateTime now) {
  var next = nextOccurrence(from, rule, interval);
  for (var i = 0; i < 10000 && !next.isAfter(now); i++) {
    next = nextOccurrence(next, rule, interval);
  }
  return next;
}
