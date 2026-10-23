import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/theme/tokens.dart';
import '../data/vault_items_repository.dart';
import '../data/vault_providers.dart';
import '../domain/notes_parser.dart';
import '../vault_session.dart';
import 'vault_ui_common.dart';

/// Paste notes, review what the local parser found, keep what's right
/// (plan Decision 16). Nothing is saved without the owner pressing Save.
class VaultImportScreen extends ConsumerStatefulWidget {
  const VaultImportScreen({super.key});

  @override
  ConsumerState<VaultImportScreen> createState() => _VaultImportScreenState();
}

class _Card {
  _Card(this.proposal) : title = TextEditingController(text: proposal.title);

  final NoteProposal proposal;
  final TextEditingController title;
  bool keep = true;
}

class _VaultImportScreenState extends ConsumerState<VaultImportScreen> {
  final _paste = TextEditingController();
  List<_Card>? _cards;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _paste.clear();
    _paste.dispose();
    _disposeCards();
    super.dispose();
  }

  void _disposeCards() {
    for (final c in _cards ?? const <_Card>[]) {
      c.title.dispose();
    }
  }

  void _find() {
    final List<NoteProposal> found;
    try {
      found = parseNotes(_paste.text);
    } on ArgumentError {
      setState(() => _error = context.l10n.vltImportTooLong);
      return;
    }
    _disposeCards();
    setState(() {
      _error = found.isEmpty ? context.l10n.vltFoundNone : null;
      _cards = found.isEmpty ? null : [for (final p in found) _Card(p)];
    });
  }

  Future<void> _save() async {
    final kept = (_cards ?? const <_Card>[]).where((c) => c.keep && c.title.text.trim().isNotEmpty).toList();
    if (kept.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final key = ref.read(vaultSessionProvider.notifier).requireKey();
      final repo = ref.read(vaultItemsRepositoryProvider);
      for (final c in kept) {
        final p = c.proposal;
        await repo.create(
          key,
          VaultItemInput(
            title: c.title.text.trim().characters.take(120).toString(),
            url: p.url,
            username: p.username,
            email: p.email,
            category: p.category,
            password: p.password,
            notes: p.notes,
            recoveryCodes: p.recoveryCodes,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('vault import failed', e.runtimeType);
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.somethingWentWrong)));
      }
      return;
    }
    _paste.clear();
    _disposeCards();
    _cards = null;
    if (!mounted) return;
    final l = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        key: const ValueKey('vault-import-reminder'),
        title: Text(l.vltImportDoneTitle),
        content: Text(l.vltImportDoneBody),
        actions: [FilledButton(onPressed: () => Navigator.of(c).pop(), child: Text(l.ok))],
      ),
    );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final cards = _cards;
    final keepCount = cards?.where((c) => c.keep).length ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.vltImport),
        actions: [
          if (cards != null)
            TextButton(
              key: const ValueKey('vault-import-save'),
              onPressed: keepCount == 0 || _saving ? null : _save,
              child: Text(l.vltSaveN(keepCount)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: VaultPage(
        children: [
          if (cards == null) ...[
            Text(l.vltImportBody, style: text.bodyLarge?.copyWith(color: k.textMuted, height: 1.5)),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('vault-import-paste'),
              controller: _paste,
              minLines: 8,
              maxLines: 16,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(hintText: l.vltImportHint, errorText: _error, errorMaxLines: 3),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('vault-import-find'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              icon: const Icon(Icons.manage_search_rounded),
              label: Text(l.vltFindItems),
              onPressed: _paste.text.trim().isEmpty ? null : _find,
            ),
          ] else
            for (var i = 0; i < cards.length; i++)
              _ProposalCard(key: ValueKey('vault-proposal-$i'), card: cards[i], onChanged: () => setState(() {})),
        ],
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({super.key, required this.card, required this.onChanged});

  final _Card card;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final p = card.proposal;
    final lines = [
      if (p.url != null) (l.vltUrl, p.url!),
      if (p.username != null) (l.vltUsername, p.username!),
      if (p.email != null) (l.vltEmail, p.email!),
      if (p.password != null) (l.vltPassword, '••••••••'),
      if (p.notes != null) (l.vltNotes, '••••'),
      if (p.recoveryCodes != null) (l.vltRecoveryCodes, '••••'),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: card.keep ? 1 : 0.55,
        child: Material(
          color: k.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusCard),
            side: BorderSide(color: card.keep ? k.border : k.border.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: card.title,
                        enabled: card.keep,
                        maxLength: 120,
                        decoration: InputDecoration(labelText: l.vltTitle, counterText: ''),
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          key: const ValueKey('vault-proposal-keep'),
                          value: card.keep,
                          onChanged: (v) {
                            card.keep = v;
                            onChanged();
                          },
                        ),
                        Text(l.vltKeep, style: text.labelSmall?.copyWith(color: k.textMuted)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(vaultCategoryLabel(l, p.category), style: text.labelMedium?.copyWith(color: k.accent)),
                for (final (label, value) in lines)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        Text(label, style: text.bodySmall?.copyWith(color: k.textMuted)),
                        Text(
                          value,
                          textDirection: TextDirection.ltr,
                          style: text.bodyMedium?.copyWith(color: k.text),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
