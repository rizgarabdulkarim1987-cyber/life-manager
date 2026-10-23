import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/storage/secure_store.dart';
import 'package:life_manager/features/vault/crypto/vault_errors.dart';
import 'package:life_manager/features/vault/platform/biometric_key_store.dart';

const _text = BioPromptText(title: 'Unlock vault', subtitle: 'Fingerprint', cancel: 'Cancel');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = PlatformBiometricKeyStore.channel;
  late List<MethodCall> calls;

  void answer(Object? Function(MethodCall c) reply) {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (c) async {
      calls.add(c);
      return reply(c);
    });
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('encrypt and decrypt pass the data and the prompt text', () async {
    answer((c) => Uint8List.fromList([1, 2, 3]));
    const store = PlatformBiometricKeyStore();
    expect(await store.encrypt(Uint8List.fromList([9]), _text), [1, 2, 3]);
    expect(calls.single.method, 'bioEncrypt');
    final args = calls.single.arguments as Map;
    expect(args['data'], [9]);
    expect((args['title'], args['subtitle'], args['cancel']), ('Unlock vault', 'Fingerprint', 'Cancel'));
    await store.decrypt(Uint8List.fromList([7]), _text);
    expect(calls.last.method, 'bioDecrypt');
  });

  test('platform error codes become typed vault errors', () async {
    const store = PlatformBiometricKeyStore();
    final expected = {
      'invalidated': isA<VaultBiometricInvalidated>(),
      'cancelled': isA<VaultBiometricCancelled>(),
      'unavailable': isA<VaultBiometricUnavailable>(),
      'lockout': isA<VaultLockedOut>(),
      'failed': isA<VaultWrongSecret>(),
      'something-new': isA<VaultWrongSecret>(),
    };
    for (final MapEntry(key: code, value: matcher) in expected.entries) {
      answer((c) => throw PlatformException(code: code));
      await expectLater(store.decrypt(Uint8List(1), _text), throwsA(matcher), reason: code);
    }
  });

  test('no plugin (tests, other platforms) means unavailable, not a crash', () async {
    messenger.setMockMethodCallHandler(channel, null);
    const store = PlatformBiometricKeyStore();
    expect(await store.isAvailable(), isFalse);
    await expectLater(store.encrypt(Uint8List(1), _text), throwsA(isA<VaultBiometricUnavailable>()));
  });

  test('bio wrap store round-trips through secure storage and clears', () async {
    final s = SecureBioWrapStore(InMemorySecureStore());
    expect(await s.read(), isNull);
    await s.write(BioWrap(vaultId: 'a' * 32, blob: Uint8List.fromList([1, 2, 3])));
    final back = (await s.read())!;
    expect(back.vaultId, 'a' * 32);
    expect(back.blob, [1, 2, 3]);
    await s.clear();
    expect(await s.read(), isNull);
  });

  test('a damaged bio wrap record reads as none', () async {
    final raw = InMemorySecureStore();
    await raw.write(SecureBioWrapStore.storeKey, '{not json');
    expect(await SecureBioWrapStore(raw).read(), isNull);
  });
}
