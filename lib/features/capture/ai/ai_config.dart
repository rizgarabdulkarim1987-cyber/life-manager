import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/net/http_port.dart';
import '../../../core/security/sensitive.dart';
import '../../../core/storage/secure_store.dart';
import '../../settings/settings_repository.dart';
import 'groq_client.dart';

export '../../settings/settings_repository.dart' show AiFeature, ConsentState;

/// The Groq key lives only in the Android Keystore-backed store, never in the DB or logs.
const kGroqKeyStoreKey = 'groq_api_key_v1';

class GroqKeyStore {
  GroqKeyStore(this._store);

  final SecureStore _store;

  Future<Sensitive<String>?> read() async {
    final v = (await _store.read(kGroqKeyStoreKey))?.trim();
    return v == null || v.isEmpty ? null : Sensitive(v);
  }

  Future<void> write(Sensitive<String> key) {
    final v = key.value.trim();
    if (v.isEmpty) throw ArgumentError('empty key');
    return _store.write(kGroqKeyStoreKey, v);
  }

  Future<void> clear() => _store.delete(kGroqKeyStoreKey);
}

/// True only when online AI is on, a key is saved and the owner agreed for [f].
Future<bool> canUseOnline(AiFeature f, AppSetting s, GroqKeyStore keys) async {
  if (!s.aiOnlineEnabled) return false;
  final consent = f == AiFeature.voice ? s.aiVoiceConsent : s.aiParseConsent;
  if (consent != ConsentState.granted.name) return false;
  return await keys.read() != null;
}

final httpPortProvider = Provider<HttpPort>((ref) => PackageHttpPort());

final groqKeyStoreProvider = Provider<GroqKeyStore>((ref) => GroqKeyStore(ref.watch(secureStoreProvider)));

final groqClientProvider = Provider<GroqClient>(
  (ref) => GroqClient(ref.watch(httpPortProvider), ref.watch(groqKeyStoreProvider)),
);

/// Whether a key is saved; invalidate after saving or clearing it.
final groqKeySavedProvider = FutureProvider<bool>((ref) async => await ref.watch(groqKeyStoreProvider).read() != null);

final canUseOnlineProvider = FutureProvider.family<bool, AiFeature>((ref, f) async {
  final s = await ref.watch(settingsProvider.future);
  await ref.watch(groqKeySavedProvider.future);
  return canUseOnline(f, s, ref.read(groqKeyStoreProvider));
});
