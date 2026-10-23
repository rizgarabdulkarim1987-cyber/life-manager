import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/restart_scope.dart';
import '../../core/l10n/ckb_fallback_localizations.dart';
import '../../core/logging/app_logger.dart';
import '../../core/security/sensitive.dart';
import '../../core/theme/tokens.dart';
import 'backup_format.dart';
import 'backup_payload.dart';
import 'backup_service.dart';

/// Where backups are saved to and picked from: the Android system file picker,
/// so the owner chooses any location (Downloads, USB, a messenger...).
abstract interface class BackupFiles {
  Future<bool> save(String fileName, Uint8List bytes);
  Future<Uint8List?> pick();
}

class FilePickerBackupFiles implements BackupFiles {
  const FilePickerBackupFiles();

  @override
  Future<bool> save(String fileName, Uint8List bytes) async =>
      await FilePicker.saveFile(fileName: fileName, bytes: bytes) != null;

  @override
  Future<Uint8List?> pick() async {
    final files = await FilePicker.pickFiles();
    return files.isEmpty ? null : files.first.readAsBytes();
  }
}

/// Overridden in main() with the service bound to the open database.
final backupServiceProvider = Provider<BackupService>(
  (ref) => throw UnimplementedError('override backupServiceProvider'),
);

final backupFilesProvider = Provider<BackupFiles>((ref) => const FilePickerBackupFiles());

enum PasswordStrength { weak, fair, strong }

PasswordStrength passwordStrength(String pw) {
  final classes = [
    RegExp('[a-z]'),
    RegExp('[A-Z]'),
    RegExp(r'\d'),
    RegExp(r'[^a-zA-Z\d]'),
  ].where((r) => r.hasMatch(pw)).length;
  if (pw.length < 10 || classes < 2) return PasswordStrength.weak;
  if (pw.length >= 14 && classes >= 3) return PasswordStrength.strong;
  return PasswordStrength.fair;
}

const kMinBackupPasswordLength = 8;

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _pw = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _pw.addListener(() => setState(() {}));
    _confirm.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pw.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _passwordError() {
    final l10n = context.l10n;
    if (_pw.text.length < kMinBackupPasswordLength) return l10n.passwordTooShort;
    if (_pw.text != _confirm.text) return l10n.passwordsDontMatch;
    return null;
  }

  String _formatDate(DateTime t) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMMMd(DateFormat.localeExists(locale) ? locale : 'ar').add_jm().format(t.toLocal());
  }

  void _snack(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _create() async {
    setState(() => _submitted = true);
    if (_passwordError() != null) return;
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final service = ref.read(backupServiceProvider);
      final bytes = await service.createBackup(Sensitive(_pw.text));
      final saved = await ref.read(backupFilesProvider).save(backupFileName(DateTime.now()), bytes);
      // A cancelled save is not a backup: only a file that was written counts.
      if (saved) await service.recordExport(bytes);
      if (!mounted) return;
      if (saved) {
        _pw.clear();
        _confirm.clear();
        _submitted = false;
        _snack(l10n.backupCreated);
      }
    } catch (e) {
      AppLogger.error('backup failed', e.runtimeType);
      if (mounted) _snack(l10n.backupFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final l10n = context.l10n;
    final service = ref.read(backupServiceProvider);
    final file = await ref.read(backupFilesProvider).pick();
    if (file == null || !mounted) return;

    final BackupHeader header;
    try {
      header = service.inspect(file);
    } on Exception catch (e) {
      _snack(_errorText(e));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.restoreConfirmTitle),
        content: Text(l10n.restoreConfirmBody(_formatDate(header.createdAtUtc), header.appVersion)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(
            key: const ValueKey('restore-confirm'),
            style: FilledButton.styleFrom(backgroundColor: context.tokens.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.replace),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final password = await showDialog<String>(context: context, builder: (_) => const _PasswordDialog());
    if (password == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await service.restore(file, Sensitive(password));
      if (!mounted) return;
      _snack(l10n.restoreSuccess);
      await RestartScope.maybeRestart(context);
    } catch (e) {
      if (mounted) _snack(e is Exception ? _errorText(e) : l10n.somethingWentWrong);
      // The swap closed the database before failing; the old data is back on
      // disk, but this instance can no longer use it, so reopen everything.
      if (service.databaseClosed && mounted) await RestartScope.maybeRestart(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _errorText(Exception e) {
    final l10n = context.l10n;
    return switch (e) {
      BackupWrongPasswordException() => l10n.restoreWrongPassword,
      BackupTooNewException() => l10n.restoreTooNew,
      BackupFormatException() || BackupCorruptException() => l10n.restoreCorrupt,
      _ => l10n.restoreCorrupt,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final last = ref.watch(settingsProvider).value?.lastBackupAt;
    final error = _submitted ? _passwordError() : null;
    final strength = passwordStrength(_pw.text);
    final strengthColor = switch (strength) {
      PasswordStrength.weak => k.danger,
      PasswordStrength.fair => k.warning,
      PasswordStrength.strong => k.success,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupRestore)),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _Panel(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: k.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(l10n.backupWarning, style: text.bodyMedium?.copyWith(color: k.text, height: 1.6)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 0),
              child: Text(
                last == null ? l10n.neverBackedUp : l10n.lastBackup(_formatDate(last)),
                style: text.bodySmall?.copyWith(color: last == null ? k.warning : k.textMuted),
              ),
            ),
            const SizedBox(height: 24),
            Text(l10n.createBackup, style: text.titleMedium?.copyWith(color: k.text)),
            const SizedBox(height: 4),
            Text(l10n.backupPasswordHint, style: text.bodySmall?.copyWith(color: k.textMuted)),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('backup-pw'),
              controller: _pw,
              obscureText: _obscure,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.backupPassword,
                suffixIcon: IconButton(
                  tooltip: l10n.backupPassword,
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            if (_pw.text.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 12, top: 6),
                child: Text(switch (strength) {
                  PasswordStrength.weak => l10n.passwordStrengthWeak,
                  PasswordStrength.fair => l10n.passwordStrengthFair,
                  PasswordStrength.strong => l10n.passwordStrengthStrong,
                }, style: text.bodySmall?.copyWith(color: strengthColor)),
              ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('backup-pw-confirm'),
              controller: _confirm,
              obscureText: _obscure,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(labelText: l10n.confirmPassword, errorText: error),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('create-backup'),
              onPressed: _busy ? null : _create,
              icon: _busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_alt_rounded),
              label: Text(l10n.createBackup),
            ),
            const SizedBox(height: 32),
            Divider(color: k.border),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const ValueKey('restore-backup'),
              onPressed: _busy ? null : _restore,
              icon: const Icon(Icons.restore_rounded),
              label: Text(l10n.restoreBackup),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.backupPassword),
      content: TextField(
        key: const ValueKey('restore-pw'),
        controller: _c,
        autofocus: true,
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          key: const ValueKey('restore-pw-ok'),
          onPressed: () => Navigator.pop(context, _c.text),
          child: Text(l10n.continueLabel),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: k.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(color: k.border),
      ),
      child: child,
    );
  }
}
