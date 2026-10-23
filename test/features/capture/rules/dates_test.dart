import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/text/digits.dart';
import 'package:life_manager/features/capture/rules/dates.dart';

// Friday 23 October 2026, 15:40.
final now = DateTime(2026, 10, 23, 15, 40);

({DateTime? date, int? hour, int? minute}) when(String s) => findWhen(normalizeForMatch(s), now);

void main() {
  test('relative days in three languages', () {
    expect(when('اليوم').date, DateTime(2026, 10, 23));
    expect(when('البارحة').date, DateTime(2026, 10, 22));
    expect(when('yesterday').date, DateTime(2026, 10, 22));
    expect(when('باجر').date, DateTime(2026, 10, 24));
    expect(when('سبەی').date, DateTime(2026, 10, 24));
    expect(when('عقب باجر').date, DateTime(2026, 10, 25));
    expect(when('بعد بكرة').date, DateTime(2026, 10, 25));
    expect(when('دوێنێ').date, DateTime(2026, 10, 22));
  });

  test('lunch is not tomorrow', () {
    expect(when('على الغدا').date, isNull);
  });

  test('weekday names mean the next one; today is today', () {
    expect(when('يوم السبت').date, DateTime(2026, 10, 24));
    expect(when('الجمعة').date, DateTime(2026, 10, 23));
    expect(when('بالخميس').date, DateTime(2026, 10, 29));
    expect(when('monday').date, DateTime(2026, 10, 26));
  });

  test('times', () {
    final a = when('باجر الساعة 11');
    expect((a.date, a.hour, a.minute), (DateTime(2026, 10, 24), 11, 0));
    final b = when('الساعة ١١ونص');
    expect((b.hour, b.minute), (11, 30));
    final c = when('at 7 pm');
    expect((c.hour, c.minute), (19, 0));
    final d = when('بالساعة 8 بالليل');
    expect(d.hour, 20);
    final e = when('الساعه 9 الصبح');
    expect(e.hour, 9);
    final f = when('10:15');
    expect((f.hour, f.minute), (10, 15));
  });

  test('nothing said, nothing found', () {
    final w = when('دفعت 40 الف تكسي');
    expect((w.date, w.hour, w.minute), (null, null, null));
  });
}
