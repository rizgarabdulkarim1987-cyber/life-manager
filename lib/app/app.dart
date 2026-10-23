import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/ckb_fallback_localizations.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../core/logging/app_logger.dart';
import '../features/capture/capture_pipeline.dart';
import '../features/lock/lock_controller.dart';
import '../features/lock/lock_screen.dart';
import '../features/settings/settings_repository.dart';
import '../features/tasks/data/task_reminder_sync.dart';
import '../features/tasks/data/tasks_providers.dart';
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
    // Relock after the configured time in the background (spec §15). The vault
    // locks as soon as the app is hidden (spec §9.2).
    _lifecycle = AppLifecycleListener(
      onHide: () {
        ref.read(lockControllerProvider.notifier).onPaused(DateTime.now());
        ref.read(vaultSessionProvider.notifier).lock();
      },
      onShow: () {
        unawaited(_intake());
        final seconds = ref.read(settingsProvider).value?.lockTimeoutSeconds ?? 300;
        ref.read(lockControllerProvider.notifier).onResumed(DateTime.now(), timeout: Duration(seconds: seconds));
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(taskReminderSyncProvider).syncAll());
      unawaited(_intake());
    });
  }

  /// Start-up and every return to the app: put the alarms right, apply Done taps
  /// made on notifications, then follow a tapped reminder or a shared text.
  Future<void> _intake() async {
    try {
      final settings = await ref.read(settingsProvider.future);
      if (!settings.setupCompleted || !mounted) return;
      final intake = await takeIntake(ref.read(reminderSchedulerProvider), ref.read(tasksRepositoryProvider));
      if (!mounted) return;
      final router = ref.read(routerProvider);
      final shared = intake.sharedText;
      if (shared != null) {
        final outcome = await ref.read(capturePipelineProvider).fromSharedText(shared);
        if (!mounted) return;
        router.push(switch (outcome) {
          ReadyForReview(:final captureId) => '/capture/$captureId',
          _ => '/inbox',
        });
      } else if (intake.openTaskId != null) {
        router.push('/tasks/${intake.openTaskId}');
      }
    } catch (e) {
      AppLogger.warn('app intake failed', e);
    }
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
    if (settings == null) return ColoredBox(color: AppTokens.dark.bg);

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
