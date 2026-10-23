import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/db/seed.dart';
import '../../core/l10n/ckb_fallback_localizations.dart';
import '../../core/logging/app_logger.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../finance/data/accounts_repository.dart';
import '../lock/lock_controller.dart';

enum _Step { language, warning, account }

/// First run: language, backup warning, then the first account (redesign §11.1). Unlocking uses the phone's
/// own face, fingerprint or screen lock, so there is no PIN to choose.
/// Steps advance only through their own buttons, so validation can't be swiped past.
class SetupFlow extends ConsumerStatefulWidget {
  const SetupFlow({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<SetupFlow> createState() => _SetupFlowState();
}

class _SetupFlowState extends ConsumerState<SetupFlow> {
  _Step _step = _Step.language;
  bool _acknowledged = false;
  bool _busy = false;
  final _accountName = TextEditingController();
  String _currency = 'IQD';

  @override
  void initState() {
    super.initState();
    _accountName.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _accountName.dispose();
    super.dispose();
  }

  List<_Step> get _steps => _Step.values;

  void _next() {
    final i = _steps.indexOf(_step);
    setState(() => _step = _steps[i + 1]);
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    final l10n = context.l10n;
    final db = ref.read(appDatabaseProvider);
    final settings = ref.read(settingsRepositoryProvider);

    try {
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
      final personal = (await (db.select(db.workspaces)..where((w) => w.sortOrder.equals(0))).getSingle()).id;
      // Setup may run again after a crash; the account is only added once.
      if ((await (db.select(db.accounts)..limit(1)).get()).isEmpty) {
        await AccountsRepository(db)
            .create(workspaceId: personal, name: _accountName.text.trim(), kind: 'cash', currencyCode: _currency);
      }
      // Unlock before setup counts as done, so the lock screen never flashes
      // over the first home screen.
      ref.read(lockControllerProvider.notifier).unlock();
      // Last, so an interrupted setup simply runs again on the next launch.
      await settings.markSetupCompleted();
    } catch (e) {
      // Every step above is safe to repeat, so the owner can just press again.
      AppLogger.error('setup failed', e.runtimeType);
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.somethingWentWrong)));
      }
      return;
    }
    if (!mounted) return;
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
                child: KeyedSubtree(key: ValueKey('step-${_step.name}'), child: _buildStep(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) => switch (_step) {
    _Step.language => _languageStep(context),
    _Step.warning => _warningStep(context),
    _Step.account => _accountStep(context),
  };

  Widget _accountStep(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final k = context.tokens;
    final ready = _accountName.text.trim().isNotEmpty && !_busy;
    return _StepBody(
      top: [
        Icon(Icons.account_balance_wallet_outlined, size: 40, color: k.accent),
        const SizedBox(height: 16),
        Text(l10n.setupAccountTitle, style: text.headlineSmall?.copyWith(color: k.text)),
        const SizedBox(height: 12),
        Text(l10n.setupAccountBody, style: text.bodyLarge?.copyWith(color: k.textMuted, height: 1.5)),
        const SizedBox(height: 24),
        TextField(
          key: const ValueKey('setup-account-name'),
          controller: _accountName,
          maxLength: 80,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.setupAccountName,
            hintText: l10n.setupAccountHint,
            counterText: '',
          ),
        ),
        const SizedBox(height: 20),
        Text(l10n.setupAccountCurrency, style: text.labelLarge?.copyWith(color: k.textMuted)),
        const SizedBox(height: 8),
        Wrap(
          key: const ValueKey('setup-account-currency'),
          spacing: 8,
          children: [
            for (final c in const ['IQD', 'USD'])
              ChoiceChip(
                key: ValueKey('setup-currency-$c'),
                label: Text(c),
                selected: _currency == c,
                onSelected: (_) => setState(() => _currency = c),
              ),
          ],
        ),
      ],
      bottom: FilledButton(
        key: const ValueKey('setup-account-save'),
        onPressed: ready ? _finish : null,
        child: _busy
            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(l10n.finish),
      ),
    );
  }

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
        onPressed: _acknowledged ? _next : null,
        child: Text(l10n.continueLabel),
      ),
    );
  }
}

/// Scrollable step layout: content on top, the action pinned to the bottom when it fits.
class _StepBody extends StatelessWidget {
  const _StepBody({required this.top, required this.bottom});

  final List<Widget> top;
  final Widget bottom;

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
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: top),
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
