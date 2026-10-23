import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/db/app_database.dart';
import '../../core/l10n/ckb_fallback_localizations.dart';
import '../../core/theme/tokens.dart';
import '../lock/lock_controller.dart';
import 'change_pin_screen.dart';
import 'settings_repository.dart';
import 'settings_section.dart';

final biometricAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(biometricAuthenticatorProvider).isAvailable(),
);

const kLockTimeoutChoices = [0, 60, 300, 900, 1800];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider).value;
    return Scaffold(
      key: const ValueKey('settings-screen'),
      appBar: AppBar(title: Text(l10n.settings)),
      body: settings == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                SettingsSection(
                  title: l10n.language,
                  children: [_LanguagePicker(current: settings.localeCode)],
                ),
                SettingsSection(
                  title: l10n.theme,
                  children: [_ThemePicker(current: settings.themeMode)],
                ),
                SettingsSection(
                  title: l10n.appLock,
                  children: [_LockSettings(settings: settings)],
                ),
                SettingsSection(
                  title: l10n.setFinance,
                  children: [
                    _Link(
                      'settings-finance',
                      Icons.currency_exchange_rounded,
                      l10n.setFinanceSettings,
                      l10n.setFinanceSettingsHint,
                      '/settings/finance',
                    ),
                    _Link(
                      'settings-categories',
                      Icons.sell_outlined,
                      l10n.setCategories,
                      l10n.setCategoriesHint,
                      '/settings/categories',
                    ),
                    _Link(
                      'settings-workspaces',
                      Icons.workspaces_outline,
                      l10n.setWorkspaces,
                      l10n.setWorkspacesHint,
                      '/settings/workspaces',
                    ),
                  ],
                ),
                SettingsSection(
                  title: l10n.setAi,
                  children: [
                    _Link('settings-ai', Icons.auto_awesome_outlined, l10n.setAi, l10n.setAiHint, '/settings/ai'),
                  ],
                ),
                SettingsSection(
                  title: l10n.navVault,
                  children: [
                    _Link(
                      'settings-vault',
                      Icons.shield_outlined,
                      l10n.vltSettings,
                      l10n.vltSettingsHint,
                      '/vault/settings',
                    ),
                  ],
                ),
                SettingsSection(
                  title: l10n.backupRestore,
                  children: [_BackupLink(lastBackupAt: settings.lastBackupAt)],
                ),
                SettingsSection(
                  title: l10n.privacy,
                  children: [
                    ListTile(leading: const Icon(Icons.verified_user_outlined), title: Text(l10n.privacyPhase1)),
                  ],
                ),
              ],
            ),
    );
  }
}

class _LanguagePicker extends ConsumerWidget {
  const _LanguagePicker({required this.current});

  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const options = [('ar', 'العربية'), ('en', 'English'), ('ckb', 'کوردی')];
    return RadioGroup<String>(
      groupValue: current,
      onChanged: (v) {
        if (v != null) ref.read(settingsRepositoryProvider).setLocale(v);
      },
      child: Column(
        children: [
          for (final (code, label) in options)
            RadioListTile<String>(key: ValueKey('locale-$code'), value: code, title: Text(label)),
        ],
      ),
    );
  }
}

class _ThemePicker extends ConsumerWidget {
  const _ThemePicker({required this.current});

  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return RadioGroup<String>(
      groupValue: themeModeOf(current) == ThemeMode.light ? 'light' : 'dark',
      onChanged: (v) {
        if (v != null) {
          ref.read(settingsRepositoryProvider).setThemeMode(v == 'light' ? ThemeMode.light : ThemeMode.dark);
        }
      },
      child: Column(
        children: [
          RadioListTile<String>(
            key: const ValueKey('theme-dark'),
            value: 'dark',
            title: Text(l10n.themeDark),
            secondary: const Icon(Icons.dark_mode_outlined),
          ),
          RadioListTile<String>(
            key: const ValueKey('theme-light'),
            value: 'light',
            title: Text(l10n.themeLight),
            secondary: const Icon(Icons.light_mode_outlined),
          ),
        ],
      ),
    );
  }
}

String lockTimeoutLabel(BuildContext context, int seconds) =>
    seconds == 0 ? context.l10n.lockImmediately : context.l10n.lockAfterMinutes(seconds ~/ 60);

class _LockSettings extends ConsumerWidget {
  const _LockSettings({required this.settings});

  final AppSetting settings;

  Future<void> _toggleBiometric(BuildContext context, WidgetRef ref, bool enable) async {
    if (enable) {
      final ok = await ref.read(biometricAuthenticatorProvider).authenticate(context.l10n.unlockReason);
      if (!ok) return;
    }
    await ref.read(settingsRepositoryProvider).setBiometricEnabled(enable);
  }

  Future<void> _changePin(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = context.l10n.pinChanged;
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const ChangePinScreen()));
    if (changed == true) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _pickTimeout(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(settingsRepositoryProvider);
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.lockTimeout),
        children: [
          RadioGroup<int>(
            groupValue: settings.lockTimeoutSeconds,
            onChanged: (v) => Navigator.of(context).pop(v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final s in kLockTimeoutChoices)
                  RadioListTile<int>(key: ValueKey('timeout-$s'), value: s, title: Text(lockTimeoutLabel(context, s))),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked != null) await repo.setLockTimeout(Duration(seconds: picked));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final available = ref.watch(biometricAvailableProvider).value ?? false;
    return Column(
      children: [
        SwitchListTile(
          key: const ValueKey('bio-switch'),
          secondary: const Icon(Icons.fingerprint_rounded),
          title: Text(l10n.biometrics),
          subtitle: available ? null : Text(l10n.biometricsUnavailable),
          value: available && settings.biometricEnabled,
          onChanged: available ? (v) => _toggleBiometric(context, ref, v) : null,
        ),
        ListTile(
          key: const ValueKey('change-pin'),
          leading: const Icon(Icons.pin_outlined),
          title: Text(l10n.changePin),
          onTap: () => _changePin(context),
        ),
        ListTile(
          key: const ValueKey('lock-timeout'),
          leading: const Icon(Icons.timer_outlined),
          title: Text(l10n.lockTimeout),
          subtitle: Text(lockTimeoutLabel(context, settings.lockTimeoutSeconds)),
          onTap: () => _pickTimeout(context, ref),
        ),
      ],
    );
  }
}

class _BackupLink extends StatelessWidget {
  const _BackupLink({required this.lastBackupAt});

  final DateTime? lastBackupAt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final k = context.tokens;
    final at = lastBackupAt;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final subtitle = at == null
        ? Text(l10n.neverBackedUp, style: TextStyle(color: k.warning))
        : Text(
            l10n.lastBackup(
              DateFormat.yMMMd(DateFormat.localeExists(locale) ? locale : 'ar').add_jm().format(at.toLocal()),
            ),
          );
    return ListTile(
      key: const ValueKey('backup-link'),
      leading: const Icon(Icons.save_alt_rounded),
      title: Text(l10n.backupRestore),
      subtitle: subtitle,
      onTap: () => context.push('/settings/backup'),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link(this.id, this.icon, this.title, this.subtitle, this.location);

  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final String location;

  @override
  Widget build(BuildContext context) => ListTile(
    key: ValueKey(id),
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => context.push(location),
  );
}
