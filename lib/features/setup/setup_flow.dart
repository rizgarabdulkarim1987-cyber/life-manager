import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/db/seed.dart';
import '../../core/l10n/ckb_fallback_localizations.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../lock/lock_controller.dart';
import '../lock/lock_screen.dart';

enum _Step { language, pin, biometric, warning }

/// First run: language, PIN, optional fingerprint, backup warning, then seed.
/// Steps advance only through their own buttons, so validation can't be swiped past.
class SetupFlow extends ConsumerStatefulWidget {
  const SetupFlow({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<SetupFlow> createState() => _SetupFlowState();
}

class _SetupFlowState extends ConsumerState<SetupFlow> {
  _Step _step = _Step.language;
  bool _bioAvailable = false;
  bool _bioEnabled = false;
  bool _acknowledged = false;
  bool _busy = false;

  // PIN entry state. The chosen PIN is held only until it is hashed at finish.
  String _entered = '';
  String? _firstPin;
  bool _pinMismatch = false;
  final _dots = GlobalKey<PinDotsState>();

  @override
  void initState() {
    super.initState();
    ref.read(biometricAuthenticatorProvider).isAvailable().then((v) {
      if (mounted) setState(() => _bioAvailable = v);
    });
  }

  List<_Step> get _steps => [_Step.language, _Step.pin, if (_bioAvailable) _Step.biometric, _Step.warning];

  void _next() {
    final i = _steps.indexOf(_step);
    setState(() => _step = _steps[i + 1]);
  }

  void _onDigit(String d) {
    if (_entered.length >= kPinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _entered += d;
      _pinMismatch = false;
    });
    if (_entered.length < kPinLength) return;

    if (_firstPin == null) {
      setState(() {
        _firstPin = _entered;
        _entered = '';
      });
    } else if (_firstPin == _entered) {
      _entered = '';
      _next();
    } else {
      HapticFeedback.heavyImpact();
      _dots.currentState?.shake();
      setState(() {
        _firstPin = null;
        _entered = '';
        _pinMismatch = true;
      });
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _enableBiometric() async {
    final ok = await ref.read(biometricAuthenticatorProvider).authenticate(context.l10n.unlockReason);
    if (!mounted || !ok) return;
    _bioEnabled = true;
    _next();
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    final l10n = context.l10n;
    final db = ref.read(appDatabaseProvider);
    final settings = ref.read(settingsRepositoryProvider);

    await ref.read(pinServiceProvider).setPin(_firstPin!);
    _firstPin = null;
    await seedInitialData(
      db,
      SeedNames(
        personal: l10n.seedPersonal,
        buzzify: l10n.seedBuzzify,
        eo: l10n.seedEo,
        otherProjects: l10n.seedOtherProjects,
        cashIqd: l10n.seedCashIqd,
        cashUsd: l10n.seedCashUsd,
      ),
    );
    await settings.setBiometricEnabled(_bioEnabled);
    // Last, so an interrupted setup simply runs again on the next launch.
    await settings.markSetupCompleted();
    if (!mounted) return;
    ref.read(lockControllerProvider.notifier).unlock();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotion(context);
    final steps = _steps;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: _StepIndicator(count: steps.length, current: steps.indexOf(_step)),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: reduce ? Duration.zero : const Duration(milliseconds: 240),
                switchInCurve: kEaseOut,
                switchOutCurve: kEaseOut,
                transitionBuilder: (child, animation) {
                  final dir = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(begin: Offset(0.06 * dir, 0), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey('step-${_step == _Step.biometric ? 'bio' : _step.name}'),
                  child: _buildStep(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) => switch (_step) {
    _Step.language => _languageStep(context),
    _Step.pin => _pinStep(context),
    _Step.biometric => _biometricStep(context),
    _Step.warning => _warningStep(context),
  };

  Widget _languageStep(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final k = context.tokens;
    final current = ref.watch(settingsProvider).value?.localeCode ?? kDefaultLocale.languageCode;
    const options = [('ar', 'العربية'), ('en', 'English'), ('ckb', 'کوردی')];
    return _StepBody(
      top: [
        Text(l10n.setupWelcome, style: text.headlineMedium?.copyWith(color: k.text)),
        const SizedBox(height: 8),
        Text(l10n.setupWelcomeBody, style: text.bodyLarge?.copyWith(color: k.textMuted)),
        const SizedBox(height: 32),
        Text(l10n.setupChooseLanguage, style: text.titleMedium?.copyWith(color: k.text)),
        const SizedBox(height: 12),
        for (final (code, label) in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ChoiceTile(
              key: ValueKey('lang-$code'),
              label: label,
              selected: current == code,
              onTap: () => ref.read(settingsRepositoryProvider).setLocale(code),
            ),
          ),
      ],
      bottom: FilledButton(key: const ValueKey('setup-next'), onPressed: _next, child: Text(l10n.continueLabel)),
    );
  }

  Widget _pinStep(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final k = context.tokens;
    return _StepBody(
      centered: true,
      top: [
        Text(
          _firstPin == null ? l10n.setupCreatePin : l10n.setupConfirmPin,
          textAlign: TextAlign.center,
          style: text.titleLarge?.copyWith(color: k.text),
        ),
        const SizedBox(height: 24),
        PinDots(key: _dots, filled: _entered.length, error: _pinMismatch),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: _pinMismatch
              ? Text(
                  l10n.pinMismatch,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: k.danger),
                )
              : null,
        ),
      ],
      bottom: PinPad(
        enabled: true,
        onDigit: _onDigit,
        onBackspace: _onBackspace,
        onBiometric: null,
        biometricLabel: '',
      ),
    );
  }

  Widget _biometricStep(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final k = context.tokens;
    return _StepBody(
      centered: true,
      top: [
        Icon(Icons.fingerprint_rounded, size: 64, color: k.accent),
        const SizedBox(height: 24),
        Text(
          l10n.setupEnableBiometrics,
          textAlign: TextAlign.center,
          style: text.titleLarge?.copyWith(color: k.text),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.setupEnableBiometricsBody,
          textAlign: TextAlign.center,
          style: text.bodyLarge?.copyWith(color: k.textMuted),
        ),
      ],
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(key: const ValueKey('bio-enable'), onPressed: _enableBiometric, child: Text(l10n.enable)),
          const SizedBox(height: 8),
          TextButton(key: const ValueKey('bio-skip'), onPressed: _next, child: Text(l10n.skip)),
        ],
      ),
    );
  }

  Widget _warningStep(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final k = context.tokens;
    return _StepBody(
      top: [
        Icon(Icons.save_alt_rounded, size: 40, color: k.warning),
        const SizedBox(height: 16),
        Text(l10n.setupBackupWarning, style: text.headlineSmall?.copyWith(color: k.text)),
        const SizedBox(height: 12),
        Text(l10n.backupWarning, style: text.bodyLarge?.copyWith(color: k.text, height: 1.6)),
        const SizedBox(height: 24),
        Material(
          color: k.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
            side: BorderSide(color: k.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: CheckboxListTile(
            key: const ValueKey('ack-checkbox'),
            value: _acknowledged,
            onChanged: _busy ? null : (v) => setState(() => _acknowledged = v ?? false),
            title: Text(l10n.iUnderstand),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
      ],
      bottom: FilledButton(
        key: const ValueKey('setup-finish'),
        onPressed: _acknowledged && !_busy ? _finish : null,
        child: _busy
            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(l10n.finish),
      ),
    );
  }
}

/// Scrollable step layout: content on top, the action pinned to the bottom when it fits.
class _StepBody extends StatelessWidget {
  const _StepBody({required this.top, required this.bottom, this.centered = false});

  final List<Widget> top;
  final Widget bottom;
  final bool centered;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: c.maxHeight - 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: top),
            const SizedBox(height: 24),
            bottom,
          ],
        ),
      ),
    ),
  );
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? k.accent.withValues(alpha: 0.14) : k.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          side: BorderSide(color: selected ? k.accent : k.border, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusSmall)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: k.text)),
                  ),
                  Icon(
                    selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                    color: selected ? k.accent : k.textMuted,
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

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: reduceMotion(context) ? Duration.zero : kDurationBase,
              curve: kEaseOut,
              height: 4,
              decoration: BoxDecoration(
                color: i <= current ? k.accent : k.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
