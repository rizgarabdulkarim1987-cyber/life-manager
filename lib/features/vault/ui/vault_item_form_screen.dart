import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/security/sensitive.dart';
import '../../../core/theme/tokens.dart';
import '../../finance/data/finance_providers.dart' show workspacesProvider;
import '../data/vault_items_repository.dart';
import '../data/vault_providers.dart';
import '../domain/password_strength.dart';
import '../vault_session.dart';
import 'generator_sheet.dart';
import 'secret_field.dart';
import 'vault_ui_common.dart';

/// Add or edit an item. Opened for editing only after fresh auth (the
/// detail screen asks), since it loads the decrypted secrets into the fields.
class VaultItemFormScreen extends ConsumerStatefulWidget {
  const VaultItemFormScreen({super.key, this.editId});

  final int? editId;

  @override
  ConsumerState<VaultItemFormScreen> createState() => _VaultItemFormScreenState();
}

class _VaultItemFormScreenState extends ConsumerState<VaultItemFormScreen> {
  final _title = TextEditingController();
  final _url = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _notes = TextEditingController();
  final _codes = TextEditingController();
  String _category = 'other';
  int? _workspaceId;
  bool _favorite = false;
  bool _loading = false;
  bool _saving = false;
  int _initial = 0;

  List<TextEditingController> get _controllers => [_title, _url, _username, _email, _password, _notes, _codes];

  // A hash, not a copy, so the form keeps no second plaintext of the secrets.
  int _snapshot() => Object.hashAll([..._controllers.map((c) => c.text), _category, _workspaceId, _favorite]);

  bool get _dirty => _snapshot() != _initial;

