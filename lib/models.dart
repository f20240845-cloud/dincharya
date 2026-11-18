import 'package:flutter/material.dart';

// ---------- ids & date helpers ----------

int _seq = 0;
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_seq++ % 1296).toRadixString(36)}';

String two(int n) => n.toString().padLeft(2, '0');
String dkey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
DateTime parseKey(String k) {
  final p = k.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
DateTime weekStart(DateTime d) => addDays(d, 1 - d.weekday);
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

const wdShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const wdLong = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const monShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const monLong = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September',
  'October', 'November', 'December'
];

String fmtMin(int m) {
  final h = (m ~/ 60) % 24;
  final mm = m % 60;
  final ap = h < 12 ? 'AM' : 'PM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return mm == 0 ? '$h12 $ap' : '$h12:${two(mm)} $ap';
}

String fmtDate(DateTime d) => '${wdShort[d.weekday - 1]}, ${d.day} ${monShort[d.month - 1]}';

String relDate(DateTime d, DateTime now) {
  final diff = dateOnly(d).difference(dateOnly(now)).inHours;
  final days = (diff / 24).round();
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  if (days == -1) return 'Yesterday';
  return fmtDate(d);
}

// ---------- enums ----------

enum TaskStatus { none, done, partial, missed }

double statusScore(TaskStatus s) {
  switch (s) {
    case TaskStatus.done:
      return 1.0;
    case TaskStatus.partial:
      return 0.5;
    default:
      return 0.0;
  }
}

enum Cat { study, quiz, labTest, midsem, compre, assignment, project, personal, health, errand, social }

extension CatX on Cat {
  String get label {
    switch (this) {
      case Cat.study:
        return 'Study';
      case Cat.quiz:
        return 'Quiz';
      case Cat.labTest:
        return 'Lab Test';
      case Cat.midsem:
        return 'Midsem';
      case Cat.compre:
        return 'Compre';
      case Cat.assignment:
        return 'Assignment';
      case Cat.project:
        return 'Project';
      case Cat.personal:
        return 'Personal';
      case Cat.health:
        return 'Health';
      case Cat.errand:
        return 'Errand';
      case Cat.social:
        return 'Social';
    }
  }

  /// Dated academic events that get an automatic "study for" task.
  bool get isExam =>
      this == Cat.quiz ||
      this == Cat.labTest ||
      this == Cat.midsem ||
      this == Cat.compre ||
      this == Cat.assignment;

  bool get isStudy => index <= Cat.assignment.index;

  Color get color {
    switch (this) {
      case Cat.study:
        return const Color(0xFF5B8DEF);
      case Cat.quiz:
        return const Color(0xFFF2A93B);
      case Cat.labTest:
        return const Color(0xFFE67C73);
      case Cat.midsem:
        return const Color(0xFFEF5350);
      case Cat.compre:
        return const Color(0xFFAB47BC);
      case Cat.assignment:
        return const Color(0xFF26A69A);
      case Cat.project:
        return const Color(0xFF7986CB);
      case Cat.personal:
        return const Color(0xFF8D99AE);
      case Cat.health:
        return const Color(0xFF66BB6A);
      case Cat.errand:
        return const Color(0xFFFF8A65);
      case Cat.social:
        return const Color(0xFFEC407A);
    }
  }

  IconData get icon {
    switch (this) {
      case Cat.study:
        return Icons.menu_book_outlined;
      case Cat.quiz:
        return Icons.quiz_outlined;
      case Cat.labTest:
        return Icons.science_outlined;
      case Cat.midsem:
        return Icons.edit_note;
      case Cat.compre:
        return Icons.school_outlined;
      case Cat.assignment:
        return Icons.assignment_outlined;
      case Cat.project:
        return Icons.code;
      case Cat.personal:
        return Icons.person_outline;
      case Cat.health:
        return Icons.fitness_center;
      case Cat.errand:
        return Icons.shopping_bag_outlined;
      case Cat.social:
        return Icons.people_outline;
    }
  }
}

