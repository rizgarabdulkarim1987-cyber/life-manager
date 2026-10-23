import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/security/sensitive.dart';

void main() {
  test('Sensitive never prints its value', () {
    const s = Sensitive('1234');
    expect('$s', isNot(contains('1234')));
    expect([s].toString(), isNot(contains('1234')));
    expect({'k': s}.toString(), isNot(contains('1234')));
  });

  test('Sensitive still exposes the value to code that asks for it', () {
    expect(const Sensitive('1234').value, '1234');
  });
}
