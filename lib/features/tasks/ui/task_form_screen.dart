import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../finance/ui/ui_format.dart';
import '../../finance/ui/widgets/undo_snack.dart';
import '../data/tasks_providers.dart';

/// Creates a task, or edits [editId].
class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key, this.editId});

  final int? editId;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _title = TextEditingController();
  final _place = TextEditingController();
  final _notes = TextEditingController();
  var _kind = 'task';
  var _priority = 1;
  var _recurrence = 'none';
  DateTime? _date;
  TimeOfDay? _time;
  Task? _loaded;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.editId;
    final t = id == null ? null : await ref.read(tasksRepositoryProvider).get(id);
    if (!mounted) return;
    setState(() {
      _ready = true;
      _loaded = t;
      if (t == null) return;
      _title.text = t.title;
      _place.text = t.place ?? '';
      _notes.text = t.notes ?? '';
      _kind = t.kind;
      _priority = t.priority;
      _recurrence = t.recurrence;
      final due = t.dueAt?.toLocal();
      _date = due == null ? null : DateTime(due.year, due.month, due.day);
      _time = due != null && t.hasTime ? TimeOfDay(hour: due.hour, minute: due.minute) : null;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (d != null && mounted) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0));
    if (t != null && mounted) {
      setState(() {
        _time = t;
        _date ??= DateTime.now();
        _date = DateTime(_date!.year, _date!.month, _date!.day);
      });
    }
  }

  Future<void> _save() async {
    final repo = ref.read(tasksRepositoryProvider);
    final d = _date;
    final due = d == null ? null : DateTime(d.year, d.month, d.day, _time?.hour ?? 0, _time?.minute ?? 0);
    String? clean(String s) => s.trim().isEmpty ? null : s.trim();
    final id = widget.editId;
    if (id == null) {
      await repo.add(
        title: _title.text,
        notes: clean(_notes.text),
        kind: _kind,
        dueAt: due,
        hasTime: due != null && _time != null,
        place: clean(_place.text),
        priority: _priority,
        recurrence: _recurrence,
      );
    } else {
      await repo.update(
        id,
        TasksCompanion(
          title: Value(_title.text.trim()),
          notes: Value(clean(_notes.text)),
          kind: Value(_kind),
          dueAt: Value(due),
          hasTime: Value(due != null && _time != null),
          place: Value(clean(_place.text)),
          priority: Value(_priority),
          recurrence: Value(_recurrence),
        ),
      );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final editing = widget.editId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? l.taskEdit : l.taskNew),
        actions: [
          if (editing && _loaded != null)
            IconButton(
              key: const ValueKey('task-delete'),
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                final id = _loaded!.id;
                final nav = GoRouter.of(context);
                final messenger = ScaffoldMessenger.of(context);
                final repo = ref.read(tasksRepositoryProvider);
                final gone = await repo.delete(id);
                nav.pop();
                if (gone != null) showUndoSnack(messenger, l, message: l.taskDeleted, onUndo: () => repo.restore(gone));
              },
            ),
        ],
      ),
      body: !_ready
          ? const SizedBox.shrink()
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      TextField(
                        key: const ValueKey('task-title'),
                        controller: _title,
                        autofocus: !editing,
                        maxLength: 300,
                        decoration: InputDecoration(labelText: l.taskTitleLabel, counterText: ''),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<String>(
                        key: const ValueKey('task-kind'),
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(value: 'task', label: Text(l.taskKindTask)),
                          ButtonSegment(value: 'appointment', label: Text(l.taskKindAppointment)),
                          ButtonSegment(value: 'reminder', label: Text(l.taskKindReminder)),
                        ],
                        selected: {_kind},
                        onSelectionChanged: (s) => setState(() => _kind = s.first),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const ValueKey('task-date'),
                              icon: const Icon(Icons.event_outlined),
                              label: Text(_date == null ? l.taskNoDate : formatDate(context, _date!)),
                              onPressed: _pickDate,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const ValueKey('task-time'),
                              icon: const Icon(Icons.schedule_rounded),
                              label: Text(
                                _time == null
                                    ? l.taskNoTime
                                    : DateFormat.Hm('en').format(DateTime(2000, 1, 1, _time!.hour, _time!.minute)),
                              ),
                              onPressed: _pickTime,
                            ),
                          ),
                        ],
                      ),
                      if (_date != null)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            key: const ValueKey('task-clear-date'),
                            onPressed: () => setState(() {
                              _date = null;
                              _time = null;
                            }),
                            child: Text(l.taskNoDate),
                          ),
                        ),
                      const SizedBox(height: 8),
                      TextField(
                        key: const ValueKey('task-place'),
                        controller: _place,
                        decoration: InputDecoration(labelText: l.taskPlace),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const ValueKey('task-notes'),
                        controller: _notes,
                        minLines: 2,
                        maxLines: 5,
                        decoration: InputDecoration(labelText: l.taskNotesLabel),
                      ),
                      const SizedBox(height: 16),
                      Text(l.taskPriority, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: k.textMuted)),
                      const SizedBox(height: 6),
                      SegmentedButton<int>(
                        key: const ValueKey('task-priority'),
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(value: 0, label: Text(l.taskPrioLow)),
                          ButtonSegment(value: 1, label: Text(l.taskPrioNormal)),
                          ButtonSegment(value: 2, label: Text(l.taskPrioHigh)),
                        ],
                        selected: {_priority},
                        onSelectionChanged: (s) => setState(() => _priority = s.first),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        key: const ValueKey('task-repeat'),
                        initialValue: _recurrence,
                        decoration: InputDecoration(labelText: l.taskRepeat),
                        items: [
                          DropdownMenuItem(value: 'none', child: Text(l.taskRepeatNone)),
                          DropdownMenuItem(value: 'daily', child: Text(l.taskRepeatDaily)),
                          DropdownMenuItem(value: 'weekly', child: Text(l.taskRepeatWeekly)),
                          DropdownMenuItem(value: 'monthly', child: Text(l.taskRepeatMonthly)),
                        ],
                        onChanged: (v) => setState(() => _recurrence = v ?? 'none'),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: FilledButton(
                      key: const ValueKey('task-save'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      onPressed: _title.text.trim().isEmpty ? null : _save,
                      child: Text(l.save),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
