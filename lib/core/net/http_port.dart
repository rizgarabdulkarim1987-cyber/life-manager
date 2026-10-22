import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class HttpReply {
  const HttpReply(this.status, this.body);

  final int status;
  final String body;
}

/// The app's only way onto the network, so tests can see every request.
abstract interface class HttpPort {
  Future<HttpReply> postJson(Uri u, Map<String, String> headers, String body, Duration timeout);

  Future<HttpReply> postMultipart(
    Uri u,
    Map<String, String> headers,
    Map<String, String> fields,
    String fileField,
    String fileName,
    Uint8List file,
    Duration timeout,
  );

  /// Streams a download; [timeout] bounds the wait for the response to start.
  Stream<List<int>> getStream(Uri u, Duration timeout);
}

class PackageHttpPort implements HttpPort {
  PackageHttpPort([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  static void _httpsOnly(Uri u) {
    if (u.scheme != 'https') throw ArgumentError('https only');
  }

  @override
  Future<HttpReply> postJson(Uri u, Map<String, String> headers, String body, Duration timeout) async {
    _httpsOnly(u);
    final r = await _client
        .post(u, headers: {...headers, 'Content-Type': 'application/json; charset=utf-8'}, body: body)
        .timeout(timeout);
    return HttpReply(r.statusCode, r.body);
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
    _httpsOnly(u);
    final req = http.MultipartRequest('POST', u)
      ..headers.addAll(headers)
      ..fields.addAll(fields)
      ..files.add(http.MultipartFile.fromBytes(fileField, file, filename: fileName));
    final r = await http.Response.fromStream(await _client.send(req).timeout(timeout)).timeout(timeout);
    return HttpReply(r.statusCode, r.body);
  }

  @override
  Stream<List<int>> getStream(Uri u, Duration timeout) async* {
    _httpsOnly(u);
    final r = await _client.send(http.Request('GET', u)).timeout(timeout);
    if (r.statusCode != 200) throw http.ClientException('status ${r.statusCode}');
    yield* r.stream;
  }
}
