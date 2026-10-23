import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/tokens.dart';

/// Shown while the stored settings load; reports whether first-run setup is done.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key, required this.onResolved});

  final ValueChanged<bool> onResolved;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final settings = await ref.read(settingsRepositoryProvider).get();
    if (mounted) widget.onResolved(settings.setupCompleted);
  }

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    return Scaffold(
      body: Center(child: Icon(Icons.lock_outline_rounded, size: 40, color: k.accent)),
    );
  }
}
