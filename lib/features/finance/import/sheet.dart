/// One spreadsheet cell as read from a file. Numbers stay decimal text so no
/// amount ever passes through a double.
sealed class Cell {
  const Cell();
}

final class TextCell extends Cell {
  const TextCell(this.value);

  final String value;
}

/// A numeric cell, its value exactly as written in the file (`1250000.0000000002`).
final class NumberCell extends Cell {
  const NumberCell(this.decimalText);

  final String decimalText;
}

/// A numeric cell styled as a date: an Excel serial day number.
final class DateSerialCell extends Cell {
  const DateSerialCell(this.serialText);

  final String serialText;
}

final class EmptyCell extends Cell {
  const EmptyCell();
}

class Sheet {
  const Sheet(this.name, this.rows);

  final String name;

  /// Row 0 is the file's first row; missing rows are empty lists.
  final List<List<Cell>> rows;
}

const kMaxImportRows = 50000;
const kMaxImportColumns = 64;
const kMaxImportBytes = 50 * 1024 * 1024;

/// The file is bigger than an import may be (rows, columns or bytes).
class ImportTooLarge implements Exception {
  const ImportTooLarge();
}

/// The file could not be read as the format it claims to be. Holds no content.
class ImportFormatException implements Exception {
  const ImportFormatException();
}

/// The cell's text as typed, for headers and value mapping.
String cellText(Cell c) => switch (c) {
  TextCell(:final value) => value,
  NumberCell(:final decimalText) => decimalText,
  DateSerialCell(:final serialText) => serialText,
  EmptyCell() => '',
};
