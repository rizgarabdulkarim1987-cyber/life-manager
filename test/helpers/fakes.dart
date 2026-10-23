import 'dart:typed_data';

import 'package:life_manager/core/crypto/kdf.dart';
import 'package:life_manager/core/net/http_port.dart';
import 'package:life_manager/features/lock/biometric_authenticator.dart';
import 'package:life_manager/features/vault/crypto/vault_errors.dart';
import 'package:life_manager/features/vault/platform/biometric_key_store.dart';

/// Fast deterministic stand-in so widget tests don't wait on a real KDF isolate.
class FakeKdf implements Kdf {
  @override
  Future<Uint8List> derive({
    required Uint8List password,
    required Uint8List salt,
    required KdfParams params,
    int length = 32,
  }) async => Uint8List.fromList(
    List.generate(length, (i) => (password[i % password.length] * 31 + salt[i % salt.length] + i) & 0xff),
  );
}

class FakeBiometric implements BiometricAuthenticator {
  FakeBiometric({required this.available, required this.result});
  final bool available;
  final bool result;
  int prompts = 0;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    return result;
  }
}

class FakeRequest {
  FakeRequest(this.uri, this.headers, {this.body, this.fields, this.fileField, this.fileName, this.file});

  final Uri uri;
  final Map<String, String> headers;
  final String? body;
  final Map<String, String>? fields;
  final String? fileField;
  final String? fileName;
  final Uint8List? file;
}

/// Records every request; [reply] decides the answer (or throws, like a dropped connection).
class FakeHttpPort implements HttpPort {
  FakeHttpPort(this.reply);

  HttpReply Function(FakeRequest r) reply;
  final requests = <FakeRequest>[];

  /// Runs before [reply], so a test can look at the app's state at the moment of the request.
  Future<void> Function(FakeRequest r)? before;

  /// Answers [getStream]; downloads fail when unset.
  Stream<List<int>> Function(Uri u)? stream;
  final streamed = <Uri>[];

  @override
  Future<HttpReply> postJson(Uri u, Map<String, String> headers, String body, Duration timeout) async {
    final r = FakeRequest(u, headers, body: body);
    requests.add(r);
    await before?.call(r);
    return reply(r);
  }

  @override
  Future<HttpReply> postMultipart(
    Uri u,
    Map<String, String> headers,
    Map<String, String> fields,
    String fileField,
    String fileName,
    Uint8List file,
    Duration timeout,
  ) async {
    final r = FakeRequest(u, headers, fields: fields, fileField: fileField, fileName: fileName, file: file);
    requests.add(r);
    await before?.call(r);
    return reply(r);
  }

  @override
  Stream<List<int>> getStream(Uri u, Duration timeout) {
    streamed.add(u);
    final s = stream;
    if (s == null) throw StateError('no stream configured');
    return s(u);
  }
}

/// Stands in for the Keystore key: "encrypts" by XOR with a fixed pad, and can
/// be told to fail the way the platform does.
class FakeBiometricKeyStore implements BiometricKeyStore {
  FakeBiometricKeyStore({this.available = true});

  bool available;

  /// When set, the next encrypt/decrypt throws it instead of prompting.
  Object? failNext;

  /// True after the Keystore key was deleted; decrypt then reports it invalidated.
  bool keyDeleted = false;
  int prompts = 0;
  int deletes = 0;

  static Uint8List _xor(Uint8List data) => Uint8List.fromList([for (var i = 0; i < data.length; i++) data[i] ^ (0x5A + i)]);

  Future<Uint8List> _run(Uint8List data) async {
    prompts++;
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
    return _xor(data);
  }

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<Uint8List> encrypt(Uint8List data, BioPromptText t) async {
    keyDeleted = false;
    return _run(data);
  }

  @override
  Future<Uint8List> decrypt(Uint8List data, BioPromptText t) async {
    if (keyDeleted) throw const VaultBiometricInvalidated();
    return _run(data);
  }

  @override
  Future<void> deleteKey() async {
    deletes++;
    keyDeleted = true;
  }
}
