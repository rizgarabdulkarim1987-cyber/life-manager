import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/crypto/aead.dart';
import 'package:life_manager/core/crypto/kdf.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/core/storage/secure_store.dart';
import 'package:life_manager/features/vault/crypto/field_cipher.dart';
import 'package:life_manager/features/vault/crypto/key_wrap.dart';
import 'package:life_manager/features/vault/crypto/recovery_key.dart';
import 'package:life_manager/features/vault/crypto/vault_errors.dart';
import 'package:life_manager/features/vault/data/unlock_throttle.dart';
import 'package:life_manager/features/vault/data/vault_items_repository.dart';
import 'package:life_manager/features/vault/data/vault_key_service.dart';
import 'package:life_manager/features/vault/platform/biometric_key_store.dart';

import '../../../helpers/fakes.dart';

const _pw = Sensitive('TEST-ONLY master 2026');
const _params = KdfParams(memoryKiB: 65536, iterations: 3);

void main() {
  late AppDatabase db;
  late InMemorySecureStore store;
  late DateTime now;
  late VaultKeyService svc;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = InMemorySecureStore();
    now = DateTime.utc(2026, 10, 23, 12);
    svc = VaultKeyService(
      db: db,
      wrapper: KeyWrapper(FakeKdf(), const AesGcmAead()),
      throttle: UnlockThrottle(store, now: () => now),
      kdf: FakeKdf(),
      bioWraps: SecureBioWrapStore(InMemorySecureStore()),
      keystore: FakeBiometricKeyStore(),
    );
  });
  tearDown(() => db.close());

  Future<RecoveryKey> setUpVault() async {
    final pending = await svc.prepareSetUp(_pw, params: _params);
    await svc.commitSetUp(pending);
    return RecoveryKey.parse(pending.recoveryKey.display)!;
  }

  test('nothing is written until the recovery key is confirmed and the setup committed', () async {
    final pending = await svc.prepareSetUp(_pw, params: _params);
    expect(await svc.isSetUp(), isFalse);
    expect(await db.select(db.vaultKeyWraps).get(), isEmpty);
    await svc.commitSetUp(pending);
    expect(await svc.isSetUp(), isTrue);
    expect(await db.select(db.vaultKeyWraps).get(), hasLength(2));
    expect((await db.select(db.vaultMeta).getSingle()).vaultId, matches(RegExp(r'^[0-9a-f]{32}$')));
  });

  test('setUp then unlockWithPassword gives the same vault key', () async {
    final pending = await svc.prepareSetUp(_pw, params: _params);
    final bytes = List<int>.of(pending.vaultKey.bytes);
    await svc.commitSetUp(pending);
    final k = await svc.unlockWithPassword(_pw);
    expect(k.bytes, bytes);
  });

  test('stored KDF parameters are the ones chosen at setup', () async {
    await setUpVault();
    final w = await (db.select(db.vaultKeyWraps)..where((r) => r.kind.equals('password'))).getSingle();
    expect(w.kdfJson, contains('"m":65536'));
    expect(w.kdfJson, contains('"t":3'));
  });

  test('a second setup is refused; a short master password is refused', () async {
    await setUpVault();
    await expectLater(svc.prepareSetUp(_pw, params: _params), throwsStateError);
    final fresh = VaultKeyService(
      db: AppDatabase(NativeDatabase.memory()),
      wrapper: KeyWrapper(FakeKdf(), const AesGcmAead()),
      throttle: UnlockThrottle(InMemorySecureStore()),
      kdf: FakeKdf(),
      bioWraps: SecureBioWrapStore(InMemorySecureStore()),
      keystore: FakeBiometricKeyStore(),
    );
    await expectLater(fresh.prepareSetUp(const Sensitive('123456789'), params: _params), throwsArgumentError);
    await expectLater(fresh.prepareSetUp(const Sensitive('١٢٣٤٥٦٧٨٩'), params: _params), throwsArgumentError);
    await fresh.prepareSetUp(const Sensitive('1234567890'), params: _params);
  });

  test('wrong password: generic error, 5th attempt locks out 30 s, right one later unlocks and resets', () async {
    await setUpVault();
    for (var i = 0; i < 4; i++) {
      await expectLater(svc.unlockWithPassword(const Sensitive('wrong password!!')), throwsA(isA<VaultWrongSecret>()));
    }
    await expectLater(
      svc.unlockWithPassword(const Sensitive('wrong password!!')),
      throwsA(isA<VaultLockedOut>().having((e) => e.remaining, 'remaining', const Duration(seconds: 30))),
    );
    // Even the right password waits out the lockout.
    await expectLater(svc.unlockWithPassword(_pw), throwsA(isA<VaultLockedOut>()));
    now = now.add(const Duration(seconds: 31));
    await svc.unlockWithPassword(_pw);
    await expectLater(svc.unlockWithPassword(const Sensitive('wrong password!!')), throwsA(isA<VaultWrongSecret>()));
  });

  test('a wrong attempt never deletes anything', () async {
    await setUpVault();
    for (var i = 0; i < 9; i++) {
      now = now.add(const Duration(hours: 2));
      await expectLater(svc.unlockWithPassword(const Sensitive('wrong password!!')), throwsA(isA<VaultUnlockError>()));
    }
    expect(await db.select(db.vaultKeyWraps).get(), hasLength(2));
    expect(await db.select(db.vaultMeta).get(), hasLength(1));
  });

  test('the recovery key unlocks; garbage and a wrong key count as failures', () async {
    final r = await setUpVault();
    final k = await svc.unlockWithRecovery(r.display.toLowerCase().replaceAll('-', ' '));
    expect(k.sameAs(await svc.unlockWithPassword(_pw)), isTrue);
    await expectLater(svc.unlockWithRecovery('not a key'), throwsA(isA<VaultWrongSecret>()));
    await expectLater(svc.unlockWithRecovery(RecoveryKey.generate().display), throwsA(isA<VaultWrongSecret>()));
    final failures = await store.read(UnlockThrottle.storeKey);
    expect(failures, contains('"count":2'));
  });

  test('changing the master password: the old one fails, the new one works, items still open', () async {
    await setUpVault();
    final k = await svc.unlockWithPassword(_pw);
    final repo = VaultItemsRepository(db, const FieldCipher(AesGcmAead()));
    final id = await repo.create(
      k,
      VaultItemInput(title: 'Mail', category: 'email', password: const Sensitive('TEST-ONLY-pw-7731')),
    );
    await svc.changeMasterPassword(k, const Sensitive('a brand new phrase'), params: _params);
    await expectLater(svc.unlockWithPassword(_pw), throwsA(isA<VaultWrongSecret>()));
    final k2 = await svc.unlockWithPassword(const Sensitive('a brand new phrase'));
    expect((await repo.secrets(k2, id)).password!.value, 'TEST-ONLY-pw-7731');
  });

  test('replacing the recovery key: the old one stops working', () async {
    final old = await setUpVault();
    final k = await svc.unlockWithPassword(_pw);
    final next = RecoveryKey.generate();
    await svc.replaceRecoveryKey(k, next);
    await expectLater(svc.unlockWithRecovery(old.display), throwsA(isA<VaultWrongSecret>()));
    await svc.unlockWithRecovery(next.display);
  });

  test('a tampered password wrap reads as a wrong password and nothing is deleted', () async {
    await setUpVault();
    final w = await (db.select(db.vaultKeyWraps)..where((r) => r.kind.equals('password'))).getSingle();
    final tampered = w.sealedKey.toList()..[20] ^= 0x01;
    await (db.update(
      db.vaultKeyWraps,
    )..where((r) => r.id.equals(w.id))).write(VaultKeyWrapsCompanion(sealedKey: Value(Uint8List.fromList(tampered))));
    await expectLater(svc.unlockWithPassword(_pw), throwsA(isA<VaultWrongSecret>()));
    expect(await db.select(db.vaultKeyWraps).get(), hasLength(2));
  });

  test('a key check that does not open → VaultCorrupt', () async {
    await setUpVault();
    await db.update(db.vaultMeta).write(VaultMetaCompanion(checkBlob: Value(Uint8List(45)..[0] = 1)));
    await expectLater(svc.unlockWithPassword(_pw), throwsA(isA<VaultCorrupt>()));
  });

  test('unlocking a vault that was never set up is a StateError', () async {
    await expectLater(svc.unlockWithPassword(_pw), throwsStateError);
  });
}
