import '../../../core/db/app_database.dart';

/// The lists of the Tasks screen (spec §11).
enum TaskView { inbox, today, tomorrow, week, upcoming, overdue, completed, all }

enum TaskSort { due, priority }

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// The task's due moment on the owner's clock, or null.
DateTime? dueLocal(Task t) => t.dueAt?.toLocal();

bool isDone(Task t) => t.status == 'done';

/// Past its due time; an all-day task is overdue only after its day.
bool isOverdue(Task t, DateTime now) {
  final due = dueLocal(t);
  if (isDone(t) || due == null) return false;
  return t.dueAllDay ? dayOf(due).isBefore(dayOf(now)) : due.isBefore(now);
}

bool taskInView(Task t, TaskView view, DateTime now) {
  final due = dueLocal(t);
  final today = dayOf(now);
  final day = due == null ? null : dayOf(due);
  switch (view) {
    case TaskView.completed:
      return isDone(t);
    case TaskView.all:
      return !isDone(t);
    case TaskView.inbox:
      return !isDone(t) && due == null && t.workspaceId == null;
    case TaskView.overdue:
      return isOverdue(t, now);
    case TaskView.today:
      return !isDone(t) && day == today;
    case TaskView.tomorrow:
      return !isDone(t) && day == _addDays(today, 1);
    case TaskView.week:
      return !isDone(t) && day != null && !day.isBefore(today) && day.isBefore(_addDays(today, 7));
    case TaskView.upcoming:
      return !isDone(t) && day != null && day.isAfter(today);
  }
}

int priorityRank(String p) => switch (p) {
  'urgent' => 3,
  'high' => 2,
  'normal' => 1,
  _ => 0,
};

/// Due soonest first (no date last), or highest priority first; ties by due, then newest.
int Function(Task, Task) taskComparator(TaskSort sort) => (a, b) {
  int byDue() {
    final x = a.dueAt, y = b.dueAt;
    if (x == null && y == null) return 0;
    if (x == null) return 1;
    if (y == null) return -1;
    return x.compareTo(y);
  }

  if (sort == TaskSort.priority) {
    final p = priorityRank(b.priority).compareTo(priorityRank(a.priority));
    if (p != 0) return p;
  }
  final d = byDue();
  return d != 0 ? d : b.id.compareTo(a.id);
};

List<String> parseTags(String raw) {
  final seen = <String>{};
  return [
    for (final t in raw.split(RegExp(r'[,،#\s]+')))
      if (t.trim().isNotEmpty && seen.add(t.trim().toLowerCase())) t.trim().toLowerCase(),
  ];
}

String joinTags(Iterable<String> tags) => parseTags(tags.join(',')).join(',');

/// Open tasks per local day of [month], for the calendar.
Map<int, int> countByDay(Iterable<Task> tasks, DateTime month) {
  final out = <int, int>{};
  for (final t in tasks) {
    final d = dueLocal(t);
    if (isDone(t) || d == null || d.year != month.year || d.month != month.month) continue;
    out[d.day] = (out[d.day] ?? 0) + 1;
  }
  return out;
}
