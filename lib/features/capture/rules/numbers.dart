import '../../../core/money/amount_parse.dart';
import '../../../core/text/digits.dart';
import 'keywords.dart';

/// An amount found in folded text: [digitsText] is a plain decimal
/// (`25000`, `12.5`) in [currency] units, or in the base currency when null.
class AmountMatch {
  const AmountMatch(this.digitsText, this.currency, this.start, this.end);

  final String digitsText;
  final String? currency;
  final int start;
  final int end;
}

/// An amount over token indices [first]..[last] (currency word included).
class TokenAmount {
  const TokenAmount(this.digitsText, this.currency, this.first, this.last);

  final String digitsText;
  final String? currency;
  final int first;
  final int last;
}

List<AmountMatch> findAmounts(String normalized) {
  final toks = tokenize(normalized);
  return [
    for (final a in amountsInTokens(toks)) AmountMatch(a.digitsText, a.currency, toks[a.first].start, toks[a.last].end),
  ];
}

// Values are kept ×10⁶ so halves, quarters and `1.5m` stay exact integers.
final _m = BigInt.from(1000000);

enum _Kind { small, hundred, scale, fixed, fraction, paper }

class _Word {
  const _Word(this.kind, this.value, {this.scale = 1, this.usd = false});

  final _Kind kind;

  /// Small: the number. Hundred/scale/paper: the multiplier. Fixed: the whole
  /// value (`الفين` = 2000). Fraction: the part ×10⁶ (half = 500000).
  final int value;

  /// For fixed words: the scale they belong to, for a following «ونص».
  final int scale;

  /// «ورقة» and «دفتر» are always dollars.
  final bool usd;
}

final Map<String, _Word> _words = () {
  final w = <String, _Word>{};
  void small(int v, List<String> forms) {
    for (final f in forms) {
      w[normalizeForMatch(f)] = _Word(_Kind.small, v);
    }
  }

  small(1, ['واحد', 'واحدة', 'وحدة', 'one', 'یەک']);
  small(2, ['اثنين', 'اثنان', 'ثنين', 'اتنين', 'two', 'دوو']);
  small(3, ['ثلاث', 'ثلاثة', 'تلاث', 'تلاثة', 'three', 'سێ']);
  small(4, ['اربع', 'اربعة', 'four', 'چوار']);
  small(5, ['خمس', 'خمسة', 'five', 'پێنج']);
  small(6, ['ست', 'ستة', 'six', 'شەش']);
  small(7, ['سبع', 'سبعة', 'seven', 'حەوت']);
  small(8, ['ثمان', 'ثمانية', 'ثماني', 'ثمنية', 'eight', 'هەشت']);
  small(9, ['تسع', 'تسعة', 'nine', 'نۆ']);
  small(10, ['عشر', 'عشرة', 'ten', 'دە']);
  small(11, ['احدعش', 'احدعشر', 'حداعش', 'eleven', 'یازدە']);
  small(12, ['اثنعش', 'اثنعشر', 'ثنعش', 'twelve', 'دوازدە']);
  small(13, ['ثلطعش', 'تلطعش', 'ثلاثطعش', 'thirteen', 'سیازدە']);
  small(14, ['اربعطعش', 'اربعتعش', 'fourteen', 'چواردە']);
  small(15, ['خمسطعش', 'خمستعش', 'fifteen', 'پازدە']);
  small(16, ['ستطعش', 'سطعش', 'sixteen', 'شازدە']);
  small(17, ['سبعطعش', 'seventeen', 'حەڤدە']);
  small(18, ['ثمنطعش', 'ثمانطعش', 'eighteen', 'هەژدە']);
  small(19, ['تسعطعش', 'nineteen', 'نۆزدە']);
  small(20, ['عشرين', 'عشرون', 'twenty', 'بیست']);
  small(30, ['ثلاثين', 'تلاثين', 'ثلاثون', 'thirty', 'سی']);
  small(40, ['اربعين', 'اربعون', 'forty', 'چل']);
  small(50, ['خمسين', 'خمسون', 'fifty', 'پەنجا']);
  small(60, ['ستين', 'ستون', 'sixty', 'شەست']);
  small(70, ['سبعين', 'سبعون', 'seventy', 'حەفتا']);
  small(80, ['ثمانين', 'ثمنين', 'ثمانون', 'eighty', 'هەشتا']);
  small(90, ['تسعين', 'تسعون', 'ninety', 'نەوەد']);
  small(200, ['ميتين', 'مئتين', 'مئتان', 'مايتين']);
  const hundreds = {
    3: ['ثلاث', 'تلاث', 'ثلث', 'تلث'],
    4: ['اربع'],
    5: ['خمس'],
    6: ['ست'],
    7: ['سبع'],
    8: ['ثمن', 'ثمان'],
    9: ['تسع'],
  };
  for (final e in hundreds.entries) {
    small(e.key * 100, [
      for (final p in e.value)
        for (final s in ['مية', 'مئة', 'ماية', 'مائة']) '$p$s',
    ]);
  }
  for (final f in ['مية', 'مئة', 'ماية', 'مائة', 'ميت', 'hundred', 'سەد']) {
    w[normalizeForMatch(f)] = const _Word(_Kind.hundred, 100);
  }
  for (final f in ['الف', 'ألف', 'آلاف', 'الاف', 'تلاف', 'thousand', 'هەزار']) {
    w[normalizeForMatch(f)] = const _Word(_Kind.scale, 1000);
  }
  for (final f in ['مليون', 'ملايين', 'million', 'ملیۆن']) {
    w[normalizeForMatch(f)] = const _Word(_Kind.scale, 1000000);
  }
  for (final f in ['الفين', 'ألفين', 'ألفان']) {
    w[normalizeForMatch(f)] = const _Word(_Kind.fixed, 2000, scale: 1000);
  }
  w[normalizeForMatch('مليونين')] = const _Word(_Kind.fixed, 2000000, scale: 1000000);
  for (final f in ['نص', 'نصف', 'نیو', 'half']) {
    w[normalizeForMatch(f)] = const _Word(_Kind.fraction, 500000);
  }
  w[normalizeForMatch('ربع')] = const _Word(_Kind.fraction, 250000);
  // Decision 16: a «ورقة» is a 100-dollar note, a «دفتر» a 10,000-dollar wad.
  for (final f in ['ورقة', 'ورقات', 'اوراق']) {
    w[normalizeForMatch(f)] = const _Word(_Kind.paper, 100, usd: true);
  }
  w[normalizeForMatch('ورقتين')] = const _Word(_Kind.fixed, 200, scale: 100, usd: true);
  for (final f in ['دفتر', 'دفاتر']) {
    w[normalizeForMatch(f)] = const _Word(_Kind.paper, 10000, usd: true);
  }
  w[normalizeForMatch('دفترين')] = const _Word(_Kind.fixed, 20000, scale: 10000, usd: true);
  return w;
}();

