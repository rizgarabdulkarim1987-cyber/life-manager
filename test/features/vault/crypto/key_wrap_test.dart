import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/crypto/aead.dart';
import 'package:life_manager/core/crypto/kdf.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/features/vault/crypto/key_wrap.dart';
import 'package:life_manager/features/vault/crypto/recovery_key.dart';
import 'package:life_manager/features/vault/crypto/vault_errors.dart';
import 'package:life_manager/features/vault/crypto/vault_kdf.dart';
import 'package:life_manager/features/vault/crypto/vault_key.dart';

import '../../../helpers/fakes.dart';

const _id = '00112233445566778899aabbccddeeff';
const _params = KdfParams(memoryKiB: 65536, iterations: 3);

void main() {
  final w = KeyWrapper(FakeKdf(), const AesGcmAead());

  group('password wrap', () {
    test('right password → same VDK; wrong password or other vault → VaultWrongSecret', () async {
      final vdk = generateVaultKey();
      final wrapped = await w.wrapWithPassword(vdk, const Sensitive('correct horse 42'), _id, _params);
      expect(wrapped.kind, 'password');
      expect(wrapped.kdf!.memoryKiB, 65536);
      expect(wrapped.salt, hasLength(16));
      expect((await w.unwrapWithPassword(wrapped, const Sensitive('correct horse 42'), _id)).sameAs(vdk), isTrue);
      await expectLater(
        w.unwrapWithPassword(wrapped, const Sensitive('correct horse 43'), _id),
        throwsA(isA<VaultWrongSecret>()),
      );
      await expectLater(
        w.unwrapWithPassword(wrapped, const Sensitive('correct horse 42'), 'ffeeddccbbaa99887766554433221100'),
        throwsA(isA<VaultWrongSecret>()),
      );
    });

    test('Arabic-Indic and Persian digits unwrap the same as Western digits', () async {
      final vdk = generateVaultKey();
      final wrapped = await w.wrapWithPassword(vdk, const Sensitive('سر-الخزنة-2026'), _id, _params);
      expect((await w.unwrapWithPassword(wrapped, const Sensitive('سر-الخزنة-٢٠٢٦'), _id)).sameAs(vdk), isTrue);
      expect((await w.unwrapWithPassword(wrapped, const Sensitive('سر-الخزنة-۲۰۲۶'), _id)).sameAs(vdk), isTrue);
    });

    test('hostile KDF parameters from the database are refused before deriving', () async {
      final vdk = generateVaultKey();
      final ok = await w.wrapWithPassword(vdk, const Sensitive('correct horse 42'), _id, _params);
      final huge = WrappedKey(
        kind: 'password',
        kdf: const KdfParams(memoryKiB: 4 * 1024 * 1024, iterations: 3),
        salt: ok.salt,
        blob: ok.blob,
      );
      await expectLater(
        w.unwrapWithPassword(huge, const Sensitive('correct horse 42'), _id),
        throwsA(isA<VaultCorrupt>()),
      );
    });

    test('works with the real Argon2id at the OWASP floor', () async {
      final real = KeyWrapper(const DartArgon2idKdf(), const AesGcmAead());
      final vdk = generateVaultKey();
      final wrapped = await real.wrapWithPassword(vdk, const Sensitive('correct horse 42'), _id, kFallbackKdfParams);
      expect((await real.unwrapWithPassword(wrapped, const Sensitive('correct horse 42'), _id)).sameAs(vdk), isTrue);
    });
  });

  group('recovery wrap', () {
    test('right key → same VDK; another key → VaultWrongSecret', () async {
      final vdk = generateVaultKey();
      final r = RecoveryKey.generate();
      final wrapped = await w.wrapWithRecovery(vdk, r, _id);
      expect(wrapped.kind, 'recovery');
      expect(wrapped.kdf, isNull);
      expect((await w.unwrapWithRecovery(wrapped, RecoveryKey.parse(r.display)!, _id)).sameAs(vdk), isTrue);
      await expectLater(w.unwrapWithRecovery(wrapped, RecoveryKey.generate(), _id), throwsA(isA<VaultWrongSecret>()));
    });
  });

  group('key check', () {
    test('verifies only the right VDK for the right vault', () async {
      final vdk = generateVaultKey();
      final check = await w.makeCheck(vdk, _id);
      expect(await w.verifyCheck(vdk, _id, check), isTrue);
      expect(await w.verifyCheck(generateVaultKey(), _id, check), isFalse);
      expect(await w.verifyCheck(vdk, 'ffeeddccbbaa99887766554433221100', check), isFalse);
      expect(await w.verifyCheck(vdk, _id, Uint8List.fromList([9, 9, 9])), isFalse);
    });
  });

  group('KDF parameters', () {
    test('checkVaultKdf accepts the spec start and the fallback, refuses extremes', () {
      checkVaultKdf(kDefaultKdfParams);
      checkVaultKdf(kFallbackKdfParams);
      checkVaultKdf(const KdfParams(memoryKiB: 65536, iterations: 8));
      for (final p in const [
        KdfParams(memoryKiB: 4 * 1024 * 1024, iterations: 3),
        KdfParams(memoryKiB: 65536, iterations: 50),
        KdfParams(memoryKiB: 1024, iterations: 3),
        KdfParams(memoryKiB: 65536, iterations: 3, parallelism: 64),
      ]) {
        expect(() => checkVaultKdf(p), throwsA(isA<VaultCorrupt>()), reason: '${p.toJson()}');
      }
    });

    Future<KdfParams> calibrateWith(Duration elapsed, {bool oom = false}) => calibrateVaultKdf(
      oom ? _OomKdf() : FakeKdf(),
      time: (run) async {
        await run();
        return elapsed;
      },
    );

    test('a slow phone keeps the spec start (m 64 MiB, t 3)', () async {
      final p = await calibrateWith(const Duration(milliseconds: 1400));
      expect((p.memoryKiB, p.iterations, p.parallelism), (65536, 3, 1));
    });

    test('a fast phone raises t towards 0.75 s, capped at 8', () async {
      expect((await calibrateWith(const Duration(milliseconds: 400))).iterations, 6);
      expect((await calibrateWith(const Duration(milliseconds: 50))).iterations, 8);
    });

    test('out of memory falls back to the OWASP minimum', () async {
      final p = await calibrateWith(const Duration(milliseconds: 100), oom: true);
      expect((p.memoryKiB, p.iterations), (19456, 2));
    });
  });

  test('no wrap type prints secret material', () async {
    final vdk = generateVaultKey();
    final wrapped = await w.wrapWithPassword(vdk, const Sensitive('correct horse 42'), _id, _params);
    expect('$wrapped', isNot(contains('correct')));
    expect('$wrapped', isNot(contains(wrapped.blob.toString())));
  });
}

class _OomKdf implements Kdf {
  @override
  Future<Uint8List> derive({
    required Uint8List password,
    required Uint8List salt,
    required KdfParams params,
    int length = 32,
  }) async {
    if (params.memoryKiB > kFallbackKdfParams.memoryKiB) throw const KdfOutOfMemory();
    return Uint8List(length);
  }
}
