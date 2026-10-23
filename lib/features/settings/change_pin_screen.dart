import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/ckb_fallback_localizations.dart';
import '../../core/logging/app_logger.dart';
import '../../core/theme/tokens.dart';
import '../lock/lock_controller.dart';
import '../lock/lock_screen.dart';
import '../lock/pin_service.dart';

enum _Stage { current, next, confirm }

/// Current PIN, then the new one twice. Pops `true` once the new PIN is saved.
class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  _Stage _stage = _Stage.current;
  String _entered = '';
  String? _next;
  String? _error;
  bool _busy = false;
  final _dots = GlobalKey<PinDotsState>();

  void _fail(String message) {
    HapticFeedback.heavyImpact();
    _dots.currentState?.shake();
    setState(() {
      _error = message;
      _entered = '';
    });
  }

  Future<void> _onDigit(String d) async {
    if (_busy || _entered.length >= kPinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _entered += d;
      _error = null;
    });
    if (_entered.length < kPinLength) return;

    final l10n = context.l10n;
    final pins = ref.read(pinServiceProvider);
    final pin = _entered;
    switch (_stage) {
      case _Stage.current:
        setState(() => _busy = true);
        final PinCheckResult result;
        try {
          result = await pins.verify(pin);
        } catch (e) {
          AppLogger.error('pin verify failed', e.runtimeType);
          if (mounted) {
            setState(() => _busy = false);
            _fail(l10n.somethingWentWrong);
          }
          return;
        }
        if (!mounted) return;
        setState(() => _busy = false);
        switch (result) {
          case PinOk():
            setState(() {
              _stage = _Stage.next;
              _entered = '';
            });
          case PinWrong():
            _fail(l10n.wrongPin);
          case PinLockedOut(:final remaining):
            _fail(l10n.tryAgainIn('${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}'));
        }
      case _Stage.next:
        setState(() {
          _next = pin;
          _stage = _Stage.confirm;
          _entered = '';
        });
      case _Stage.confirm:
        if (pin != _next) {
          _next = null;
          _stage = _Stage.next;
          _fail(l10n.pinMismatch);
          return;
        }
        setState(() => _busy = true);
        try {
          await pins.setPin(pin);
        } catch (e) {
          // The old PIN is still in place; start the new-PIN step again.
          AppLogger.error('pin change failed', e.runtimeType);
          if (mounted) {
            setState(() => _busy = false);
            _next = null;
            _stage = _Stage.next;
            _fail(l10n.somethingWentWrong);
          }
          return;
        }
        if (mounted) Navigator.of(context).pop(true);
    }
  }

  void _onBackspace() {
    if (_busy || _entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final title = switch (_stage) {
      _Stage.current => l10n.currentPin,
      _Stage.next => l10n.newPin,
      _Stage.confirm => l10n.setupConfirmPin,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.changePin)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight - 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: text.titleLarge?.copyWith(color: k.text),
                      ),
                      const SizedBox(height: 24),
                      PinDots(key: _dots, filled: _entered.length, error: _error != null),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: _error == null
                            ? null
                            : Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: text.bodyMedium?.copyWith(color: k.danger),
                              ),
                      ),
                    ],
                  ),
                  PinPad(
                    enabled: !_busy,
                    onDigit: _onDigit,
                    onBackspace: _onBackspace,
                    onBiometric: null,
                    biometricLabel: '',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
