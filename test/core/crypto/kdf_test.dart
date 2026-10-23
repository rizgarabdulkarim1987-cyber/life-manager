import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/crypto/kdf.dart';

Uint8List utf8b(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  const kdf = DartArgon2idKdf();
  const cheap = KdfParams(memoryKiB: 1024, iterations: 2);

  test('argon2id is deterministic and 32 bytes', () async {
    final k1 = await kdf.derive(password: utf8b('pw'), salt: Uint8List(16), params: cheap);
    final k2 = await kdf.derive(password: utf8b('pw'), salt: Uint8List(16), params: cheap);
    expect(k1.length, 32);
    expect(k1, k2);
  });

  test('salt and password both change the key', () async {
    final base = await kdf.derive(password: utf8b('pw'), salt: Uint8List(16), params: cheap);
    final otherSalt = await kdf.derive(password: utf8b('pw'), salt: Uint8List(16)..[0] = 1, params: cheap);
    final otherPw = await kdf.derive(password: utf8b('pw2'), salt: Uint8List(16), params: cheap);
    expect(otherSalt, isNot(base));
    expect(otherPw, isNot(base));
  });

  test('params change the key', () async {
    final a = await kdf.derive(password: utf8b('pw'), salt: Uint8List(16), params: cheap);
    final b = await kdf.derive(
      password: utf8b('pw'),
      salt: Uint8List(16),
      params: const KdfParams(memoryKiB: 1024, iterations: 3),
    );
    expect(a, isNot(b));
  });

  test('underlying Argon2id matches the RFC 9106 test vector', () async {
    final algo = DartArgon2id(parallelism: 4, memory: 32, iterations: 3, hashLength: 32);
    final key = await algo.deriveKey(
      secretKey: SecretKey(List.filled(32, 0x01)),
      nonce: List.filled(16, 0x02),
      optionalSecret: List.filled(8, 0x03),
      associatedData: List.filled(12, 0x04),
    );
    final hex = (await key.extractBytes()).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    expect(hex, '0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659');
  });

  test('KdfParams json round-trips', () {
    final p = KdfParams.fromJson(kDefaultKdfParams.toJson());
    expect(p.memoryKiB, 65536);
    expect(p.iterations, 3);
    expect(p.parallelism, 1);
  });

  test('default and fallback params match the spec', () {
    expect(kDefaultKdfParams.memoryKiB, 65536);
    expect(kDefaultKdfParams.iterations, 3);
    expect(kFallbackKdfParams.memoryKiB, 19456);
    expect(kFallbackKdfParams.iterations, 2);
  });

  test('calibrateKdf falls back when default params run out of memory', () async {
    final p = await calibrateKdf(_OomOnDefaultKdf());
    expect(p.memoryKiB, kFallbackKdfParams.memoryKiB);
  });

  test('calibrateKdf keeps defaults when they work', () async {
    final p = await calibrateKdf(_AlwaysOkKdf());
    expect(p.memoryKiB, kDefaultKdfParams.memoryKiB);
  });
}

class _OomOnDefaultKdf implements Kdf {
  @override
  Future<Uint8List> derive({
    required Uint8List password,
    required Uint8List salt,
    required KdfParams params,
    int length = 32,
  }) async {
    if (params.memoryKiB == kDefaultKdfParams.memoryKiB) throw const KdfOutOfMemory();
    return Uint8List(length);
  }
}

class _AlwaysOkKdf implements Kdf {
  @override
  Future<Uint8List> derive({
    required Uint8List password,
    required Uint8List salt,
    required KdfParams params,
    int length = 32,
  }) async => Uint8List(length);
}
