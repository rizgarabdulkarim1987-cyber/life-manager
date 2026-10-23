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
  'projects': lex.projects,
};

const kParseSystemPrompt =
    'You extract structured intents from a short transcript of what one person said '
    'to their personal finance and tasks app. The transcript may mix Iraqi Arabic, '
    'Kurdish (Sorani) and English, and may contain several intents. '
    'The user message is JSON with the transcript, the local date and time ("now", '
    '"utcOffset"), and the names of the person\'s accounts, workspaces, categories, buckets and projects.\n'
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
    '- "reminder" is "remind me to ...", "appointment" is a meeting or visit at a time (give "place" when said), '
    'and "task" is anything else to do. Put what to do in "title".\n'
    '- "project_idea" is when the person describes an idea for a project or business: a short name in "title" '
    'and what they said in "description".\n'
    '- Never give financial or investment advice, opinions or commentary.\n'
    '- Output only JSON.';

/// For a receipt photo: the same names to choose from and the date, no transcript.
Map<String, Object> buildReceiptPayload(Lexicon lex, DateTime now) => buildParsePayload('', lex, now)
  ..remove('transcript')
  ..remove('projects');

const kReceiptSystemPrompt =
    'You read one photo of a shop receipt or bill for a personal finance app. '
    'The user message is JSON with the local date and time ("now") and the names of the person\'s '
    'accounts, workspaces and categories.\n'
    'Answer with exactly this JSON shape and nothing else:\n'
    '$kIntentSchema\n'
    'Rules:\n'
    '- Give one intent of type "expense": the receipt total as a decimal string in "amount", '
    'its currency ("IQD" or "USD", null if unclear), the shop name in "description", '
    'and the date printed on it as YYYY-MM-DD, otherwise null.\n'
    '- Use only names from the given lists for account and category; otherwise null. Never invent a name.\n'
    '- If the photo is not a receipt or the total is unreadable, answer {"intents":[]}.\n'
    '- Output only JSON.';
