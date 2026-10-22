import '../../../core/money/amount_parse.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/rounding.dart';
import '../../../core/text/digits.dart';
import 'sheet.dart';
import 'xlsx_reader.dart' show excelSerialToDate;

enum DateOrder { dayFirst, monthFirst, iso }

enum AmountMode { signed, typeColumn, splitColumns }

final _datePart = RegExp(r'^(\d{1,4})[/\-.](\d{1,2})[/\-.](\d{1,4})$');
final _timePart = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$');

/// A typed date (`3/4/2024`, `2024-04-03`, `٣.٤.٢٠٢٤`, optional `14:30`).
/// A four-digit first part is always year-month-day.
DateTime? parseTextDate(String s, DateOrder o) {
  final parts = normalizeDigits(s.trim()).split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.length > 2) return null;
  final m = _datePart.firstMatch(parts[0]);
  if (m == null) return null;
  final a = int.parse(m[1]!), b = int.parse(m[2]!), c = int.parse(m[3]!);
  int y, mo, d;
  if (m[1]!.length == 4 || o == DateOrder.iso) {
    (y, mo, d) = (a, b, c);
  } else if (o == DateOrder.dayFirst) {
    (y, mo, d) = (c, b, a);
  } else {
    (y, mo, d) = (c, a, b);
  }
  if (y < 100) y += 2000;
  var h = 0, mi = 0, sec = 0;
  if (parts.length == 2) {
    final t = _timePart.firstMatch(parts[1]);
    if (t == null) return null;
    (h, mi, sec) = (int.parse(t[1]!), int.parse(t[2]!), int.parse(t[3] ?? '0'));
    if (h > 23 || mi > 59 || sec > 59) return null;
  }
  final out = DateTime(y, mo, d, h, mi, sec);
  return out.year == y && out.month == mo && out.day == d ? out : null;
}

final _plainDecimal = RegExp(r'^-?\d+(\.\d+)?$');
final _sci = RegExp(r'^(-?)(\d+)(?:\.(\d+))?[eE]([+-]?\d+)$');

/// `1.5E3` → `1500`, exactly, as text.
String _plain(String t) {
  final m = _sci.firstMatch(t);
  if (m == null) return t;
  final digits = '${m[2]}${m[3] ?? ''}';
  final point = m[2]!.length + int.parse(m[4]!);
  final String body;
  if (point <= 0) {
    body = '0.${'0' * -point}$digits';
  } else if (point >= digits.length) {
    body = digits + '0' * (point - digits.length);
  } else {
    body = '${digits.substring(0, point)}.${digits.substring(point)}';
  }
  return '${m[1]}$body';
}

/// Spreadsheet decimal text → minor units. The text is first rounded half-even
/// to 6 places, which absorbs binary artefacts like `1250000.0000000002`.
int? decimalTextToMinor(String text, String currency) {
  final t = _plain(normalizeDigits(text.trim()).replaceAll('−', '-'));
  if (!_plainDecimal.hasMatch(t)) return null;
  final six = decimalToMinor(t, 6).minor;
  return divRoundHalfEven(BigInt.from(six), pow10(6 - currencyExponent(currency))).toInt();
}

class ColumnMapping {
  const ColumnMapping({
    required this.dateCol,
    this.dateOrder = DateOrder.dayFirst,
    this.amountMode = AmountMode.signed,
    this.amountCol,
    this.incomeCol,
    this.expenseCol,
    this.typeCol,
    this.currencyCol,
    this.categoryCol,
    this.workspaceCol,
    this.accountCol,
    this.descriptionCol,
  });

  final int dateCol;
  final DateOrder dateOrder;
  final AmountMode amountMode;
  final int? amountCol, incomeCol, expenseCol, typeCol, currencyCol, categoryCol, workspaceCol, accountCol;
  final int? descriptionCol;
}

class ImportDefaults {
  const ImportDefaults({required this.currency, required this.workspaceId, required this.accountByWorkspaceCurrency});

  final String currency;
  final int workspaceId;

  /// `"wsId:IQD"` → account id.
  final Map<String, int> accountByWorkspaceCurrency;
}

/// What each raw value in a mapped column means. A null id means "create new",
/// which the wizard resolves before planning.
class ValueMaps {
  const ValueMaps({
    this.typeValues = const {},
    this.categories = const {},
    this.workspaces = const {},
    this.accounts = const {},
  });

  /// raw → `income`, `expense` or `skip`.
  final Map<String, String> typeValues;
  final Map<String, int?> categories;
  final Map<String, int?> workspaces;
  final Map<String, int?> accounts;
}

class ImportRow {
  const ImportRow({
    required this.sourceRow,
    required this.type,
    required this.accountId,
    required this.amountMinor,
    required this.occurredAt,
    this.categoryId,
    this.description,
    this.duplicate = false,
    this.problem,
  });

  /// 1-based, as the spreadsheet numbers rows.
  final int sourceRow;
  final String type;
  final int accountId;
  final int amountMinor;
  final DateTime occurredAt;
  final int? categoryId;
  final String? description;
  final bool duplicate;

