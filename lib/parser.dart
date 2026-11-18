// Turns spoken or typed text (English, Hindi, Hinglish) into task drafts.
// Pure rules, no network and no AI: everything here runs on the phone.

import 'models.dart';

class Draft {
  String title;
  DateTime date;
  int? startMin;
  int durationMin;
  Cat cat;
  String? courseId;
  bool surprise; // "surprise quiz coming up" -> mark the course's classes that week
  bool hasDate;

  Draft({
    required this.title,
    required this.date,
    this.startMin,
    this.durationMin = 60,
    this.cat = Cat.personal,
    this.courseId,
    this.surprise = false,
    this.hasDate = false,
  });
}

RegExp _r(String p) => RegExp(p, caseSensitive: false);

// Hindi words the recogniser returns in Devanagari -> tokens the rules understand.
const Map<String, String> _dev = {
  'कल': 'kal', 'आज': 'aaj', 'परसों': 'parso', 'बजे': 'baje', 'सुबह': 'subah', 'शाम': 'shaam',
  'रात': 'raat', 'दोपहर': 'dopahar', 'सोमवार': 'monday', 'मंगलवार': 'tuesday', 'बुधवार': 'wednesday',
  'गुरुवार': 'thursday', 'बृहस्पतिवार': 'thursday', 'शुक्रवार': 'friday', 'शनिवार': 'saturday',
  'रविवार': 'sunday', 'इतवार': 'sunday', 'क्विज़': 'quiz', 'क्विज': 'quiz', 'टेस्ट': 'test',
  'लैब': 'lab', 'असाइनमेंट': 'assignment', 'मिडसेम': 'midsem', 'कॉम्प्रे': 'compre',
  'पढ़ाई': 'padhai', 'पढ़ना': 'padhna', 'घंटे': 'ghante', 'घंटा': 'ghanta', 'मिनट': 'minute',
  'साढ़े': 'saadhe', 'सवा': 'sava', 'पौने': 'paune', 'और': 'aur', 'फिर': 'phir', 'अगले': 'agle',
  'हफ्ते': 'hafte', 'हफ़्ते': 'hafte', 'तक': 'tak', 'से': 'se', 'को': 'ko', 'सरप्राइज': 'surprise',
  'सरप्राइज़': 'surprise', 'एक': 'ek', 'दो': 'do', 'तीन': 'teen', 'चार': 'char', 'पांच': 'paanch',
  'पाँच': 'paanch', 'छह': 'chhe', 'छः': 'chhe', 'सात': 'saat', 'आठ': 'aath', 'नौ': 'nau',
  'दस': 'das', 'ग्यारह': 'gyarah', 'बारह': 'barah', 'दिन': 'din', 'बाद': 'baad', 'करना': 'karna',
  'करनी': 'karni', 'है': 'hai', 'मुझे': 'mujhe', 'जिम': 'gym', 'क्लास': 'class', 'सबमिट': 'submit',
  'में': 'mein', 'का': 'ka', 'की': 'ki', 'के': 'ke', 'जाना': 'jana', 'कॉल': 'call',
  'मीटिंग': 'meeting', 'एग्जाम': 'exam', 'प्रोजेक्ट': 'project', 'तारीख': 'tarikh',
};

// The same table with nukta dots removed from the keys, built once.
final Map<String, String> _devPlain = {
  for (final e in _dev.entries)
    e.key
        .replaceAll(String.fromCharCode(0x093C), '')
        .replaceAll(String.fromCharCode(0x095B), String.fromCharCode(0x091C))
        .replaceAll(String.fromCharCode(0x095C), String.fromCharCode(0x0921))
        .replaceAll(String.fromCharCode(0x095D), String.fromCharCode(0x0922)): e.value,
};

