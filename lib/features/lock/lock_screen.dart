import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/ckb_fallback_localizations.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import 'lock_controller.dart';
import 'pin_service.dart';

const kPinLength = 6;

/// Full-screen unlock: fingerprint first when enabled, PIN always available.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _entered = '';
  String? _error;
  bool _busy = false;
  bool _bioAvailable = false;
  DateTime? _lockedUntil;
  Timer? _ticker;
  final _shake = GlobalKey<PinDotsState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBiometric(auto: true));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _maybeBiometric({required bool auto}) async {
    final settings = await ref.read(settingsRepositoryProvider).get();
    if (!settings.biometricEnabled) return;
    final bio = ref.read(biometricAuthenticatorProvider);
    final available = await bio.isAvailable();
    if (!mounted) return;
    setState(() => _bioAvailable = available);
    if (!available) return;
    final ok = await bio.authenticate(context.l10n.unlockReason);
    if (ok && mounted) ref.read(lockControllerProvider.notifier).unlock();
  }

  void _onDigit(String d) {
    if (_busy || _isLockedOut || _entered.length >= kPinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _entered += d;
      _error = null;
    });
    if (_entered.length == kPinLength) _submit();
  }

  void _onBackspace() {
    if (_busy || _entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  bool get _isLockedOut => _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);

  Future<void> _submit() async {
    setState(() => _busy = true);
    final l10n = context.l10n;
    final result = await ref.read(pinServiceProvider).verify(_entered);
    if (!mounted) return;
    switch (result) {
      case PinOk():
        ref.read(lockControllerProvider.notifier).unlock();
      case PinWrong(:final attemptsBeforeLockout):
        HapticFeedback.heavyImpact();
        _shake.currentState?.shake();
        setState(
          () => _error = attemptsBeforeLockout <= 2
              ? '${l10n.wrongPin}\n${l10n.attemptsLeft(attemptsBeforeLockout)}'
              : l10n.wrongPin,
        );
      case PinLockedOut(:final remaining):
        HapticFeedback.heavyImpact();
        _shake.currentState?.shake();
        _startLockout(remaining);
    }
    setState(() {
      _busy = false;
      _entered = '';
    });
  }

  void _startLockout(Duration remaining) {
    _lockedUntil = DateTime.now().add(remaining);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (!_isLockedOut) {
        t.cancel();
        setState(() {
          _lockedUntil = null;
          _error = null;
        });
      } else {
        setState(() {});
      }
    });
    setState(() {});
  }

  String _formatRemaining() {
    final s = _lockedUntil!.difference(DateTime.now()).inSeconds + 1;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final message = _isLockedOut ? l10n.tryAgainIn(_formatRemaining()) : _error;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 24),
                        Icon(Icons.lock_outline_rounded, size: 32, color: k.accent),
                        const SizedBox(height: 16),
                        Text(l10n.enterPin, style: text.titleLarge?.copyWith(color: k.text)),
                        const SizedBox(height: 24),
                        PinDots(key: _shake, filled: _entered.length, error: message != null),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 48,
                          child: AnimatedSwitcher(
                            duration: kDurationBase,
                            switchInCurve: kEaseOut,
                            child: message == null
                                ? const SizedBox.shrink()
                                : Text(
                                    message,
                                    key: ValueKey(message),
                                    textAlign: TextAlign.center,
                                    style: text.bodyMedium?.copyWith(color: k.danger),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    PinPad(
                      enabled: !_busy && !_isLockedOut,
                      onDigit: _onDigit,
                      onBackspace: _onBackspace,
                      onBiometric: _bioAvailable ? () => _maybeBiometric(auto: false) : null,
                      biometricLabel: l10n.useFingerprint,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Six dots that fill as digits are typed and shake on a wrong PIN.
class PinDots extends StatefulWidget {
  const PinDots({super.key, required this.filled, required this.error, this.length = kPinLength});

  final int filled;
  final bool error;
  final int length;

  @override
  State<PinDots> createState() => PinDotsState();
}

class PinDotsState extends State<PinDots> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));

  void shake() {
    if (reduceMotion(context)) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Three decaying oscillations; ends exactly at rest.
        final t = _controller.value;
        final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: AnimatedContainer(
                  duration: reduceMotion(context) ? Duration.zero : kDurationFast,
                  curve: kEaseOut,
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < widget.filled ? (widget.error ? k.danger : k.accent) : Colors.transparent,
                    border: Border.all(color: widget.error ? k.danger : k.textMuted, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Phone-style keypad. Digits stay 1-2-3 left to right in every locale.
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
    required this.onBiometric,
    required this.biometricLabel,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;
  final String biometricLabel;

  @override
  Widget build(BuildContext context) {
    Widget digit(String d) => _PadKey(
      key: ValueKey('pin-key-$d'),
      onTap: enabled ? () => onDigit(d) : null,
      semanticLabel: d,
      child: Text(d, style: Theme.of(context).textTheme.headlineSmall),
    );

    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in rows) Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: r.map(digit).toList()),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              onBiometric == null
                  ? const SizedBox(width: _PadKey.size, height: _PadKey.size)
                  : _PadKey(
                      key: const ValueKey('pin-key-bio'),
                      onTap: onBiometric,
                      semanticLabel: biometricLabel,
                      child: const Icon(Icons.fingerprint_rounded, size: 30),
                    ),
              digit('0'),
              _PadKey(
                key: const ValueKey('pin-key-back'),
                onTap: enabled ? onBackspace : null,
                semanticLabel: MaterialLocalizations.of(context).deleteButtonTooltip,
                child: const Icon(Icons.backspace_outlined, size: 24),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({super.key, required this.onTap, required this.child, required this.semanticLabel});

  static const double size = 72;

  final VoidCallback? onTap;
  final Widget child;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Semantics(
        button: true,
        label: semanticLabel,
        excludeSemantics: true,
        child: Material(
          color: k.surfaceHigh,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: IconTheme.merge(
                  data: IconThemeData(color: k.text),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
