import '../../../core/text/digits.dart';

/// One word of a transcript: [text] as said, [norm] folded for matching,
/// and its character range in the string it came from.
class Tok {
  const Tok(this.text, this.norm, this.start, this.end);

  final String text;
  final String norm;
  final int start;
  final int end;

  bool get isDigits => _digitsOnly.hasMatch(norm);
}

final _token = RegExp(r'[0-9٠-٩۰-۹]+(?:[.,٬٫:][0-9٠-٩۰-۹]+)*|\$|[\p{L}\p{M}]+', unicode: true);
final _digitsOnly = RegExp(r'^[0-9]');

List<Tok> tokenize(String s) => [
  for (final m in _token.allMatches(s)) Tok(m[0]!, normalizeForMatch(m[0]!), m.start, m.end),
];

/// Attached particles stripped before a word is looked up:
/// و (and), ب (with/in), ل/لل (for), ال (the), ف, ك, and their combinations.
const _proclitics = ['وبال', 'وال', 'بال', 'لل', 'ال', 'و', 'ب', 'ل', 'ف', 'ك'];

/// The word itself plus each form with one or two particles stripped.
Set<String> candidates(String norm) {
  final out = {norm};
  void strip(String w, int depth) {
    for (final p in _proclitics) {
      if (w.startsWith(p) && w.length - p.length >= 2) {
        final rest = w.substring(p.length);
        if (out.add(rest) && depth > 0) strip(rest, depth - 1);
      }
    }
  }

  strip(norm, 1);
  return out;
}

/// Words a phrase is made of, folded the same way as tokens.
List<String> phraseWords(String phrase) => [for (final t in tokenize(phrase)) t.norm];

List<List<String>> phrases(List<String> raw) => [
  for (final r in raw)
    if (phraseWords(r).isNotEmpty) phraseWords(r),
];

/// Whether [words] matches the tokens starting at [i]; the first word may
/// carry particles, the rest must be the words themselves or carry particles too.
bool matchesAt(List<Tok> toks, int i, List<String> words, {Set<int> skip = const {}}) {
  if (i + words.length > toks.length) return false;
  for (var k = 0; k < words.length; k++) {
    if (skip.contains(i + k)) return false;
    if (!candidates(toks[i + k].norm).contains(words[k])) return false;
  }
  return true;
}

/// Every place one of [list] matches: (start token, word count).
List<(int, int)> findPhrases(List<Tok> toks, List<List<String>> list, {Set<int> skip = const {}}) => [
  for (var i = 0; i < toks.length; i++)
    for (final p in list)
      if (matchesAt(toks, i, p, skip: skip)) (i, p.length),
];

bool hasPhrase(List<Tok> toks, List<List<String>> list, {Set<int> skip = const {}}) =>
    findPhrases(toks, list, skip: skip).isNotEmpty;

// Intent cues. Each list is matched after folding, so spelling variants of
// hamza, taa marbuta and yaa need not be listed twice.

final kIncomeCues = phrases([
  'استلمت', 'قبضت', 'وصلني', 'وصلتني', 'دخلي', 'راتب', 'راتبي', 'received', 'got paid', 'earned', 'وەرگرت', //
]);
final kTransferCues = phrases(['حولت', 'نقلت', 'transfer', 'transferred', 'moved', 'گواستمەوە', 'ناردم']);
final kExchangeCues = phrases(['صرفت', 'صرفنا', 'exchanged', 'exchange', 'گۆڕیمەوە']);
final kExpenseCues = phrases([
  'دفعت', 'صرفت', 'اشتريت', 'شريت', 'دفعنا', 'paid', 'bought', 'spent', 'دام', 'کڕیم', 'خەرجم کرد', //
]);
final kDebtCues = phrases([
  'سلفه', 'سلفتي', 'دين', 'ديون', 'دينت', 'تسلفت', 'استدنت', 'رجعلي', 'رجعتلي', 'سددت', 'قسط', 'قرض', //
  'owe', 'owes', 'loan', 'lent', 'borrowed', 'repaid', 'paid back', 'paid me back', 'قەرز', //
]);
final kTaskCues = phrases([
  'ذكرني', 'لازم', 'اتصل', 'موعد', 'اجتماع', 'remind', 'call', 'meeting', 'todo', 'بیرم بخەرەوە', 'پەیوەندی', //
]);
final kNoteCues = phrases(['ملاحظه', 'ملاحظات', 'note', 'تێبینی']);

// Changing or removing something already saved.
final kDeleteCues = phrases(['احذف', 'احذفلي', 'امسح', 'امسحلي', 'شيل', 'delete', 'remove', 'بسڕەوە', 'بسرەوە']);
final kEditCues = phrases(['غير', 'غيرلي', 'عدل', 'عدللي', 'صحح', 'change', 'edit', 'fix', 'بگۆڕە', 'چاکی بکە']);
final kExpenseNouns = phrases(['مصروف', 'صرفيه', 'مصرف', 'مصاريف', 'expense', 'خەرجی']);
final kIncomeNouns = phrases(['دخل', 'مدخول', 'وارد', 'income', 'داهات']);

/// Filler around a target: «آخر», «المبلغ», «لـ».
final kTargetFiller = phrases([
  'اخر', 'last', 'المبلغ', 'مبلغ', 'amount', 'the', 'to', 'الى', 'لـ', 'ل', 'من', 'دواین', 'بڕەکە', //
]);

/// Reminder framing dropped from a task's title ("remind me to …").
final kTaskFraming = phrases(['ذكرني', 'ذكريني', 'remind me to', 'remind me', 'بیرم بخەرەوە']);

// Debt direction and leg, from the owner's point of view.
final kOwedToMeRepayment = phrases(['رجعلي', 'رجعتلي', 'paid me back', 'گەڕاندیەوە']);
final kOwedToMePrincipal = phrases(['سلفته', 'دينته', 'lent', 'قەرزم دا']);
final kOwedByMePrincipal = phrases(['تسلفت', 'استدنت', 'borrowed', 'قەرزم کرد']);
final kOwedByMeRepayment = phrases(['سددت', 'قسط', 'repaid', 'paid back']);

/// Small words that never name a person, a place or a thing in a description.
final kStopWords = phrases([
  'من', 'الى', 'لي', 'على', 'عن', 'عند', 'مال', 'هاي', 'to', 'from', 'for', 'me', 'my', 'the', 'بۆ', 'لە', //
]);
