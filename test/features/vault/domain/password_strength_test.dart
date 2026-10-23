import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/vault/domain/password_strength.dart';

void main() {
  test('strength is length-based: <10 weak, <14 fair, <20 strong, else very strong', () {
    expect(masterPasswordStrength(''), Strength.weak);
    expect(masterPasswordStrength('a' * 9), Strength.weak);
    expect(masterPasswordStrength('a' * 10), Strength.fair);
    expect(masterPasswordStrength('a' * 13), Strength.fair);
    expect(masterPasswordStrength('a' * 14), Strength.strong);
    expect(masterPasswordStrength('a' * 19), Strength.strong);
    expect(masterPasswordStrength('a' * 20), Strength.veryStrong);
  });

  test('counts code points, not UTF-16 units (Arabic, emoji)', () {
    expect(masterPasswordStrength('كلمة سر ط'), Strength.weak); // 9 characters
    expect(masterPasswordStrength('🔑' * 10), Strength.fair);
  });
}
