import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'sheet.dart';

/// Excel 1900-system serial → local date and time. Serial 60 is the
/// 1900-02-29 that never existed (Lotus bug), so it has no date.
DateTime? excelSerialToDate(String serial) {
  final m = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(serial.trim());
  if (m == null) return null;
  final days = int.parse(m[1]!);
  if (days < 1 || days == 60 || days > 2958465) return null;
  final frac = m[2] ?? '';
  // Seconds from the fraction, rounded, using integers only.
  final scale = BigInt.from(10).pow(frac.length);
  final seconds = frac.isEmpty
      ? 0
      : ((BigInt.parse(frac) * BigInt.from(86400) * BigInt.two + scale) ~/ (scale * BigInt.two)).toInt();
  final base = days < 60 ? DateTime.utc(1899, 12, 31) : DateTime.utc(1899, 12, 30);
  final d = base.add(Duration(days: days, seconds: seconds));
  return DateTime(d.year, d.month, d.day, d.hour, d.minute, d.second);
}

/// Reads every sheet of an .xlsx, in workbook order.
List<Sheet> readXlsx(Uint8List bytes) {
  if (bytes.length > kMaxImportBytes) throw const ImportTooLarge();
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const ImportFormatException();
  }
  var total = 0;
  for (final f in zip.files) {
    total += f.size;
    if (total > kMaxImportBytes) throw const ImportTooLarge();
  }
  try {
    return _read(zip);
  } on ImportTooLarge {
    rethrow;
  } catch (_) {
    throw const ImportFormatException();
  }
}

XmlDocument? _xml(Archive zip, String path) {
  final f = zip.findFile(path);
  return f == null ? null : XmlDocument.parse(utf8.decode(f.content));
}

Iterable<XmlElement> _all(XmlNode n, String local) =>
    n.descendants.whereType<XmlElement>().where((e) => e.localName == local);

String? _attr(XmlElement e, String local) =>
    e.attributes.where((a) => a.name.local == local).map((a) => a.value).firstOrNull;

List<Sheet> _read(Archive zip) {
  final workbook = _xml(zip, 'xl/workbook.xml');
  if (workbook == null) throw const ImportFormatException();
  final rels = <String, String>{
    for (final r in _all(_xml(zip, 'xl/_rels/workbook.xml.rels') ?? XmlDocument(), 'Relationship'))
      _attr(r, 'Id')!: _attr(r, 'Target')!,
  };
  final shared = [
    for (final si in _all(_xml(zip, 'xl/sharedStrings.xml') ?? XmlDocument(), 'si'))
      _all(si, 't').where((t) => t.parentElement?.localName != 'rPh').map((t) => t.innerText).join(),
  ];
  final dateStyles = _dateStyles(_xml(zip, 'xl/styles.xml'));

  final sheets = <Sheet>[];
  for (final s in _all(workbook, 'sheet')) {
    final target = rels[_attr(s, 'id')];
    if (target == null) continue;
    final path = target.startsWith('/') ? target.substring(1) : 'xl/$target';
    final doc = _xml(zip, path);
    if (doc == null) throw const ImportFormatException();
    sheets.add(Sheet(_attr(s, 'name') ?? '', _rows(doc, shared, dateStyles)));
  }
  return sheets;
}

/// Indexes into `cellXfs` whose number format shows a date.
Set<int> _dateStyles(XmlDocument? styles) {
  if (styles == null) return const {};
  final custom = <int, String>{
    for (final f in _all(styles, 'numFmt')) int.parse(_attr(f, 'numFmtId')!): _attr(f, 'formatCode') ?? '',
  };
  final xfsParent = _all(styles, 'cellXfs').firstOrNull;
  if (xfsParent == null) return const {};
  final out = <int>{};
  var i = 0;
  for (final xf in xfsParent.childElements.where((e) => e.localName == 'xf')) {
    final id = int.tryParse(_attr(xf, 'numFmtId') ?? '0') ?? 0;
    final builtInDate = (id >= 14 && id <= 22) || (id >= 45 && id <= 47);
    if (builtInDate || (custom.containsKey(id) && _isDateFormat(custom[id]!))) out.add(i);
    i++;
  }
  return out;
}

/// A format shows a date when `d`, `m` or `y` appears outside quotes,
/// brackets (colours, locales) and escapes.
bool _isDateFormat(String code) {
  final bare = code
      .replaceAll(RegExp(r'"[^"]*"'), '')
      .replaceAll(RegExp(r'\[[^\]]*\]'), '')
      .replaceAll(RegExp(r'\\.'), '')
      .toLowerCase();
  return bare.contains(RegExp('[dmy]'));
}

int _column(String ref) {
  var n = 0;
  for (final u in ref.codeUnits) {
    if (u < 65 || u > 90) break;
    n = n * 26 + (u - 64);
  }
  return n - 1;
}

List<List<Cell>> _rows(XmlDocument doc, List<String> shared, Set<int> dateStyles) {
  final rows = <List<Cell>>[];
  for (final r in _all(doc, 'row')) {
    final index = (int.tryParse(_attr(r, 'r') ?? '') ?? rows.length + 1) - 1;
    if (index > kMaxImportRows) throw const ImportTooLarge();
    while (rows.length < index) {
      rows.add(<Cell>[]);
    }
    final row = <Cell>[];
    for (final c in r.childElements.where((e) => e.localName == 'c')) {
      final ref = _attr(c, 'r');
      final col = ref == null ? row.length : _column(ref);
      if (col >= kMaxImportColumns) throw const ImportTooLarge();
      while (row.length < col) {
        row.add(const EmptyCell());
      }
      row.add(_cell(c, shared, dateStyles));
    }
    rows.add(row);
  }
  return rows;
}

Cell _cell(XmlElement c, List<String> shared, Set<int> dateStyles) {
  final type = _attr(c, 't') ?? 'n';
  final v = c.childElements.where((e) => e.localName == 'v').firstOrNull?.innerText;
  switch (type) {
    case 's':
      final i = int.tryParse(v ?? '');
      return i == null || i >= shared.length ? const EmptyCell() : _text(shared[i]);
    case 'inlineStr':
      return _text(_all(c, 't').map((t) => t.innerText).join());
    case 'str' || 'd':
      return _text(v ?? '');
    case 'b':
      return _text(v == '1' ? 'TRUE' : 'FALSE');
    case 'e':
      return const EmptyCell();
  }
  if (v == null || v.trim().isEmpty) return const EmptyCell();
  final style = int.tryParse(_attr(c, 's') ?? '');
  return style != null && dateStyles.contains(style) ? DateSerialCell(v.trim()) : NumberCell(v.trim());
}

Cell _text(String s) => s.isEmpty ? const EmptyCell() : TextCell(s);
