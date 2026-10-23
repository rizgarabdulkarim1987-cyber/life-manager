import 'dart:async';

import 'package:flutter/services.dart';

import '../../../core/crypto/random.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/security/sensitive.dart';
import 'biometric_key_store.dart';

/// How long a copied secret stays on the clipboard (spec §9.2).
const kClipboardClear = Duration(seconds: 30);

abstract interface class SecretClipboard {
  /// Copies [value] marked sensitive and clears it after [clearAfter] where
  /// Android allows. Returns false when the copy failed.
  Future<bool> copy(Sensitive<String> value, {Duration clearAfter = kClipboardClear});
}

/// Copies through `VaultChannel.kt` (plan Decision 15): the clip carries
/// `EXTRA_IS_SENSITIVE` and a one-off label, and the native side clears it
/// after the delay unless something else was copied since. Never logs the value.
final class PlatformSecretClipboard implements SecretClipboard {
  PlatformSecretClipboard([this._channel = channel, this._timer = Timer.new]);

  static const channel = PlatformBiometricKeyStore.channel;

  final MethodChannel _channel;
  final Timer Function(Duration, void Function()) _timer;

  static String _label() => 'plm-${secureRandomBytes(8).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

  @override
  Future<bool> copy(Sensitive<String> value, {Duration clearAfter = kClipboardClear}) async {
    try {
      await _channel.invokeMethod<void>('copySecret', {
        'text': value.value,
        'label': _label(),
        'clearAfterMs': clearAfter.inMilliseconds,
      });
      return true;
    } on MissingPluginException {
      return _fallback(value, clearAfter);
    } on PlatformException catch (e) {
      AppLogger.warn('secret copy failed', e);
      return false;
    }
  }

  /// Tests and non-Android platforms: plain clipboard, cleared by a Dart timer
  /// only if it still holds the same text.
  Future<bool> _fallback(Sensitive<String> value, Duration clearAfter) async {
    try {
      await Clipboard.setData(ClipboardData(text: value.value));
    } on PlatformException catch (e) {
      AppLogger.warn('secret copy failed', e);
      return false;
    }
    _timer(clearAfter, () async {
      try {
        final now = await Clipboard.getData(Clipboard.kTextPlain);
        if (now?.text == value.value) await Clipboard.setData(const ClipboardData(text: ''));
      } on PlatformException catch (e) {
        AppLogger.warn('secret clear failed', e);
      }
    });
    return true;
  }
}
