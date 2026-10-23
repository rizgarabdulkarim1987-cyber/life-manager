import '../../../core/text/digits.dart';
import 'keywords.dart';

typedef When = ({DateTime? date, int? hour, int? minute});

/// A date and time said in folded text, relative to [now]. Fields not said are null.
When findWhen(String normalized, DateTime now) => whenInTokens(tokenize(normalized), now).when;

Set<String> _set(List<String> raw) => {for (final r in raw) normalizeForMatch(r)};

final _today = _set(['اليوم', 'today', 'ئەمڕۆ', 'هسه']);
final _yesterday = _set(['امس', 'البارحة', 'البارح', 'yesterday', 'دوێنێ']);
// «غدا» is left out: in Iraqi speech it is lunch, and tomorrow is «باجر».
final _tomorrow = _set(['باجر', 'باچر', 'بكرة', 'بكرا', 'tomorrow', 'سبەی']);
final _afterTomorrow = _set(['دووسبەی']);
final _after = _set(['عقب', 'بعد', 'after']);

/// DateTime.weekday numbering: Monday 1 … Sunday 7. Arabic names need «ال»
/// because «اثنين» is also the number two.
final Map<String, int> _weekdays = {
  for (final e in {
    1: ['الاثنين', 'الاتنين', 'monday', 'دووشەممە'],
    2: ['الثلاثاء', 'الثلاثا', 'tuesday', 'سێشەممە'],
    3: ['الاربعاء', 'الاربعا', 'wednesday', 'چوارشەممە'],
    4: ['الخميس', 'thursday', 'پێنجشەممە'],
    5: ['الجمعة', 'الجمعه', 'friday', 'هەینی'],
    6: ['السبت', 'saturday', 'شەممە'],
    7: ['الاحد', 'sunday', 'یەکشەممە'],
  }.entries)
    for (final f in e.value) normalizeForMatch(f): e.key,
};

final _hourWords = _set(['ساعة', 'at', 'کاتژمێر']);
final _morning = _set(['صبح', 'صباح', 'صباحا', 'فجر', 'am', 'بەیانی']);

/// Whether the words say morning («صباحا», «am»).
bool saysMorning(List<Tok> toks) => toks.any((t) => _in(t, _morning));

final _evening = _set(['ليل', 'مساء', 'مساءا', 'عصر', 'ظهر', 'مغرب', 'pm', 'ئێوارە', 'شەو']);

final Map<String, int> _hourNames = {
  for (final e in {
    1: ['وحدة', 'واحدة', 'one', 'یەک'],
    2: ['ثنتين', 'اثنين', 'two', 'دوو'],
    3: ['ثلاثة', 'تلاثة', 'three', 'سێ'],
    4: ['اربعة', 'four', 'چوار'],
    5: ['خمسة', 'five', 'پێنج'],
    6: ['ستة', 'six', 'شەش'],
    7: ['سبعة', 'seven', 'حەوت'],
    8: ['ثمانية', 'ثمنية', 'eight', 'هەشت'],
    9: ['تسعة', 'nine', 'نۆ'],
    10: ['عشرة', 'ten', 'دە'],
    11: ['احدعش', 'eleven', 'یازدە'],
    12: ['اثنعش', 'twelve', 'دوازدە'],
  }.entries)
    for (final f in e.value) normalizeForMatch(f): e.key,
};

bool _in(Tok t, Set<String> words) => candidates(t.norm).any(words.contains);

/// The same as [findWhen] over tokens, plus the token indices the words used.
({When when, Set<int> used}) whenInTokens(List<Tok> toks, DateTime now) {
  final used = <int>{};
  final day = DateTime(now.year, now.month, now.day);
  DateTime? date;
  int? hour, minute;

  for (var i = 0; i < toks.length && date == null; i++) {
    final t = toks[i];
    if (i + 1 < toks.length && _after.contains(t.norm) && _in(toks[i + 1], _tomorrow)) {
      date = day.add(const Duration(days: 2));
      used.addAll([i, i + 1]);
    } else if (_afterTomorrow.contains(t.norm)) {
      date = day.add(const Duration(days: 2));
      used.add(i);
    } else if (_in(t, _today)) {
      date = day;
      used.add(i);
    } else if (_in(t, _yesterday)) {
      date = day.subtract(const Duration(days: 1));
      used.add(i);
    } else if (_in(t, _tomorrow)) {
      date = day.add(const Duration(days: 1));
      used.add(i);
    } else {
      final wd = candidates(t.norm).map((c) => _weekdays[c]).nonNulls.firstOrNull;
      if (wd != null) {
        date = day.add(Duration(days: (wd - now.weekday) % 7));
        used.add(i);
        if (i > 0 && _in(toks[i - 1], _set(['يوم', 'day']))) used.add(i - 1);
      }
    }
  }

  int? hourAt(int i) {
    if (i >= toks.length) return null;
    final n = toks[i].norm;
    if (RegExp(r'^\d{1,2}$').hasMatch(n)) {
      final h = int.parse(n);
      return h <= 24 ? h : null;
    }
    return _hourNames[n];
  }

  for (var i = 0; i < toks.length && hour == null; i++) {
    final clock = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(toks[i].norm);
    int? at;
    if (clock != null) {
      hour = int.parse(clock[1]!);
      minute = int.parse(clock[2]!);
      used.add(i);
      at = i;
    } else if (_in(toks[i], _hourWords) && hourAt(i + 1) != null) {
      hour = hourAt(i + 1);
      minute = 0;
      used.addAll([i, i + 1]);
      at = i + 1;
    } else if (toks[i].isDigits &&
        hourAt(i) != null &&
        i + 1 < toks.length &&
        _in(toks[i + 1], {..._morning, ..._evening})) {
      hour = hourAt(i);
      minute = 0;
      used.add(i);
      at = i;
    }
    if (at == null) continue;
    var k = at + 1;
    if (k < toks.length) {
      final n = toks[k].norm;
      final fraction = switch (n) {
        'ونص' => 30,
        'وربع' => 15,
        _ => null,
      };
      if (fraction != null) {
        minute = fraction;
        used.add(k++);
      } else if (n == 'و' && k + 1 < toks.length && {'نص', 'ربع'}.contains(toks[k + 1].norm)) {
        minute = toks[k + 1].norm == 'نص' ? 30 : 15;
        used.addAll([k, k + 1]);
        k += 2;
      }
    }
    if (k < toks.length && _in(toks[k], _evening)) {
      if (hour! < 12) hour += 12;
      used.add(k);
    } else if (k < toks.length && _in(toks[k], _morning)) {
      if (hour == 12) hour = 0;
      used.add(k);
    }
  }
  return (when: (date: date, hour: hour, minute: minute), used: used);
}
