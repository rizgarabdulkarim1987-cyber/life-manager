// Drift check constraints reference their own column getter by design.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import 'tables.dart';

/// Vault item categories from the original spec (plan Decision 18).
const kVaultCategories = [
  'personal',
  'business',
  'social',
  'banking',
  'hosting',
  'domain',
  'email',
  'marketing',
  'dev',
  'other',
];

/// One row, id 1, once the vault is set up. [checkBlob] is the vault key's
/// seal of a fixed label: every unlock path must open it (plan Decision 2).
@DataClassName('VaultMetaRow')
class VaultMeta extends Table {
  @override
  String get tableName => 'vault_meta';

  IntColumn get id => integer().check(id.equals(1)).withDefault(const Constant(1))();
  TextColumn get vaultId => text().withLength(min: 32, max: 32)();
  BlobColumn get checkBlob => blob()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The vault key wrapped by the master password (Argon2id, [kdfJson] holds its
/// parameters) or by the recovery key (HKDF). The biometric wrap is never here,
/// so it never reaches a backup (spec §13).
@DataClassName('VaultKeyWrapRow')
class VaultKeyWraps extends Table {
  @override
  String get tableName => 'vault_key_wraps';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => text().unique().check(kind.isIn(const ['password', 'recovery']))();
  TextColumn get kdfJson => text().nullable()();
  BlobColumn get salt => blob()();
  BlobColumn get sealedKey => blob()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  List<String> get customConstraints => ["CHECK ((kind = 'password') = (kdf_json IS NOT NULL))"];
}

/// A password-vault entry. Only the non-secret fields are plain columns (in the
/// SQLCipher database); password, notes and recovery codes are AES-GCM blobs
/// under the vault key, bound to [uid] and the field name.
@TableIndex(name: 'vault_item_title', columns: {#title})
class VaultItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uid => text().unique().withLength(min: 32, max: 32)();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  TextColumn get url => text().nullable().withLength(max: 2000)();
  TextColumn get username => text().nullable().withLength(max: 200)();
  TextColumn get email => text().nullable().withLength(max: 200)();
  TextColumn get category => text().check(category.isIn(kVaultCategories))();
  IntColumn get workspaceId => integer().nullable().references(Workspaces, #id, onDelete: KeyAction.restrict)();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  BlobColumn get passwordBlob => blob().nullable()();
  BlobColumn get notesBlob => blob().nullable()();
  BlobColumn get recoveryCodesBlob => blob().nullable()();
  DateTimeColumn get passwordChangedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
