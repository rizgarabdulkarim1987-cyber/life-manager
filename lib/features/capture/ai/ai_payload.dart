import '../domain/intent_validator.dart';
import '../domain/lexicon.dart';

String _two(int n) => n.toString().padLeft(2, '0');

String formatUtcOffset(Duration d) {
  final sign = d.isNegative ? '-' : '+';
  final m = d.inMinutes.abs();
  return '$sign${_two(m ~/ 60)}:${_two(m % 60)}';
}

/// Everything the model sees about the owner: what was said, the time, and
/// the names it may choose from. No balances, amounts, history or vault data.
Map<String, Object> buildParsePayload(String transcript, Lexicon lex, DateTime now) => {
  'transcript': transcript,
  'now': '${now.year}-${_two(now.month)}-${_two(now.day)}T${_two(now.hour)}:${_two(now.minute)}',
  'utcOffset': formatUtcOffset(now.timeZoneOffset),
  'accounts': {for (final a in lex.accounts) a.name}.toList(),
  'workspaces': [
    for (final w in lex.workspaces) {'name': w.name, 'aliases': w.aliases},
  ],
  'categories': [
    for (final c in lex.categories) {'name': c.name, 'kind': c.kind},
  ],
  'buckets': [for (final b in lex.buckets) b.name],
};

const kParseSystemPrompt =
    'You extract structured intents from a short transcript of what one person said '
    'to their personal finance and tasks app. The transcript may mix Iraqi Arabic, '
    'Kurdish (Sorani) and English, and may contain several intents. '
    'The user message is JSON with the transcript, the local date and time ("now", '
    '"utcOffset"), and the names of the person\'s accounts, workspaces, categories and buckets.\n'
    'Answer with exactly this JSON shape and nothing else:\n'
    '$kIntentSchema\n'
    'Rules:\n'
    '- Give amounts as decimal strings (for example "25000" or "12.5"), never as numbers. '
    'Iraqi words: "ورقة" is 100 USD, "دفتر" is 10000 USD, "الف" is a thousand.\n'
    '- Use only names from the given lists for workspace, account, to_account and category; '
    'otherwise use null. Never invent a name.\n'
    '- Dates as YYYY-MM-DD and times as HH:MM, relative to "now". Use null when not said.\n'
    '- Use null for anything not said. Do not guess amounts.\n'
    '- "edit" and "delete" change or remove something already saved: set "target" to "last", '
    '"last_expense", "last_income" or a few words naming the entry, and for "edit" give only the new values.\n'
    '- Never give financial or investment advice, opinions or commentary.\n'
    '- Output only JSON.';
