const kMaxActionPoints = 50;

final _bullet = RegExp(r'^\s*(?:[-–—•*▪●·]+|\(?[0-9٠-٩۰-۹]{1,3}[.)\-:]|\(?[a-zA-Z][.)])\s+');
final _sentenceEnd = RegExp(r'(?<=[.!?؟;؛])\s+');

/// Splits pasted text (a meeting note, a WhatsApp message) into candidate tasks:
/// one per line or sentence, bullets and numbering removed, headings ending in
/// a colon dropped, at most [kMaxActionPoints].
List<String> splitActionPoints(String text) {
  final out = <String>[];
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    var line = raw.trim();
    if (line.isEmpty) continue;
    line = line.replaceFirst(_bullet, '').trim();
    if (line.endsWith(':') || line.endsWith('：')) continue;
    for (final part in line.split(_sentenceEnd)) {
      final p = part.trim().replaceFirst(RegExp(r'[.;؛]+$'), '').trim();
      if (p.runes.length >= 2) out.add(p);
    }
  }
  return out.take(kMaxActionPoints).toList();
}
