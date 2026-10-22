import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/logging/app_logger.dart';
import 'package:life_manager/core/security/sensitive.dart';

void main() {
  late List<String> lines;
  setUp(() {
    lines = [];
    AppLogger.sink = lines.add;
  });

  test('logger does not print error messages', () {
    AppLogger.error('backup failed', StateError('password=hunter2'));
    expect(lines.join(), isNot(contains('hunter2')));
    expect(lines.join(), contains('StateError'));
    expect(lines.join(), contains('backup failed'));
  });

  test('warn also hides the error message', () {
    AppLogger.warn('retrying', FormatException('pin 123456'));
    expect(lines.join(), isNot(contains('123456')));
    expect(lines.join(), contains('FormatException'));
  });

  test('interpolated Sensitive values are redacted', () {
    const pin = Sensitive('654321');
    AppLogger.info('pin is $pin');
    expect(lines.join(), isNot(contains('654321')));
  });
}