Cat catFromName(String? n) => Cat.values.firstWhere((c) => c.name == n, orElse: () => Cat.personal);
TaskStatus statusFromName(String? n) =>
    TaskStatus.values.firstWhere((c) => c.name == n, orElse: () => TaskStatus.none);

const coursePalette = <Color>[
  Color(0xFF4F9DDE),
  Color(0xFF33B679),
  Color(0xFFE67C73),
  Color(0xFF9E69AF),
  Color(0xFFF6BF26),
  Color(0xFF039BE5),
  Color(0xFFF4511E),
  Color(0xFF7CB342),
  Color(0xFFD81B60),
  Color(0xFF8E24AA),
  Color(0xFF009688),
  Color(0xFFC0A060),
];

// ---------- data classes ----------

class Task {
  String id;
  String title;
  String date; // yyyy-mm-dd
  int? startMin; // null = any time that day
  int durationMin;
  Cat cat;
  String? courseId;
  TaskStatus status;
  String note;
  int? remindMin; // minute of day on [date]; null = no reminder
  String? linkedTo; // exam task this study task was created for
  String? origin; // task this one was copied from
  bool reviewed;

  Task({
    required this.id,
    required this.title,
    required this.date,
    this.startMin,
    this.durationMin = 60,
    this.cat = Cat.personal,
    this.courseId,
    this.status = TaskStatus.none,
    this.note = '',
    this.remindMin,
    this.linkedTo,
    this.origin,
    this.reviewed = false,
  });

  int? get endMin => startMin == null ? null : startMin! + durationMin;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date,
        'startMin': startMin,
        'durationMin': durationMin,
        'cat': cat.name,
        'courseId': courseId,
        'status': status.name,
        'note': note,
        'remindMin': remindMin,
        'linkedTo': linkedTo,
        'origin': origin,
        'reviewed': reviewed,
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: (j['title'] ?? '') as String,
        date: j['date'] as String,
        startMin: j['startMin'] as int?,
        durationMin: (j['durationMin'] ?? 60) as int,
        cat: catFromName(j['cat'] as String?),
        courseId: j['courseId'] as String?,
        status: statusFromName(j['status'] as String?),
        note: (j['note'] ?? '') as String,
        remindMin: j['remindMin'] as int?,
        linkedTo: j['linkedTo'] as String?,
        origin: j['origin'] as String?,
        reviewed: (j['reviewed'] ?? false) as bool,
      );

  Task copy() => Task.fromJson(toJson());
}

class Course {
  String id;
  String name;
  List<String> abbrs;
  int colorIdx;

  Course({required this.id, required this.name, List<String>? abbrs, this.colorIdx = 0})
      : abbrs = abbrs ?? [];

  Color get color => coursePalette[colorIdx % coursePalette.length];
  String get short => abbrs.isNotEmpty ? abbrs.first : name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'abbrs': abbrs, 'colorIdx': colorIdx};
  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        abbrs: ((j['abbrs'] ?? []) as List).map((e) => e.toString()).toList(),
        colorIdx: (j['colorIdx'] ?? 0) as int,
      );
}

class ClassSlot {
  String id;
  String courseId;
  int weekday; // 1 = Monday
  int startMin;
  int endMin;
  String kind; // Lecture / Tutorial / Lab
  String room;

  ClassSlot({
    required this.id,
    required this.courseId,
    required this.weekday,
    required this.startMin,
    required this.endMin,
    this.kind = 'Lecture',
    this.room = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseId': courseId,
        'weekday': weekday,
        'startMin': startMin,
        'endMin': endMin,
        'kind': kind,
        'room': room,
      };
  factory ClassSlot.fromJson(Map<String, dynamic> j) => ClassSlot(
        id: j['id'] as String,
        courseId: j['courseId'] as String,
        weekday: j['weekday'] as int,
        startMin: j['startMin'] as int,
        endMin: j['endMin'] as int,
        kind: (j['kind'] ?? 'Lecture') as String,
        room: (j['room'] ?? '') as String,
      );
}

enum JSection { day, interactions, learnings, mistakes, improvements }

extension JSectionX on JSection {
  String get label {
    switch (this) {
      case JSection.day:
        return 'My day';
      case JSection.interactions:
        return 'Interactions';
      case JSection.learnings:
        return 'Learnings';
      case JSection.mistakes:
        return 'Keep in mind next time';
      case JSection.improvements:
        return 'How I will improve';
    }
  }

