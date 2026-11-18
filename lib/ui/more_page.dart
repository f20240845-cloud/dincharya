import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../notifications.dart';
import '../store.dart';
import 'common.dart';

void _open(BuildContext context, Widget page) {
  Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
}

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Widget tile(IconData icon, String title, String sub, Widget page) => ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(sub, style: TextStyle(color: p.muted, fontSize: 12.5)),
          trailing: Icon(Icons.chevron_right, color: p.muted),
          onTap: () => _open(context, page),
        );
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => Scaffold(
        appBar: AppBar(titleSpacing: 16, title: const Text('More')),
        body: ListView(
          children: [
            tile(Icons.grid_on, 'Timetable', '${app.slots.length} class slots a week',
                const TimetablePage()),
            tile(Icons.school_outlined, 'Courses & abbreviations',
                app.courses.isEmpty ? 'Add courses like "Digital Design = DD"' : app.courses.map((c) => c.short).join(', '),
                const CoursesPage()),
            tile(Icons.record_voice_over_outlined, 'My words',
                '${app.vocab.length} corrections for speech-to-text', const VocabPage()),
            tile(Icons.auto_awesome_outlined, 'Manifestations', '${app.manifests.length} written',
                const ManifestPage()),
            tile(Icons.settings_outlined, 'Settings', 'Reminders, language, theme, backup',
                const SettingsPage()),
          ],
        ),
      ),
    );
  }
}

// ---------------- courses ----------------

class CoursesPage extends StatelessWidget {
  const CoursesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Courses')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _editCourse(context, null),
          icon: const Icon(Icons.add),
          label: const Text('Course'),
        ),
        body: app.courses.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                      'Add your courses and the short names you say out loud, for example '
                      'Digital Design with the abbreviation DD. The mic then understands "DD quiz".',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.muted, fontSize: 14.5, height: 1.4)),
                ),
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 90),
                children: [
                  for (final c in app.courses)
                    ListTile(
                      leading: CircleAvatar(backgroundColor: c.color, radius: 10),
                      title: Text(c.name),
                      subtitle: Text(
                          c.abbrs.isEmpty ? 'No abbreviations' : 'Say: ${c.abbrs.join(', ')}',
                          style: TextStyle(color: p.muted, fontSize: 12.5)),
                      trailing: app.isSurprise(c.id, DateTime.now())
                          ? const Icon(Icons.bolt, color: kPartial)
                          : null,
                      onTap: () => _editCourse(context, c),
                    ),
                ],
              ),
      ),
    );
  }
}

Future<void> _editCourse(BuildContext context, Course? existing) {
  final name = TextEditingController(text: existing?.name ?? '');
  final abbr = TextEditingController(text: existing?.abbrs.join(', ') ?? '');
  var color = existing?.colorIdx ?? (app.courses.length % coursePalette.length);
  var surprise = existing != null && app.isSurprise(existing.id, DateTime.now());
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final p = Pal.of(ctx);
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(existing == null ? 'New course' : 'Edit course',
                    style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Course name', hintText: 'Digital Design'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: abbr,
                  decoration: const InputDecoration(
                      labelText: 'Abbreviations (comma separated)', hintText: 'DD, CS F215'),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < coursePalette.length; i++)
                      GestureDetector(
                        onTap: () => setS(() => color = i),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: coursePalette[i],
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: color == i ? p.text : Colors.transparent, width: 2.5),
                          ),
                        ),
                      ),
                  ],
                ),
                if (existing != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: surprise,
                    onChanged: (v) => setS(() => surprise = v),
                    title: const Text('Surprise quiz may come this week'),
                    subtitle: Text('Marks every class of this course this week',
                        style: TextStyle(color: p.muted, fontSize: 12.5)),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (existing != null)
                      TextButton(
                        onPressed: () {
                          app.deleteCourse(existing.id);
                          Navigator.pop(ctx);
                        },
                        child: const Text('Delete', style: TextStyle(color: kMissed)),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        final n = name.text.trim();
                        if (n.isEmpty) return;
                        final c = Course(
                          id: existing?.id ?? newId(),
                          name: n,
                          abbrs: abbr.text
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList(),
                          colorIdx: color,
                        );
                        app.saveCourse(c);
                        if (existing != null) app.setSurprise(c.id, DateTime.now(), surprise);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

// ---------------- timetable ----------------

class TimetablePage extends StatelessWidget {
  const TimetablePage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Timetable'),
          actions: [
            TextButton(
              onPressed: () => _open(context, const CoursesPage()),
              child: const Text('Courses'),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            if (app.courses.isEmpty) {
              toast(context, 'Add a course first');
              _open(context, const CoursesPage());
            } else {
              _editSlot(context, null);
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('Class'),
        ),
        body: app.slots.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                      'Add your weekly classes here. They appear in the calendar every week, '
                      'so tasks and surprise-quiz marks line up with them.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.muted, fontSize: 14.5, height: 1.4)),
                ),
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 90),
                children: [
                  for (var wd = 1; wd <= 7; wd++)
                    if (app.slots.any((s) => s.weekday == wd)) ...[
                      SectionTitle(wdLong[wd - 1]),
                      for (final s in (app.slots.where((s) => s.weekday == wd).toList()
                        ..sort((a, b) => a.startMin.compareTo(b.startMin))))
                        _slotTile(context, s, p),
                    ],
                ],
              ),
      ),
    );
  }

  Widget _slotTile(BuildContext context, ClassSlot s, Pal p) {
    final c = app.courseById(s.courseId);
    return ListTile(
      dense: true,
      leading: CircleAvatar(backgroundColor: c?.color ?? p.muted, radius: 8),
      title: Text('${c?.name ?? 'Deleted course'} · ${s.kind}',
          style: TextStyle(color: p.text, fontSize: 14.5)),
      subtitle: Text(
          '${fmtMin(s.startMin)} – ${fmtMin(s.endMin)}${s.room.isEmpty ? '' : ' · ${s.room}'}',
          style: TextStyle(color: p.muted, fontSize: 12.5)),
      onTap: () => _editSlot(context, s),
    );
  }
}

