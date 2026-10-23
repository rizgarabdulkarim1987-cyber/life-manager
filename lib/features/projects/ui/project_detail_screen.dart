import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/money/amount_parse.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/tokens.dart';
import '../../capture/ai/ai_config.dart';
import '../../capture/ai/consent.dart';
import '../../capture/ai/groq_client.dart';
import '../../capture/domain/intent_validator.dart' show InvalidAiOutput;
import '../../finance/ui/ui_format.dart';
import '../../finance/ui/widgets/money_text.dart';
import '../../finance/ui/widgets/panel.dart';
import '../../lock/sensitive_gate.dart';
import '../../tasks/data/tasks_providers.dart';
import '../ai/planner.dart';
import '../data/projects_providers.dart';
import 'projects_screen.dart' show projectStatusLabel;

/// One project: status, steps with progress, the cost against the Investment bucket, and the planner chat.
class ProjectDetailScreen extends ConsumerStatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final int projectId;

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  final _input = TextEditingController();
  var _sending = false;
  PlannerReply? _pending;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final settings = await ref.read(settingsProvider.future);
    final keySaved = await ref.read(groqKeyStoreProvider).read() != null;
    if (!settings.aiOnlineEnabled || !keySaved) {
      messenger.showSnackBar(SnackBar(content: Text(l.projectPlannerOffline)));
      return;
    }
    if (!mounted || !await ensureConsent(context, AiFeature.parse)) return;
    setState(() => _sending = true);
    _input.clear();
    final repo = ref.read(projectsRepositoryProvider);
    try {
      await repo.addMessage(widget.projectId, 'user', text);
      final project = await repo.get(widget.projectId);
      if (project == null) return;
      final reply = await Planner(
        ref.read(groqClientProvider),
        () => settings.groqLlmModel,
      ).reply(project, await repo.messagesOf(widget.projectId), await repo.stepsOf(widget.projectId));
      await repo.addMessage(widget.projectId, 'assistant', reply.reply);
      await repo.applyStepUpdates(widget.projectId, reply.stepUpdates);
      if (mounted) setState(() => _pending = reply.plan == null ? _pending : reply);
    } on GroqError {
      messenger.showSnackBar(SnackBar(content: Text(l.projectPlannerFailed)));
    } on FormatException {
      messenger.showSnackBar(SnackBar(content: Text(l.projectPlannerFailed)));
    } on InvalidAiOutput {
      messenger.showSnackBar(SnackBar(content: Text(l.projectPlannerFailed)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _usePlan() async {
    final plan = _pending?.plan;
    if (plan == null) return;
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(projectsRepositoryProvider).applyPlan(widget.projectId, plan);
    if (!mounted) return;
    setState(() => _pending = null);
    messenger.showSnackBar(SnackBar(content: Text(l.projectPlanSaved)));
  }

  Future<void> _stepsToTasks() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final n = await ref.read(projectsRepositoryProvider).makeAllTasks(widget.projectId);
    messenger.showSnackBar(SnackBar(content: Text(l.projectTasksMade(n))));
  }

  Future<void> _toggleStep(ProjectStep s, bool done) async {
    final tasks = ref.read(tasksRepositoryProvider);
    if (s.taskId != null && await tasks.get(s.taskId!) != null) {
      done ? await tasks.complete(s.taskId!) : await tasks.reopen(s.taskId!);
    }
    await ref.read(projectsRepositoryProvider).setStepDone(s.id, done);
  }

  Future<void> _setCost(Project p) async {
    final l = context.l10n;
    final amount = TextEditingController();
    var currency = p.currencyCode ?? 'USD';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(l.projectCostSet),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('project-cost-field'),
                controller: amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l.projectCost),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'IQD', label: Text('IQD')),
                  ButtonSegment(value: 'USD', label: Text('USD')),
                ],
                selected: {currency},
                onSelectionChanged: (v) => set(() => currency = v.first),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
            FilledButton(
              key: const ValueKey('project-cost-save'),
              onPressed: () => Navigator.pop(c, true),
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
    final parsed = parseDecimalToMinor(amount.text, currency);
    amount.dispose();
    if (ok != true || parsed == null || parsed.minor <= 0) return;
    await ref.read(projectsRepositoryProvider).setEstimate(p.id, costMinor: parsed.minor, currency: currency);
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(l.projectDeleteAsk),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(
            key: const ValueKey('project-delete-yes'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await ref.read(projectsRepositoryProvider).delete(widget.projectId);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final id = widget.projectId;
    final project = ref.watch(projectProvider(id)).value;
    final steps = ref.watch(projectStepsProvider(id)).value ?? const [];
    final messages = ref.watch(projectMessagesProvider(id)).value ?? const [];
    if (project == null) return Scaffold(appBar: AppBar());
    final done = steps.where((s) => s.done).length;
    final phases = <String?, List<ProjectStep>>{};
    for (final s in steps) {
      phases.putIfAbsent(s.phase, () => []).add(s);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(project.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            key: const ValueKey('project-delete'),
            tooltip: l.projectDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _delete,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                if (project.description != null) ...[
                  Text(project.description!, style: text.bodyMedium?.copyWith(color: k.textMuted)),
                  const SizedBox(height: 12),
                ],
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final s in kProjectStatuses)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: ChoiceChip(
                            key: ValueKey('project-status-$s'),
                            label: Text(projectStatusLabel(l, s)),
                            selected: project.status == s,
                            selectedColor: k.accent.withValues(alpha: 0.16),
                            onSelected: (_) => ref.read(projectsRepositoryProvider).setStatus(id, s),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _CostCard(project: project, onSet: () => _setCost(project)),
                if (steps.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: done / steps.length, minHeight: 6),
                  ),
                  const SizedBox(height: 6),
                  Text(l.projectProgress(done, steps.length), style: text.bodySmall?.copyWith(color: k.textMuted)),
                  const SizedBox(height: 8),
                  for (final e in phases.entries) ...[
                    if (e.key != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(e.key!, style: text.titleSmall?.copyWith(color: k.text)),
                      ),
                    for (final s in e.value) _StepRow(step: s, onToggle: (v) => _toggleStep(s, v)),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      key: const ValueKey('steps-to-tasks'),
                      onPressed: _stepsToTasks,
                      icon: const Icon(Icons.task_alt_rounded),
                      label: Text(l.projectStepsToTasks),
                    ),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      l.projectNoSteps,
                      key: const ValueKey('project-no-steps'),
                      style: text.bodyMedium?.copyWith(color: k.textMuted),
                    ),
                  ),
                const SizedBox(height: 16),
                for (final m in messages) _Bubble(m),
                if (_pending?.plan case final plan?)
                  Panel(
                    key: const ValueKey('plan-proposal'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l.projectPlanProposed(plan.stepCount), style: text.titleSmall),
                        const SizedBox(height: 8),
                        for (final ph in plan.phases)
                          Text(
                            '• ${ph.name} (${ph.steps.length})',
                            style: text.bodyMedium?.copyWith(color: k.textMuted),
                          ),
                        const SizedBox(height: 12),
                        FilledButton(
                          key: const ValueKey('plan-use'),
                          onPressed: _usePlan,
                          child: Text(l.projectPlanUse),
                        ),
                      ],
                    ),
                  ),
                if (_sending) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('planner-input'),
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(hintText: l.projectPlannerHint),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('planner-send'),
                    tooltip: l.projectPlannerSend,
                    icon: const Icon(Icons.send_rounded),
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.onToggle});

  final ProjectStep step;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final due = step.dueDate;
    return Consumer(
      builder: (context, ref, _) => CheckboxListTile(
        key: ValueKey('step-${step.id}'),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: step.done,
        onChanged: (v) => onToggle(v ?? false),
        title: Text(
          step.title,
          style: TextStyle(
            decoration: step.done ? TextDecoration.lineThrough : null,
            color: step.done ? k.textMuted : k.text,
          ),
        ),
        subtitle: due == null ? null : Text(formatDate(context, due)),
        secondary: step.taskId != null
            ? Icon(Icons.task_alt_rounded, color: k.success, size: 20)
            : IconButton(
                key: ValueKey('step-task-${step.id}'),
                tooltip: l.projectStepToTask,
                icon: const Icon(Icons.add_task_rounded),
                onPressed: () => ref.read(projectsRepositoryProvider).makeTask(step.id),
              ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.m);

  final ProjectMessage m;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    final mine = m.role == 'user';
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        decoration: BoxDecoration(
          color: mine ? k.accent.withValues(alpha: 0.14) : k.surface,
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        ),
        child: Text(m.body),
      ),
    );
  }
}