  @override
  void initState() {
    super.initState();
    _initial = _snapshot();
    if (widget.editId != null) {
      _loading = true;
      _load(widget.editId!);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.clear();
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load(int id) async {
    final repo = ref.read(vaultItemsRepositoryProvider);
    try {
      final item = await repo.get(id);
      if (item == null) {
        if (mounted) context.pop();
        return;
      }
      final secrets = await repo.secrets(ref.read(vaultSessionProvider.notifier).requireKey(), id);
      if (!mounted) return;
      setState(() {
        _title.text = item.title;
        _url.text = item.url ?? '';
        _username.text = item.username ?? '';
        _email.text = item.email ?? '';
        _password.text = secrets.password?.value ?? '';
        _notes.text = secrets.notes?.value ?? '';
        _codes.text = secrets.recoveryCodes?.value ?? '';
        _category = item.category;
        _workspaceId = item.workspaceId;
        _favorite = item.favorite;
        _initial = _snapshot();
        _loading = false;
      });
    } catch (e) {
      AppLogger.error('vault item load failed', e.runtimeType);
      if (mounted) context.pop();
    }
  }

  Future<void> _save() async {
    if (_saving || _title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final input = VaultItemInput(
      title: _title.text,
      url: _url.text,
      username: _username.text,
      email: _email.text,
      category: _category,
      workspaceId: _workspaceId,
      favorite: _favorite,
      password: Sensitive(_password.text),
      notes: Sensitive(_notes.text),
      recoveryCodes: Sensitive(_codes.text),
    );
    try {
      final key = ref.read(vaultSessionProvider.notifier).requireKey();
      final repo = ref.read(vaultItemsRepositoryProvider);
      if (widget.editId == null) {
        await repo.create(key, input);
      } else {
        await repo.update(key, widget.editId!, input);
      }
      _initial = _snapshot();
      if (mounted) context.pop();
    } catch (e) {
      AppLogger.error('vault item save failed', e.runtimeType);
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.somethingWentWrong)));
      }
    }
  }

  Future<void> _confirmLeave() async {
    final l = context.l10n;
    final leave = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.vltDiscardTitle),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text(l.vltKeepEditing)),
          FilledButton(
            key: const ValueKey('vault-discard-confirm'),
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(l.vltDiscard),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      _initial = _snapshot();
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final workspaces = (ref.watch(workspacesProvider).value ?? const <Workspace>[])
        .where((w) => !w.isArchived || w.id == _workspaceId)
        .toList();
    final strength = masterPasswordStrength(_password.text);
    InputDecoration deco(String label) => InputDecoration(labelText: label);
    Widget gap([double h = 16]) => SizedBox(height: h);
    void changed(_) => setState(() {});

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.editId == null ? l.vltNewItem : l.vltEditItem),
          actions: [
            TextButton(
              key: const ValueKey('vault-form-save'),
              onPressed: _loading || _saving || _title.text.trim().isEmpty ? null : _save,
              child: Text(l.save),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : VaultPage(
                children: [
                  TextField(
                    key: const ValueKey('vault-form-title'),
                    controller: _title,
                    maxLength: 120,
                    autofocus: widget.editId == null,
                    textInputAction: TextInputAction.next,
                    decoration: deco(l.vltTitle),
                    onChanged: changed,
                  ),
                  gap(8),
                  TextField(
                    key: const ValueKey('vault-form-url'),
                    controller: _url,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    textDirection: TextDirection.ltr,
                    textInputAction: TextInputAction.next,
                    decoration: deco(l.vltUrl),
                    onChanged: changed,
                  ),
                  gap(),
                  TextField(
                    key: const ValueKey('vault-form-username'),
                    controller: _username,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    decoration: deco(l.vltUsername),
                    onChanged: changed,
                  ),
                  gap(),
                  TextField(
                    key: const ValueKey('vault-form-email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textDirection: TextDirection.ltr,
                    textInputAction: TextInputAction.next,
                    decoration: deco(l.vltEmail),
                    onChanged: changed,
                  ),
                  gap(),
                  SecretField(
                    key: const ValueKey('vault-form-password'),
                    controller: _password,
                    label: l.vltPassword,
                    onChanged: changed,
                    extraAction: IconButton(
                      key: const ValueKey('vault-form-generate'),
                      tooltip: l.vltGenerate,
                      icon: const Icon(Icons.auto_fix_high_rounded),
                      onPressed: () =>
                          showGeneratorSheet(context, onUse: (pw) => setState(() => _password.text = pw.value)),
                    ),
                  ),
                  if (_password.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 12, top: 6),
                      child: Text(
                        strengthLabel(l, strength),
                        style: text.labelMedium?.copyWith(color: strengthColor(k, strength)),
                      ),
                    ),
                  gap(20),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('vault-form-category'),
                    initialValue: _category,
                    isExpanded: true,
                    decoration: deco(l.vltCategory),
                    items: [
                      for (final c in kVaultCategories)
                        DropdownMenuItem(
                          value: c,
                          child: Text(vaultCategoryLabel(l, c), overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _category = v ?? _category),
                  ),
                  gap(),
                  DropdownButtonFormField<int?>(
                    key: const ValueKey('vault-form-workspace'),
                    initialValue: _workspaceId,
                    isExpanded: true,
                    decoration: deco(l.vltWorkspace),
                    items: [
                      DropdownMenuItem<int?>(child: Text(l.vltNoWorkspace)),
                      for (final w in workspaces)
                        DropdownMenuItem<int?>(
                          value: w.id,
                          child: Text(w.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _workspaceId = v),
                  ),
                  gap(8),
                  SwitchListTile(
                    key: const ValueKey('vault-form-favorite'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.vltFavorite),
                    value: _favorite,
                    onChanged: (v) => setState(() => _favorite = v),
                  ),
                  gap(8),
                  SecretMultilineField(
                    key: const ValueKey('vault-form-notes'),
                    controller: _notes,
                    label: l.vltNotes,
                    onChanged: changed,
                  ),
                  gap(),
                  SecretMultilineField(
                    key: const ValueKey('vault-form-codes'),
                    controller: _codes,
                    label: l.vltRecoveryCodes,
                    onChanged: changed,
                  ),
                ],
              ),
      ),
    );
  }
}
