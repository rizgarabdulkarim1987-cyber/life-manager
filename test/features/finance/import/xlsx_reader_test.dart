import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/finance/import/import_mapping.dart';
import 'package:life_manager/features/finance/import/sheet.dart';
import 'package:life_manager/features/finance/import/xlsx_reader.dart';

import '../../../fixtures/import/make_fixtures.dart';

void main() {
  test('xlsx float artefact', () {
    expect(decimalTextToMinor('1250000.0000000002', 'IQD'), 1250000);
    expect(decimalTextToMinor('12.3', 'USD'), 1230);
    expect(decimalTextToMinor('-1.5E3', 'IQD'), -1500);
    expect(decimalTextToMinor('0.1234565', 'USD'), 12);
    expect(decimalTextToMinor('abc', 'IQD'), isNull);
  });

  test('date serial', () {
    expect(excelSerialToDate('45658'), DateTime(2025, 1, 1));
    expect(excelSerialToDate('60'), isNull);
    expect(excelSerialToDate('59'), DateTime(1900, 2, 28));
    expect(excelSerialToDate('61'), DateTime(1900, 3, 1));
    expect(excelSerialToDate('45659.5'), DateTime(2025, 1, 2, 12));
  });

  test('day-first', () {
    expect(parseTextDate('3/4/2024', DateOrder.dayFirst), DateTime(2024, 4, 3));
    expect(parseTextDate('3/4/2024', DateOrder.monthFirst), DateTime(2024, 3, 4));
    expect(parseTextDate('2024-04-03', DateOrder.dayFirst), DateTime(2024, 4, 3));
    expect(parseTextDate('٣.٤.٢٠٢٤', DateOrder.dayFirst), DateTime(2024, 4, 3));
    expect(parseTextDate('31/2/2024', DateOrder.dayFirst), isNull);
    expect(parseTextDate('3/4/2024 14:30', DateOrder.dayFirst), DateTime(2024, 4, 3, 14, 30));
  });

  test('xlsx fixture: shared strings, date-styled cells and gaps', () {
    final sheets = readXlsx(File('test/fixtures/import/sample.xlsx').readAsBytesSync());
    expect(sheets.map((s) => s.name), ['مصاريف', 'Notes']);
    final rows = sheets.first.rows;
    expect(rows.length, 6);
    expect((rows[0][0] as TextCell).value, 'التاريخ');
    expect((rows[1][0] as DateSerialCell).serialText, '45658');
    // A custom format with "d" only inside quotes is still a number.
    expect((rows[1][1] as NumberCell).decimalText, '25000');
    expect((rows[1][2] as TextCell).value, 'غدا مطعم');
    expect(rows[2][0], isA<DateSerialCell>());
    expect(rows[2][1], isA<EmptyCell>());
    expect((rows[2][2] as TextCell).value, 'بدون مبلغ');
    expect((rows[3][1] as NumberCell).decimalText, '1250000.0000000002');
    expect(rows[4], isEmpty);
    expect((rows[5][0] as TextCell).value, '2025-01-05');
    expect(sheets[1].rows.single.first, isA<EmptyCell>());
  });

  test('xlsx beyond 64 columns → ImportTooLarge', () {
    final bytes = buildXlsx({
      'xl/workbook.xml': '<workbook xmlns:r="r"><sheets><sheet name="S" sheetId="1" r:id="rId1"/></sheets></workbook>',
      'xl/_rels/workbook.xml.rels':
          '<Relationships><Relationship Id="rId1" Target="worksheets/s.xml"/></Relationships>',
      'xl/worksheets/s.xml': '<worksheet><sheetData><row r="1"><c r="BM1"><v>1</v></c></row></sheetData></worksheet>',
    });
    expect(() => readXlsx(bytes), throwsA(isA<ImportTooLarge>()));
  });

  test('not a zip → ImportFormatException', () {
    expect(() => readXlsx(Uint8List.fromList([1, 2, 3, 4])), throwsA(isA<ImportFormatException>()));
  });
}
