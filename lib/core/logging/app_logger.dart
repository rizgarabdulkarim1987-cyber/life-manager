import 'package:flutter/foundation.dart';

/// The app's only logger. Errors are logged by type, never by message, so an
/// exception that carries a secret in its text cannot leak it (spec §9.2).
abstract final class AppLogger {
  static void Function(String line) sink = _defaultSink;

  static void _defaultSink(String line) => debugPrint(line);

  static void info(String msg) {
    if (kReleaseMode) return;
    sink('[info] $msg');
  }

  static void warn(String msg, [Object? error]) {
    sink('[warn] $msg${_describe(error)}');
  }

  static void error(String msg, [Object? error, StackTrace? st]) {
    sink('[error] $msg${_describe(error)}');
  }

  static String _describe(Object? error) => error == null ? '' : ' (${error.runtimeType})';
}
