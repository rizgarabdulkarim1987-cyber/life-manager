import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/theme/tokens.dart';
import '../../finance/data/finance_providers.dart' show workspacesProvider;
import '../../finance/ui/ui_format.dart';
import '../data/tasks_providers.dart';
import '../data/tasks_repository.dart';
import '../domain/task_views.dart';
import 'task_format.dart';

/// When the reminder rings, relative to the due moment.
enum RemindChoice { none, atDue, min10, hour1, day1, morning, dayBefore, custom }

const _morningHour = 9;

/// The reminder time a choice means for the given due moment, or null.
DateTime? remindFor(RemindChoice c, DateTime? due, {required bool allDay, DateTime? custom}) {
  if (c == RemindChoice.custom) return custom;
  if (due == null) return null;
  final day = DateTime(due.year, due.month, due.day, _morningHour);
  return switch (c) {
    RemindChoice.none || RemindChoice.custom => null,
    RemindChoice.atDue => due,
    RemindChoice.min10 => due.subtract(const Duration(minutes: 10)),
    RemindChoice.hour1 => due.subtract(const Duration(hours: 1)),
    RemindChoice.day1 => due.subtract(const Duration(days: 1)),
    RemindChoice.morning => day,
    RemindChoice.dayBefore => DateTime(day.year, day.month, day.day - 1, _morningHour),
  };
}

/// Which choice produces [remind] for [due]; custom when none does.
RemindChoice choiceFor(DateTime? remind, DateTime? due, {required bool allDay}) {
  if (remind == null) return RemindChoice.none;
  final options = allDay
      ? const [RemindChoice.morning, RemindChoice.dayBefore]
      : const [RemindChoice.atDue, RemindChoice.min10, RemindChoice.hour1, RemindChoice.day1];
  for (final c in options) {
    if (remindFor(c, due, allDay: allDay)?.isAtSameMomentAs(remind) ?? false) return c;
  }
  return RemindChoice.custom;
}

