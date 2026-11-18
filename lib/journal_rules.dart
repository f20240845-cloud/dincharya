// Sorts free journal text into sections using cue words (English, Hindi, Hinglish).
// No AI: plain keyword rules that run on the phone.

import 'models.dart';
import 'parser.dart' show normalizeSpeech;

RegExp _r(String p) => RegExp(p, caseSensitive: false);

final _mistake = _r(
    r"\b(mistakes?|wrong|galti|galat|should\s*n[o']?t\s+have|shouldn'?t|should\s+have|regret\w*|next\s+time|agli\s+baar|agli\s+bar|yaad\s+rakh\w*|keep\s+in\s+mind|remember\s+to|never\s+again|messed\s+up|screwed\s+up|wasted|forgot|bhool\w*|bhul\w*|lesson\s+learn\w*|dobara\s+nahi|careless\w*|procrastinat\w*)\b");
final _learning = _r(
    r'\b(learn(?:ed|t|ing)?|reali[sz]ed?|understood|understand|figured\s+out|found\s+out|discovered|got\s+to\s+know|came\s+to\s+know|seekh\w*|sikh\w*|samajh\w*|pata\s+chal\w*|insight|takeaway|til)\b');
final _improve = _r(
    r"\b(improv\w*|i\s+will|i'll|going\s+to|plan\s+to|planning\s+to|need\s+to|from\s+tomorrow|kal\s+se|aaj\s+se|from\s+now|ab\s+se|goal|target|better|sudhar\w*|karunga|karungi|karna\s+hai|karna\s+chahiye|should\s+start|will\s+start|will\s+try|try\s+to|focus\s+on|work\s+on)\b");
final _interact = _r(
    r"\b(met|meet|talk(?:ed)?|spoke|speak|call(?:ed)?|chat(?:ted)?|discuss(?:ed)?|told|asked|said|friends?|professor|prof|sir|ma'?am|teacher|mom|dad|mummy|papa|brother|sister|bhai|didi|roommate|senior|junior|team|manager|mentor|mila|mili|mile|baat|bola|boli|bataya|puch\w*)\b");

JSection classifySentence(String s) {
  if (_mistake.hasMatch(s)) return JSection.mistakes;
  if (_learning.hasMatch(s)) return JSection.learnings;
  if (_improve.hasMatch(s)) return JSection.improvements;
  if (_interact.hasMatch(s) || RegExp(r'\bwith\s+[A-Z][a-z]+').hasMatch(s)) {
    return JSection.interactions;
  }
  return JSection.day;
}

List<String> _split(String text) {
  return text
      .split(_r(r'[;।\n!?]+\s*|\.(?=\s|$)\s*|\s+(?:and then|aur phir|uske baad|after that)\s+'))
      .map((e) => e.trim())
      .where((e) => e.length >= 2)
      .toList();
}

String _sentence(String s) {
  final t = s.trim();
  if (t.isEmpty) return t;
  final c = t[0].toUpperCase() + t.substring(1);
  return RegExp(r'[.!?।]$').hasMatch(c) ? c : '$c.';
}

/// Splits [text] into blocks, one per run of sentences that belong to the same section.
/// Sentences in "Keep in mind next time" are highlighted.
List<JournalBlock> sortJournal(String text, {Map<String, String> vocab = const {}}) {
  // Apply the user's word list but keep the original script for reading back.
  var t = text;
  vocab.forEach((k, v) {
    final key = k.trim();
    if (key.isEmpty) return;
    t = t.replaceAll(
        RegExp('(?<![A-Za-z0-9])${RegExp.escape(key)}(?![A-Za-z0-9])', caseSensitive: false), v);
  });
  final blocks = <JournalBlock>[];
  for (final piece in _split(t)) {
    // Classify on a normalised copy so Devanagari cue words are understood too.
    final sec = classifySentence(normalizeSpeech(piece, const {}));
    if (blocks.isNotEmpty && blocks.last.section == sec) {
      blocks.last.text = '${blocks.last.text} ${_sentence(piece)}';
    } else {
      blocks.add(JournalBlock(
        id: newId(),
        section: sec,
        text: _sentence(piece),
        star: sec == JSection.mistakes,
      ));
    }
  }
  return blocks;
}

/// Plain-text version for sharing to WhatsApp, ChatGPT and so on.
String journalAsText(DateTime date, List<JournalBlock> blocks) {
  final b = StringBuffer();
  b.writeln('Journal - ${wdLong[date.weekday - 1]}, ${date.day} ${monLong[date.month - 1]} ${date.year}');
  for (final sec in JSection.values) {
    final items = blocks.where((x) => x.section == sec).toList();
    if (items.isEmpty) continue;
    b.writeln();
    b.writeln('${sec.emoji} ${sec.label}');
    for (final x in items) {
      b.writeln('${x.star ? '★ ' : '• '}${x.text}');
    }
  }
  return b.toString().trim();
}
