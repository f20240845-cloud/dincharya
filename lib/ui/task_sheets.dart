import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'common.dart';

Widget _grabber(BuildContext context) => Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        decoration: BoxDecoration(color: Pal.of(context).line, borderRadius: BorderRadius.circular(2)),
      ),
    );

// ---------------- quick actions for one task ----------------

Future<void> showTaskSheet(BuildContext context, Task task) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => ListenableBuilder(
      listenable: app,
      builder: (ctx, _) {
        final p = Pal.of(ctx);
        final t = app.taskById(task.id);
        if (t == null) return const SizedBox(height: 40);
        final exam = app.taskById(t.linkedTo);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _grabber(ctx),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(top: 6, right: 10),
                    decoration:
                        BoxDecoration(color: t.cat.color, borderRadius: BorderRadius.circular(4)),
                  ),
                  Expanded(
                    child: Text(t.title,
                        style: TextStyle(color: p.text, fontSize: 20, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('${fmtDate(parseKey(t.date))} · ${taskSubtitle(t)}',
                  style: TextStyle(color: p.muted, fontSize: 14)),
              if (t.remindMin != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Reminder at ${fmtMin(t.remindMin!)}',
                      style: TextStyle(color: p.muted, fontSize: 13)),
                ),
              if (t.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(t.note, style: TextStyle(color: p.text, fontSize: 14)),
                ),
              if (exam != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Created for: ${exam.title}',
                      style: TextStyle(color: p.muted, fontSize: 13)),
                ),
              const SizedBox(height: 18),
              Text('How much did you finish?', style: TextStyle(color: p.muted, fontSize: 13)),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final s in const [TaskStatus.done, TaskStatus.partial, TaskStatus.missed])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _BigStatus(task: t, status: s),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event_repeat, size: 18),
                      label: const Text('Add to other days'),
                      onPressed: () => showAddToDays(ctx, t),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () {
                      Navigator.pop(ctx);
                      showTaskEditor(context, task: t);
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButton.outlined(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      Navigator.pop(ctx);
                      app.deleteTask(t.id);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _BigStatus extends StatelessWidget {
  final Task task;
  final TaskStatus status;
  const _BigStatus({required this.task, required this.status});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final on = task.status == status;
    final col = statusColor(status);
    final sym = status == TaskStatus.done
        ? '✓'
        : status == TaskStatus.partial
            ? '~'
            : '✕';
    final range = status == TaskStatus.done
        ? '70–100%'
        : status == TaskStatus.partial
            ? '20–70%'
            : '0–20%';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => app.setStatus(task, status),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: on ? col.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? col : p.line, width: 1.5),
        ),
        child: Column(
          children: [
            Text(sym, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: on ? col : p.muted)),
            const SizedBox(height: 2),
            Text(range, style: TextStyle(fontSize: 12, color: on ? p.text : p.muted)),
          ],
        ),
      ),
    );
  }
}

// ---------------- add a task on other days ----------------

