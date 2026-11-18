import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';
import 'notifications.dart';
import 'parser.dart';

/// All app data, kept in one JSON file on the phone.
class AppState extends ChangeNotifier {
  List<Task> tasks = [];
  List<Course> courses = [];
  List<ClassSlot> slots = [];
  Set<String> surprises = {}; // "courseId|weekStartKey"
  Map<String, List<JournalBlock>> journal = {};
  List<Manifestation> manifests = [];
  Map<String, String> vocab = {};
  Settings settings = Settings();

  File? _file;
  Timer? _saveTimer;
  Timer? _syncTimer;
  bool loaded = false;

  // ---------- persistence ----------

  Future<void> load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/dincharya.json');
      if (await _file!.exists()) {
        final raw = await _file!.readAsString();
        if (raw.trim().isNotEmpty) fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('load failed: $e');
    }
    loaded = true;
    notifyListeners();
    _scheduleSync();
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'courses': courses.map((e) => e.toJson()).toList(),
        'slots': slots.map((e) => e.toJson()).toList(),
        'surprises': surprises.toList(),
        'journal': journal.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList())),
        'manifests': manifests.map((e) => e.toJson()).toList(),
        'vocab': vocab,
        'settings': settings.toJson(),
      };

  void fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> list(String k) =>
        ((j[k] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    tasks = list('tasks').map(Task.fromJson).toList();
    courses = list('courses').map(Course.fromJson).toList();
    slots = list('slots').map(ClassSlot.fromJson).toList();
    surprises = ((j['surprises'] ?? []) as List).map((e) => e.toString()).toSet();
    journal = {};
    final jj = j['journal'];
    if (jj is Map) {
      jj.forEach((k, v) {
        journal[k.toString()] = (v as List)
            .map((e) => JournalBlock.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      });
    }
    manifests = list('manifests').map(Manifestation.fromJson).toList();
    vocab = {};
    final vv = j['vocab'];
    if (vv is Map) vv.forEach((k, v) => vocab[k.toString()] = v.toString());
    final ss = j['settings'];
    settings = ss is Map ? Settings.fromJson(Map<String, dynamic>.from(ss)) : Settings();
  }

  /// Call after any change: refreshes the UI, saves, and re-plans reminders.
  void touch() {
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), _save);
    _scheduleSync();
  }

  Future<void> _save() async {
    final f = _file;
    if (f == null) return;
    try {
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(toJson()), flush: true);
      await tmp.rename(f.path);
    } catch (e) {
      debugPrint('save failed: $e');
    }
  }

  String exportJson() => const JsonEncoder.withIndent(' ').convert(toJson());

  bool importJson(String raw) {
    try {
      final j = jsonDecode(raw);
      if (j is! Map || j['tasks'] is! List) return false;
      fromJson(Map<String, dynamic>.from(j));
      touch();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _scheduleSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 2), () {
      Notifier.sync(
        upcomingReminders(DateTime.now()),
        dailyReviewMin: settings.reviewOn ? settings.reviewMin : null,
      );
    });
  }

  // ---------- courses & timetable ----------

  Course? courseById(String? id) {
    if (id == null) return null;
    for (final c in courses) {
      if (c.id == id) return c;
    }
    return null;
  }

  void saveCourse(Course c) {
    final i = courses.indexWhere((e) => e.id == c.id);
    if (i >= 0) {
      courses[i] = c;
    } else {
      courses.add(c);
    }
    touch();
  }

  void deleteCourse(String id) {
    courses.removeWhere((c) => c.id == id);
    slots.removeWhere((s) => s.courseId == id);
    surprises.removeWhere((s) => s.startsWith('$id|'));
    for (final t in tasks) {
      if (t.courseId == id) t.courseId = null;
    }
    touch();
  }

  void saveSlot(ClassSlot s) {
    final i = slots.indexWhere((e) => e.id == s.id);
    if (i >= 0) {
      slots[i] = s;
    } else {
      slots.add(s);
    }
    touch();
  }

  void deleteSlot(String id) {
    slots.removeWhere((s) => s.id == id);
    touch();
  }

  List<ClassSlot> classesOn(DateTime d) {
    final out = slots.where((s) => s.weekday == d.weekday && courseById(s.courseId) != null).toList();
    out.sort((a, b) => a.startMin.compareTo(b.startMin));
    return out;
  }

  String _sKey(String courseId, DateTime d) => '$courseId|${dkey(weekStart(d))}';
  bool isSurprise(String courseId, DateTime d) => surprises.contains(_sKey(courseId, d));

  void setSurprise(String courseId, DateTime d, bool on) {
    if (on) {
      surprises.add(_sKey(courseId, d));
    } else {
      surprises.remove(_sKey(courseId, d));
    }
    touch();
  }

  // ---------- tasks ----------

  List<Task> tasksOn(String key) {
    final out = tasks.where((t) => t.date == key).toList();
    out.sort((a, b) {
      final x = a.startMin ?? 100000;
      final y = b.startMin ?? 100000;
      if (x != y) return x.compareTo(y);
      return a.title.compareTo(b.title);
    });
    return out;
  }

  Task? taskById(String? id) {
    if (id == null) return null;
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  int? defaultReminder(Task t) {
    if (t.startMin == null) return null;
    final r = t.startMin! - settings.taskLeadMin;
    return r < 0 ? 0 : r;
  }

  void addTask(Task t, {bool withPrep = true}) {
    tasks.add(t);
    if (withPrep && t.cat.isExam) _addPrep(t);
    touch();
  }

  void updateTask(Task t, {String? oldDate, Cat? oldCat}) {
    final i = tasks.indexWhere((e) => e.id == t.id);
    if (i < 0) return;
    tasks[i] = t;
    if ((oldDate != null && oldDate != t.date) || (oldCat != null && oldCat != t.cat)) {
      tasks.removeWhere((e) => e.linkedTo == t.id && e.status == TaskStatus.none);
      if (t.cat.isExam) _addPrep(t);
    }
    touch();
  }

  void deleteTask(String id) {
    tasks.removeWhere((e) => e.id == id || (e.linkedTo == id && e.status == TaskStatus.none));
    touch();
  }

  void setStatus(Task t, TaskStatus s) {
    t.status = t.status == s ? TaskStatus.none : s;
    touch();
  }

  /// A quiz, test, exam or assignment gets a study task some days earlier, with a reminder.
  void _addPrep(Task exam) {
    final lead = settings.leadDays[exam.cat.name] ?? 7;
    if (lead <= 0) return;
    final today = dateOnly(DateTime.now());
    final examDay = parseKey(exam.date);
    var d = addDays(examDay, -lead);
    if (d.isBefore(today)) d = today;
    if (!d.isBefore(examDay)) return;
    final verb = exam.cat == Cat.assignment ? 'Start' : 'Study for';
    tasks.add(Task(
      id: newId(),
      title: '$verb ${exam.title}',
      date: dkey(d),
      cat: Cat.study,
      courseId: exam.courseId,
      remindMin: settings.studyReminderMin,
      linkedTo: exam.id,
      note: '${exam.cat.label} on ${fmtDate(examDay)}',
    ));
  }

  /// "Add this task on other days": copies it, unmarked, to each chosen day.
  void copyToDays(Task t, List<DateTime> days) {
    for (final d in days) {
      final c = t.copy()
        ..id = newId()
        ..date = dkey(d)
        ..status = TaskStatus.none
        ..reviewed = false
        ..linkedTo = null
        ..origin = t.id;
      tasks.add(c);
    }
    t.reviewed = true;
    touch();
  }

  void markReviewed(Iterable<Task> ts) {
    for (final t in ts) {
      t.reviewed = true;
    }
    touch();
  }

  /// Tasks that were not ticked and have not been looked at in the evening review.
  List<Task> pendingReview(DateTime now) {
    final today = dkey(now);
    final floor = dkey(addDays(now, -7));
    final nowMin = now.hour * 60 + now.minute;
    final out = tasks.where((t) {
      if (t.reviewed || t.status == TaskStatus.done) return false;
      if (t.date.compareTo(today) < 0) return t.date.compareTo(floor) >= 0;
      if (t.date == today) return nowMin >= settings.reviewMin;
      return false;
    }).toList();
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  /// 0..1 for the day, or null when the day has no tasks. Tick = 1, ~ = 0.5, cross = 0.
  double? dayScore(String key) {
    var n = 0;
    var sum = 0.0;
    for (final t in tasks) {
      if (t.date != key) continue;
      n++;
      sum += statusScore(t.status);
    }
    return n == 0 ? null : sum / n;
  }

  int dayCount(String key) => tasks.where((t) => t.date == key).length;

  // ---------- voice drafts ----------

  /// Saves drafts from the voice sheet. Returns a short summary line.
  String commitDrafts(List<Draft> drafts) {
    var added = 0;
    var flagged = 0;
    for (final d in drafts) {
      if (d.surprise && d.courseId != null) {
        surprises.add(_sKey(d.courseId!, d.date));
        flagged++;
        continue;
      }
      final t = Task(
        id: newId(),
        title: d.title,
        date: dkey(d.date),
        startMin: d.startMin,
        durationMin: d.durationMin,
        cat: d.cat,
        courseId: d.courseId,
      );
      t.remindMin = defaultReminder(t);
      tasks.add(t);
      if (t.cat.isExam) _addPrep(t);
      added++;
    }
    touch();
    final parts = <String>[];
    if (added > 0) parts.add('$added task${added == 1 ? '' : 's'} added');
    if (flagged > 0) parts.add('$flagged surprise-quiz week${flagged == 1 ? '' : 's'} marked');
    return parts.isEmpty ? 'Nothing added' : parts.join(', ');
  }

  // ---------- journal ----------

  List<JournalBlock> journalOn(String key) => journal[key] ?? const [];

  void addJournalBlocks(String key, List<JournalBlock> blocks) {
    if (blocks.isEmpty) return;
    final list = journal.putIfAbsent(key, () => []);
    list.addAll(blocks);
    touch();
  }

  void removeJournalBlock(String key, String id) {
    journal[key]?.removeWhere((b) => b.id == id);
    if (journal[key]?.isEmpty ?? false) journal.remove(key);
    touch();
  }

  // ---------- manifestations ----------

  void saveManifest(Manifestation m) {
    final i = manifests.indexWhere((e) => e.id == m.id);
    if (i >= 0) {
      manifests[i] = m;
    } else {
      manifests.insert(0, m);
    }
    touch();
  }

  void deleteManifest(String id) {
    manifests.removeWhere((e) => e.id == id);
    touch();
  }

  // ---------- reminders ----------

  List<Reminder> upcomingReminders(DateTime now) {
    final out = <Reminder>[];
    final horizon = now.add(const Duration(days: 60));
    for (final t in tasks) {
      if (t.remindMin == null || t.status != TaskStatus.none) continue;
      final d = parseKey(t.date);
      final when = DateTime(d.year, d.month, d.day, t.remindMin! ~/ 60, t.remindMin! % 60);
      if (!when.isAfter(now) || when.isAfter(horizon)) continue;
      final c = courseById(t.courseId);
      final bits = <String>[
        if (t.startMin != null) fmtMin(t.startMin!),
        t.cat.label,
        if (c != null) c.short,
        if (t.note.isNotEmpty) t.note,
      ];
      out.add(Reminder(when, t.title, bits.join(' · ')));
    }
    if (settings.classReminders) {
      for (var i = 0; i < 7; i++) {
        final day = addDays(now, i);
        for (final s in classesOn(day)) {
          final c = courseById(s.courseId)!;
          final st = s.startMin - 10;
          final when = DateTime(day.year, day.month, day.day, st ~/ 60, st % 60);
          if (!when.isAfter(now)) continue;
          final sq = isSurprise(c.id, day) ? ' · surprise quiz possible' : '';
          out.add(Reminder(when, '${c.short} ${s.kind} at ${fmtMin(s.startMin)}',
              '${s.room.isEmpty ? c.name : s.room}$sq'));
        }
      }
    }
    out.sort((a, b) => a.when.compareTo(b.when));
    return out;
  }
}

/// The one shared instance.
final AppState app = AppState();
