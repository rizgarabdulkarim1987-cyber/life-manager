import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/finance/import/csv_reader.dart';
import 'package:life_manager/features/finance/import/sheet.dart';

String _t(Cell c) => switch (c) {
  TextCell(:final value) => value,
  EmptyCell() => '',
  _ => '?',
};

void main() {
  test('csv: BOM, semicolons, quoted newline', () {
    final sheets = readCsv(File('test/fixtures/import/sample.csv').readAsBytesSync());
    final rows = sheets.single.rows;
    expect(sheets.single.name, '');
    expect(rows.length, 4);
    expect(rows[0].map(_t), ['التاريخ', 'المبلغ', 'الوصف']);
    expect(rows[1].map(_t), ['01/01/2025', '25000', 'غدا; مطعم']);
    expect(_t(rows[2][2]), 'سطر\nثاني');
    expect(_t(rows[3][1]), '-20000');
  });

  test('csv: commas, doubled quotes, tabs and empty cells', () {
    final rows = readCsv(Uint8List.fromList(utf8.encode('a,b,c\n"x ""q""",,3\n'))).single.rows;
    expect(_t(rows[1][0]), 'x "q"');
    expect(rows[1][1], isA<EmptyCell>());
    final tabs = readCsv(Uint8List.fromList(utf8.encode('a\tb\n1\t2'))).single.rows;
    expect(tabs[1].map(_t), ['1', '2']);
  });

  test('50,001 rows → ImportTooLarge', () {
    final b = StringBuffer('date,amount\n');
    for (var i = 0; i < 50001; i++) {
      b.write('1/1/2025,1\n');
    }
    expect(() => readCsv(Uint8List.fromList(utf8.encode(b.toString()))), throwsA(isA<ImportTooLarge>()));
  });

  test('65 columns → ImportTooLarge', () {
    final line = List.filled(65, 'x').join(',');
    expect(() => readCsv(Uint8List.fromList(utf8.encode(line))), throwsA(isA<ImportTooLarge>()));
  });

  test('bytes that are not UTF-8 → ImportFormatException', () {
    expect(() => readCsv(Uint8List.fromList([0xff, 0xfe, 0x00, 0xc3])), throwsA(isA<ImportFormatException>()));
  });
}