final Map<String, String> _currencyWords = {
  for (final f in ['دينار', 'دنانير', 'دینار', 'iqd', 'ع']) normalizeForMatch(f): 'IQD',
  for (final f in ['دولار', 'دولارات', 'دۆلار', r'$', 'usd', 'اخضر', 'dollar', 'dollars']) normalizeForMatch(f): 'USD',
};

const _connectors = {'و', 'and'};

/// The currency a token names, also with particles attached («بالدولار»).
String? currencyOf(Tok t) {
  for (final c in candidates(t.norm)) {
    final cur = _currencyWords[c];
    if (cur != null) return cur;
  }
  return null;
}

_Word? _wordOf(String norm) => _words[norm];

BigInt? _digitsValue(Tok t) {
  if (!t.isDigits || t.norm.contains(':')) return null;
  final plain = t.norm.replaceAll(RegExp('[,٬]'), '').replaceAll('٫', '.');
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(plain)) return null;
  final v = decimalToMinor(plain, 6);
  return v == null ? null : BigInt.from(v.minor);
}

String _format(BigInt micro) {
  final whole = micro ~/ _m;
  final frac = (micro % _m).toString().padLeft(6, '0').replaceFirst(RegExp(r'0+$'), '');
  return frac.isEmpty ? '$whole' : '$whole.$frac';
}

/// Amounts over [toks], in order, skipping token indices in [skip]
/// (dates and times are found first so «الساعة 11» is not 11 dinars).
List<TokenAmount> amountsInTokens(List<Tok> toks, {Set<int> skip = const {}}) {
  final out = <TokenAmount>[];
  var i = 0;
  while (i < toks.length) {
    final a = skip.contains(i) ? null : _phraseAt(toks, i, skip);
    if (a == null) {
      i++;
      continue;
    }
    out.add(a);
    i = a.last + 1;
  }
  return out;
}

