import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/crypto/aead.dart';
import '../core/crypto/kdf.dart';
import '../core/db/app_database.dart';
import '../core/storage/secure_store.dart';
import '../features/settings/settings_repository.dart';

/// Overridden in main() with the opened SQLCipher database, and in tests.
final appDatabaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('override appDatabaseProvider'));

final secureStoreProvider = Provider<SecureStore>((ref) => FlutterSecureStore());

final kdfProvider = Provider<Kdf>((ref) => const DartArgon2idKdf());

final aeadProvider = Provider<Aead>((ref) => const AesGcmAead());

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
);

final settingsProvider = StreamProvider<AppSetting>((ref) => ref.watch(settingsRepositoryProvider).watch());
