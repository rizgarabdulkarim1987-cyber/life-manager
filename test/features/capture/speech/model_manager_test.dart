import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/net/http_port.dart';
import 'package:life_manager/features/capture/speech/model_manager.dart';

import '../../../helpers/fakes.dart';

final _bytes = List<int>.generate(10000, (i) => (i * 7) & 0xff);

WhisperModelSpec _spec({String? sha}) => WhisperModelSpec(
  id: 'tiny-test',
  fileName: 'ggml-tiny-test.bin',
  url: Uri.parse('https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny-test.bin'),
  sha256: sha ?? sha256.convert(_bytes).toString(),
  sizeBytes: _bytes.length,
);

void main() {
  late Directory dir;
  late FakeHttpPort http;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('models_test');
    http = FakeHttpPort((_) => const HttpReply(500, ''))
      ..stream = (_) => Stream.fromIterable([_bytes.sublist(0, 4000), _bytes.sublist(4000)]);
  });
  tearDown(() => dir.delete(recursive: true));

  ModelManager manager(WhisperModelSpec spec) => ModelManager(http, () async => dir, specs: {spec.id: spec});

  test('download verifies sha256 and installs', () async {
    final m = manager(_spec());
    expect(await m.installed('tiny-test'), isNull);
    final events = await m.download('tiny-test').toList();
    expect(events.whereType<Downloading>().map((e) => (e.received, e.total)), [(4000, 10000), (10000, 10000)]);
    expect(events.last, isA<Installed>());
    expect(events.whereType<Verifying>(), hasLength(1));
    final f = (await m.installed('tiny-test'))!;
    expect(f.path, endsWith('${Platform.pathSeparator}models${Platform.pathSeparator}ggml-tiny-test.bin'));
    expect(await f.readAsBytes(), _bytes);
    expect(File('${f.path}.part').existsSync(), isFalse);
    expect(http.streamed.single.toString(), startsWith('https://huggingface.co/'));

    await m.delete('tiny-test');
    expect(await m.installed('tiny-test'), isNull);
  });

  test('checksum mismatch deletes the part file and throws', () async {
    final m = manager(_spec(sha: '0' * 64));
    await expectLater(m.download('tiny-test').drain<void>(), throwsA(isA<ModelChecksumMismatch>()));
    expect(await m.installed('tiny-test'), isNull);
    expect(Directory('${dir.path}/models').listSync(), isEmpty);
  });

  test('a broken download leaves no part file and installs nothing', () async {
    http.stream = (_) async* {
      yield _bytes.sublist(0, 100);
      throw const SocketException('reset');
    };
    final m = manager(_spec());
    await expectLater(m.download('tiny-test').drain<void>(), throwsA(isA<SocketException>()));
    expect(Directory('${dir.path}/models').listSync(), isEmpty);
  });

  test('a file of the wrong size is not counted as installed', () async {
    final m = manager(_spec());
    await Directory('${dir.path}/models').create();
    await File('${dir.path}/models/ggml-tiny-test.bin').writeAsBytes([1, 2, 3]);
    expect(await m.installed('tiny-test'), isNull);
  });

  test('kWhisperModels pins a 64-hex sha and size', () {
    expect(kWhisperModels.keys, {'small', 'base'});
    for (final s in kWhisperModels.values) {
      expect(s.sha256, matches(RegExp(r'^[0-9a-f]{64}$')), reason: s.id);
      expect(s.sizeBytes, greaterThan(0), reason: s.id);
      expect(s.url.toString(), 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/${s.fileName}');
    }
    expect(kWhisperModels['base']!.fileName, 'ggml-base.bin');
    expect(kWhisperModels['small']!.fileName, 'ggml-small.bin');
  });
}