const Map<String, int> _nums = {
  'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6, 'seven': 7, 'eight': 8,
  'nine': 9, 'ten': 10, 'eleven': 11, 'twelve': 12, 'ek': 1, 'do': 2, 'teen': 3, 'tin': 3,
  'char': 4, 'chaar': 4, 'paanch': 5, 'panch': 5, 'chhe': 6, 'che': 6, 'chheh': 6, 'saat': 7,
  'aath': 8, 'aat': 8, 'nau': 9, 'das': 10, 'dus': 10, 'gyarah': 11, 'gyaarah': 11, 'barah': 12,
  'baarah': 12,
};

/// Applies the user's own word list, then maps Devanagari digits and common words.
String normalizeSpeech(String text, Map<String, String> vocab) {
  var s = text;
  vocab.forEach((k, v) {
    final key = k.trim();
    if (key.isEmpty) return;
    s = s.replaceAll(
        RegExp('(?<![A-Za-z0-9])${RegExp.escape(key)}(?![A-Za-z0-9])', caseSensitive: false), v);
  });
  const dd = '०१२३४५६७८९';
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll(dd[i], '$i');
  }
  // Look up each Devanagari word; also try it without the nukta dot (ज़ -> ज).
  final nukta = String.fromCharCode(0x093C);
  s = s.replaceAllMapped(RegExp('[${String.fromCharCode(0x0900)}-${String.fromCharCode(0x097F)}]+'), (m) {
    final w = m.group(0)!;
    final plain = w
        .replaceAll(nukta, '')
        .replaceAll(String.fromCharCode(0x095B), String.fromCharCode(0x091C))
        .replaceAll(String.fromCharCode(0x095C), String.fromCharCode(0x0921))
        .replaceAll(String.fromCharCode(0x095D), String.fromCharCode(0x0922));
    return _dev[w] ?? _dev[plain] ?? _devPlain[plain] ?? w;
  });
  // The recogniser writes "5 p.m." - make it "5 pm" so the full stop is not read as a sentence end.
  s = s.replaceAllMapped(_r(r'\b([ap])\.\s?m\b\.?'), (m) => '${m.group(1)}m');
  return s;
}

String _numberWords(String s) {
  final keys = _nums.keys.join('|');
  s = s.replaceAllMapped(
      _r(r'\b(' +
          keys +
          r")\b(?=\s+(?:baje|bje|ghante|ghanta|din|minutes?|mins?|a\.?m|p\.?m|o'?clock|hours?|hrs?|days?)\b)"),
      (m) => '${_nums[m.group(1)!.toLowerCase()]}');
  s = s.replaceAllMapped(
      _r(r'\b(at|by|from|till|until|around)\s+(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\b'),
      (m) => '${m.group(1)} ${_nums[m.group(2)!.toLowerCase()]}');
  return s;
}

const _monPat =
    r'(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)';
const _monIdx = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

const _wdPat =
    r'(monday|mon|tuesday|tues|tue|wednesday|wed|thursday|thurs|thu|friday|fri|saturday|sunday|somvar|somwar|mangalvar|mangalwar|budhvar|budhwar|guruvar|guruwar|shukravar|shukrawar|shanivar|shaniwar|ravivar|raviwar|itwar|itvaar)';

int _weekdayIndex(String w) {
  final x = w.toLowerCase();
  if (x.startsWith('mon') || x.startsWith('som')) return 1;
  if (x.startsWith('tue') || x.startsWith('mangal')) return 2;
  if (x.startsWith('wed') || x.startsWith('budh')) return 3;
  if (x.startsWith('thu') || x.startsWith('guru')) return 4;
  if (x.startsWith('fri') || x.startsWith('shukra')) return 5;
  if (x.startsWith('sat') || x.startsWith('shani')) return 6;
  return 7;
}

// Abbreviations that are also everyday words: only accepted in capitals or next to a study word.
const _riskyAbbr = {
  'or', 'is', 'it', 'do', 'me', 'am', 'an', 'as', 'at', 'be', 'by', 'go', 'he', 'if', 'in', 'my',
  'no', 'of', 'on', 'so', 'to', 'up', 'us', 'we', 'pe', 'se', 'ka', 'ki', 'ko', 'hai', 'the', 'and',
};

