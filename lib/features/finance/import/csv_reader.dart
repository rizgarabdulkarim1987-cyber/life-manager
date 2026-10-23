import 'dart:convert';
import 'dart:typed_data';

import 'sheet.dart';

/// Reads a UTF-8 CSV (BOM optional) into one unnamed sheet. The delimiter is
/// whichever of `,` `;` tab appears most on the first line; quoting is RFC 4180.
List<Sheet> readCsv(Uint8List bytes) {
  if (bytes.length > kMaxImportBytes) throw const ImportTooLarge();
  String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    throw const ImportFormatException();
  }
  if (text.startsWith('﻿')) text = text.substring(1);
  final delimiter = _delimiter(text);

  final rows = <List<Cell>>[];
  var row = <Cell>[];
  final field = StringBuffer();
  var quoted = false;
  var wasQuoted = false;

  void endField() {
    final v = field.toString();
    row.add(v.isEmpty && !wasQuoted ? const EmptyCell() : TextCell(v));
    if (row.length > kMaxImportColumns) throw const ImportTooLarge();
    field.clear();
    wasQuoted = false;
  }

  void endRow() {
    endField();
    rows.add(row);
    if (rows.length > kMaxImportRows + 1) throw const ImportTooLarge();
    row = <Cell>[];
  }

  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(ch);
      }
    } else if (ch == '"' && field.isEmpty) {
      quoted = true;
      wasQuoted = true;
    } else if (ch == delimiter) {
      endField();
    } else if (ch == '\r' || ch == '\n') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      endRow();
    } else {
      field.write(ch);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty || wasQuoted) endRow();
  // The header row is allowed on top of the row limit.
  if (rows.length > kMaxImportRows + 1) throw const ImportTooLarge();
  return [Sheet('', rows)];
}

String _delimiter(String text) {
  final end = text.indexOf(RegExp('[\r\n]'));
  final first = end < 0 ? text : text.substring(0, end);
  var best = ',';
  var bestCount = 0;
  for (final d in const [',', ';', '\t']) {
    final n = d.allMatches(first).length;
    if (n > bestCount) {
      best = d;
      bestCount = n;
    }
  }
  return best;
}
