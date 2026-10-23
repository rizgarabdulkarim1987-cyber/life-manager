import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/crypto/aead.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/features/vault/crypto/field_cipher.dart';
import 'package:life_manager/features/vault/crypto/vault_errors.dart';
import 'package:life_manager/features/vault/crypto/vault_key.dart';
import 'package:life_manager/features/vault/data/vault_items_repository.dart';

const _pw = 'TEST-ONLY-pw-7731';
const _notes = 'TEST-ONLY-notes-ملاحظة';
const _codes = 'TEST-ONLY-codes-1111 2222';

/// True when [needle] appears in any column of any row, as text or inside a blob.
Future<bool> rawContains(AppDatabase db, String table, String needle) async {
  final rows = await db.customSelect('SELECT * FROM $table').get();
  for (final r in rows) {
    for (final v in r.data.values) {
      if (v is String && v.contains(needle)) return true;
      if (v is Uint8List) {
        if (utf8.decode(v, allowMalformed: true).contains(needle)) return true;
        if (latin1.decode(v).contains(needle)) return true;
      }
    }
  }
  return false;
}

void main() {
  late AppDatabase db;
  late VaultItemsRepository repo;
  late VaultKey k;
  var clock = DateTime.utc(2026, 10, 23, 9);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = DateTime.utc(2026, 10, 23, 9);
    repo = VaultItemsRepository(db, const FieldCipher(AesGcmAead()), now: () => clock);
    k = generateVaultKey();
  });
  tearDown(() => db.close());

  VaultItemInput input({
    String title = 'Facebook',
    String? username,
    String? email,
    String? url,
    String category = 'social',
    bool favorite = false,
    String? password = _pw,
    String? notes,
    String? codes,
  }) => VaultItemInput(
    title: title,
    username: username,
    email: email,
    url: url,
    category: category,
    favorite: favorite,
    password: password == null ? null : Sensitive(password),
    notes: notes == null ? null : Sensitive(notes),
    recoveryCodes: codes == null ? null : Sensitive(codes),
  );

  test('create and read back secrets; the row holds no plaintext secret', () async {
    final id = await repo.create(k, input(username: 'ahmed', notes: _notes, codes: _codes));
    final s = await repo.secrets(k, id);
    expect((s.password!.value, s.notes!.value, s.recoveryCodes!.value), (_pw, _notes, _codes));
    for (final secret in [_pw, _notes, _codes, 'TEST-ONLY']) {
      expect(await rawContains(db, 'vault_items', secret), isFalse, reason: secret);
    }
    final item = (await repo.get(id))!;
    expect(item.uid, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(item.passwordChangedAt!.toUtc(), clock);
  });

  test('empty strings are stored as null', () async {
    final id = await repo.create(k, input(username: '  ', email: '', url: ' ', password: '', notes: ''));
    final item = (await repo.get(id))!;
    expect((item.username, item.email, item.url, item.passwordBlob, item.notesBlob), (null, null, null, null, null));
    expect(item.passwordChangedAt, isNull);
    expect((await repo.secrets(k, id)).password, isNull);
  });

  test('title is required and the category must be known', () async {
    await expectLater(repo.create(k, input(title: '   ')), throwsArgumentError);
    await expectLater(repo.create(k, input(category: 'games')), throwsArgumentError);
    await expectLater(repo.create(k, input(title: 'x' * 121)), throwsArgumentError);
  });

  test('another vault key cannot read the secrets', () async {
    final id = await repo.create(k, input());
    await expectLater(repo.secrets(generateVaultKey(), id), throwsA(isA<VaultCorrupt>()));
  });

  test('update re-seals with fresh nonces; passwordChangedAt moves only when the password changes', () async {
    final id = await repo.create(k, input(notes: _notes));
    final before = (await repo.get(id))!;
    clock = clock.add(const Duration(days: 1));
    await repo.update(k, id, input(title: 'Facebook main', notes: 'new notes'));
    final same = (await repo.get(id))!;
    expect(same.passwordBlob, isNot(before.passwordBlob));
    expect(same.passwordChangedAt, before.passwordChangedAt);
    expect(same.updatedAt.toUtc(), clock);
    expect((await repo.secrets(k, id)).notes!.value, 'new notes');

    clock = clock.add(const Duration(days: 1));
    await repo.update(k, id, input(password: 'TEST-ONLY-new-pw'));
    expect((await repo.get(id))!.passwordChangedAt!.toUtc(), clock);
    expect((await repo.secrets(k, id)).password!.value, 'TEST-ONLY-new-pw');
  });

  test('search matches title, username, email and URL, folding Arabic; never the password', () async {
    await repo.create(k, input(title: 'Gmail', username: 'أحمد', email: 'ahmed@example.com'));
    await repo.create(k, input(title: 'Hostinger', url: 'https://hpanel.hostinger.com', category: 'hosting'));
    await repo.create(k, input(title: 'مصرف الرافدين', category: 'banking'));
    Future<List<String>> titles(String text) async =>
        (await repo.watch(VaultQuery(text: text)).first).map((i) => i.title).toList();
    expect(await titles('احمد'), ['Gmail']);
    expect(await titles('EXAMPLE.com'), ['Gmail']);
    expect(await titles('hpanel'), ['Hostinger']);
    expect(await titles('الرافدين'), ['مصرف الرافدين']);
    expect(await titles('7731'), isEmpty);
    expect(await titles(_pw), isEmpty);
  });

  test('filters by category and favourites; sorts by title, updated, created', () async {
    final a = await repo.create(k, input(title: 'beta', category: 'dev'));
    clock = clock.add(const Duration(minutes: 1));
    await repo.create(k, input(title: 'Alpha', category: 'social', favorite: true));
    clock = clock.add(const Duration(minutes: 1));
    await repo.create(k, input(title: 'gamma', category: 'dev'));
    clock = clock.add(const Duration(minutes: 1));
    await repo.update(k, a, input(title: 'beta', category: 'dev'));

    Future<List<String>> titles(VaultQuery q) async => (await repo.watch(q).first).map((i) => i.title).toList();
    expect(await titles(const VaultQuery()), ['Alpha', 'beta', 'gamma']);
    expect(await titles(const VaultQuery(sort: VaultSort.updated)), ['beta', 'gamma', 'Alpha']);
    expect(await titles(const VaultQuery(sort: VaultSort.created)), ['gamma', 'Alpha', 'beta']);
    expect(await titles(const VaultQuery(category: 'dev')), ['beta', 'gamma']);
    expect(await titles(const VaultQuery(favoritesOnly: true)), ['Alpha']);
  });

  test('delete removes the item', () async {
    final id = await repo.create(k, input());
    await repo.delete(id);
    expect(await repo.get(id), isNull);
    expect(await repo.count(), 0);
  });

  test('VaultItemInput and VaultSecrets never print a secret', () async {
    final i = input(notes: _notes, codes: _codes);
    expect('$i', isNot(contains('TEST-ONLY')));
    final id = await repo.create(k, i);
    expect('${await repo.secrets(k, id)}', isNot(contains('TEST-ONLY')));
  });
}
