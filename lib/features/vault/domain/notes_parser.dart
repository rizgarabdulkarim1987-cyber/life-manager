import '../../../core/security/sensitive.dart';
import '../../../core/text/digits.dart';

const kNotesImportMaxChars = 200000;
const kNotesImportMaxProposals = 500;
const _maxTitle = 120;

/// One item the parser thinks it found. The owner reviews every proposal
/// before anything is saved (plan Decision 16).
final class NoteProposal {
  const NoteProposal({
    required this.title,
    this.url,
    this.username,
    this.email,
    this.password,
    this.notes,
    this.recoveryCodes,
    required this.category,
  });

  final String title;
  final String? url, username, email;
  final Sensitive<String>? password, notes, recoveryCodes;
  final String category;

  @override
  String toString() => 'NoteProposal(‹redacted›)';
}

enum _Field { site, user, email, password, notes, codes }

const _labels = {
  _Field.user: ['user', 'username', 'login', 'يوزر', 'اليوزر', 'اسم المستخدم', 'ناوی بەکارهێنەر'],
  _Field.email: ['email', 'mail', 'e-mail', 'ايميل', 'الايميل', 'بريد', 'ئیمەیڵ'],
  _Field.password: [
    'pass',
    'password',
    'pw',
    'pwd',
    'باسورد',
    'الباسورد',
    'كلمة السر',
    'كلمه المرور',
    'الرمز',
    'رمز',
    'پاسۆرد',
    'وشەی نهێنی',
  ],
  _Field.site: ['site', 'website', 'url', 'link', 'موقع', 'الموقع', 'رابط', 'ماڵپەڕ'],
  _Field.notes: ['note', 'notes', 'ملاحظة', 'ملاحظات', 'تێبینی'],
  _Field.codes: ['codes', 'backup codes', 'recovery', 'recovery codes', 'رموز', 'كودات', 'کۆدەکان'],
};

final Map<String, _Field> _labelIndex = {
  for (final MapEntry(key: field, value: words) in _labels.entries)
    for (final w in words) _foldLabel(w): field,
};

String _foldLabel(String s) => normalizeForMatch(s).trim().replaceAll(RegExp(r'\s+'), ' ');

/// Keywords → category, checked against the folded title, URL and email.
const _categoryKeywords = <String, List<String>>{
  'social': ['facebook', 'instagram', 'insta', 'انستا', 'فيس', 'tiktok', 'snapchat', 'twitter', 'telegram', 'whatsapp'],
  'email': ['gmail', 'outlook', 'hotmail', 'yahoo', 'proton'],
  'banking': ['bank', 'rafidain', 'rasheed', 'مصرف', 'بنك', 'رافدين', 'رشيد', 'zaincash', 'qicard'],
  'hosting': ['hostinger', 'cpanel', 'hosting', 'vps', 'cloudflare'],
  'domain': ['godaddy', 'namecheap', 'domain', 'دومين'],
  'dev': ['github', 'gitlab', 'bitbucket', 'stackoverflow'],
};

final _separatorLine = RegExp(r'^\s*[-=_*—–~]{3,}\s*$');
final _bullet = RegExp(r'^\s*(?:[•·*]|-(?=\s))\s*');
final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
final _url = RegExp(
  r'^(?:https?://)?(?:www\.)?((?:[a-z0-9-]+\.)+[a-z]{2,})(?::\d+)?(?:[/?#]\S*)?$',
  caseSensitive: false,
);
const _labelSeparators = [':', '：', '=', '-'];
const _maxLabelHead = 30;

bool _isEmail(String s) => _email.hasMatch(s);
bool _isUrl(String s) => !_isEmail(s) && _url.hasMatch(s);
String? _host(String url) => _url.firstMatch(url)?.group(1)?.toLowerCase();

/// Finds `label <sep> value` at the start of [line]. Every separator position
/// is tried left to right, so `e-mail: x` still reads as the email label.
(_Field, String)? _labelled(String line) {
  for (var i = 0; i < line.length && i <= _maxLabelHead; i++) {
    if (!_labelSeparators.contains(line[i])) continue;
    final field = _labelIndex[_foldLabel(line.substring(0, i))];
    if (field != null) return (field, line.substring(i + 1).trim());
  }
  return null;
}