  /// `date`, `amount`, `type` or `account`; such rows are never imported.
  final String? problem;
}

String _two(int v) => v.toString().padLeft(2, '0');

/// What makes two rows "the same": day, account, amount and description.
String importKey(DateTime local, int accountId, int amountMinor, String? description) =>
    '${local.year}-${_two(local.month)}-${_two(local.day)}|$accountId|$amountMinor|'
    '${normalizeForMatch(description ?? '')}';

Cell _at(List<Cell> row, int? col) => col == null || col >= row.length ? const EmptyCell() : row[col];

DateTime? _date(Cell c, DateOrder o) => switch (c) {
  DateSerialCell(:final serialText) => excelSerialToDate(serialText),
  NumberCell(:final decimalText) => excelSerialToDate(decimalText),
  TextCell(:final value) => parseTextDate(value, o),
  EmptyCell() => null,
};

/// Signed amount in minor units, or null when the cell has none.
int? _amount(Cell c, String currency) {
  switch (c) {
    case NumberCell(:final decimalText):
      return decimalTextToMinor(decimalText, currency);
    case TextCell(:final value):
      var t = normalizeDigits(value.trim()).replaceAll('−', '-');
      var negative = false;
      if (t.startsWith('(') && t.endsWith(')')) {
        negative = true;
        t = t.substring(1, t.length - 1);
      }
      // Drop currency words and symbols around the number.
      t = t.replaceAll(RegExp(r'[^\d.,٫٬\-]'), '');
      final v = parseDecimalToMinor(t, currency)?.minor ?? decimalTextToMinor(t.replaceAll(',', ''), currency);
      if (v == null) return null;
      return negative ? -v.abs() : v;
    default:
      return null;
  }
}

/// Turns a sheet into rows to import. Pure: everything it needs is passed in.
List<ImportRow> planImport(
  Sheet s,
  int headerRow,
  ColumnMapping m,
  ImportDefaults d,
  ValueMaps v, {
  required Set<String> existingKeys,
}) {
  final out = <ImportRow>[];
  final seen = <String>{};
  for (var i = headerRow + 1; i < s.rows.length; i++) {
    final row = s.rows[i];
    if (row.every((c) => c is EmptyCell)) continue;
    ImportRow problem(String p) =>
        ImportRow(sourceRow: i + 1, type: '', accountId: 0, amountMinor: 0, occurredAt: DateTime(0), problem: p);

    final rawCurrency = cellText(_at(row, m.currencyCol)).trim().toUpperCase();
    final currency = kCurrencyExponents.containsKey(rawCurrency) ? rawCurrency : d.currency;

    final date = _date(_at(row, m.dateCol), m.dateOrder);
    if (date == null) {
      out.add(problem('date'));
      continue;
    }

    String type;
    int? amount;
    switch (m.amountMode) {
      case AmountMode.signed:
        amount = _amount(_at(row, m.amountCol), currency);
        type = (amount ?? 0) < 0 ? 'expense' : 'income';
      case AmountMode.typeColumn:
        amount = _amount(_at(row, m.amountCol), currency)?.abs();
        final mapped = v.typeValues[cellText(_at(row, m.typeCol)).trim()];
        if (mapped == 'skip') continue;
        if (mapped != 'income' && mapped != 'expense') {
          out.add(problem('type'));
          continue;
        }
        type = mapped!;
      case AmountMode.splitColumns:
        final income = _amount(_at(row, m.incomeCol), currency)?.abs() ?? 0;
        final expense = _amount(_at(row, m.expenseCol), currency)?.abs() ?? 0;
        (type, amount) = income > 0 ? ('income', income) : ('expense', expense > 0 ? expense : null);
    }
    if (amount == null || amount == 0) {
      out.add(problem('amount'));
      continue;
    }
    amount = amount.abs();

    final wsRaw = cellText(_at(row, m.workspaceCol)).trim();
    final ws = (wsRaw.isEmpty ? null : v.workspaces[wsRaw]) ?? d.workspaceId;
    final accRaw = cellText(_at(row, m.accountCol)).trim();
    final account = (accRaw.isEmpty ? null : v.accounts[accRaw]) ?? d.accountByWorkspaceCurrency['$ws:$currency'];
    if (account == null) {
      out.add(problem('account'));
      continue;
    }
    final catRaw = cellText(_at(row, m.categoryCol)).trim();
    final description = cellText(_at(row, m.descriptionCol)).trim();

    final key = importKey(date, account, amount, description);
    final duplicate = existingKeys.contains(key) || !seen.add(key);
    out.add(
      ImportRow(
        sourceRow: i + 1,
        type: type,
        accountId: account,
        amountMinor: amount,
        occurredAt: date,
        categoryId: catRaw.isEmpty ? null : v.categories[catRaw],
        description: description.isEmpty ? null : description,
        duplicate: duplicate,
      ),
    );
  }
  return out;
}