Future<void> _editSlot(BuildContext context, ClassSlot? existing) {
  var courseId = existing?.courseId ?? app.courses.first.id;
  final days = <int>{existing?.weekday ?? DateTime.now().weekday};
  var start = existing?.startMin ?? 9 * 60;
  var end = existing?.endMin ?? 9 * 60 + 50;
  var kind = existing?.kind ?? 'Lecture';
  final room = TextEditingController(text: existing?.room ?? '');
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final p = Pal.of(ctx);
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(existing == null ? 'New class' : 'Edit class',
                    style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in app.courses)
                      ChoiceChip(
                        avatar: CircleAvatar(backgroundColor: c.color, radius: 6),
                        label: Text(c.short),
                        selected: courseId == c.id,
                        onSelected: (_) => setS(() => courseId = c.id),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(existing == null ? 'Days (pick all that apply)' : 'Day',
                    style: TextStyle(color: p.muted, fontSize: 12.5)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    for (var wd = 1; wd <= 7; wd++)
                      FilterChip(
                        label: Text(wdShort[wd - 1]),
                        selected: days.contains(wd),
                        onSelected: (v) => setS(() {
                          if (existing != null) {
                            days
                              ..clear()
                              ..add(wd);
                          } else if (v) {
                            days.add(wd);
                          } else {
                            days.remove(wd);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final m = await pickMinutes(ctx, start);
                          if (m != null) {
                            setS(() {
                              final len = end - start;
                              start = m;
                              end = (m + (len > 0 ? len : 50)).clamp(0, 1439).toInt();
                            });
                          }
                        },
                        child: Text('Starts ${fmtMin(start)}'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final m = await pickMinutes(ctx, end);
                          if (m != null) setS(() => end = m);
                        },
                        child: Text('Ends ${fmtMin(end)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final k in const ['Lecture', 'Tutorial', 'Lab'])
                      ChoiceChip(
                        label: Text(k),
                        selected: kind == k,
                        onSelected: (_) => setS(() => kind = k),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: room,
                  decoration: const InputDecoration(labelText: 'Room (optional)'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (existing != null)
                      TextButton(
                        onPressed: () {
                          app.deleteSlot(existing.id);
                          Navigator.pop(ctx);
                        },
                        child: const Text('Delete', style: TextStyle(color: kMissed)),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        if (days.isEmpty) return;
                        if (end <= start) {
                          toast(ctx, 'End time must be after the start time');
                          return;
                        }
                        var first = true;
                        for (final wd in days) {
                          app.saveSlot(ClassSlot(
                            id: (existing != null && first) ? existing.id : newId(),
                            courseId: courseId,
                            weekday: wd,
                            startMin: start,
                            endMin: end,
                            kind: kind,
                            room: room.text.trim(),
                          ));
                          first = false;
                        }
                        Navigator.pop(ctx);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

// ---------------- my words ----------------

class VocabPage extends StatelessWidget {
  const VocabPage({super.key});

  Future<void> _edit(BuildContext context, String? key) {
    final heard = TextEditingController(text: key ?? '');
    final means = TextEditingController(text: key == null ? '' : app.vocab[key] ?? '');
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(key == null ? 'Add a word' : 'Edit word'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: heard,
              decoration: const InputDecoration(labelText: 'When the mic writes', hintText: 'didi'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: means,
              decoration: const InputDecoration(labelText: 'Replace it with', hintText: 'DD'),
            ),
          ],
        ),
        actions: [
          if (key != null)
            TextButton(
              onPressed: () {
                app.vocab.remove(key);
                app.touch();
                Navigator.pop(ctx);
              },
              child: const Text('Delete', style: TextStyle(color: kMissed)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final h = heard.text.trim();
              final m = means.text.trim();
              if (h.isEmpty || m.isEmpty) return;
              if (key != null && key != h) app.vocab.remove(key);
              app.vocab[h] = m;
              app.touch();
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final keys = app.vocab.keys.toList()..sort();
        return Scaffold(
          appBar: AppBar(title: const Text('My words')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(context, null),
            icon: const Icon(Icons.add),
            label: const Text('Word'),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                    'When speech-to-text keeps writing a word wrongly, add it here and it is '
                    'fixed automatically in tasks and the journal. Names, course nicknames and '
                    'Hinglish words work well.',
                    style: TextStyle(color: p.muted, fontSize: 13.5, height: 1.4)),
              ),
              for (final k in keys)
                ListTile(
                  title: Text('$k  →  ${app.vocab[k]}'),
                  onTap: () => _edit(context, k),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------- manifestations ----------------

class ManifestPage extends StatelessWidget {
  const ManifestPage({super.key});

  Future<void> _edit(BuildContext context, Manifestation? m) {
    final c = TextEditingController(text: m?.text ?? '');
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(m == null ? 'New manifestation' : 'Edit'),
        content: TextField(
          controller: c,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Write it as if it is already true'),
        ),
        actions: [
          if (m != null)
            TextButton(
              onPressed: () {
                app.deleteManifest(m.id);
                Navigator.pop(ctx);
              },
              child: const Text('Delete', style: TextStyle(color: kMissed)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final t = c.text.trim();
              if (t.isEmpty) return;
              app.saveManifest(Manifestation(
                id: m?.id ?? newId(),
                text: t,
                created: m?.created ?? dkey(DateTime.now()),
                pinned: m?.pinned ?? false,
              ));
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Manifestations')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(context, null),
          icon: const Icon(Icons.add),
          label: const Text('Write'),
        ),
        body: app.manifests.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                      'Write what you are working towards. Pinned ones show at the top of your '
                      'day as a reminder.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.muted, fontSize: 14.5, height: 1.4)),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                children: [
                  for (final m in app.manifests)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _edit(context, m),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(colors: [
                              const Color(0xFFAB47BC).withValues(alpha: 0.24),
                              const Color(0xFF5B8DEF).withValues(alpha: 0.18),
                            ]),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.text,
                                        style: TextStyle(color: p.text, fontSize: 16, height: 1.4)),
                                    const SizedBox(height: 6),
                                    Text(m.created.isEmpty ? '' : fmtDate(parseKey(m.created)),
                                        style: TextStyle(color: p.muted, fontSize: 11.5)),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: m.pinned ? 'Unpin' : 'Pin to my day',
                                icon: Icon(m.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                                    color: m.pinned ? p.accent : p.muted, size: 20),
                                onPressed: () {
                                  m.pinned = !m.pinned;
                                  app.touch();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

// ---------------- settings ----------------

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _lead(BuildContext context, Cat cat) async {
    final s = app.settings;
    final cur = s.leadDays[cat.name] ?? 7;
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('${cat.label}: study task how early?'),
        children: [
          for (final d in const [0, 1, 2, 3, 5, 7, 10, 14, 21, 30])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, d),
              child: Text(d == 0 ? 'Do not add one' : '$d day${d == 1 ? '' : 's'} before',
                  style: TextStyle(fontWeight: d == cur ? FontWeight.w700 : FontWeight.w400)),
            ),
        ],
      ),
    );
    if (v != null) {
      s.leadDays[cat.name] = v;
      app.touch();
    }
  }

  Future<void> _export(BuildContext context) async {
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/dincharya-backup-${dkey(DateTime.now())}.json');
      await f.writeAsString(app.exportJson());
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], text: 'Dincharya backup'));
    } catch (e) {
      if (context.mounted) toast(context, 'Could not export: $e');
    }
  }

  Future<void> _import(BuildContext context) async {
    final c = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Paste the contents of a backup file. This replaces everything in the app.'),
            const SizedBox(height: 10),
            TextField(controller: c, minLines: 3, maxLines: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () async {
                  final d = await Clipboard.getData('text/plain');
                  c.text = d?.text ?? '';
                },
                child: const Text('Paste from clipboard'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Restore')),
        ],
      ),
    );
    if (raw == null || raw.trim().isEmpty) return;
    final ok = app.importJson(raw);
    if (context.mounted) toast(context, ok ? 'Backup restored' : 'That is not a valid backup');
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final s = app.settings;
        Text sub(String t) => Text(t, style: TextStyle(color: p.muted, fontSize: 12.5));
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              const SectionTitle('Reminders'),
              ListTile(
                title: const Text('Allow notifications'),
                subtitle: sub('Needed once so reminders can appear'),
                trailing: const Icon(Icons.notifications_active_outlined),
                onTap: () async {
                  final ok = await Notifier.requestPermission();
                  if (ok) await Notifier.showNow('Reminders are on', 'This is how a reminder looks.');
                  if (context.mounted) {
                    toast(context, ok ? 'Notifications allowed' : 'Notifications are blocked in Android settings');
                  }
                },
              ),
              ListTile(
                title: const Text('Study reminder time'),
                subtitle: sub('For the study task added before a quiz, test or exam'),
                trailing: Text(fmtMin(s.studyReminderMin), style: TextStyle(color: p.accent)),
                onTap: () async {
                  final m = await pickMinutes(context, s.studyReminderMin);
                  if (m != null) {
                    s.studyReminderMin = m;
                    app.touch();
                  }
                },
              ),
              for (final c in const [Cat.quiz, Cat.labTest, Cat.midsem, Cat.compre, Cat.assignment])
                ListTile(
                  dense: true,
                  title: Text('${c.label}: add study task'),
                  trailing: Text(
                      (s.leadDays[c.name] ?? 7) == 0 ? 'Off' : '${s.leadDays[c.name] ?? 7} days before',
                      style: TextStyle(color: p.accent)),
                  onTap: () => _lead(context, c),
                ),
              ListTile(
                title: const Text('Remind before a timed task'),
                trailing: Text('${s.taskLeadMin} min', style: TextStyle(color: p.accent)),
                onTap: () async {
                  final v = await showDialog<int>(
                    context: context,
                    builder: (ctx) => SimpleDialog(
                      title: const Text('Remind me'),
                      children: [
                        for (final d in const [0, 5, 10, 15, 30, 60])
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(ctx, d),
                            child: Text(d == 0 ? 'At the start time' : '$d minutes before'),
                          ),
                      ],
                    ),
                  );
                  if (v != null) {
                    s.taskLeadMin = v;
                    app.touch();
                  }
                },
              ),
              SwitchListTile(
                title: const Text('Evening review'),
                subtitle: sub('Asks which day to add unfinished tasks to'),
                value: s.reviewOn,
                onChanged: (v) {
                  s.reviewOn = v;
                  app.touch();
                },
              ),
              if (s.reviewOn)
                ListTile(
                  dense: true,
                  title: const Text('Review time'),
                  trailing: Text(fmtMin(s.reviewMin), style: TextStyle(color: p.accent)),
                  onTap: () async {
                    final m = await pickMinutes(context, s.reviewMin);
                    if (m != null) {
                      s.reviewMin = m;
                      app.touch();
                    }
                  },
                ),
              SwitchListTile(
                title: const Text('Class reminders'),
                subtitle: sub('10 minutes before each class in the timetable'),
                value: s.classReminders,
                onChanged: (v) {
                  s.classReminders = v;
                  app.touch();
                },
              ),
              const SectionTitle('Speech'),
              ListTile(
                title: const Text('Speech language'),
                subtitle: sub('English (India) also handles Hinglish written in English letters'),
                trailing: Text(s.speechLocale == 'hi_IN' ? 'हिंदी' : 'English / Hinglish',
                    style: TextStyle(color: p.accent)),
                onTap: () {
                  s.speechLocale = s.speechLocale == 'hi_IN' ? 'en_IN' : 'hi_IN';
                  app.touch();
                },
              ),
              const SectionTitle('Appearance'),
              ListTile(
                title: const Text('Theme'),
                trailing: Text(s.theme[0].toUpperCase() + s.theme.substring(1),
                    style: TextStyle(color: p.accent)),
                onTap: () {
                  const order = ['dark', 'light', 'system'];
                  s.theme = order[(order.indexOf(s.theme) + 1) % order.length];
                  app.touch();
                },
              ),
              const SectionTitle('Backup'),
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('Export backup'),
                subtitle: sub('Share a file with all tasks, timetable and journal'),
                onTap: () => _export(context),
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Restore backup'),
                onTap: () => _import(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
