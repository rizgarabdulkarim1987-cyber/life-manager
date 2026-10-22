import '../crypto/random.dart';
import '../security/sensitive.dart';
import '../storage/secure_store.dart';

const _dbKeyName = 'db_key_v1';

/// The SQLCipher key: 32 random bytes as 64 lowercase hex characters, created
/// on first launch and kept in Keystore-backed storage (spec §9.1).
Future<Sensitive<String>> obtainDatabaseKey(SecureStore store) async {
  final existing = await store.read(_dbKeyName);
  if (existing != null) return Sensitive(existing);
  final hex = secureRandomBytes(32).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  await store.write(_dbKeyName, hex);
  return Sensitive(hex);
}
