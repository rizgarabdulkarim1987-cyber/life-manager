import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/logging/app_logger.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/features/vault/platform/secret_clipboard.dart';

const _secret = 'TEST-ONLY-pw-7731';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = PlatformSecretClipboard.channel;
  late List<String> logs;

  setUp(() {
    logs = [];
    AppLogger.sink = logs.add;
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('copy sends the text, a fresh plm- label and 30 000 ms, and logs nothing', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (c) async {
      calls.add(c);
      return null;
    });
    final clip = PlatformSecretClipboard();
    expect(await clip.copy(const Sensitive(_secret)), isTrue);
    await clip.copy(const Sensitive(_secret));
    final a = calls[0].arguments as Map;
    final b = calls[1].arguments as Map;
    expect(calls[0].method, 'copySecret');
    expect(a['text'], _secret);
    expect(a['clearAfterMs'], 30000);
    expect(a['label'], matches(RegExp(r'^plm-[0-9a-f]{16}$')));
    expect(b['label'], isNot(a['label']));
    expect(logs, isEmpty);
  });

  test('a platform error logs only its type and reports failure', () async {
    messenger.setMockMethodCallHandler(channel, (c) async => throw PlatformException(code: 'failed', message: _secret));
    expect(await PlatformSecretClipboard().copy(const Sensitive(_secret)), isFalse);
    expect(logs.single, contains('PlatformException'));
    expect(logs.join(), isNot(contains(_secret)));
  });

  test('without the native side, the fallback clears after 30 s only if the clip is unchanged', () async {
    String? clip;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (c) async {
      if (c.method == 'Clipboard.setData') clip = (c.arguments as Map)['text'] as String?;
      if (c.method == 'Clipboard.getData') return {'text': clip};
      return null;
    });
    final timers = <(Duration, void Function())>[];
    final board = PlatformSecretClipboard(PlatformSecretClipboard.channel, (d, f) {
      timers.add((d, f));
      return Timer(Duration.zero, () {});
    });
    // The real vault channel has no handler here, so copy() takes the fallback.
    await board.copy(const Sensitive(_secret));
    expect(clip, _secret);
    expect(timers.single.$1, kClipboardClear);
    timers.single.$2();
    await pumpEventQueue();
    expect(clip, '');

    await board.copy(const Sensitive(_secret));
    clip = 'something the owner copied later';
    timers.last.$2();
    await pumpEventQueue();
    expect(clip, 'something the owner copied later');
    expect(logs, isEmpty);
  });
}
