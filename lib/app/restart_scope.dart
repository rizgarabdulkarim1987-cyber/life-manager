import 'package:flutter/widgets.dart';

import '../core/logging/app_logger.dart';

/// Builds the app (opening the database and its ProviderScope) and can rebuild
/// it from scratch, used after a restore swaps the database file.
class RestartScope extends StatefulWidget {
  const RestartScope({super.key, required this.build, required this.loading, required this.failed});

  final Future<Widget> Function() build;
  final Widget loading;

  /// Shown when [build] throws (e.g. the database can't be opened), so the app
  /// never sits on a blank screen. `retry` runs [build] again.
  final Widget Function(VoidCallback retry) failed;

  static Future<void> maybeRestart(BuildContext context) async =>
      context.findAncestorStateOfType<_RestartScopeState>()?._restart();

  static Future<void> restart(BuildContext context) =>
      context.findAncestorStateOfType<_RestartScopeState>()!._restart();

  @override
  State<RestartScope> createState() => _RestartScopeState();
}

class _RestartScopeState extends State<RestartScope> {
  Widget? _app;
  Key _key = UniqueKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Widget app;
    try {
      app = await widget.build();
    } catch (e, st) {
      AppLogger.error('app failed to start', e.runtimeType, st);
      app = widget.failed(_restart);
    }
    if (mounted) setState(() => _app = app);
  }

  Future<void> _restart() async {
    setState(() {
      _app = null;
      _key = UniqueKey();
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(key: _key, child: _app ?? widget.loading);
}
