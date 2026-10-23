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