class _Hit {
  final Course course;
  final int start;
  final int end;
  _Hit(this.course, this.start, this.end);
}

_Hit? _findCourse(String s, List<Course> courses) {
  _Hit? best;
  void consider(Course c, RegExpMatch? m) {
    if (m == null) return;
    if (best == null || (m.end - m.start) > (best!.end - best!.start)) {
      best = _Hit(c, m.start, m.end);
    }
  }

  for (final c in courses) {
    final name = c.name.trim();
    if (name.length >= 3) {
      final words = name.split(RegExp(r'\s+')).map(RegExp.escape).join(r'\s+');
      consider(c, _r('(?<![A-Za-z0-9])$words(?![A-Za-z0-9])').firstMatch(s));
    }
    for (final raw in c.abbrs) {
      final a = raw.trim();
      if (a.isEmpty) continue;
      final lettersOnly = RegExp(r'^[A-Za-z]{2,5}$').hasMatch(a);
      if (_riskyAbbr.contains(a.toLowerCase())) {
        consider(
            c,
            RegExp('(?<![A-Za-z0-9])${RegExp.escape(a.toUpperCase())}(?![A-Za-z0-9])')
                .firstMatch(s));
        consider(
            c,
            _r('(?<![A-Za-z0-9])${RegExp.escape(a)}(?=\\s+(?:ka|ki|ke)?\\s*(?:surprise|quiz|test|midsem|mid|compre|assignment|lab|class|lecture|tut|exam)\\b)')
                .firstMatch(s));
      } else if (lettersOnly) {
        final spaced = a.split('').map(RegExp.escape).join(r'[\s.]*');
        consider(c, _r('(?<![A-Za-z0-9])$spaced(?![A-Za-z0-9])').firstMatch(s));
      } else {
        final words = a.split(RegExp(r'\s+')).map(RegExp.escape).join(r'\s*');
        consider(c, _r('(?<![A-Za-z0-9])$words(?![A-Za-z0-9])').firstMatch(s));
      }
    }
  }
  return best;
}

const _leadWords = {
  'so', 'ok', 'okay', 'and', 'aur', 'then', 'phir', 'please', 'hey', 'um', 'uh', 'i', "i'm", 'im',
  "i've", "i'll", 'have', 'has', 'need', 'want', 'will', 'should', 'must', 'gotta', 'got', 'to',
  'am', 'going', 'remind', 'me', 'about', 'of', 'add', 'a', 'an', 'the', 'task', 'reminder',
  'there', 'is', "there's", 'mujhe', 'muje', 'mereko', 'we', 'my', 'mera', 'meri', 'for', 'on',
  'also', 'ka', 'ki', 'ke', 'hai', 'ko',
};

const _trailWords = {
  'karna', 'karni', 'karne', 'hai', 'he', 'h', 'hain', 'on', 'at', 'by', 'ko', 'pe', 'par', 'in',
  'for', 'from', 'till', 'until', 'se', 'tak', 'the', 'a', 'is', 'of', 'and', 'aur', 'ka', 'ki',
  'ke', 'bhi', 'also', 'this', 'next', 'coming', 'mein', 'baje', 'wala', 'wali', 'to', 'it', 'due',
};

