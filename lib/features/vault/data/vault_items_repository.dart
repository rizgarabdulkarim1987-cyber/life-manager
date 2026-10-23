import 'package:drift/drift.dart';

import '../../../core/crypto/random.dart';
import '../../../core/db/app_database.dart';
import '../../../core/security/sensitive.dart';
import '../../../core/text/digits.dart';
import '../crypto/field_cipher.dart';
import '../crypto/vault_key.dart';

/// What the form saves. Blank text becomes `null`; secrets stay [Sensitive].
final class VaultItemInput {
  VaultItemInput({
    required String title,
    String? url,
    String? username,
    String? email,
    required this.category,
    this.workspaceId,
    this.favorite = false,
    Sensitive<String>? password,
    Sensitive<String>? notes,
    Sensitive<String>? recoveryCodes,
  }) : title = title.trim(),
       url = _blank(url),
       username = _blank(username),
       email = _blank(email),
       password = _blankSecret(password),
       notes = _blankSecret(notes),
       recoveryCodes = _blankSecret(recoveryCodes);

  final String title;
  final String? url;
  final String? username;
  final String? email;
  final String category;
  final int? workspaceId;
  final bool favorite;
  final Sensitive<String>? password;
  final Sensitive<String>? notes;
  final Sensitive<String>? recoveryCodes;

  static String? _blank(String? s) => s == null || s.trim().isEmpty ? null : s.trim();

  // Secrets are kept exactly as typed (a password may start with a space); only empty means none.
  static Sensitive<String>? _blankSecret(Sensitive<String>? s) => s == null || s.value.isEmpty ? null : s;

  @override
  String toString() => 'VaultItemInput(‹redacted›)';
}

/// The decrypted secret fields of one item. Never cached: read, use, drop.
final class VaultSecrets {
  const VaultSecrets({this.password, this.notes, this.recoveryCodes});

  final Sensitive<String>? password;
  final Sensitive<String>? notes;
  final Sensitive<String>? recoveryCodes;

  @override
  String toString() => 'VaultSecrets(‹redacted›)';
}

enum VaultSort { title, updated, created }

class VaultQuery {
  const VaultQuery({this.text = '', this.category, this.favoritesOnly = false, this.sort = VaultSort.title});

  final String text;
  final String? category;
  final bool favoritesOnly;
  final VaultSort sort;

  VaultQuery copyWith({String? text, String? Function()? category, bool? favoritesOnly, VaultSort? sort}) => VaultQuery(
    text: text ?? this.text,
    category: category == null ? this.category : category(),
    favoritesOnly: favoritesOnly ?? this.favoritesOnly,
    sort: sort ?? this.sort,
  );

  @override
  bool operator ==(Object other) =>
      other is VaultQuery &&
      other.text == text &&
      other.category == category &&
      other.favoritesOnly == favoritesOnly &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(text, category, favoritesOnly, sort);
}