class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key, this.editId, this.initialTitle, this.initialDue});

  final int? editId;
  final String? initialTitle;
  final DateTime? initialDue;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  final _tags = TextEditingController();
  int? _workspaceId;
  String _priority = 'normal';
  DateTime? _date;
  TimeOfDay? _time;
  RemindChoice _remind = RemindChoice.none;
  DateTime? _customRemind;
  String? _recurrence;
  int _interval = 1;
  int? _captureId;
  int? _meetingNoteId;
  bool _loaded = false;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    if (widget.editId == null) {
      _title.text = widget.initialTitle ?? '';
      final d = widget.initialDue;
      if (d != null) _date = DateTime(d.year, d.month, d.day);
      _loaded = true;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final t = await ref.read(tasksRepositoryProvider).get(widget.editId!);
    if (!mounted || t == null) {
      if (mounted) context.pop();
      return;
    }
    final due = dueLocal(t);
    setState(() {
      _title.text = t.title;
      _notes.text = t.notes ?? '';
      _tags.text = t.tags.split(',').where((x) => x.isNotEmpty).join(', ');
      _workspaceId = t.workspaceId;
      _priority = t.priority;
      if (due != null) _date = DateTime(due.year, due.month, due.day);
      if (due != null && !t.dueAllDay) _time = TimeOfDay(hour: due.hour, minute: due.minute);
      _recurrence = t.recurrence;
      _interval = t.recurrenceInterval;
      _captureId = t.captureId;
      _meetingNoteId = t.meetingNoteId;
      final remind = t.remindAt?.toLocal();
      _remind = choiceFor(remind, due, allDay: t.dueAllDay);
      if (_remind == RemindChoice.custom) _customRemind = remind;
      _loaded = true;
    });
  }

  DateTime? get _due {
    final d = _date;
    if (d == null) return null;
    final t = _time;
    return DateTime(d.year, d.month, d.day, t?.hour ?? 0, t?.minute ?? 0);
  }

  bool get _allDay => _time == null;

  List<RemindChoice> get _choices {
    if (_date == null) return const [RemindChoice.none, RemindChoice.custom];
    if (_allDay) return const [RemindChoice.none, RemindChoice.morning, RemindChoice.dayBefore, RemindChoice.custom];
    return const [
      RemindChoice.none,
      RemindChoice.atDue,
      RemindChoice.min10,
      RemindChoice.hour1,
      RemindChoice.day1,
      RemindChoice.custom,
    ];
  }

  void _touch(VoidCallback f) => setState(() {
    f();
    _dirty = true;
    if (!_choices.contains(_remind)) _remind = RemindChoice.none;
    if (_date == null) _recurrence = null;
  });

  String _choiceLabel(RemindChoice c) {
    final l = context.l10n;
    return switch (c) {
      RemindChoice.none => l.tskRemindNone,
      RemindChoice.atDue => l.tskRemindAtDue,
      RemindChoice.min10 => l.tskRemind10,
      RemindChoice.hour1 => l.tskRemind1h,
      RemindChoice.day1 => l.tskRemind1d,
      RemindChoice.morning => l.tskRemindMorning,
      RemindChoice.dayBefore => l.tskRemindDayBefore,
      RemindChoice.custom =>
        _customRemind == null ? l.tskRemindCustom : formatDateTime(context, _customRemind!, allDay: false),
    };
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10, 12, 31),
    );
    if (d != null) _touch(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0));
    if (t != null) _touch(() => _time = t);
  }

  Future<void> _pickCustomRemind() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _customRemind ?? _due ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10, 12, 31),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_customRemind ?? DateTime(d.year, d.month, d.day, 9)),
    );
    if (t == null) return;
    _touch(() {
      _customRemind = DateTime(d.year, d.month, d.day, t.hour, t.minute);
      _remind = RemindChoice.custom;
    });
  }

  bool get _valid => _title.text.trim().isNotEmpty;

  Future<void> _save() async {
    setState(() => _saving = true);
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final due = _due;
      final remind = remindFor(_remind, due, allDay: _allDay, custom: _customRemind);
      final input = TaskInput(
        title: _title.text,
        notes: _notes.text,
        workspaceId: _workspaceId,
        priority: _priority,
        dueAt: due,
        dueAllDay: due != null && _allDay,
        remindAt: remind,
        recurrence: due == null ? null : _recurrence,
        recurrenceInterval: _interval,
        tags: parseTags(_tags.text),
        captureId: _captureId,
        meetingNoteId: _meetingNoteId,
      );
      if (remind != null) await _askNotifications();
      final repo = ref.read(tasksRepositoryProvider);
      final id = widget.editId;
      if (id == null) {
        await repo.create(input);
      } else {
        await repo.update(id, input);
      }
      ref.invalidate(reminderStatusProvider);
      if (mounted) context.pop(true);
    } on Exception catch (e) {
      AppLogger.warn('task save failed', e);
      messenger.showSnackBar(SnackBar(content: Text(l.somethingWentWrong)));
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The first reminder asks for the notification permission; saving never waits on the answer.
  Future<void> _askNotifications() async {
    final scheduler = ref.read(reminderSchedulerProvider);
    final status = await scheduler.status();
    if (!status.notifications) await scheduler.requestNotifications();
  }

  Future<void> _leave() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.tskDiscardTitle),
        content: Text(l.tskDiscardBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text(l.cancel)),
          FilledButton(
            key: const ValueKey('task-discard-confirm'),
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(l.tskDiscard),
          ),
        ],
      ),
    );
    if (ok == true && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final workspaces = ref.watch(workspacesProvider).value ?? const <Workspace>[];
    final gap = const SizedBox(height: 16);
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        key: const ValueKey('task-form'),
        appBar: AppBar(title: Text(widget.editId == null ? l.tskNew : l.tskEdit)),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  TextField(
                    key: const ValueKey('task-title'),
                    controller: _title,
                    autofocus: widget.editId == null,
                    maxLength: 200,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: l.tskFieldTitle, counterText: ''),
                    onChanged: (_) => _touch(() {}),
                  ),
                  gap,
                  TextField(
                    key: const ValueKey('task-notes'),
                    controller: _notes,
                    minLines: 2,
                    maxLines: 6,
                    maxLength: 4000,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(labelText: l.tskFieldNotes, counterText: ''),
                    onChanged: (_) => _touch(() {}),
                  ),
                  gap,
                  Text(l.tskFieldPriority, style: text.labelLarge?.copyWith(color: k.textMuted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in kTaskPriorities)
                        ChoiceChip(
                          key: ValueKey('task-priority-$p'),
                          label: Text(priorityLabel(l, p)),
                          selected: _priority == p,
                          onSelected: (_) => _touch(() => _priority = p),
                        ),
                    ],
                  ),
                  gap,
                  DropdownButtonFormField<int?>(
                    key: const ValueKey('task-workspace'),
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
                    onChanged: (v) => _touch(() => _workspaceId = v),
                  ),
                  gap,
                  Text(l.tskDueDate, style: text.labelLarge?.copyWith(color: k.textMuted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('task-date'),
                        onPressed: _pickDate,
                        icon: const Icon(Icons.event_rounded, size: 18),
                        label: Text(_date == null ? l.tskNoDate : formatDate(context, _date!)),
                      ),
                      if (_date != null)
                        OutlinedButton.icon(
                          key: const ValueKey('task-time'),
                          onPressed: _pickTime,
                          icon: const Icon(Icons.schedule_rounded, size: 18),
                          label: Text(_time == null ? l.tskAllDay : formatTime(context, _due!)),
                        ),
                      if (_time != null)
                        TextButton(
                          key: const ValueKey('task-all-day'),
                          onPressed: () => _touch(() => _time = null),
                          child: Text(l.tskAllDay),
                        ),
                      if (_date != null)
                        TextButton(
                          key: const ValueKey('task-clear-date'),
                          onPressed: () => _touch(() {
                            _date = null;
                            _time = null;
                          }),
                          child: Text(l.tskClearDate),
                        ),
                    ],
                  ),
                  gap,
                  DropdownButtonFormField<RemindChoice>(
                    key: const ValueKey('task-remind'),
                    initialValue: _remind,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.tskReminder),
                    items: [
                      for (final c in _choices)
                        DropdownMenuItem(
                          value: c,
                          child: Text(_choiceLabel(c), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (c) {
                      if (c == null) return;
                      if (c == RemindChoice.custom) {
                        _pickCustomRemind();
                      } else {
                        _touch(() => _remind = c);
                      }
                    },
                  ),
                  gap,
                  DropdownButtonFormField<String?>(
                    key: const ValueKey('task-repeat'),
                    initialValue: _date == null ? null : _recurrence,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.tskRepeat),
                    items: [
                      DropdownMenuItem<String?>(value: null, child: Text(l.tskRepeatNone)),
                      for (final r in kTaskRecurrences)
                        DropdownMenuItem<String?>(value: r, child: Text(recurrenceLabel(l, r, 1))),
                    ],
                    onChanged: _date == null ? null : (v) => _touch(() => _recurrence = v),
                  ),
                  if (_recurrence != null && _date != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          key: const ValueKey('task-interval-minus'),
                          tooltip: '−',
                          onPressed: _interval > 1 ? () => _touch(() => _interval--) : null,
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                        ),
                        Expanded(
                          child: Text(
                            recurrenceLabel(l, _recurrence!, _interval),
                            key: const ValueKey('task-interval'),
                            textAlign: TextAlign.center,
                            style: text.bodyLarge?.copyWith(color: k.text),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('task-interval-plus'),
                          tooltip: '+',
                          onPressed: _interval < 365 ? () => _touch(() => _interval++) : null,
                          icon: const Icon(Icons.add_circle_outline_rounded),
                        ),
                      ],
                    ),
                  ],
                  gap,
                  TextField(
                    key: const ValueKey('task-tags'),
                    controller: _tags,
                    decoration: InputDecoration(labelText: l.tskTags, hintText: l.tskTagsHint),
                    onChanged: (_) => _touch(() {}),
                  ),
                ],
              ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton(
              key: const ValueKey('task-save'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _valid && !_saving && _loaded ? _save : null,
              child: Text(l.save),
            ),
          ),
        ),
      ),
    );
  }
}
