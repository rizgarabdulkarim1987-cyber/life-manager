import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vault code has no network imports', () {
    final files = Directory('lib/features/vault')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    expect(files, isNotEmpty);
    final banned = RegExp(r'''^import\s+['"](package:http/|dart:io|.*core/net/|.*capture/ai/)''', multiLine: true);
    for (final f in files) {
      expect(banned.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
    }
  });
}
