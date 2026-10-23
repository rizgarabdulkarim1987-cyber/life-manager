import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/vault/domain/notes_parser.dart';

void main() {
  test('labelled English block', () {
    final p = parseNotes('Facebook\nUsername: ahmed.k\nEmail: ahmed@example.com\nPassword: S3cret!pass\n').single;
    expect(p.title, 'Facebook');
    expect(p.username, 'ahmed.k');
    expect(p.email, 'ahmed@example.com');
    expect(p.password!.value, 'S3cret!pass');
    expect(p.category, 'social');
  });

  test('Iraqi Arabic labels with : and =', () {
    final p = parseNotes('حساب الانستا\nاليوزر: ahmed\nالباسورد = 1234abcd').single;
    expect(p.title, 'حساب الانستا');
    expect(p.username, 'ahmed');
    expect(p.password!.value, '1234abcd');
  });

  test('label variants fold hamza, taa marbuta and case', () {
    final p = parseNotes('ألإيميل : x@y.com\nكلمة المرور: pw-pw-pw\nPASSWORD: ignored-second').single;
    expect(p.email, 'x@y.com');
    expect(p.password!.value, 'pw-pw-pw');
  });

  test('Sorani labels', () {
    final p = parseNotes('ماڵپەڕ: hostinger.com\nئیمەیڵ: rizgar@example.com\nوشەی نهێنی: Hh-778899').single;
    expect(p.url, 'hostinger.com');
    expect(p.title, 'hostinger.com');
    expect(p.email, 'rizgar@example.com');
    expect(p.password!.value, 'Hh-778899');
    expect(p.category, 'hosting');
  });

  test('single line: site email password', () {
    final p = parseNotes('gmail ahmed@gmail.com Pa55word!').single;
    expect(p.title, 'gmail');
    expect(p.email, 'ahmed@gmail.com');
    expect(p.password!.value, 'Pa55word!');
    expect(p.category, 'email');
  });

  test('several single-line entries in one block give one proposal each', () {
    final ps = parseNotes('gmail a@gmail.com pw1pw1pw1\noutlook b@outlook.com pw2pw2pw2');
    expect(ps.map((p) => p.title), ['gmail', 'outlook']);
    expect(ps.map((p) => p.password!.value), ['pw1pw1pw1', 'pw2pw2pw2']);
  });

  test('URLs with and without scheme become the url; the title is the host', () {
    final a = parseNotes('https://www.github.com/login\nuser: dev1\npass: x1x1x1x1').single;
    expect(a.url, 'https://www.github.com/login');
    expect(a.title, 'github.com');
    expect(a.category, 'dev');
    final b = parseNotes('namecheap.com\nuser: dev2\npass: y2y2y2y2').single;
    expect(b.url, 'namecheap.com');
    expect(b.title, 'namecheap.com');
    expect(b.category, 'domain');
  });

  test('blocks separated by --- or by blank lines', () {
    const text =
        'Site A\nuser: a\npass: aaaa1111\n---\nSite B\nuser: b\npass: bbbb2222\n\n\nSite C\nuser: c\npass: cccc3333';
    expect(parseNotes(text).map((p) => p.title), ['Site A', 'Site B', 'Site C']);
  });

  test('a shopping list gives no proposals', () {
    expect(parseNotes('شراء\nحليب\nخبز 2\nبيض - 30\n\nتلفون للصيانة'), isEmpty);
  });

  test('a block with only a bare email gives nothing; with a labelled one it does', () {
    expect(parseNotes('Call Ali\nali@example.com'), isEmpty);
    expect(parseNotes('Ali shop\nemail: ali@example.com').single.email, 'ali@example.com');
  });

  test('passwords keep Arabic-Indic digits and inner spaces exactly as typed', () {
    final p = parseNotes('بنك الرافدين\nيوزر: ١٢٣\nرمز: ٤٥٦ ٧٨٩').single;
    expect(p.password!.value, '٤٥٦ ٧٨٩');
    expect(p.username, '١٢٣');
    expect(p.category, 'banking');
  });

  test('notes and recovery codes collect their following lines', () {
    final p = parseNotes(
      'GitHub\nuser: octo\npassword: pw12pw12\nbackup codes:\nAAAA-1111\nBBBB-2222\nnotes: two-factor on\nphone in drawer',
    ).single;
    expect(p.recoveryCodes!.value, 'AAAA-1111\nBBBB-2222');
    expect(p.notes!.value, 'two-factor on\nphone in drawer');
  });

  test('bullets before labels are ignored; a dash inside a label still works', () {
    final p = parseNotes('• e-mail: q@q.io\n- pass: qqqq9999').single;
    expect(p.email, 'q@q.io');
    expect(p.password!.value, 'qqqq9999');
  });

  test('a block without a title takes it from the email domain or the username', () {
    expect(parseNotes('email: z@proton.me\npass: zzzz0000').single.title, 'proton.me');
    expect(parseNotes('user: zed\npass: zzzz0000').single.title, 'zed');
  });

  test('long titles are cut to 120 characters', () {
    expect(parseNotes('${'T' * 300}\npass: 12341234').single.title.length, 120);
  });

  test('at most 500 proposals', () {
    final text = List.generate(600, (i) => 'site$i a$i@x.com pw$i-pw$i').join('\n');
    expect(parseNotes(text).length, 500);
  });

  test('text over 200 000 characters is refused', () {
    expect(() => parseNotes('a' * 200001), throwsArgumentError);
    expect(parseNotes('a' * 200000), isEmpty);
  });

  test('toString hides the password and notes', () {
    final p = parseNotes('X\npass: marker-pw-1\nnotes: marker-note-1').single;
    expect(p.toString(), isNot(contains('marker')));
  });
}
