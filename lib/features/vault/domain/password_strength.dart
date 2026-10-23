enum Strength { weak, fair, strong, veryStrong }

/// A length-only hint (plan Decision 6): no composition rules, because length
/// is what makes a passphrase hard to guess and rules push people to patterns.
Strength masterPasswordStrength(String pw) {
  final n = pw.runes.length;
  if (n < 10) return Strength.weak;
  if (n < 14) return Strength.fair;
  if (n < 20) return Strength.strong;
  return Strength.veryStrong;
}
