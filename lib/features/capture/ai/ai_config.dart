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

/// Set at build time (`--dart-define=AI_PROXY_URL=... --dart-define=AI_PROXY_TOKEN=...`) so the app works
/// without the owner typing a Groq key: requests go to a small server that holds the real key.
const kAiProxyUrl = String.fromEnvironment('AI_PROXY_URL');
const kAiProxyToken = String.fromEnvironment('AI_PROXY_TOKEN');

/// Where a request goes and with what secret.
typedef AiCredential = ({String base, Sensitive<String> secret});

class GroqKeyStore {
  GroqKeyStore(this._store, {this.proxyUrl = kAiProxyUrl, this.proxyToken = kAiProxyToken});

  final SecureStore _store;
  final String proxyUrl;
  final String proxyToken;

  Future<Sensitive<String>?> _own() async {
    final v = (await _store.read(kGroqKeyStoreKey))?.trim();
    return v == null || v.isEmpty ? null : Sensitive(v);
  }

  /// A key of the owner's own goes straight to Groq; with none, the built-in proxy is used if there is one.
  Future<AiCredential?> credential() async {
    final own = await _own();
    if (own != null) return (base: kGroqBase, secret: own);
    if (proxyUrl.isNotEmpty && proxyToken.isNotEmpty) return (base: proxyUrl, secret: Sensitive(proxyToken));
    return null;
  }

  /// Whether online AI can be used at all: the owner's key, or the built-in proxy.
  Future<Sensitive<String>?> read() async => (await credential())?.secret;

  Future<void> write(Sensitive<String> key) {
    final v = key.value.trim();
    if (v.isEmpty) throw ArgumentError('empty key');
    return _store.write(kGroqKeyStoreKey, v);
  }

  Future<void> clear() => _store.delete(kGroqKeyStoreKey);
}

/// What the owner answered for [f]: `granted`, `declined`, or null when never asked.
String? consentOf(AiFeature f, AppSetting s) => switch (f) {
  AiFeature.voice => s.aiVoiceConsent,
  AiFeature.parse => s.aiParseConsent,
  AiFeature.receipt => s.aiReceiptConsent,
};

/// True only when online AI is on, a key is saved and the owner agreed for [f].
Future<bool> canUseOnline(AiFeature f, AppSetting s, GroqKeyStore keys) async {
  if (!s.aiOnlineEnabled) return false;
  if (consentOf(f, s) != ConsentState.granted.name) return false;
  return await keys.read() != null;
}

/// The first thing stopping voice from going to Groq, as a capture reason key;
/// null when nothing is.
String? onlineVoiceGap(AppSetting s, {required bool keySaved}) {
  if (!s.aiOnlineEnabled) return 'noSpeechOnlineOff';
  if (!keySaved) return 'noSpeechNoKey';
  if (s.aiVoiceConsent == ConsentState.declined.name) return 'noSpeechDeclined';
  if (s.aiVoiceConsent != ConsentState.granted.name) return 'noSpeechNotAsked';
  return null;
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
