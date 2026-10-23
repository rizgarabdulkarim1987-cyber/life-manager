import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/theme/tokens.dart';
import '../../capture/capture_pipeline.dart';
import '../../capture/domain/proposal.dart';
import '../../finance/data/finance_providers.dart' show workspacesProvider;
import '../../finance/ui/ui_format.dart';
import '../data/tasks_providers.dart';
import '../data/tasks_repository.dart';

class MeetingsScreen extends ConsumerWidget {
  const MeetingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final notes = ref.watch(meetingNotesProvider).value ?? const <MeetingNote>[];
    return Scaffold(
      key: const ValueKey('meetings-screen'),
      appBar: AppBar(
        title: Text(l.tskMeetings),
        actions: [
          IconButton(
            key: const ValueKey('meeting-add'),
            tooltip: l.tskMeetingNew,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push('/tasks/meetings/new'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: notes.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l.tskMeetingEmpty,
                  key: const ValueKey('meetings-empty'),
                  textAlign: TextAlign.center,
                  style: text.bodyLarge?.copyWith(color: k.textMuted),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 112),
              itemCount: notes.length,
              separatorBuilder: (_, _) => Divider(color: k.border, height: 1, indent: 20, endIndent: 20),
              itemBuilder: (context, i) {
                final n = notes[i];
                return InkWell(
                  key: ValueKey('meeting-${n.id}'),
                  onTap: () => context.push('/tasks/meetings/${n.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyLarge?.copyWith(color: k.text),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          n.body.isEmpty ? formatDate(context, n.updatedAt.toLocal()) : n.body.replaceAll('\n', ' '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(color: k.textMuted),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// A meeting note: title, workspace, free text, and the action points that become tasks.
class MeetingEditorScreen extends ConsumerStatefulWidget {
  const MeetingEditorScreen({super.key, this.noteId});

  final int? noteId;

  @override
  ConsumerState<MeetingEditorScreen> createState() => _MeetingEditorScreenState();
}

class _MeetingEditorScreenState extends ConsumerState<MeetingEditorScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  int? _workspaceId;
  int? _id;
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _id = widget.noteId;
    if (_id == null) {
      _loaded = true;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final n = await ref.read(meetingNotesRepositoryProvider).get(_id!);
    if (!mounted) return;
    if (n == null) {
      context.pop();
      return;
    }
    setState(() {
      _title.text = n.title;
      _body.text = n.body;
      _workspaceId = n.workspaceId;
      _loaded = true;
    });
  }

  /// Saves (creating on the first save) and returns the note id.
  Future<int> _save() async {
    final repo = ref.read(meetingNotesRepositoryProvider);
    final id = _id;
    if (id == null) {
      return _id = await repo.create(title: _title.text, body: _body.text, workspaceId: _workspaceId);
    }
    await repo.update(id, title: _title.text, body: _body.text, workspaceId: _workspaceId);
    return id;
  }

  Future<void> _saveAndClose() async {
    setState(() => _busy = true);
    try {
      await _save();
      if (mounted) context.pop();
    } on Exception catch (e) {
      AppLogger.warn('meeting save failed', e);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _extract() async {
    setState(() => _busy = true);
    try {
      final id = await _save();
      final points = await ref.read(capturePipelineProvider).actionPoints(_body.text);
      if (!mounted) return;
      setState(() => _busy = false);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ActionPointsSheet(points: points, meetingNoteId: id, workspaceId: _workspaceId),
      );
    } on Exception catch (e) {
      AppLogger.warn('action points failed', e);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final id = _id;
    if (id != null) await ref.read(meetingNotesRepositoryProvider).delete(id);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final workspaces = ref.watch(workspacesProvider).value ?? const <Workspace>[];
    return Scaffold(
      key: const ValueKey('meeting-editor'),
      appBar: AppBar(
        title: Text(l.tskMeetingNote),
        actions: [
          if (_id != null)
            IconButton(
              key: const ValueKey('meeting-delete'),
              tooltip: l.tskDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _busy ? null : _delete,
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                TextField(
                  key: const ValueKey('meeting-title'),
                  controller: _title,
                  maxLength: 200,
                  decoration: InputDecoration(labelText: l.tskFieldTitle, counterText: ''),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  key: const ValueKey('meeting-workspace'),
                  initialValue: workspaces.any((w) => w.id == _workspaceId) ? _workspaceId : null,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.tskFieldWorkspace),
                  items: [
                    DropdownMenuItem<int?>(value: null, child: Text(l.tskNoWorkspace)),
                    for (final w in workspaces)
                      DropdownMenuItem<int?>(
                        value: w.id,
                        child: Text(w.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _workspaceId = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('meeting-body'),
                  controller: _body,
                  minLines: 8,
                  maxLines: 20,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(labelText: l.tskMeetingBody, alignLabelWithHint: true),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const ValueKey('meeting-extract'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: _busy || _title.text.trim().isEmpty || _body.text.trim().isEmpty ? null : _extract,
                  icon: const Icon(Icons.checklist_rounded),
                  label: Text(l.tskExtract),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            key: const ValueKey('meeting-save'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: !_busy && _loaded && _title.text.trim().isNotEmpty ? _saveAndClose : null,
            child: Text(l.save),
          ),
        ),
      ),
    );
  }
}

/// The proposed tasks of one text, each one kept, edited or dropped before saving.
class ActionPointsSheet extends ConsumerStatefulWidget {
  const ActionPointsSheet({super.key, required this.points, this.meetingNoteId, this.workspaceId});

  final List<TaskProposal> points;
  final int? meetingNoteId;
  final int? workspaceId;

  @override
  ConsumerState<ActionPointsSheet> createState() => _ActionPointsSheetState();
}

class _ActionPointsSheetState extends ConsumerState<ActionPointsSheet> {
  late final List<TextEditingController> _titles;
  late final List<bool> _keep;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titles = [for (final p in widget.points) TextEditingController(text: p.title)];
    _keep = List.filled(widget.points.length, true);
  }

  @override
  void dispose() {
    for (final c in _titles) {
      c.dispose();
    }
    super.dispose();
  }

  int get _count => [
    for (var i = 0; i < _keep.length; i++)
      if (_keep[i] && _titles[i].text.trim().isNotEmpty) i,
  ].length;

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = ref.read(tasksRepositoryProvider);
    try {
      for (var i = 0; i < widget.points.length; i++) {
        if (!_keep[i] || _titles[i].text.trim().isEmpty) continue;
        final p = widget.points[i];
        await repo.create(
          TaskInput(
            title: _titles[i].text,
            dueAt: p.due,
            dueAllDay: p.due != null && p.due!.hour == 0 && p.due!.minute == 0,
            workspaceId: p.workspaceId ?? widget.workspaceId,
            meetingNoteId: widget.meetingNoteId,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on Exception catch (e) {
      AppLogger.warn('action points save failed', e);
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        key: const ValueKey('action-points'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(l.tskExtractTitle, style: text.titleMedium?.copyWith(color: k.text)),
            ),
          ),
          if (widget.points.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l.tskExtractNone,
                key: const ValueKey('action-points-none'),
                style: text.bodyMedium?.copyWith(color: k.textMuted),
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (var i = 0; i < widget.points.length; i++)
                    Row(
                      key: ValueKey('point-$i'),
                      children: [
                        Checkbox(
                          key: ValueKey('point-keep-$i'),
                          value: _keep[i],
                          onChanged: (v) => setState(() => _keep[i] = v ?? false),
                        ),
                        Expanded(
                          child: TextField(
                            key: ValueKey('point-title-$i'),
                            controller: _titles[i],
                            maxLines: 3,
                            minLines: 1,
                            maxLength: 200,
                            enabled: _keep[i],
                            decoration: const InputDecoration(counterText: ''),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: Text(l.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('points-save'),
                    onPressed: _saving || _count == 0 ? null : _save,
                    child: Text(l.tskAddNTasks(_count), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
