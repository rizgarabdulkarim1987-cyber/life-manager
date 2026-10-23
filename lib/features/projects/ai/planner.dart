import 'dart:convert';

import '../../../core/db/app_database.dart';
import '../../../core/money/amount_parse.dart';
import '../../capture/ai/groq_client.dart';
import '../../capture/domain/intent_validator.dart' show InvalidAiOutput;

class PlanStep {
  const PlanStep(this.title, this.due);

  final String title;
  final DateTime? due;
}

class PlanPhase {
  const PlanPhase(this.name, this.steps);

  final String name;
  final List<PlanStep> steps;
}

/// A plan the planner proposes; it replaces the project's steps only after the owner says OK.
class PlanProposal {
  const PlanProposal({required this.phases, this.estCostMinor, this.currency});

  final List<PlanPhase> phases;
  final int? estCostMinor;
  final String? currency;

  int get stepCount => phases.fold(0, (n, p) => n + p.steps.length);
}

class StepUpdate {
  const StepUpdate(this.seq, this.done);

  final int seq;
  final bool done;
}

class PlannerReply {
  const PlannerReply({required this.reply, required this.question, this.plan, this.stepUpdates = const []});

  final String reply;

  /// The reply ends with a question for the owner.
  final bool question;
  final PlanProposal? plan;
  final List<StepUpdate> stepUpdates;
}

const kPlannerSchema =
    '{"reply":"<text to the person>","question":true|false,'
    '"plan":null|{"phases":[{"name":"<text>","steps":[{"title":"<text>","due":"YYYY-MM-DD|null"}]}],'
    '"est_cost":"<decimal string>|null","currency":"IQD|USD|null"},'
    '"step_updates":[{"seq":<int>,"done":true|false}]}';

const kPlannerSystemPrompt =
    'You help one person turn a project idea into a plan they can follow. The person may write Iraqi Arabic, '
    'Kurdish (Sorani) or English: answer in the language of their last message.\n'
    'The user message is JSON with the project title and description, today\'s date ("today"), the chat so far '
    '("messages", oldest first) and the current steps ("steps", numbered by "seq").\n'
    'Answer with exactly this JSON shape and nothing else:\n'
    '$kPlannerSchema\n'
    'Rules:\n'
    '- Ask ONE short question at a time, in this order, skipping what is already known: the goal, the budget, '
    'the deadline, what the person already has, what worries them. While you still need an answer, '
    'set "question" to true and "plan" to null.\n'
    '- Once you know enough, propose a plan: 2 to 5 phases with 3 to 8 concrete steps each, due dates when a '
    'deadline is known, and "est_cost" as a decimal string with its "currency" if the person gave a budget '
    'or cost; otherwise null.\n'
    '- When the person says they finished steps, list them in "step_updates" by their "seq".\n'
    '- Never give financial or investment advice, and never say whether the person can afford the project: '
    'the app works that out itself.\n'
    '- Keep "reply" under 600 characters. Output only JSON.';

/// What the model sees about a project: its words and the chat, never any money held in the app.
Map<String, Object> buildPlannerPayload(
  Project p,
  List<ProjectMessage> history,
  List<ProjectStep> steps,
  DateTime now,
) => {
  'today': '${now.year}-${_two(now.month)}-${_two(now.day)}',
  'title': p.title,
  'description': p.description ?? '',
  'messages': [
    for (final m in history.length > 30 ? history.sublist(history.length - 30) : history)
      {'role': m.role, 'text': m.body},
  ],
  'steps': [
    for (final s in steps) {'seq': s.seq, 'title': s.title, 'done': s.done},
  ],
};

String _two(int n) => n.toString().padLeft(2, '0');

final _date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final _decimal = RegExp(r'^\d{1,12}(\.\d{1,2})?$');

const kMaxPlanSteps = 60;