/// The cost against the Investment bucket. Masked behind the eye and the biometric gate.
class _CostCard extends ConsumerWidget {
  const _CostCard({required this.project, required this.onSet});

  final Project project;
  final VoidCallback onSet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final a = ref.watch(projectAffordabilityProvider(project.id)).value;
    final hasCost = project.estCostMinor != null && project.currencyCode != null;
    return Panel(
      key: const ValueKey('project-cost-card'),
      child: SensitiveGate(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l.projectCost, style: text.titleSmall?.copyWith(color: k.textMuted)),
                ),
                TextButton(key: const ValueKey('project-cost-edit'), onPressed: onSet, child: Text(l.projectCostSet)),
              ],
            ),
            if (!hasCost)
              Text(l.projectCostNone, style: text.bodyMedium?.copyWith(color: k.textMuted))
            else ...[
              FittedMoney(
                Money(project.estCostMinor!, project.currencyCode!),
                alignment: AlignmentDirectional.centerStart,
                style: text.headlineSmall?.copyWith(color: k.text),
              ),
              const SizedBox(height: 8),
              if (a == null)
                Text(l.projectCostNoRate, style: text.bodySmall?.copyWith(color: k.textMuted))
              else ...[
                _Line(l.projectInInvestment, a.available),
                if (a.result.remainingMinor == 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      l.projectCovered,
                      key: const ValueKey('project-covered'),
                      style: text.bodyMedium?.copyWith(color: k.success),
                    ),
                  )
                else ...[
                  _Line(l.projectStillMissing, Money(a.result.remainingMinor, a.available.currency)),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      a.result.months == null ? l.projectNoPace : l.projectMonthsToGo(a.result.months!),
                      key: const ValueKey('project-months'),
                      style: text.bodySmall?.copyWith(color: k.textMuted),
                    ),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.money);

  final String label;
  final Money money;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: text.bodyMedium?.copyWith(color: k.textMuted)),
          ),
          Flexible(
            child: FittedMoney(money, style: text.bodyMedium?.copyWith(color: k.text)),
          ),
        ],
      ),
    );
  }
}
