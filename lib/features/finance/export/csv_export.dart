import '../../../core/db/app_database.dart';
import '../ui/widgets/amount_field.dart' show minorToPlain;

/// Names the CSV shows instead of ids. Column titles stay fixed English keys so
/// a spreadsheet formula keeps working whatever the app language.
class CsvLabels {
  const CsvLabels({
    required this.type,
    required this.workspaces,
    required this.accounts,
    required this.accountCurrencies,
    required this.categories,
  });

  final String Function(Transaction t) type;
  final Map<int, String> workspaces;
  final Map<int, String> accounts;
  final Map<int, String> accountCurrencies;
  final Map<int, String> categories;
}

const _columns = [
  'date',
  'type',
  'workspace',
  'account',
  'category',
  'amount',
  'currency',
  'description',
  'transfer_to',
  'to_amount',
  'rate',
];

String _date(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

/// UTF-8 text with a BOM, so Excel opens Arabic and Kurdish correctly.
/// Amounts are exact decimals built from minor units, never a double.
String transactionsCsv(List<Transaction> txs, CsvLabels labels) {
  final out = StringBuffer('\uFEFF')..write('${_columns.join(',')}\r\n');
  for (final t in txs) {
    final toCurrency = t.toAccountId == null ? null : labels.accountCurrencies[t.toAccountId] ?? t.currencyCode;
    final row = [
      _date(t.occurredAt.toLocal()),
      _text(labels.type(t)),
      _text(labels.workspaces[t.workspaceId] ?? ''),
      _text(labels.accounts[t.accountId] ?? ''),
      _text(t.categoryId == null ? '' : labels.categories[t.categoryId] ?? ''),
      minorToPlain(t.amountMinor, t.currencyCode),
      t.currencyCode,
      _text(t.description ?? ''),
      _text(t.toAccountId == null ? '' : labels.accounts[t.toAccountId] ?? ''),
      t.toAmountMinor == null ? '' : minorToPlain(t.toAmountMinor!, toCurrency!),
      t.rateE6 == null ? '' : _rate(t.rateE6!),
    ];
    out.write('${row.join(',')}\r\n');
  }
  return out.toString();
}

/// RFC 4180 quoting, and a leading `'` on text a spreadsheet would run as a
/// formula. Numbers are built here and never pass through this.
String _text(String s) {
  final safe = s.isNotEmpty && '=+-@\t\r'.contains(s[0]) ? "'$s" : s;
  final quote = safe.contains(RegExp('[",\r\n]'));
  return quote ? '"${safe.replaceAll('"', '""')}"' : safe;
}

String _rate(int e6) {
  final whole = e6 ~/ 1000000;
  final frac = (e6 % 1000000).toString().padLeft(6, '0').replaceFirst(RegExp(r'0+$'), '');
  return frac.isEmpty ? '$whole' : '$whole.$frac';
}
