import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/security/sensitive.dart';
import '../../../core/theme/tokens.dart';
import '../../finance/data/finance_providers.dart' show workspacesProvider;
import '../../finance/ui/ui_format.dart' show formatDate;
import '../crypto/field_cipher.dart';
import '../data/vault_items_repository.dart';
import '../data/vault_providers.dart';
import '../vault_session.dart';
import 'fresh_auth.dart';
import 'vault_ui_common.dart';

/// How long a revealed secret stays visible.
const kRevealFor = Duration(seconds: 30);

/// One item. Plain fields show at once; secrets need a reveal behind fresh
/// auth and hide again after 30 s (spec §9.2). Locking rebuilds the route as
/// the unlock screen, which drops this state and every revealed value.
class VaultItemScreen extends ConsumerStatefulWidget {
  const VaultItemScreen({super.key, required this.itemId});

  final int itemId;

  @override
  ConsumerState<VaultItemScreen> createState() => _VaultItemScreenState();
}

class _VaultItemScreenState extends ConsumerState<VaultItemScreen> {
  final Map<VaultField, Sensitive<String>> _revealed = {};
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    _revealed.clear();
    super.dispose();
  }

  Future<VaultSecrets?> _secrets() async {
    if (!await ensureFreshAuth(context, ref)) return null;
    try {
      final key = ref.read(vaultSessionProvider.notifier).requireKey();
      return await ref.read(vaultItemsRepositoryProvider).secrets(key, widget.itemId);
    } catch (e) {
      AppLogger.error('vault secrets failed', e.runtimeType);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.somethingWentWrong)));
      }
      return null;
    }
  }

  static Sensitive<String>? _field(VaultSecrets s, VaultField f) => switch (f) {
    VaultField.password => s.password,
    VaultField.notes => s.notes,
    VaultField.recoveryCodes => s.recoveryCodes,
  };

  Future<void> _toggle(VaultField f) async {
    if (_revealed.containsKey(f)) {
      setState(() => _revealed.remove(f));
      return;
    }
    final s = await _secrets();
    final v = s == null ? null : _field(s, f);
    if (!mounted || v == null) return;
    setState(() => _revealed[f] = v);
    _hide?.cancel();
    _hide = Timer(kRevealFor, () {
      if (mounted) setState(_revealed.clear);
    });
  }

  Future<void> _copySecret(VaultField f) async {
    final s = await _secrets();
    final v = s == null ? null : _field(s, f);
    if (!mounted || v == null) return;
    await copyToClipboard(context, ref, v);
  }

  Future<void> _delete(VaultItem item) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.vltDeleteTitle),
        content: Text(l.vltDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text(l.cancel)),
          FilledButton(
            key: const ValueKey('vault-delete-confirm'),
            style: FilledButton.styleFrom(backgroundColor: c.tokens.danger, foregroundColor: c.tokens.onAccent),
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(l.vltDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(vaultItemsRepositoryProvider).delete(item.id);
    if (mounted) context.pop();
  }

  Future<void> _edit() async {
    if (!await ensureFreshAuth(context, ref) || !mounted) return;
    await context.push('/vault/item/${widget.itemId}/edit');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final async = ref.watch(vaultItemProvider(widget.itemId));
    final item = async.value;
    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: async.isLoading ? const CircularProgressIndicator() : Text(l.vltNoMatches)),
      );
    }
    final workspaces = ref.watch(workspacesProvider).value ?? const <Workspace>[];
    final workspace = workspaces.where((w) => w.id == item.workspaceId).firstOrNull;

    Widget plain(String id, String label, String value, {bool copy = true}) => _FieldRow(
      key: ValueKey('vault-field-$id'),
      label: label,
      value: value,
      ltr: true,
      actions: [
        if (copy)
          IconButton(
            key: ValueKey('vault-copy-$id'),
            tooltip: l.vltCopy,
            icon: const Icon(Icons.copy_rounded),
            onPressed: () => copyToClipboard(context, ref, Sensitive(value), secret: false),
          ),
      ],
    );

    Widget secret(VaultField f, String id, String label, {bool copy = false, bool multiline = false}) {
      final v = _revealed[f];
      return _FieldRow(
        key: ValueKey('vault-field-$id'),
        label: label,
        value: v?.value ?? '••••••••',
        ltr: !multiline,
        mono: !multiline && v != null,
        muted: v == null,
        actions: [
          IconButton(
            key: ValueKey('vault-reveal-$id'),
            tooltip: v == null ? l.vltReveal : l.vltHide,
            icon: Icon(v == null ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => _toggle(f),
          ),
          if (copy)
            IconButton(
              key: ValueKey('vault-copy-$id'),
              tooltip: l.vltCopy,
              icon: const Icon(Icons.copy_rounded),
              onPressed: () => _copySecret(f),
            ),
        ],
      );
    }

    final fields = <Widget>[
      if (item.url != null) plain('url', l.vltUrl, item.url!),
      if (item.username != null) plain('username', l.vltUsername, item.username!),
      if (item.email != null) plain('email', l.vltEmail, item.email!),
      if (item.passwordBlob != null) secret(VaultField.password, 'password', l.vltPassword, copy: true),
      if (item.notesBlob != null) secret(VaultField.notes, 'notes', l.vltNotes, multiline: true),
      if (item.recoveryCodesBlob != null)
        secret(VaultField.recoveryCodes, 'codes', l.vltRecoveryCodes, copy: true, multiline: true),
    ];

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            key: const ValueKey('vault-item-favorite'),
            tooltip: l.vltFavorite,
            icon: Icon(item.favorite ? Icons.star_rounded : Icons.star_outline_rounded),
            color: item.favorite ? k.warning : null,
            onPressed: () => ref.read(vaultItemsRepositoryProvider).setFavorite(item.id, !item.favorite),
          ),
          IconButton(
            key: const ValueKey('vault-item-edit'),
            tooltip: l.vltEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: _edit,
          ),
          IconButton(
            key: const ValueKey('vault-item-delete'),
            tooltip: l.vltDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _delete(item),
          ),
        ],
      ),
      body: VaultPage(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: k.surfaceHigh, borderRadius: BorderRadius.circular(12)),
                child: Icon(vaultCategoryIcon(item.category), color: k.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: text.headlineSmall?.copyWith(color: k.text)),
                    const SizedBox(height: 2),
                    Text(
                      [vaultCategoryLabel(l, item.category), ?workspace?.name].join(' · '),
                      style: text.bodyMedium?.copyWith(color: k.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (fields.isNotEmpty)
            Material(
              color: k.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                side: BorderSide(color: k.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < fields.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: k.border, indent: 16, endIndent: 16),
                    fields[i],
                  ],
                ],
              ),
            ),
          if (item.passwordChangedAt != null) ...[
            const SizedBox(height: 16),
            Text(
              l.vltPasswordChanged(formatDate(context, item.passwordChangedAt!.toLocal())),
              style: text.bodySmall?.copyWith(color: k.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    super.key,
    required this.label,
    required this.value,
    required this.actions,
    this.ltr = false,
    this.mono = false,
    this.muted = false,
  });

  final String label;
  final String value;
  final List<Widget> actions;
  final bool ltr;
  final bool mono;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.labelMedium?.copyWith(color: k.textMuted)),
                const SizedBox(height: 4),
                SelectionContainer.disabled(
                  child: Text(
                    value,
                    textDirection: ltr ? TextDirection.ltr : null,
                    textAlign: TextAlign.start,
                    style: text.bodyLarge?.copyWith(
                      color: muted ? k.textMuted : k.text,
                      fontFamily: mono ? 'monospace' : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
