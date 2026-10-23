import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/text/digits.dart';

void main() {
  test('normalizeDigits', () => expect(normalizeDigits('١٢٣۴۵۶'), '123456'));
  test('normalizeForMatch', () {
    expect(normalizeForMatch('أكلة'), normalizeForMatch('اكله'));
    expect(normalizeForMatch('مـطـعـم'), normalizeForMatch('مطعم'));
    expect(normalizeForMatch('Taxi'), 'taxi');
    expect(normalizeForMatch('کوردی'), normalizeForMatch('كوردي'));
    expect(normalizeForMatch('مُحَمَّد'), 'محمد');
    expect(normalizeForMatch('على'), 'علي');
  });
}
