import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../crypto/field_cipher.dart';
import '../crypto/key_wrap.dart';
import '../platform/biometric_key_store.dart';
import '../platform/secret_clipboard.dart';
import 'unlock_throttle.dart';
import 'vault_items_repository.dart';
import 'vault_key_service.dart';

/// Overridable clock for the vault's timers and fresh-auth window.
final vaultClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final biometricKeyStoreProvider = Provider<BiometricKeyStore>((ref) => const PlatformBiometricKeyStore());

final vaultKeyServiceProvider = Provider<VaultKeyService>((ref) {
  final store = ref.watch(secureStoreProvider);
  final kdf = ref.watch(kdfProvider);
  return VaultKeyService(
    db: ref.watch(appDatabaseProvider),
    wrapper: KeyWrapper(kdf, ref.watch(aeadProvider)),
    throttle: UnlockThrottle(store, now: ref.watch(vaultClockProvider)),
    kdf: kdf,
    bioWraps: SecureBioWrapStore(store),
    keystore: ref.watch(biometricKeyStoreProvider),
    now: ref.watch(vaultClockProvider),
  );
});

final vaultItemsRepositoryProvider = Provider<VaultItemsRepository>(
  (ref) => VaultItemsRepository(
    ref.watch(appDatabaseProvider),
    FieldCipher(ref.watch(aeadProvider)),
    now: ref.watch(vaultClockProvider),
  ),
);

/// Whether this phone has fingerprint unlock on for the vault; invalidate after changing it.
final vaultBiometricEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(vaultKeyServiceProvider).biometricEnabled(),
);

final secretClipboardProvider = Provider<SecretClipboard>((ref) => PlatformSecretClipboard());

/// The list screen's items for one query (plain fields only).
final vaultItemsProvider = StreamProvider.family<List<VaultItem>, VaultQuery>(
  (ref, q) => ref.watch(vaultItemsRepositoryProvider).watch(q),
);

final vaultItemProvider = StreamProvider.family<VaultItem?, int>(
  (ref, id) => ref.watch(vaultItemsRepositoryProvider).watchOne(id),
);

/// Whether this phone has a strong biometric the vault key can be bound to.
final vaultBiometricAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(vaultKeyServiceProvider).biometricAvailable(),
);
