import 'package:flutter/widgets.dart';

/// Builds the app (opening the database and its ProviderScope) and can rebuild
/// it from scratch, used after a restore swaps the database file.
class RestartScope extends StatefulWidget {
  const RestartScope({super.key, required this.build, required this.loading});

  final Future<Widget> Function() build;
  final Widget loading;

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
    final app = await widget.build();
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