/// Vault items in the database. Secret fields are sealed per field with the
/// vault key (spec §9.1); search, filter and sort only ever see the plain
/// fields (spec §9.2).
class VaultItemsRepository {
  VaultItemsRepository(this._db, this._cipher, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final FieldCipher _cipher;
  final DateTime Function() _now;

  static String _newUid() => secureRandomBytes(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  void _validate(VaultItemInput i) {
    if (i.title.isEmpty || i.title.length > 120) throw ArgumentError('title must be 1–120 characters');
    if (!kVaultCategories.contains(i.category)) throw ArgumentError('unknown vault category');
    if ((i.url?.length ?? 0) > 2000 || (i.username?.length ?? 0) > 200 || (i.email?.length ?? 0) > 200) {
      throw ArgumentError('field too long');
    }
  }

  Future<Uint8List?> _seal(VaultKey k, String uid, VaultField f, Sensitive<String>? v) async =>
      v == null ? null : await _cipher.seal(k, uid, f, v);

  Stream<List<VaultItem>> watch(VaultQuery q) {
    final sel = _db.select(_db.vaultItems);
    final category = q.category;
    if (category != null) sel.where((i) => i.category.equals(category));
    if (q.favoritesOnly) sel.where((i) => i.favorite.equals(true));
    final needle = normalizeForMatch(q.text.trim());
    return sel.watch().map((rows) {
      final out = needle.isEmpty
          ? rows
          : rows
                .where(
                  (i) => [
                    i.title,
                    i.url,
                    i.username,
                    i.email,
                  ].any((f) => f != null && normalizeForMatch(f).contains(needle)),
                )
                .toList();
      int byTitle(VaultItem a, VaultItem b) => normalizeForMatch(a.title).compareTo(normalizeForMatch(b.title));
      out.sort(switch (q.sort) {
        VaultSort.title => byTitle,
        VaultSort.updated => (a, b) => b.updatedAt.compareTo(a.updatedAt),
        VaultSort.created => (a, b) => b.createdAt.compareTo(a.createdAt),
      });
      return out;
    });
  }

  Future<VaultItem?> get(int id) => (_db.select(_db.vaultItems)..where((i) => i.id.equals(id))).getSingleOrNull();

  Stream<VaultItem?> watchOne(int id) =>
      (_db.select(_db.vaultItems)..where((i) => i.id.equals(id))).watchSingleOrNull();

  Future<int> count() async => (await _db.select(_db.vaultItems).get()).length;

  Future<int> create(VaultKey k, VaultItemInput i) async {
    _validate(i);
    final uid = _newUid();
    final now = _now().toUtc();
    return _db
        .into(_db.vaultItems)
        .insert(
          VaultItemsCompanion.insert(
            uid: uid,
            title: i.title,
            url: Value(i.url),
            username: Value(i.username),
            email: Value(i.email),
            category: i.category,
            workspaceId: Value(i.workspaceId),
            favorite: Value(i.favorite),
            passwordBlob: Value(await _seal(k, uid, VaultField.password, i.password)),
            notesBlob: Value(await _seal(k, uid, VaultField.notes, i.notes)),
            recoveryCodesBlob: Value(await _seal(k, uid, VaultField.recoveryCodes, i.recoveryCodes)),
            passwordChangedAt: Value(i.password == null ? null : now),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// Replaces every field. Secret fields are sealed again with fresh nonces.
  Future<void> update(VaultKey k, int id, VaultItemInput i) async {
    _validate(i);
    final old = await get(id);
    if (old == null) throw StateError('no such vault item');
    final oldPassword = old.passwordBlob == null
        ? null
        : await _cipher.open(k, old.uid, VaultField.password, old.passwordBlob!);
    final changed = oldPassword?.value != i.password?.value;
    final now = _now().toUtc();
    await (_db.update(_db.vaultItems)..where((r) => r.id.equals(id))).write(
      VaultItemsCompanion(
        title: Value(i.title),
        url: Value(i.url),
        username: Value(i.username),
        email: Value(i.email),
        category: Value(i.category),
        workspaceId: Value(i.workspaceId),
        favorite: Value(i.favorite),
        passwordBlob: Value(await _seal(k, old.uid, VaultField.password, i.password)),
        notesBlob: Value(await _seal(k, old.uid, VaultField.notes, i.notes)),
        recoveryCodesBlob: Value(await _seal(k, old.uid, VaultField.recoveryCodes, i.recoveryCodes)),
        passwordChangedAt: changed ? Value(i.password == null ? null : now) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> setFavorite(int id, bool favorite) =>
      (_db.update(_db.vaultItems)..where((r) => r.id.equals(id))).write(VaultItemsCompanion(favorite: Value(favorite)));

  Future<void> delete(int id) => (_db.delete(_db.vaultItems)..where((r) => r.id.equals(id))).go();

  Future<VaultSecrets> secrets(VaultKey k, int id) async {
    final i = await get(id);
    if (i == null) throw StateError('no such vault item');
    Future<Sensitive<String>?> open(VaultField f, Uint8List? b) async =>
        b == null ? null : _cipher.open(k, i.uid, f, b);
    return VaultSecrets(
      password: await open(VaultField.password, i.passwordBlob),
      notes: await open(VaultField.notes, i.notesBlob),
      recoveryCodes: await open(VaultField.recoveryCodes, i.recoveryCodesBlob),
    );
  }
}
