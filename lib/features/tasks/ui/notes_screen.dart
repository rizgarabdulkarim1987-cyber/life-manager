import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../finance/ui/widgets/undo_snack.dart';
import '../data/tasks_providers.dart';

/// Opens the editor sheet for [note], or a new note.
Future<void> editNote(BuildContext context, WidgetRef ref, [Note? note]) async {
  final l = context.l10n;
  final repo = ref.read(notesRepositoryProvider);
  final body = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _NoteSheet(initial: note?.body ?? '', title: note == null ? l.noteNew : l.noteEdit),
  );
  if (body == null || body.trim().isEmpty) return;
  if (note == null) {
    await repo.add(body);
  } else {
    await repo.update(note.id, body);
  }
}

class _NoteSheet extends StatefulWidget {
  const _NoteSheet({required this.initial, required this.title});

  final String initial;
  final String title;

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  late final _ctl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('note-field'),
            controller: _ctl,
            autofocus: true,
            minLines: 3,
            maxLines: 8,
            maxLength: 5000,
            decoration: InputDecoration(hintText: l.noteHint),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const ValueKey('note-save'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _ctl.text.trim().isEmpty ? null : () => Navigator.of(context).pop(_ctl.text),
            child: Text(l.save),
          ),
        ],
      ),
    );
  }
}

class NotesView extends ConsumerWidget {
  const NotesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final notes = ref.watch(notesProvider).value;
    if (notes == null) return const SizedBox.shrink();
    if (notes.isEmpty) {
      return Center(
        child: Text(
          l.tasksEmpty,
          key: const ValueKey('notes-empty'),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: k.textMuted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: notes.length,
      itemBuilder: (context, i) {
        final n = notes[i];
        return Dismissible(
          key: ValueKey('note-row-${n.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            color: k.danger.withValues(alpha: 0.16),
            alignment: AlignmentDirectional.centerEnd,
            padding: const EdgeInsetsDirectional.only(end: 24),
            child: Icon(Icons.delete_outline_rounded, color: k.danger),
          ),
          onDismissed: (_) async {
            final messenger = ScaffoldMessenger.of(context);
            final repo = ref.read(notesRepositoryProvider);
            final gone = await repo.delete(n.id);
            if (gone == null) return;
            showUndoSnack(messenger, l, message: l.noteDeleted, onUndo: () => repo.restore(gone));
          },
          child: ListTile(
            key: ValueKey('note-${n.id}'),
            title: Text(n.body, maxLines: 4, overflow: TextOverflow.ellipsis),
            onTap: () => editNote(context, ref, n),
          ),
        );
      },
    );
  }
}
