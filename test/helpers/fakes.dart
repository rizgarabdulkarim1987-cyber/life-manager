import 'dart:async';
import 'dart:typed_data';

import 'package:life_manager/features/capture/speech/recorder.dart';
import 'package:life_manager/core/crypto/kdf.dart';
import 'package:life_manager/core/net/http_port.dart';
import 'package:life_manager/features/lock/biometric_authenticator.dart';

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
  FakeBiometric({this.deviceSupported = true, this.result = true});
  final bool deviceSupported;
  bool result;
  int prompts = 0;
  @override
  Future<bool> deviceSecure() async => deviceSupported;
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

class FakeRecorder implements AudioRecorderPort {
  FakeRecorder({this.allowed = true});

  final bool allowed;
  final levels = StreamController<double>.broadcast();
  int starts = 0;
  int stops = 0;
  int cancels = 0;

  @override
  Future<bool> ensurePermission() async => allowed;

  @override
  Future<void> start() async => starts++;

  @override
  Stream<double> get level => levels.stream;

  @override
  Future<Uint8List> stop() async {
    stops++;
    return Uint8List.fromList(List.filled(32, 1));
  }

  @override
  Future<void> cancel() async => cancels++;
}
