// Builds the synthetic import fixtures. Every number here is invented.
// Run from the repo root: dart run test/fixtures/import/make_fixtures.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

const _contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
</Types>''';

const _workbook = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets><sheet name="مصاريف" sheetId="1" r:id="rId1"/><sheet name="Notes" sheetId="2" r:id="rId2"/></sheets>
</workbook>''';

const _rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="/xl/worksheets/sheet2.xml"/>
<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';

const _shared = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="5" uniqueCount="5">
<si><t>التاريخ</t></si><si><t>المبلغ</t></si><si><t>الوصف</t></si>
<si><r><t>غدا </t></r><r><rPr><b/></rPr><t>مطعم</t></r></si><si><t>نقل</t></si>
</sst>''';

// Style 0 = General, 1 = built-in date (14), 2 = custom "dd/mm/yyyy", 3 = custom quoted text with a "d".
const _styles = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<numFmts count="2"><numFmt numFmtId="164" formatCode="dd/mm/yyyy"/><numFmt numFmtId="165" formatCode="#,##0 &quot;dinar&quot;"/></numFmts>
<cellXfs count="4"><xf numFmtId="0"/><xf numFmtId="14"/><xf numFmtId="164"/><xf numFmtId="165"/></cellXfs>
</styleSheet>''';

// Row 3 leaves B empty (a gap); row 4 has a float artefact; row 5 is missing entirely.
const _sheet1 = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>
<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c><c r="C1" t="s"><v>2</v></c></row>
<row r="2"><c r="A2" s="1"><v>45658</v></c><c r="B2" s="3"><v>25000</v></c><c r="C2" t="s"><v>3</v></c></row>
<row r="3"><c r="A3" s="2"><v>45659.5</v></c><c r="C3" t="inlineStr"><is><t>بدون مبلغ</t></is></c></row>
<row r="4"><c r="A4" s="1"><v>45660</v></c><c r="B4"><v>1250000.0000000002</v></c><c r="C4" t="s"><v>4</v></c></row>
<row r="6"><c r="A6" t="str"><v>2025-01-05</v></c><c r="B6"><v>-1.5E3</v></c></row>
</sheetData></worksheet>''';

const _sheet2 = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>
<row r="1"><c r="B1" t="inlineStr"><is><t>note</t></is></c></row>
</sheetData></worksheet>''';

Uint8List buildXlsx(Map<String, String> parts) {
  final a = Archive();
  for (final e in parts.entries) {
    a.add(ArchiveFile.bytes(e.key, utf8.encode(e.value)));
  }
  return ZipEncoder().encodeBytes(a);
}

Uint8List sampleXlsx() => buildXlsx({
  '[Content_Types].xml': _contentTypes,
  'xl/workbook.xml': _workbook,
  'xl/_rels/workbook.xml.rels': _rels,
  'xl/sharedStrings.xml': _shared,
  'xl/styles.xml': _styles,
  'xl/worksheets/sheet1.xml': _sheet1,
  'xl/worksheets/sheet2.xml': _sheet2,
});

const sampleCsv =
    '\uFEFFالتاريخ;المبلغ;الوصف\r\n'
    '01/01/2025;25000;"غدا; مطعم"\r\n'
    '02/01/2025;"1.250.000";"سطر\nثاني"\r\n'
    '03/01/2025;-20000;نقل\r\n';

void main() {
  final dir = Directory('test/fixtures/import')..createSync(recursive: true);
  File('${dir.path}/sample.xlsx').writeAsBytesSync(sampleXlsx());
  File('${dir.path}/sample.csv').writeAsStringSync(sampleCsv);
  stdout.writeln('wrote sample.xlsx and sample.csv');
}
