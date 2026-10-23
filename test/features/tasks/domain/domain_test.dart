import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/features/tasks/domain/action_points.dart';
import 'package:life_manager/features/tasks/domain/recurrence.dart';
import 'package:life_manager/features/tasks/domain/task_views.dart';

Task task({
  int id = 1,
  String status = 'todo',
  DateTime? due,
  bool allDay = false,
  int? workspaceId,
  String priority = 'normal',
}) => Task(
  id: id,
  title: 't',
  priority: priority,
  status: status,
  dueAt: due?.toUtc(),
  dueAllDay: allDay,
  recurrenceInterval: 1,
  tags: '',
  workspaceId: workspaceId,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  group('recurrence', () {
    test('daily and weekly keep the wall-clock time', () {
      final d = DateTime(2026, 10, 23, 9, 30);
      expect(nextOccurrence(d, 'daily', 1), DateTime(2026, 10, 24, 9, 30));
      expect(nextOccurrence(d, 'daily', 3), DateTime(2026, 10, 26, 9, 30));
      expect(nextOccurrence(d, 'weekly', 2), DateTime(2026, 11, 6, 9, 30));
    });

    test('monthly clamps to the last day', () {
      expect(nextOccurrence(DateTime(2026, 1, 31, 8), 'monthly', 1), DateTime(2026, 2, 28, 8));
      expect(nextOccurrence(DateTime(2028, 1, 31), 'monthly', 1), DateTime(2028, 2, 29));
      expect(nextOccurrence(DateTime(2026, 11, 15), 'monthly', 2), DateTime(2027, 1, 15));
    });

    test('yearly handles 29 February', () {
      expect(nextOccurrence(DateTime(2028, 2, 29), 'yearly', 1), DateTime(2029, 2, 28));
      expect(nextOccurrence(DateTime(2028, 2, 29), 'yearly', 4), DateTime(2032, 2, 29));
    });

    test('unknown rule throws', () => expect(() => nextOccurrence(DateTime(2026), 'hourly', 1), throwsArgumentError));

    test('after a late finish the next one is in the future', () {
      final now = DateTime(2026, 10, 23, 12);
      expect(nextOccurrenceAfter(DateTime(2026, 10, 1, 9), 'daily', 1, now), DateTime(2026, 10, 24, 9));
      expect(nextOccurrenceAfter(DateTime(2026, 10, 23, 18), 'daily', 1, now), DateTime(2026, 10, 24, 18));
    });
  });

  group('views', () {
    final now = DateTime(2026, 10, 23, 12);
    bool inView(Task t, TaskView v) => taskInView(t, v, now);

    test('inbox is open, undated and without a workspace', () {
      expect(inView(task(), TaskView.inbox), isTrue);
      expect(inView(task(workspaceId: 1), TaskView.inbox), isFalse);
      expect(inView(task(due: now), TaskView.inbox), isFalse);
      expect(inView(task(status: 'done'), TaskView.inbox), isFalse);
    });

    test('today, tomorrow, week, upcoming', () {
      const views = [TaskView.today, TaskView.tomorrow, TaskView.week, TaskView.upcoming];
      final today = task(due: DateTime(2026, 10, 23, 8));
      final tomorrow = task(due: DateTime(2026, 10, 24, 8));
      final in6 = task(due: DateTime(2026, 10, 29, 8));
      final in7 = task(due: DateTime(2026, 10, 30, 8));
      expect(views.map((v) => inView(today, v)), [true, false, true, false]);
      expect(views.map((v) => inView(tomorrow, v)), [false, true, true, true]);
      expect(inView(in6, TaskView.week), isTrue);
      expect(inView(in7, TaskView.week), isFalse);
      expect(inView(in7, TaskView.upcoming), isTrue);
    });

    test('overdue: timed tasks after their time, all-day tasks after their day', () {
      expect(inView(task(due: DateTime(2026, 10, 23, 11)), TaskView.overdue), isTrue);
      expect(inView(task(due: DateTime(2026, 10, 23, 13)), TaskView.overdue), isFalse);
      expect(inView(task(due: DateTime(2026, 10, 23), allDay: true), TaskView.overdue), isFalse);
      expect(inView(task(due: DateTime(2026, 10, 22), allDay: true), TaskView.overdue), isTrue);
      expect(inView(task(due: DateTime(2026, 10, 1), status: 'done'), TaskView.overdue), isFalse);
    });

    test('completed and all', () {
      expect(inView(task(status: 'done'), TaskView.completed), isTrue);
      expect(inView(task(status: 'done'), TaskView.all), isFalse);
      expect(inView(task(), TaskView.all), isTrue);
    });

    test('sorting by due puts undated last; by priority comes first', () {
      final a = task(id: 1, due: DateTime(2026, 11), priority: 'low');
      final b = task(id: 2, priority: 'urgent');
      final c = task(id: 3, due: DateTime(2026, 10), priority: 'normal');
      expect(([a, b, c]..sort(taskComparator(TaskSort.due))).map((t) => t.id), [3, 1, 2]);
      expect(([a, b, c]..sort(taskComparator(TaskSort.priority))).map((t) => t.id), [2, 3, 1]);
    });

    test('tags are lower-cased, deduplicated and cleaned', () {
      expect(parseTags('Client, #urgent  client،عاجل'), ['client', 'urgent', 'عاجل']);
      expect(joinTags(['A', 'a', ' b ']), 'a,b');
    });

    test('calendar counts open tasks per day of the month', () {
      final tasks = [
        task(id: 1, due: DateTime(2026, 10, 5, 9)),
        task(id: 2, due: DateTime(2026, 10, 5, 17)),
        task(id: 3, due: DateTime(2026, 10, 6), status: 'done'),
        task(id: 4, due: DateTime(2026, 11, 5)),
      ];
      expect(countByDay(tasks, DateTime(2026, 10)), {5: 2});
    });
  });

  group('action points', () {
    test('bullets, numbers and sentences become separate points', () {
      expect(splitActionPoints('Agenda:\n- Call Ahmed tomorrow\n2) Send the invoice. Book the hall\n• ا'), [
        'Call Ahmed tomorrow',
        'Send the invoice',
        'Book the hall',
      ]);
    });

    test('Arabic numbering and punctuation', () {
      expect(splitActionPoints('١. اتصل بأحمد غداً\n٢- ارسل الفاتورة؟ راجع العقد'), [
        'اتصل بأحمد غداً',
        'ارسل الفاتورة؟',
        'راجع العقد',
      ]);
    });

    test('empty text gives nothing and the list is capped', () {
      expect(splitActionPoints('  \n\n'), isEmpty);
      expect(splitActionPoints(List.generate(80, (i) => 'task $i').join('\n')), hasLength(kMaxActionPoints));
    });
  });
}