class _Draft {
  String? title, url, username, email, password;
  final notes = <String>[];
  final codes = <String>[];
  bool labelledLogin = false;

  bool get worthKeeping => password != null || labelledLogin;

  NoteProposal build() {
    var t = title ?? (url == null ? null : _host(url!)) ?? email?.split('@').last ?? username ?? email ?? '';
    if (t.runes.length > _maxTitle) t = String.fromCharCodes(t.runes.take(_maxTitle));
    Sensitive<String>? secret(List<String> lines) => lines.isEmpty ? null : Sensitive(lines.join('\n'));
    return NoteProposal(
      title: t,
      url: url,
      username: username,
      email: email,
      password: password == null ? null : Sensitive(password!),
      notes: secret(notes),
      recoveryCodes: secret(codes),
      category: guessVaultCategory('$t ${url ?? ''} ${email ?? ''}'),
    );
  }
}

/// The category whose keyword appears first in the table, else `other`.
String guessVaultCategory(String text) {
  final folded = normalizeForMatch(text);
  for (final MapEntry(key: category, value: words) in _categoryKeywords.entries) {
    if (words.any((w) => folded.contains(normalizeForMatch(w)))) return category;
  }
  return 'other';
}

/// Reads pasted notes into item proposals, locally and without AI (plan
/// Decision 16). Blocks end at blank or separator lines. Labels are matched
/// folded (case, hamza, diacritics); values, passwords above all, are kept as
/// typed apart from surrounding spaces.
List<NoteProposal> parseNotes(String text) {
  if (text.length > kNotesImportMaxChars) {
    throw ArgumentError('notes text is longer than $kNotesImportMaxChars characters');
  }
  final out = <NoteProposal>[];
  var draft = _Draft();
  List<String>? collecting;

  void endBlock() {
    if (draft.worthKeeping) out.add(draft.build());
    draft = _Draft();
    collecting = null;
  }

  for (final raw in text.split(RegExp(r'\r?\n'))) {
    if (out.length >= kNotesImportMaxProposals) break;
    if (raw.trim().isEmpty || _separatorLine.hasMatch(raw)) {
      endBlock();
      continue;
    }
    final line = raw.replaceFirst(_bullet, '').trim();

    final labelled = _labelled(line);
    if (labelled != null) {
      final (field, value) = labelled;
      collecting = null;
      switch (field) {
        case _Field.user:
          if (value.isNotEmpty && draft.username == null) {
            draft.username = value;
            draft.labelledLogin = true;
          }
        case _Field.email:
          if (value.isNotEmpty && draft.email == null) {
            draft.email = value;
            draft.labelledLogin = true;
          }
        case _Field.password:
          if (value.isNotEmpty) draft.password ??= value;
        case _Field.site:
          if (value.isEmpty) break;
          if (_isUrl(value)) {
            draft.url ??= value;
          } else {
            draft.title ??= value;
          }
        case _Field.notes:
          collecting = draft.notes;
          if (value.isNotEmpty) draft.notes.add(value);
        case _Field.codes:
          collecting = draft.codes;
          if (value.isNotEmpty) draft.codes.add(value);
      }
      continue;
    }

    if (collecting != null) {
      collecting!.add(line);
      continue;
    }

    final tokens = line.split(RegExp(r'\s+'));
    if (tokens.length == 3 && _isEmail(tokens[1])) {
      // `site email password` on one line is an item of its own.
      final single = _Draft()
        ..title = tokens[0]
        ..email = tokens[1]
        ..password = tokens[2];
      out.add(single.build());
      continue;
    }
    if (_isUrl(line)) {
      draft.url ??= line;
    } else if (_isEmail(line)) {
      draft.email ??= line;
    } else if (draft.title == null) {
      draft.title = line;
    } else {
      draft.notes.add(line);
    }
  }
  endBlock();
  return out.length > kNotesImportMaxProposals ? out.sublist(0, kNotesImportMaxProposals) : out;
}