TokenAmount? _phraseAt(List<Tok> toks, int i, Set<int> skip) {
  var total = BigInt.zero, current = BigInt.zero;
  var lastUnit = 1; // what a following «ونص» is half of
  var lastWasScale = false;
  var substantive = false; // more than a bare «نص»
  var usd = false;
  var last = -1;
  int? prevSmall;
  var j = i;
  loop:
  while (j < toks.length && !skip.contains(j)) {
    final t = toks[j];
    var norm = t.norm;
    var joined = false;
    if (j > i && _connectors.contains(norm)) {
      if (j + 1 < toks.length && !skip.contains(j + 1) && _wordOf(_stripAnd(toks[j + 1].norm)) != null) {
        j++;
        norm = _stripAnd(toks[j].norm);
        joined = true;
      } else {
        break loop;
      }
    } else if (j > i && norm.startsWith('و') && _wordOf(norm.substring(1)) != null) {
      norm = norm.substring(1);
      joined = true;
    }

    final digits = j == i ? _digitsValue(t) : null;
    if (digits != null) {
      current = digits;
      lastUnit = 1;
      substantive = true;
      last = j;
      // `25k`, `1.5m`: the letter sits right against the digits.
      if (j + 1 < toks.length && toks[j + 1].start == t.end && !skip.contains(j + 1)) {
        final s = switch (toks[j + 1].norm) {
          'k' => 1000,
          'm' => 1000000,
          _ => null,
        };
        if (s != null) {
          total += current * BigInt.from(s);
          current = BigInt.zero;
          lastUnit = s;
          lastWasScale = true;
          j += 2;
          last = j - 1;
          continue;
        }
      }
      j++;
      continue;
    }

    final w = _wordOf(norm);
    if (w == null) break loop;
    switch (w.kind) {
      case _Kind.small:
        // «twenty five» joins without «و»; «five ten» is two numbers.
        final follows = prevSmall != null && prevSmall >= 20 && prevSmall % 10 == 0 && w.value < 10;
        if (last >= 0 && !joined && !follows) break loop;
        current += BigInt.from(w.value) * _m;
        prevSmall = w.value;
        lastUnit = w.value >= 100 ? 100 : 1;
        lastWasScale = false;
        substantive = true;
      case _Kind.hundred:
        current = (current == BigInt.zero ? _m : current) * BigInt.from(100);
        lastUnit = 100;
        lastWasScale = false;
        prevSmall = null;
        substantive = true;
      case _Kind.scale || _Kind.paper:
        if (w.usd) usd = true;
        total += (current == BigInt.zero ? _m : current) * BigInt.from(w.value);
        current = BigInt.zero;
        lastUnit = w.value;
        lastWasScale = true;
        prevSmall = null;
        substantive = true;
      case _Kind.fixed:
        if (current != BigInt.zero) break loop;
        if (w.usd) usd = true;
        total += BigInt.from(w.value) * _m;
        lastUnit = w.scale;
        lastWasScale = true;
        prevSmall = null;
        substantive = true;
      case _Kind.fraction:
        if (joined && last >= 0) {
          // «مليون ونص», «مية ونص»: half of the unit just said.
          final part = BigInt.from(w.value) * BigInt.from(lastUnit);
          if (lastWasScale) {
            total += part;
          } else {
            current += part;
          }
        } else {
          // «ربع مليون», «نص ورقة»: only before a scale word.
          if (last >= 0 || j + 1 >= toks.length) break loop;
          final next = _wordOf(toks[j + 1].norm);
          if (next == null || !(next.kind == _Kind.scale || next.kind == _Kind.paper)) break loop;
          current = BigInt.from(w.value);
        }
    }
    last = j;
    j++;
  }
  if (last < 0 || !substantive) return null;
  final value = total + current;
  if (value == BigInt.zero) return null;

  String? currency = usd ? 'USD' : null;
  var end = last;
  if (currency == null && last + 1 < toks.length && !skip.contains(last + 1)) {
    currency = currencyOf(toks[last + 1]);
    if (currency != null) end = last + 1;
  }
  var first = i;
  if (currency == null && i > 0 && !skip.contains(i - 1)) {
    final before = toks[i - 1].norm;
    if (before == r'$' || before == 'usd') {
      currency = 'USD';
      first = i - 1;
    }
  }
  return TokenAmount(_format(value), currency, first, end);
}

String _stripAnd(String norm) => norm.startsWith('و') && _wordOf(norm.substring(1)) != null ? norm.substring(1) : norm;
