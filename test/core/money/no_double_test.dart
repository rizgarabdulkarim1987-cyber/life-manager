import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Money is integer minor units only (spec §10.2). Chart widgets are the one
/// place a double may appear, and they live outside these folders.
const _dirs = [
  'lib/core/money',
  'lib/features/finance/domain',
  'lib/features/finance/data',
  'lib/features/finance/import',
  'lib/features/finance/export',
  'lib/features/capture/domain',
  'lib/features/capture/rules',
];

void main() {
  test('money code never uses double', () {
    final banned = RegExp(r'\bdouble\b|toDouble\(|num\.parse\(|double\.parse\(');
    final offenders = <String>[];
    for (final d in _dirs) {
      final dir = Directory(d);
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        if (f.path.endsWith('.g.dart')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final l = lines[i].trimLeft();
          if (l.startsWith('//')) continue;
          if (banned.hasMatch(l)) offenders.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
