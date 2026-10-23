import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/crypto/aead.dart';
import 'package:life_manager/core/crypto/kdf.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/core/storage/secure_store.dart';
import 'package:life_manager/features/vault/crypto/key_wrap.dart';
import 'package:life_manager/features/vault/crypto/vault_errors.dart';
import 'package:life_manager/features/vault/data/unlock_throttle.dart';
import 'package:life_manager/features/vault/data/vault_key_service.dart';
import 'package:life_manager/features/vault/platform/biometric_key_store.dart';

import '../../../helpers/fakes.dart';

const _pw = Sensitive('TEST-ONLY master 2026');
const _text = BioPromptText(title: 't', subtitle: 's', cancel: 'c');

void main() {
  late AppDatabase db;
  late FakeBiometricKeyStore keystore;
  late SecureBioWrapStore wraps;
  late VaultKeyService svc;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    keystore = FakeBiometricKeyStore();
    wraps = SecureBioWrapStore(InMemorySecureStore());
    svc = VaultKeyService(
      db: db,
      wrapper: KeyWrapper(FakeKdf(), const AesGcmAead()),
      throttle: UnlockThrottle(InMemorySecureStore()),
      kdf: FakeKdf(),
      bioWraps: wraps,
      keystore: keystore,
    );
    final pending = await svc.prepareSetUp(_pw, params: const KdfParams(memoryKiB: 65536, iterations: 3));
    await svc.commitSetUp(pending);
  });
  tearDown(() => db.close());

  test('enable, then unlock with the fingerprint gives the vault key', () async {
    final k = await svc.unlockWithPassword(_pw);
    expect(await svc.biometricEnabled(), isFalse);
    await svc.enableBiometric(k, _text);
    expect(await svc.biometricEnabled(), isTrue);
    expect((await svc.unlockWithBiometric(_text)).sameAs(k), isTrue);
    expect(keystore.prompts, 2);
  });

  test('enabling on a phone without biometrics → unavailable, nothing stored', () async {
    keystore.available = false;
    final k = await svc.unlockWithPassword(_pw);
    await expectLater(svc.enableBiometric(k, _text), throwsA(isA<VaultBiometricUnavailable>()));
    expect(await wraps.read(), isNull);
  });

  test('a wrap from another vault (after a restore) is invalidated and cleared', () async {
    final k = await svc.unlockWithPassword(_pw);
    await svc.enableBiometric(k, _text);
    final w = (await wraps.read())!;
    await wraps.write(BioWrap(vaultId: 'f' * 32, blob: w.blob));
    expect(await svc.biometricEnabled(), isFalse);
    await expectLater(svc.unlockWithBiometric(_text), throwsA(isA<VaultBiometricInvalidated>()));
    expect(await wraps.read(), isNull);
    expect(keystore.deletes, 1);
  });

  test('a new fingerprint invalidates the key; the password still unlocks; enabling again works', () async {
    final k = await svc.unlockWithPassword(_pw);
    await svc.enableBiometric(k, _text);
    keystore.failNext = const VaultBiometricInvalidated();
    await expectLater(svc.unlockWithBiometric(_text), throwsA(isA<VaultBiometricInvalidated>()));
    expect(await wraps.read(), isNull);
    final k2 = await svc.unlockWithPassword(_pw);
    await svc.enableBiometric(k2, _text);
    expect((await svc.unlockWithBiometric(_text)).sameAs(k2), isTrue);
  });

  test('a key that decrypts to something else fails the key check and is cleared', () async {
    final k = await svc.unlockWithPassword(_pw);
    await svc.enableBiometric(k, _text);
    final w = (await wraps.read())!;
    final tampered = Uint8List.fromList(w.blob)..[0] ^= 0xff;
    await wraps.write(BioWrap(vaultId: w.vaultId, blob: tampered));
    await expectLater(svc.unlockWithBiometric(_text), throwsA(isA<VaultBiometricInvalidated>()));
    expect(await wraps.read(), isNull);
  });

  test('cancelling the prompt keeps the wrap', () async {
    final k = await svc.unlockWithPassword(_pw);
    await svc.enableBiometric(k, _text);
    keystore.failNext = const VaultBiometricCancelled();
    await expectLater(svc.unlockWithBiometric(_text), throwsA(isA<VaultBiometricCancelled>()));
    expect(await svc.biometricEnabled(), isTrue);
  });

  test('disable clears the wrap and deletes the Keystore key', () async {
    final k = await svc.unlockWithPassword(_pw);
    await svc.enableBiometric(k, _text);
    await svc.disableBiometric();
    expect(await svc.biometricEnabled(), isFalse);
    expect(keystore.deletes, 1);
    await expectLater(svc.unlockWithBiometric(_text), throwsA(isA<VaultBiometricInvalidated>()));
  });

  test('forgetDeviceKeys (after a restore) leaves biometrics off', () async {
    final k = await svc.unlockWithPassword(_pw);
    await svc.enableBiometric(k, _text);
    await svc.forgetDeviceKeys();
    expect(await svc.biometricEnabled(), isFalse);
    expect(keystore.deletes, 1);
  });

  test('confirmWithBiometric is true only for the same vault key', () async {
    final k = await svc.unlockWithPassword(_pw);
    await svc.enableBiometric(k, _text);
    expect(await svc.confirmWithBiometric(k, _text), isTrue);
    keystore.failNext = const VaultBiometricCancelled();
    await expectLater(svc.confirmWithBiometric(k, _text), throwsA(isA<VaultBiometricCancelled>()));
  });
}
