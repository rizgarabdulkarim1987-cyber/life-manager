/// Maps Arabic-Indic (٠-٩) and Extended Arabic-Indic (۰-۹) digits to ASCII so
/// a PIN typed on an Arabic or Kurdish keyboard matches the same PIN.
String normalizeDigits(String s) {
  final out = StringBuffer();
  for (final r in s.runes) {
    if (r >= 0x0660 && r <= 0x0669) {
      out.writeCharCode(0x30 + r - 0x0660);
    } else if (r >= 0x06F0 && r <= 0x06F9) {
      out.writeCharCode(0x30 + r - 0x06F0);
    } else {
      out.writeCharCode(r);
    }
  }
  return out.toString();
}

const _letterFolds = {
  0x0623: 0x0627, // أ → ا
  0x0625: 0x0627, // إ → ا
  0x0622: 0x0627, // آ → ا
  0x0671: 0x0627, // ٱ → ا
  0x0649: 0x064A, // ى → ي
  0x06CC: 0x064A, // ی → ي
  0x0629: 0x0647, // ة → ه
  0x06A9: 0x0643, // ک → ك
};

bool _isMark(int r) => (r >= 0x064B && r <= 0x0652) || r == 0x0670 || r == 0x0640;

/// Folds text for matching keywords and names: digits to ASCII, lower case,
/// Arabic diacritics and tatweel removed, and common letter variants unified.
String normalizeForMatch(String s) {
  final out = StringBuffer();
  for (final r in normalizeDigits(s).toLowerCase().runes) {
    if (_isMark(r)) continue;
    out.writeCharCode(_letterFolds[r] ?? r);
  }
  return out.toString();
}