/// Checks the planner's answer against [kPlannerSchema]; anything off throws [InvalidAiOutput].
PlannerReply parsePlannerReply(Object? json) {
  if (json is! Map) throw const InvalidAiOutput('root');
  const allowed = {'reply', 'question', 'plan', 'step_updates'};
  if (json.keys.any((k) => !allowed.contains(k))) throw const InvalidAiOutput('key');
  final reply = json['reply'];
  if (reply is! String || reply.trim().isEmpty || reply.length > 2000) throw const InvalidAiOutput('reply');
  final question = json['question'] ?? false;
  if (question is! bool) throw const InvalidAiOutput('question');

  PlanProposal? plan;
  final rawPlan = json['plan'];
  if (rawPlan != null) {
    if (rawPlan is! Map || rawPlan.keys.any((k) => !const {'phases', 'est_cost', 'currency'}.contains(k))) {
      throw const InvalidAiOutput('plan');
    }
    final phases = rawPlan['phases'];
    if (phases is! List || phases.isEmpty || phases.length > 10) throw const InvalidAiOutput('phases');
    var total = 0;
    final out = <PlanPhase>[];
    for (final ph in phases) {
      if (ph is! Map) throw const InvalidAiOutput('phase');
      final name = ph['name'];
      final steps = ph['steps'];
      if (name is! String || name.trim().isEmpty || name.length > 80) throw const InvalidAiOutput('phase name');
      if (steps is! List || steps.isEmpty || steps.length > 15) throw const InvalidAiOutput('steps');
      final list = <PlanStep>[];
      for (final s in steps) {
        if (s is! Map) throw const InvalidAiOutput('step');
        final title = s['title'];
        if (title is! String || title.trim().isEmpty || title.length > 200) throw const InvalidAiOutput('step title');
        DateTime? due;
        final rawDue = s['due'];
        if (rawDue != null) {
          final m = rawDue is String ? _date.firstMatch(rawDue) : null;
          if (m == null) throw const InvalidAiOutput('due');
          final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
          due = DateTime(y, mo, d);
          if (due.month != mo || due.day != d) throw const InvalidAiOutput('due');
        }
        list.add(PlanStep(title.trim(), due));
        total++;
      }
      out.add(PlanPhase(name.trim(), list));
    }
    if (total > kMaxPlanSteps) throw const InvalidAiOutput('too many steps');
    final cost = rawPlan['est_cost'];
    final currency = rawPlan['currency'];
    if (currency != null && currency != 'IQD' && currency != 'USD') throw const InvalidAiOutput('currency');
    int? minor;
    if (cost != null) {
      if (cost is! String || !_decimal.hasMatch(cost) || currency == null) throw const InvalidAiOutput('est_cost');
      minor = parseDecimalToMinor(cost, currency as String)?.minor;
      if (minor == null || minor <= 0) throw const InvalidAiOutput('est_cost');
    }
    plan = PlanProposal(phases: out, estCostMinor: minor, currency: minor == null ? null : currency as String?);
  }

  final updates = <StepUpdate>[];
  final rawUpdates = json['step_updates'] ?? const [];
  if (rawUpdates is! List || rawUpdates.length > kMaxPlanSteps) throw const InvalidAiOutput('step_updates');
  for (final u in rawUpdates) {
    if (u is! Map || u['seq'] is! int || u['done'] is! bool) throw const InvalidAiOutput('step update');
    updates.add(StepUpdate(u['seq'] as int, u['done'] as bool));
  }
  return PlannerReply(reply: reply.trim(), question: question, plan: plan, stepUpdates: updates);
}

/// Asks the planner for its next reply. Online only; the caller checks consent.
class Planner {
  Planner(this._client, this._model);

  final GroqClient _client;
  final String Function() _model;

  /// Throws [GroqError], [FormatException] or [InvalidAiOutput] when the answer can't be used.
  Future<PlannerReply> reply(Project p, List<ProjectMessage> history, List<ProjectStep> steps) async {
    final content = await _client.chatJson(
      model: _model(),
      system: kPlannerSystemPrompt,
      user: jsonEncode(buildPlannerPayload(p, history, steps, DateTime.now())),
    );
    return parsePlannerReply(jsonDecode(content));
  }
}
