import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/money/amount_parse.dart';
import '../../../core/money/conversion.dart';
import '../../../core/money/money.dart';
import '../../../core/text/digits.dart';

/// Parses a typed rate ("1310", "1,312.5", Arabic-Indic digits) into rate × 10⁶.
int? parseRateE6(String s) {
  final t = normalizeDigits(s.trim()).replaceAll(RegExp('[,٬\\s]'), '').replaceAll('٫', '.');
  if (!RegExp(r'^\d+(\.\d{1,6})?$').hasMatch(t)) return null;
  final v = decimalToMinor(t, 6).minor;
  return v > 0 ? v : null;
}

class ConvertedLine {
  const ConvertedLine({required this.original, required this.converted, required this.rate});

  final Money original;

  /// Null when no rate exists for this currency.
  final Money? converted;
  final RateValue? rate;
}

/// A consolidated figure with everything needed to show how it was converted.
class Consolidated {
  const Consolidated({
    required this.base,
    required this.total,
    required this.subtotals,
    required this.lines,
    required this.missingRates,
  });

  final String base;

  /// Null when any currency has no rate: wrong numbers are worse than none.
  final Money? total;
  final Map<String, Money> subtotals;
  final List<ConvertedLine> lines;
  final List<String> missingRates;
}

DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

RateValue _value(ExchangeRate r) =>
    RateValue(base: r.baseCode, quote: r.quoteCode, rateE6: r.rateE6, effectiveFrom: r.effectiveFrom);

class RatesRepository {
  RatesRepository(this._db);

  final AppDatabase _db;

  Expression<bool> _pair(ExchangeRates r, String a, String b) =>
      (r.baseCode.equals(a) & r.quoteCode.equals(b)) | (r.baseCode.equals(b) & r.quoteCode.equals(a));

  /// One rate per pair and day; setting it again replaces it.
  Future<void> setRate({
    required String base,
    required String quote,
    required int rateE6,
    required DateTime effectiveFrom,
  }) {
    if (rateE6 <= 0) throw ArgumentError.value(rateE6, 'rateE6');
    if (base == quote) throw ArgumentError.value(quote, 'quote');
    final day = _day(effectiveFrom);
    return _db.transaction(() async {
      await (_db.delete(_db.exchangeRates)..where((r) => _pair(r, base, quote) & r.effectiveFrom.equals(day))).go();
      await _db
          .into(_db.exchangeRates)
          .insert(
            ExchangeRatesCompanion.insert(
              baseCode: base,
              quoteCode: quote,
              rateE6: rateE6,
              effectiveFrom: day,
              createdAt: DateTime.now().toUtc(),
            ),
          );
    });
  }

  Future<RateValue?> rateOn(String a, String b, DateTime day) async {
    final row =
        await (_db.select(_db.exchangeRates)
              ..where((r) => _pair(r, a, b) & r.effectiveFrom.isSmallerOrEqualValue(day))
              ..orderBy([(r) => OrderingTerm.desc(r.effectiveFrom)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _value(row);
  }

  /// Every stored rate, any pair, oldest first (for lookups over a range).
  Future<List<RateValue>> all() async {
    final rows = await (_db.select(_db.exchangeRates)..orderBy([(r) => OrderingTerm.asc(r.effectiveFrom)])).get();
    return rows.map(_value).toList();
  }

  Stream<List<RateValue>> watchHistory(String a, String b) =>
      (_db.select(_db.exchangeRates)
            ..where((r) => _pair(r, a, b))
            ..orderBy([(r) => OrderingTerm.desc(r.effectiveFrom)]))
          .watch()
          .map((rows) => rows.map(_value).toList());

  Future<Consolidated> consolidate(Map<int, Money> balances, {required String base, required DateTime day}) async {
    final subtotals = <String, Money>{};
    for (final m in balances.values) {
      subtotals[m.currency] = (subtotals[m.currency] ?? Money(0, m.currency)) + m;
    }
    final rates = <String, RateValue?>{};
    for (final c in subtotals.keys) {
      if (c != base) rates[c] = await rateOn(c, base, day);
    }
    final lines = <ConvertedLine>[];
    for (final m in balances.values) {
      final r = m.currency == base ? null : rates[m.currency];
      final converted = m.currency == base ? m : (r == null ? null : convert(m, base, r));
      lines.add(ConvertedLine(original: m, converted: converted, rate: r));
    }
    final missing = [
      for (final e in rates.entries)
        if (e.value == null) e.key,
    ];
    Money? total;
    if (missing.isEmpty) {
      total = lines.fold<Money>(Money(0, base), (s, l) => s + l.converted!);
    }
    return Consolidated(base: base, total: total, subtotals: subtotals, lines: lines, missingRates: missing);
  }
}

/// All rates in memory, for converting many rows at their own dates.
class RateBook {
  RateBook(List<RateValue> rates) : _rates = [...rates]..sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));

  final List<RateValue> _rates;

  /// The latest rate for the pair with `effectiveFrom ≤ day`, either direction.
  RateValue? on(String a, String b, DateTime day) {
    for (final r in _rates) {
      if (r.covers(a, b) && !r.effectiveFrom.isAfter(day)) return r;
    }
    return null;
  }

  /// Null when [m] is in another currency and no rate covers [day].
  Money? convertOn(Money m, String to, DateTime day) {
    if (m.currency == to) return m;
    final r = on(m.currency, to, day);
    return r == null ? null : convert(m, to, r);
  }
}

extension RateBookLoad on RatesRepository {
  Future<RateBook> book() async => RateBook(await all());
}