  String get emoji {
    switch (this) {
      case JSection.day:
        return '🗓️';
      case JSection.interactions:
        return '🤝';
      case JSection.learnings:
        return '💡';
      case JSection.mistakes:
        return '⚠️';
      case JSection.improvements:
        return '📈';
    }
  }

  Color get color {
    switch (this) {
      case JSection.day:
        return const Color(0xFF5B8DEF);
      case JSection.interactions:
        return const Color(0xFFEC407A);
      case JSection.learnings:
        return const Color(0xFF33B679);
      case JSection.mistakes:
        return const Color(0xFFF2A93B);
      case JSection.improvements:
        return const Color(0xFFAB47BC);
    }
  }
}

JSection sectionFromName(String? n) =>
    JSection.values.firstWhere((c) => c.name == n, orElse: () => JSection.day);

class JournalBlock {
  String id;
  JSection section;
  String text;
  bool star;

  JournalBlock({required this.id, required this.section, required this.text, this.star = false});

  Map<String, dynamic> toJson() => {'id': id, 'section': section.name, 'text': text, 'star': star};
  factory JournalBlock.fromJson(Map<String, dynamic> j) => JournalBlock(
        id: (j['id'] ?? newId()) as String,
        section: sectionFromName(j['section'] as String?),
        text: (j['text'] ?? '') as String,
        star: (j['star'] ?? false) as bool,
      );
}

class Manifestation {
  String id;
  String text;
  String created;
  bool pinned;

  Manifestation({required this.id, required this.text, required this.created, this.pinned = false});

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'created': created, 'pinned': pinned};
  factory Manifestation.fromJson(Map<String, dynamic> j) => Manifestation(
        id: j['id'] as String,
        text: (j['text'] ?? '') as String,
        created: (j['created'] ?? '') as String,
        pinned: (j['pinned'] ?? false) as bool,
      );
}

class Settings {
  Map<String, int> leadDays = {'quiz': 7, 'labTest': 7, 'midsem': 14, 'compre': 21, 'assignment': 3};
  int studyReminderMin = 18 * 60; // reminder time for auto study tasks
  int taskLeadMin = 10; // minutes before a timed task
  bool reviewOn = true;
  int reviewMin = 21 * 60 + 30;
  bool classReminders = false;
  String speechLocale = 'en_IN';
  String theme = 'dark'; // dark / light / system

  Map<String, dynamic> toJson() => {
        'leadDays': leadDays,
        'studyReminderMin': studyReminderMin,
        'taskLeadMin': taskLeadMin,
        'reviewOn': reviewOn,
        'reviewMin': reviewMin,
        'classReminders': classReminders,
        'speechLocale': speechLocale,
        'theme': theme,
      };

  static Settings fromJson(Map<String, dynamic> j) {
    final s = Settings();
    final ld = j['leadDays'];
    if (ld is Map) {
      ld.forEach((k, v) {
        if (v is int) s.leadDays[k.toString()] = v;
      });
    }
    s.studyReminderMin = (j['studyReminderMin'] ?? s.studyReminderMin) as int;
    s.taskLeadMin = (j['taskLeadMin'] ?? s.taskLeadMin) as int;
    s.reviewOn = (j['reviewOn'] ?? s.reviewOn) as bool;
    s.reviewMin = (j['reviewMin'] ?? s.reviewMin) as int;
    s.classReminders = (j['classReminders'] ?? s.classReminders) as bool;
    s.speechLocale = (j['speechLocale'] ?? s.speechLocale) as String;
    s.theme = (j['theme'] ?? s.theme) as String;
    return s;
  }
}

class Reminder {
  final DateTime when;
  final String title;
  final String body;
  const Reminder(this.when, this.title, this.body);
}
