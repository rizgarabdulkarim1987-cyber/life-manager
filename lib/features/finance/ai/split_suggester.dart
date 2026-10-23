import 'dart:convert';

import '../../capture/ai/groq_client.dart';
import '../../capture/domain/intent_validator.dart' show InvalidAiOutput;

const kSplitKeys = ['expenses', 'emergency', 'investment'];

const _system =
    'You help a person in Iraq split each income into three buckets: expenses (day-to-day spending), '
    'emergency (a safety fund) and investment (saving toward projects). Read their goal and suggest '
    'percentages as basis points (100% = 10000). Expenses never goes below 4000. '
    'Do not give investment or financial product advice. '
    'Answer only with JSON: {"expenses":<int>,"emergency":<int>,"investment":<int>}, summing to 10000.';

/// Redesign §11.2: the AI suggests a split from the owner's goal only; it never
/// sees an amount. Returns basis points per `expenses|emergency|investment`.
Future<Map<String, int>> suggestSplit(GroqClient c, String model, String goal) async {
  final content = await c.chatJson(model: model, system: _system, user: jsonEncode({'goal': goal.trim()}));
  final Object? json;
  try {
    json = jsonDecode(content);
  } on FormatException {
    throw const InvalidAiOutput('split');
  }
  if (json is! Map<String, Object?>) throw const InvalidAiOutput('split');
  final out = <String, int>{};
  for (final k in kSplitKeys) {
    final v = json[k];
    if (v is! int || v < 0 || v > 10000) throw const InvalidAiOutput('split');
    out[k] = v;
  }
  if (out.values.fold<int>(0, (s, v) => s + v) != 10000) throw const InvalidAiOutput('split');
  return out;
}