String _clean(String s) {
  var words = s
      .replaceAll(RegExp(r'[,;:!?।]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty && w != '.' && w != '-')
      .toList();
  while (words.isNotEmpty && _leadWords.contains(words.first.toLowerCase())) {
    words.removeAt(0);
  }
  while (words.isNotEmpty && _trailWords.contains(words.last.toLowerCase())) {
    words.removeLast();
  }
  var out = words.join(' ');
  out = out.replaceAll(RegExp(r'^[\s.\-]+|[\s.\-]+$'), '');
  return out;
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

final _cue = _r(r'\b(study|revise|revision|read|finish|complete|submit|do|go|call|buy|meet|attend|prepare|practice|write|make|clean|pay|send|check|watch|start|work|quiz|test|assignment|midsem|compre|exam|gym|padh\w*|karna|jana|dekhna|likhna|kharid\w*|khareed\w*|milna|tomorrow|today|tonight|kal|aaj|parso|monday|tuesday|wednesday|thursday|friday|saturday|sunday|\d{1,2}\s*(?:am|pm|baje))\b');

List<String> _sentences(String t) {
  return t
      .split(_r(r'[;।\n!?]+\s*|\.(?=\s|$)\s*|\s+(?:and then|aur phir|uske baad|after that|and also)\s+|\s+(?:then|phir)\s+'))
      .map((e) => e.trim())
      .where((e) => e.length >= 2)
      .toList();
}

List<String> _andSplit(String sentence) {
  final parts = sentence.split(_r(r'\s+(?:and|aur|&)\s+'));
  final out = <String>[];
  for (final p in parts) {
    if (p.trim().isEmpty) continue;
    if (out.isEmpty || _cue.hasMatch(p)) {
      out.add(p.trim());
    } else {
      out[out.length - 1] = '${out.last} and ${p.trim()}';
    }
  }
  return out;
}

Draft? _parseSegment(String seg, DateTime now, List<Course> courses) {
  var s = ' ${_numberWords(seg)} ';
  void mask(int a, int b) {
    s = s.replaceRange(a, b, ' ' * (b - a));
  }

  final today = dateOnly(now);
  final nowMin = now.hour * 60 + now.minute;
  DateTime? date;
  int? start;
  int? dur;
  RegExpMatch? m;

  // Part of day, used to decide AM/PM.
  var q = '';
  if (_r(r'\b(morning|subah|subha|savere)\b').hasMatch(s)) {
    q = 'am';
  } else if (_r(r'\b(afternoon|dopahar)\b').hasMatch(s)) {
    q = 'noon';
  } else if (_r(r'\b(evening|shaam|sham)\b').hasMatch(s)) {
    q = 'pm';
  } else if (_r(r'\b(night|raat|tonight)\b').hasMatch(s)) {
    q = 'night';
  }

  // "in 2 hours", "2 ghante baad"
  m = _r(r'\bin\s+(\d+)\s*(?:hours?|hrs?)\b').firstMatch(s) ??
      _r(r'\b(\d+)\s*(?:ghante|ghanta)\s+(?:baad|bad|mein|me)\b').firstMatch(s);
  if (m != null) {
    final t = now.add(Duration(hours: int.parse(m.group(1)!)));
    date = dateOnly(t);
    start = ((t.hour * 60 + t.minute) ~/ 5) * 5;
    mask(m.start, m.end);
  }

  // Durations
  m = _r(r'\b(?:for\s+)?(?:half\s+an?\s+hour|half\s+hour|aadha\s+ghanta|adha\s+ghanta)\b').firstMatch(s);
  if (m != null) {
    dur = 30;
    mask(m.start, m.end);
  }
  m = _r(r'\b(?:for\s+)?(dedh|dhai)\s+(?:ghante|ghanta)\b').firstMatch(s);
  if (m != null) {
    dur = m.group(1)!.toLowerCase() == 'dedh' ? 90 : 150;
    mask(m.start, m.end);
  }
  m = _r(r'\b(?:for\s+)?(\d+(?:\.\d+)?)\s*(?:hours?|hrs?|hr|ghante|ghanta)\b').firstMatch(s);
  if (m != null) {
    dur = (double.parse(m.group(1)!) * 60).round();
    mask(m.start, m.end);
  }
  m = _r(r'\b(?:for\s+)?(\d+)\s*(?:minutes?|mins?)\b').firstMatch(s);
  if (m != null) {
    dur = (dur ?? 0) + int.parse(m.group(1)!);
    mask(m.start, m.end);
  }

  // ---- Dates ----
  m = _r(r'\b(?:day\s+after\s+tomorrow|parson?)\b').firstMatch(s);
  if (m != null) {
    date ??= addDays(today, 2);
    mask(m.start, m.end);
  }
  if (date == null) {
    m = _r(r'\b(\d{1,2})\s*/\s*(\d{1,2})(?:\s*/\s*(\d{2,4}))?(?!\d)').firstMatch(s);
    if (m != null) {
      final d = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      if (d >= 1 && d <= 31 && mo >= 1 && mo <= 12) {
        var y = now.year;
        final yg = m.group(3);
        if (yg != null) {
          y = int.parse(yg);
          if (y < 100) y += 2000;
        }
        var dt = DateTime(y, mo, d);
        if (yg == null && dt.isBefore(addDays(today, -30))) dt = DateTime(y + 1, mo, d);
        date = dt;
        mask(m.start, m.end);
      }
    }
  }
  if (date == null) {
    int? d;
    String? mon;
    m = _r(r'\b(\d{1,2})(?:st|nd|rd|th)?\s+(?:of\s+)?' + _monPat + r'\b').firstMatch(s);
    if (m != null) {
      d = int.parse(m.group(1)!);
      mon = m.group(2);
    } else {
      m = _r(r'\b' + _monPat + r'\s+(\d{1,2})(?:st|nd|rd|th)?\b').firstMatch(s);
      if (m != null) {
        mon = m.group(1);
        d = int.parse(m.group(2)!);
      }
    }
    if (m != null && d != null && mon != null && d >= 1 && d <= 31) {
      final mo = _monIdx.indexOf(mon.toLowerCase().substring(0, 3)) + 1;
      var dt = DateTime(now.year, mo, d);
      if (dt.isBefore(addDays(today, -30))) dt = DateTime(now.year + 1, mo, d);
      date = dt;
      mask(m.start, m.end);
    }
  }
  if (date == null) {
    m = _r(r'\b(?:the\s+)?(\d{1,2})(?:st|nd|rd|th)\b').firstMatch(s) ??
        _r(r'\b(\d{1,2})\s*(?:tarikh|tareekh|tarik)\b').firstMatch(s);
    if (m != null) {
      final d = int.parse(m.group(1)!);
      if (d >= 1 && d <= 31) {
        var dt = DateTime(now.year, now.month, d);
        if (dt.isBefore(today)) dt = DateTime(now.year, now.month + 1, d);
        date = dt;
        mask(m.start, m.end);
      }
    }
  }
  if (date == null) {
    m = _r(r'\bin\s+(\d+)\s+days?\b').firstMatch(s) ??
        _r(r'\b(\d+)\s+din\s+(?:mein|me|baad|bad)\b').firstMatch(s);
    if (m != null) {
      date = addDays(today, int.parse(m.group(1)!));
      mask(m.start, m.end);
    }
  }
  var nextWeek = false;
  m = _r(r'\b(?:next\s+week|agle\s+hafte|agle\s+week)\b').firstMatch(s);
  if (m != null) {
    nextWeek = true;
    mask(m.start, m.end);
  }
  if (date == null) {
    m = _r(r'\b(?:(next|this|coming|agle|agli|is)\s+)?' + _wdPat + r'\b').firstMatch(s);
    if (m != null) {
      final idx = _weekdayIndex(m.group(2)!);
      final pre = (m.group(1) ?? '').toLowerCase();
      if (nextWeek || pre == 'next' || pre == 'agle' || pre == 'agli') {
        date = addDays(weekStart(today), 7 + idx - 1);
      } else {
        var diff = (idx - today.weekday) % 7;
        if (diff < 0) diff += 7;
        if (diff == 0 && pre != 'this' && pre != 'is') diff = 7;
        date = addDays(today, diff);
      }
      mask(m.start, m.end);
    }
  }
  if (date == null && nextWeek) date = addDays(today, 7);
  m = _r(r'\b(?:tomorrow|tmrw|tmr|kal)\b').firstMatch(s);
  if (m != null) {
    date ??= addDays(today, 1);
    mask(m.start, m.end);
  }
  m = _r(r'\b(?:today|aaj|tonight)\b').firstMatch(s);
  if (m != null) {
    date ??= today;
    mask(m.start, m.end);
  }
  final hasDate = date != null;
  final onDate = date ?? today;

  // ---- Times ----
  int resolve(int h, int mi, String? ap) {
    if (ap != null && ap.isNotEmpty) {
      final pm = ap.toLowerCase().startsWith('p');
      if (h == 12) {
        h = pm ? 12 : 0;
      } else if (pm) {
        h += 12;
      }
      return h * 60 + mi;
    }
    if (h > 12 || h == 0) return (h % 24) * 60 + mi;
    if (q == 'am') return (h == 12 ? 0 : h) * 60 + mi;
    if (q == 'noon') return (h == 12 ? 12 : (h <= 6 ? h + 12 : h)) * 60 + mi;
    if (q == 'pm') return (h == 12 ? 12 : h + 12) * 60 + mi;
    if (q == 'night') {
      if (h == 12) return mi;
      if (h <= 4) return h * 60 + mi;
      return (h + 12) * 60 + mi;
    }
    if (h == 12) return 12 * 60 + mi;
    if (h <= 6) return (h + 12) * 60 + mi;
    final am = h * 60 + mi;
    if (sameDay(onDate, now) && am <= nowMin) return am + 720;
    return am;
  }

  const ap = r'(a\.?m\.?|p\.?m\.?)';
  int? end;
  if (start == null) {
    m = _r(r'\b(?:from|between)\s+(\d{1,2})(?:[:.](\d{2}))?\s*' +
                ap +
                r'?\s*(?:to|and|-|–|till|until|se)\s*(\d{1,2})(?:[:.](\d{2}))?\s*' +
                ap +
                r'?(?![a-z0-9])')
            .firstMatch(s) ??
        _r(r'\b(\d{1,2})(?:[:.](\d{2}))?\s*' +
                ap +
                r'?\s*(?:to|se|-|–|till)\s*(\d{1,2})(?:[:.](\d{2}))?\s*(a\.?m\.?|p\.?m\.?|baje|bje)(?:\s+tak)?(?![a-z0-9])')
            .firstMatch(s);
    if (m != null) {
      final h1 = int.parse(m.group(1)!);
      final m1 = int.tryParse(m.group(2) ?? '') ?? 0;
      final h2 = int.parse(m.group(4)!);
      final m2 = int.tryParse(m.group(5) ?? '') ?? 0;
      var ap1 = m.group(3);
      var ap2 = m.group(6);
      if (ap2 != null && !RegExp(r'^[aApP]').hasMatch(ap2)) ap2 = null; // "baje"
      if (h1 <= 23 && h2 <= 23 && m1 <= 59 && m2 <= 59) {
        var e = resolve(h2, m2, ap2 ?? ap1);
        var st = resolve(h1, m1, ap1 ?? ap2);
        if (st >= e && st - 720 >= 0) st -= 720;
        if (e <= st) e += 720;
        if (e > st && e - st <= 12 * 60) {
          start = st;
          end = e;
          mask(m.start, m.end);
        }
      }
    }
  }
  if (start == null) {
    final found = <List<int>>[]; // [position, minutes]
    for (final mm in _r(r'\b(\d{1,2})[:.](\d{2})\s*' + ap + r'?(?![a-z0-9])').allMatches(s).toList()) {
      final h = int.parse(mm.group(1)!);
      final mi = int.parse(mm.group(2)!);
      if (h <= 23 && mi <= 59) {
        found.add([mm.start, resolve(h, mi, mm.group(3))]);
        mask(mm.start, mm.end);
      }
    }
    for (final mm in _r(r'\b(\d{1,2})\s*' + ap + r'(?![a-z0-9])').allMatches(s).toList()) {
      final h = int.parse(mm.group(1)!);
      if (h >= 1 && h <= 12) {
        found.add([mm.start, resolve(h, 0, mm.group(2))]);
        mask(mm.start, mm.end);
      }
    }
    for (final mm in _r(r"\b(?:(saadhe|sadhe|saade|sava|sawa|paune|pone)\s+)?(\d{1,2})\s*(?:baje|bje|o'?clock)\b")
        .allMatches(s)
        .toList()) {
      final h = int.parse(mm.group(2)!);
      if (h <= 23) {
        var t = resolve(h, 0, null);
        final pre = (mm.group(1) ?? '').toLowerCase();
        if (pre.startsWith('sa') && pre.contains('dh') || pre == 'saade') {
          t += 30;
        } else if (pre == 'sava' || pre == 'sawa') {
          t += 15;
        } else if (pre == 'paune' || pre == 'pone') {
          t -= 15;
        }
        found.add([mm.start, t]);
        mask(mm.start, mm.end);
      }
    }
    for (final mm in _r(r'\b(?:at|by|around)\s+(\d{1,2})\b(?!\s*(?:st|nd|rd|th|%|/|days?|din|hours?|chapters?|marks?|pages?))')
        .allMatches(s)
        .toList()) {
      final h = int.parse(mm.group(1)!);
      if (h <= 23) {
        found.add([mm.start, resolve(h, 0, null)]);
        mask(mm.start, mm.end);
      }
    }
    if (found.isNotEmpty) {
      found.sort((a, b) => a[0].compareTo(b[0]));
      start = found.first[1];
    }
  }
  // Part-of-day words: drop from the title, and use as a time when no clock time was said.
  final qm = _r(r'\b(?:in\s+the\s+|at\s+)?(morning|subah|subha|savere|afternoon|dopahar|evening|shaam|sham|night|raat)\b(?:\s+(?:ko|mein|me))?')
      .firstMatch(s);
  if (qm != null && (start != null || _r(r'\b(?:in\s+the|at|ko|mein|me)\b').hasMatch(qm.group(0)!))) {
    mask(qm.start, qm.end);
  }
  if (start == null && q.isNotEmpty) {
    final explicit = _r(r'\b(tonight|in\s+the\s+(?:morning|afternoon|evening)|at\s+night|subah|shaam|sham|raat|dopahar|savere)\b')
        .hasMatch(' $seg ');
    if (explicit) {
      start = q == 'am'
          ? 8 * 60
          : q == 'noon'
              ? 14 * 60
              : q == 'pm'
                  ? 18 * 60
                  : 21 * 60;
      final lm = _r(r'\b(subah|subha|savere|dopahar|shaam|sham|raat)\b').firstMatch(s);
      if (lm != null) mask(lm.start, lm.end);
    }
  }
  if (start != null) start = start.clamp(0, 23 * 60 + 55).toInt();
  if (end != null && start != null) dur = end - start;

  // Look for the course before category words are blanked out.
  final hit = _findCourse(s, courses);

  // ---- Category ----
  var cat = Cat.personal;
  var explicitCat = false;
  var surprise = false;
  m = _r(r'\bsurprise\s+(?:quiz(?:zes)?|tests?)\b').firstMatch(s);
  if (m != null) {
    cat = Cat.quiz;
    surprise = true;
    explicitCat = true;
    mask(m.start, m.end);
  }
  if (!explicitCat) {
    final exam = <MapEntry<Cat, String>>[
      const MapEntry(Cat.labTest, r'\b(?:lab\s+(?:test|exam|quiz|eval\w*)|practical\s+exam|lab\s+compre)\b'),
      const MapEntry(Cat.midsem, r'\b(?:mid\s*-?\s*sem(?:ester)?s?|mid\s*-?\s*terms?|mid\s+exams?|mids)\b'),
      const MapEntry(Cat.compre, r'\b(?:compre(?:hensive)?s?|final\s+exams?|finals|end\s*-?\s*sem(?:ester)?s?)\b'),
      const MapEntry(Cat.quiz, r'\b(?:quiz(?:zes)?|class\s+test|tut\s+test|tests?|exam)\b'),
      const MapEntry(Cat.assignment, r'\b(?:assignments?|submission|homework|hw|lab\s+report|project\s+report|deadline)\b'),
    ];
    for (final e in exam) {
      m = _r(e.value).firstMatch(s);
      if (m != null) {
        cat = e.key;
        explicitCat = true;
        mask(m.start, m.end);
        break;
      }
    }
  }
  if (!explicitCat) {
    final soft = <MapEntry<Cat, String>>[
      const MapEntry(Cat.study, r'\b(?:study|revise|revision|padhai|padh\w*|read|practice|pyqs?|lecture|notes|tutorial|tut|prepare|prep|chapter|class)\b'),
      const MapEntry(Cat.health, r'\b(?:gym|workout|run|running|jog|jogging|walk|yoga|exercise|doctor|medicine|football|cricket|badminton|sports|swim\w*|meditat\w*)\b'),
      const MapEntry(Cat.errand, r'\b(?:buy|purchase|shopping|kharid\w*|khareed\w*|laundry|clean|recharge|pay|bill|bank|atm|order|pick\s+up|collect|print|xerox|haircut|groceries)\b'),
      const MapEntry(Cat.social, r'\b(?:call|meet|milna|milne|party|birthday|hangout|dinner|lunch|mom|dad|mummy|papa|friends?)\b'),
      const MapEntry(Cat.project, r'\b(?:internship|intern|project|code|coding|deploy|meeting|standup|research|paper|bug|pr)\b'),
    ];
    for (final e in soft) {
      if (_r(e.value).hasMatch(s)) {
        cat = e.key;
        break;
      }
    }
  }

  // ---- Course ----
  Course? course;
  if (hit != null) {
    course = hit.course;
    if (cat.isExam) {
      mask(hit.start, hit.end);
    } else {
      s = s.replaceRange(hit.start, hit.end, course.short);
      if (cat == Cat.personal) cat = Cat.study;
    }
  }

  // ---- Title ----
  var rest = _clean(s);
  if (cat.isExam) {
    const noise = {
      'submit', 'give', 'write', 'attempt', 'dena', 'deni', 'likhna', 'have', 'has', 'is', 'there',
      'coming', 'up', 'hai', 'karna', 'karni', 'wala', 'wali', 'hone', 'hoga', 'hogi', 'due',
    };
    rest = _clean(rest.split(' ').where((w) => !noise.contains(w.toLowerCase())).join(' '));
  }
  String title;
  if (cat.isExam) {
    final head = [if (course != null) course.short, surprise ? 'Surprise Quiz' : cat.label].join(' ');
    title = (rest.isEmpty || rest.length > 48) ? head : '$head: $rest';
  } else if (rest.isEmpty) {
    if (course == null) return null;
    title = 'Study ${course.short}';
  } else {
    title = _cap(rest);
  }

  return Draft(
    title: title,
    date: onDate,
    startMin: start,
    durationMin: (dur != null && dur > 0) ? dur : 60,
    cat: cat,
    courseId: course?.id,
    surprise: surprise,
    hasDate: hasDate,
  );
}

/// Main entry point: free text in, one draft per task out.
List<Draft> parseTasks(
  String text, {
  required DateTime now,
  List<Course> courses = const [],
  Map<String, String> vocab = const {},
}) {
  final norm = normalizeSpeech(text, vocab);
  final out = <Draft>[];
  for (final sentence in _sentences(norm)) {
    final group = <Draft>[];
    for (final piece in _andSplit(sentence)) {
      final d = _parseSegment(piece, now, courses);
      if (d != null) group.add(d);
    }
    // Tasks joined by "and" share a date said once: "DD quiz and OOP assignment tomorrow".
    DateTime? last;
    for (final d in group) {
      if (d.hasDate) {
        last = d.date;
      } else if (last != null) {
        d.date = last;
        d.hasDate = true;
      }
    }
    DateTime? next;
    for (final d in group.reversed) {
      if (d.hasDate) {
        next = d.date;
      } else if (next != null) {
        d.date = next;
        d.hasDate = true;
      }
    }
    out.addAll(group);
  }
  return out;
}
