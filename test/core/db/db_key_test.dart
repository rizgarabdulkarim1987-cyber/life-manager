import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/db/db_key.dart';
import 'package:life_manager/core/storage/secure_store.dart';

void main() {
  test('creates a 64-hex key once and reuses it', () async {
    final s = InMemorySecureStore();
    final a = await obtainDatabaseKey(s);
    final b = await obtainDatabaseKey(s);
    expect(a.value, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(b.value, a.value);
  });

  test('different stores get different keys', () async {
    final a = await obtainDatabaseKey(InMemorySecureStore());
    final b = await obtainDatabaseKey(InMemorySecureStore());
    expect(a.value, isNot(b.value));
  });

  test('stored under db_key_v1', () async {
    final s = InMemorySecureStore();
    final k = await obtainDatabaseKey(s);
    expect(await s.read('db_key_v1'), k.value);
  });

  test('InMemorySecureStore delete removes the value', () async {
    final s = InMemorySecureStore();
    await s.write('a', '1');
    await s.delete('a');
    expect(await s.read('a'), isNull);
  });
}
