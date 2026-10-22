import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/crypto/kdf.dart';
import 'package:life_manager/core/storage/secure_store.dart';
import 'package:life_manager/features/lock/digits.dart';
import 'package:life_manager/features/lock/pin_service.dart';

void main() {
  const cheap = KdfParams(memoryKiB: 1024, iterations: 1);
  late InMemorySecureStore store;
  late DateTime clock;
  late PinService pins;

  PinService make() => PinService(store, const DartArgon2idKdf(), now: () => clock, params: cheap);

  setUp(() {
    store = InMemorySecureStore();
    clock = DateTime.utc(2026, 10, 22, 12);
    pins = make();
  });

  test('normalizeDigits maps Arabic-Indic and Extended Arabic-Indic digits', () {
    expect(normalizeDigits('١٢٣۴۵۶'), '123456');
    expect(normalizeDigits('12ab'), '12ab');
  });

  test('hasPin is false until a PIN is set', () async {
    expect(await pins.hasPin(), isFalse);
    await pins.setPin('123456');
    expect(await pins.hasPin(), isTrue);
  });

  test('setPin rejects anything but 6 digits', () {
    expect(() => pins.setPin('123'), throwsArgumentError);
    expect(() => pins.setPin('12345a'), throwsArgumentError);
    expect(() => pins.setPin('1234567'), throwsArgumentError);
  });

  test('verify ok and wrong', () async {
    await pins.setPin('123456');
    expect(await pins.verify('123456'), isA<PinOk>());
    final wrong = await pins.verify('000000');
    expect(wrong, isA<PinWrong>());
    expect((wrong as PinWrong).attemptsBeforeLockout, 4);
  });

  test('verify accepts arabic-indic digits', () async {
    await pins.setPin('123456');
    expect(await pins.verify('١٢٣٤٥٦'), isA<PinOk>());
  });

  test('success resets the failure count', () async {
    await pins.setPin('123456');
    for (var i = 0; i < 4; i++) {
      await pins.verify('000000');
    }
    await pins.verify('123456');
    expect((await pins.verify('000000') as PinWrong).attemptsBeforeLockout, 4);
  });

  test('5 failures lock out 30s, the next failure doubles it, and it persists across instances', () async {
    await pins.setPin('123456');
    for (var i = 0; i < 4; i++) {
      expect(await pins.verify('000000'), isA<PinWrong>());
    }
    final fifth = await pins.verify('000000');
    expect(fifth, isA<PinLockedOut>());

    final during = await pins.verify('123456');
    expect(during, isA<PinLockedOut>());
    expect((during as PinLockedOut).remaining, lessThanOrEqualTo(const Duration(seconds: 30)));

    clock = clock.add(const Duration(seconds: 31));
    final again = make();
    expect(await again.verify('000000'), isA<PinLockedOut>());
    final r = await again.verify('123456') as PinLockedOut;
    expect(r.remaining, greaterThan(const Duration(seconds: 30)));
    expect(r.remaining, lessThanOrEqualTo(const Duration(seconds: 60)));
  });

  test('lockout is capped at 1 hour', () async {
    await pins.setPin('123456');
    for (var i = 0; i < 40; i++) {
      await pins.verify('000000');
      clock = clock.add(const Duration(hours: 2));
    }
    await pins.verify('000000');
    final r = await pins.verify('123456') as PinLockedOut;
    expect(r.remaining, lessThanOrEqualTo(const Duration(hours: 1)));
  });

  test('stored pin record contains no plaintext pin', () async {
    await pins.setPin('123456');
    final raw = await store.read(PinService.recordKey);
    expect(raw, isNot(contains('123456')));
    final j = jsonDecode(raw!) as Map<String, dynamic>;
    expect(j.keys, containsAll(['salt', 'hash', 'kdf']));
  });

  test('changePin requires the current PIN', () async {
    await pins.setPin('123456');
    expect(await pins.changePin(current: '000000', next: '654321'), isFalse);
    expect(await pins.changePin(current: '123456', next: '654321'), isTrue);
    expect(await pins.verify('654321'), isA<PinOk>());
  });

  test('setPin falls back to lighter params when memory runs out', () async {
    final p = PinService(store, _OomOnDefaultKdf(), now: () => clock);
    await p.setPin('123456');
    final j = jsonDecode((await store.read(PinService.recordKey))!) as Map<String, dynamic>;
    expect(KdfParams.fromJson((j['kdf'] as Map).cast()).memoryKiB, kFallbackKdfParams.memoryKiB);
    expect(await p.verify('123456'), isA<PinOk>());
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
    return Uint8List.fromList(List.generate(length, (i) => (password.fold(0, (a, b) => a + b) + salt[i % salt.length] + i) & 0xff));
  }
}
