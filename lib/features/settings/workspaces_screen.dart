import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/l10n/ckb_fallback_localizations.dart';
import '../../core/theme/tokens.dart';
import '../finance/data/finance_providers.dart';
import '../finance/data/workspaces_repository.dart';
import 'settings_section.dart';
import 'word_chips.dart';

/// The fixed icon set a workspace can use, by stored key.
const kWorkspaceIcons = <String, IconData>{
  'person': Icons.person_rounded,
  'campaign': Icons.campaign_rounded,
  'handshake': Icons.handshake_rounded,
  'folder': Icons.folder_rounded,
  'work': Icons.work_rounded,
  'store': Icons.storefront_rounded,
  'home': Icons.home_rounded,
  'school': Icons.school_rounded,
  'family': Icons.family_restroom_rounded,
  'car': Icons.directions_car_rounded,
  'build': Icons.build_rounded,
  'favorite': Icons.favorite_rounded,
};

/// The fixed colour palette, readable on both the dark and light surfaces.
const kWorkspaceColors = <int>[
  0xFF3B82FF,
  0xFF8B5CF6,
  0xFFF5B544,
  0xFF3DDC97,
  0xFFFF6B7A,
  0xFF22B8CF,
  0xFFE879F9,
  0xFFA3ADC2,
];

IconData workspaceIcon(String key) => kWorkspaceIcons[key] ?? Icons.folder_rounded;

class WorkspacesScreen extends ConsumerWidget {
  const WorkspacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final workspaces = ref.watch(workspacesProvider).value ?? const <Workspace>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(l.setWorkspaces),
        actions: [
          IconButton(
            key: const ValueKey('add-workspace'),
            tooltip: l.setAddWorkspace,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => showWorkspaceSheet(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          SettingsSection(
            title: l.setWorkspaces,
            children: [
              for (final w in workspaces)
                ListTile(
                  key: ValueKey('workspace-${w.id}'),
                  leading: CircleAvatar(
                    backgroundColor: Color(w.colorArgb).withValues(alpha: 0.18),
                    child: Icon(workspaceIcon(w.iconKey), color: Color(w.colorArgb), size: 20),
                  ),
                  title: Text(w.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: workspaceAliases(w).isEmpty && !w.countsInBuckets
                      ? null
                      : Text(
                          [if (w.countsInBuckets) l.setCountsInBuckets, ...workspaceAliases(w)].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: k.textMuted),
                        ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showWorkspaceSheet(context, editing: w),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> showWorkspaceSheet(BuildContext context, {Workspace? editing}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _WorkspaceSheet(editing: editing),
);

class _WorkspaceSheet extends ConsumerStatefulWidget {
  const _WorkspaceSheet({this.editing});

  final Workspace? editing;

  @override
  ConsumerState<_WorkspaceSheet> createState() => _WorkspaceSheetState();
}

class _WorkspaceSheetState extends ConsumerState<_WorkspaceSheet> {
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late String _icon = widget.editing?.iconKey ?? 'folder';
  late int _color = widget.editing?.colorArgb ?? kWorkspaceColors.first;
  late List<String> _aliases = widget.editing == null ? [] : workspaceAliases(widget.editing!);
  late bool _counts = widget.editing?.countsInBuckets ?? false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(workspacesRepositoryProvider);
    final w = widget.editing;
    final name = _name.text.trim();
    final id = w?.id ?? await repo.create(name: name, iconKey: _icon, colorArgb: _color);
    if (w != null && (name != w.name || _icon != w.iconKey || _color != w.colorArgb)) {
      await repo.update(w.copyWith(name: name, iconKey: _icon, colorArgb: _color));
    }
    if (_aliases.join(',') != (w?.aliases ?? '')) await repo.setAliases(id, _aliases);
    if (_counts != (w?.countsInBuckets ?? false)) await repo.setCountsInBuckets(id, _counts);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _archive() async {
    final l = context.l10n;
    final w = widget.editing!;
    final blocked = await ref.read(workspacesRepositoryProvider).hasActiveAccounts(w.id);
    if (!mounted) return;
    if (blocked) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          key: const ValueKey('archive-blocked'),
          icon: const Icon(Icons.info_outline_rounded),
          content: Text(l.setArchiveBlocked(w.name)),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: Text(l.ok))],
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.setArchiveWorkspace(w.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(
            key: const ValueKey('archive-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.archive),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(workspacesRepositoryProvider).archive(w.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final w = widget.editing;
    final heading = text.titleSmall?.copyWith(color: k.text);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(w == null ? l.setAddWorkspace : l.setEditWorkspace, style: text.titleLarge),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('workspace-name'),
                controller: _name,
                maxLength: 80,
                decoration: InputDecoration(labelText: l.finAccountName),
                onChanged: (_) => setState(() {}),
              ),
              Text(l.setIcon, style: heading),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in kWorkspaceIcons.entries)
                    _Swatch(
                      key: ValueKey('icon-${e.key}'),
                      selected: _icon == e.key,
                      color: Color(_color),
                      onTap: () => setState(() => _icon = e.key),
                      child: Icon(e.value, size: 22, color: _icon == e.key ? Color(_color) : k.textMuted),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(l.setColour, style: heading),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in kWorkspaceColors)
                    _Swatch(
                      key: ValueKey('colour-${c.toRadixString(16)}'),
                      selected: _color == c,
                      color: Color(c),
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(l.setAliases, style: heading),
              const SizedBox(height: 2),
              Text(l.setAliasesHint, style: text.bodySmall?.copyWith(color: k.textMuted)),
              const SizedBox(height: 10),
              WordChips(
                words: _aliases,
                inputLabel: l.setAddAlias,
                inputKey: const ValueKey('alias-input'),
                addKey: const ValueKey('alias-add'),
                onChanged: (a) => setState(() => _aliases = a),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const ValueKey('workspace-counts'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.setCountsInBuckets),
                subtitle: Text(l.setCountsInBucketsHint),
                value: _counts,
                onChanged: (v) => setState(() => _counts = v),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('workspace-save'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _name.text.trim().isEmpty ? null : _save,
                child: Text(l.save),
              ),
              if (w != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const ValueKey('workspace-archive'),
                  style: TextButton.styleFrom(foregroundColor: k.danger, minimumSize: const Size.fromHeight(48)),
                  onPressed: _archive,
                  icon: const Icon(Icons.archive_outlined, size: 18),
                  label: Text(l.archive),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A 48 dp choice with a ring when selected.
class _Swatch extends StatelessWidget {
  const _Swatch({super.key, required this.selected, required this.color, required this.onTap, required this.child});

  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    return Semantics(
      selected: selected,
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? color.withValues(alpha: 0.16) : k.surfaceHigh,
            border: Border.all(color: selected ? color : Colors.transparent, width: 2),
          ),
          child: child,
        ),
      ),
    );
  }
}
