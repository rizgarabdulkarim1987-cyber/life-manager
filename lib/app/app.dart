import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/ckb_fallback_localizations.dart';
import '../core/security/money_privacy.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../features/lock/lock_controller.dart';
import '../features/lock/lock_screen.dart';
import '../features/settings/settings_repository.dart';
import '../features/tasks/reminders/reminder_service.dart';
import '../features/vault/vault_session.dart';
import 'providers.dart';
import 'router.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Notifications start after the unlock: on Android 13+ the permission dialog would take focus from the
    // fingerprint prompt and cancel it.
    if (ref.read(lockControllerProvider) == LockStatus.unlocked) unawaited(ref.read(reminderServiceProvider).start());
    ref.listenManual(lockControllerProvider, (_, next) {
      if (next == LockStatus.unlocked) unawaited(ref.read(reminderServiceProvider).start());
    });
    // Relock after the configured time in the background (spec §15). The vault
    // locks as soon as the app is hidden (spec §9.2).
    _lifecycle = AppLifecycleListener(
      onHide: () {
        ref.read(moneyRevealedProvider.notifier).hide();
        ref.read(lockControllerProvider.notifier).onPaused(DateTime.now());
        ref.read(vaultSessionProvider.notifier).lock();
      },
      onShow: () {
        final seconds = ref.read(settingsProvider).value?.lockTimeoutSeconds ?? 300;
        ref.read(lockControllerProvider.notifier).onResumed(DateTime.now(), timeout: Duration(seconds: seconds));
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Whenever the app lock closes, the vault closes with it.
    ref.listen(lockControllerProvider, (_, next) {
      if (next == LockStatus.locked) ref.read(vaultSessionProvider.notifier).lock();
    });
    final settings = ref.watch(settingsProvider).value;
    if (settings == null) return ColoredBox(color: AppTokens.light.bg);

    final locked = settings.setupCompleted && ref.watch(lockControllerProvider) == LockStatus.locked;
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: themeModeOf(settings.themeMode),
      locale: Locale(settings.localeCode),
      supportedLocales: kSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
      routerConfig: ref.watch(routerProvider),
      // The lock covers the app without tearing down navigation state.
      builder: (context, child) => Stack(
        children: [
          Offstage(
            offstage: locked,
            child: TickerMode(enabled: !locked, child: child!),
          ),
          if (locked) const LockScreen(),
        ],
      ),
    );
  }
}