Future<void> showAddToDays(BuildContext context, Task task) {
  final today = dateOnly(DateTime.now());
  final chosen = <String>{};
  final extra = <DateTime>[];
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final p = Pal.of(ctx);
        final days = [for (var i = 1; i <= 7; i++) addDays(today, i), ...extra];
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _grabber(ctx),
              Text('Add "${task.title}" on',
                  style: TextStyle(color: p.text, fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Pick one or more days. The original keeps its mark.',
                  style: TextStyle(color: p.muted, fontSize: 13)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in days)
                    FilterChip(
                      label: Text(sameDay(d, addDays(today, 1))
                          ? 'Tomorrow'
                          : '${wdShort[d.weekday - 1]} ${d.day} ${monShort[d.month - 1]}'),
                      selected: chosen.contains(dkey(d)),
                      onSelected: (v) => setS(() {
                        if (v) {
                          chosen.add(dkey(d));
                        } else {
                          chosen.remove(dkey(d));
                        }
                      }),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.calendar_month, size: 16),
                    label: const Text('Other date'),
                    onPressed: () async {
                      final d = await pickDate(ctx, addDays(today, 8));
                      if (d == null) return;
                      setS(() {
                        if (!days.any((x) => sameDay(x, d))) extra.add(dateOnly(d));
                        chosen.add(dkey(d));
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: chosen.isEmpty
                      ? null
                      : () {
                          final list = chosen.map(parseKey).toList()..sort();
                          app.copyToDays(task, list);
                          Navigator.pop(ctx);
                          toast(context, 'Added on ${list.length} day${list.length == 1 ? '' : 's'}');
                        },
                  child: Text(chosen.isEmpty
                      ? 'Choose days'
                      : 'Add on ${chosen.length} day${chosen.length == 1 ? '' : 's'}'),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

// ---------------- evening review ----------------

Future<void> showReviewSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => ListenableBuilder(
      listenable: app,
      builder: (ctx, _) {
        final p = Pal.of(ctx);
        final now = DateTime.now();
        final pending = app.pendingReview(now);
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _grabber(ctx),
                Text('Review unfinished tasks',
                    style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Mark how much you did, then add anything left to another day.',
                    style: TextStyle(color: p.muted, fontSize: 13)),
                const SizedBox(height: 12),
                if (pending.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                        child: Text('All caught up.', style: TextStyle(color: p.muted, fontSize: 15))),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: pending.length,
                      separatorBuilder: (_, __) => Divider(height: 18, color: p.line),
                      itemBuilder: (ctx, i) {
                        final t = pending[i];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(t.title,
                                          style: TextStyle(
                                              color: p.text, fontSize: 15, fontWeight: FontWeight.w500)),
                                      Text('${relDate(parseKey(t.date), now)} · ${t.cat.label}',
                                          style: TextStyle(color: p.muted, fontSize: 12.5)),
                                    ],
                                  ),
                                ),
                                StatusButtons(task: t),
                              ],
                            ),
                            Row(
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.event_repeat, size: 16),
                                  label: const Text('Add to other days'),
                                  onPressed: () => showAddToDays(ctx, t),
                                ),
                                TextButton(
                                  onPressed: () => app.markReviewed([t]),
                                  child: const Text('Leave it'),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      app.markReviewed(pending);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Finish review'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

// ---------------- create / edit ----------------

Future<void> showTaskEditor(BuildContext context,
    {Task? task, DateTime? date, int? startMin, String? courseId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _TaskEditor(task: task, date: date, startMin: startMin, courseId: courseId),
  );
}

class _TaskEditor extends StatefulWidget {
  final Task? task;
  final DateTime? date;
  final int? startMin;
  final String? courseId;
  const _TaskEditor({this.task, this.date, this.startMin, this.courseId});

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late Task t;
  late bool isNew;
  late TextEditingController title;
  late TextEditingController note;
  bool prep = true;
  bool reminderTouched = false;
  String? oldDate;
  Cat? oldCat;

  @override
  void initState() {
    super.initState();
    isNew = widget.task == null;
    if (isNew) {
      t = Task(
        id: newId(),
        title: '',
        date: dkey(widget.date ?? DateTime.now()),
        startMin: widget.startMin,
        courseId: widget.courseId,
        cat: widget.courseId != null ? Cat.study : Cat.personal,
      );
      t.remindMin = app.defaultReminder(t);
    } else {
      t = widget.task!.copy();
      oldDate = t.date;
      oldCat = t.cat;
      reminderTouched = true;
    }
    title = TextEditingController(text: t.title);
    note = TextEditingController(text: t.note);
  }

  @override
  void dispose() {
    title.dispose();
    note.dispose();
    super.dispose();
  }

  void _save() {
    final name = title.text.trim();
    t.title = name.isEmpty ? t.cat.label : name;
    t.note = note.text.trim();
    if (isNew) {
      app.addTask(t, withPrep: prep);
    } else {
      app.updateTask(t, oldDate: oldDate, oldCat: oldCat);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final day = parseKey(t.date);
    final lead = app.settings.leadDays[t.cat.name] ?? 7;
    Widget row(IconData icon, String label, String value, VoidCallback onTap, {Widget? trailing}) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: p.muted),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: TextStyle(color: p.text, fontSize: 15))),
              Text(value, style: TextStyle(color: p.accent, fontSize: 15)),
              if (trailing != null) trailing,
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _grabber(context),
            Row(
              children: [
                Expanded(
                  child: Text(isNew ? 'New task' : 'Edit task',
                      style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                FilledButton(onPressed: _save, child: const Text('Save')),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: title,
              autofocus: isNew,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'What do you need to do?'),
            ),
            const SizedBox(height: 14),
            Text('Type', style: TextStyle(color: p.muted, fontSize: 12.5)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in Cat.values)
                  ChoiceChip(
                    avatar: Icon(c.icon, size: 16, color: c.color),
                    label: Text(c.label),
                    selected: t.cat == c,
                    onSelected: (_) => setState(() => t.cat = c),
                  ),
              ],
            ),
            if (app.courses.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Course', style: TextStyle(color: p.muted, fontSize: 12.5)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('None'),
                    selected: t.courseId == null,
                    onSelected: (_) => setState(() => t.courseId = null),
                  ),
                  for (final c in app.courses)
                    ChoiceChip(
                      avatar: CircleAvatar(backgroundColor: c.color, radius: 6),
                      label: Text(c.short),
                      selected: t.courseId == c.id,
                      onSelected: (_) => setState(() => t.courseId = c.id),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            row(Icons.event, 'Date', relDate(day, DateTime.now()), () async {
              final d = await pickDate(context, day);
              if (d != null) setState(() => t.date = dkey(d));
            }),
            row(
              Icons.schedule,
              'Time',
              t.startMin == null ? 'Any time' : fmtMin(t.startMin!),
              () async {
                final m = await pickMinutes(context, t.startMin ?? 17 * 60);
                if (m != null) {
                  setState(() {
                    t.startMin = m;
                    if (!reminderTouched) t.remindMin = app.defaultReminder(t);
                  });
                }
              },
              trailing: t.startMin == null
                  ? null
                  : IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close, size: 18, color: p.muted),
                      onPressed: () => setState(() {
                        t.startMin = null;
                        if (!reminderTouched) t.remindMin = null;
                      }),
                    ),
            ),
            if (t.startMin != null)
              Padding(
                padding: const EdgeInsets.only(left: 34, bottom: 6),
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final d in const [30, 60, 90, 120, 180])
                      ChoiceChip(
                        label: Text(d < 60 ? '$d min' : '${(d / 60).toString().replaceAll('.0', '')} h'),
                        selected: t.durationMin == d,
                        onSelected: (_) => setState(() => t.durationMin = d),
                      ),
                  ],
                ),
              ),
            row(
              Icons.notifications_none,
              'Reminder',
              t.remindMin == null ? 'Off' : fmtMin(t.remindMin!),
              () async {
                final m = await pickMinutes(context, t.remindMin ?? t.startMin ?? app.settings.studyReminderMin);
                if (m != null) {
                  setState(() {
                    t.remindMin = m;
                    reminderTouched = true;
                  });
                }
              },
              trailing: t.remindMin == null
                  ? null
                  : IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close, size: 18, color: p.muted),
                      onPressed: () => setState(() {
                        t.remindMin = null;
                        reminderTouched = true;
                      }),
                    ),
            ),
            if (isNew && t.cat.isExam && lead > 0)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: prep,
                onChanged: (v) => setState(() => prep = v),
                title: Text(
                    t.cat == Cat.assignment
                        ? 'Add a "start" task $lead days before'
                        : 'Add a study task $lead days before',
                    style: TextStyle(color: p.text, fontSize: 15)),
                subtitle: Text('With a reminder at ${fmtMin(app.settings.studyReminderMin)}',
                    style: TextStyle(color: p.muted, fontSize: 12.5)),
              ),
            const SizedBox(height: 6),
            TextField(
              controller: note,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Note (optional)'),
            ),
            if (!isNew) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, color: kMissed),
                label: const Text('Delete task', style: TextStyle(color: kMissed)),
                onPressed: () {
                  app.deleteTask(t.id);
                  Navigator.pop(context);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
