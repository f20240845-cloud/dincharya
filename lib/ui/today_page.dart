import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'more_page.dart' show ManifestPage;
import 'task_sheets.dart';

/// The daily checklist: classes, tasks with tick / ~ / cross, and the evening review.
class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  DateTime day = dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final now = DateTime.now();
        final key = dkey(day);
        final tasks = app.tasksOn(key);
        final classes = app.classesOn(day);
        final pending = app.pendingReview(now);
        final score = app.dayScore(key);
        final doneCount = tasks.where((t) => t.status == TaskStatus.done).length;
        Manifestation? man;
        if (app.manifests.isNotEmpty) {
          final pinned = app.manifests.where((m) => m.pinned).toList();
          final pool = pinned.isNotEmpty ? pinned : app.manifests;
          man = pool[(day.day + day.month * 31) % pool.length];
        }

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(relDate(day, now)),
                Text('${wdLong[day.weekday - 1]}, ${day.day} ${monLong[day.month - 1]}',
                    style: TextStyle(color: p.muted, fontSize: 12.5, fontWeight: FontWeight.w400)),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Previous day',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => day = addDays(day, -1)),
              ),
              IconButton(
                tooltip: 'Today',
                icon: const Icon(Icons.today),
                onPressed: () => setState(() => day = dateOnly(DateTime.now())),
              ),
              IconButton(
                tooltip: 'Next day',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => day = addDays(day, 1)),
              ),
              IconButton(
                tooltip: 'New task',
                icon: const Icon(Icons.add),
                onPressed: () => showTaskEditor(context, date: day),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 110),
            children: [
              if (man != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute<void>(builder: (_) => const ManifestPage())),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(colors: [
                          const Color(0xFFAB47BC).withValues(alpha: 0.28),
                          const Color(0xFF5B8DEF).withValues(alpha: 0.22),
                        ]),
                      ),
                      child: Row(
                        children: [
                          const Text('✨', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(man.text,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: p.text, fontSize: 14.5, height: 1.3)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (pending.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => showReviewSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: kPartial.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kPartial.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.rate_review_outlined, color: kPartial, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                                '${pending.length} unfinished task${pending.length == 1 ? '' : 's'} to review',
                                style: TextStyle(color: p.text, fontSize: 14.5)),
                          ),
                          Text('Review', style: TextStyle(color: p.accent, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              if (tasks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$doneCount of ${tasks.length} done · ${((score ?? 0) * 100).round()}%',
                          style: TextStyle(color: p.muted, fontSize: 13)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: score ?? 0,
                          minHeight: 6,
                          backgroundColor: p.card2,
                          color: kDone,
                        ),
                      ),
                    ],
                  ),
                ),
              if (classes.isNotEmpty) ...[
                const SectionTitle('Classes'),
                for (final s in classes) _classRow(context, s),
              ],
              SectionTitle('Tasks',
                  trailing: Text('✓ 70–100   ~ 20–70   ✕ 0–20',
                      style: TextStyle(color: p.muted, fontSize: 11))),
              if (tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Text(
                      'Nothing planned. Tap the mic and say something like\n'
                      '"DD quiz next Friday at 5 pm" or "kal subah 7 baje gym".',
                      style: TextStyle(color: p.muted, fontSize: 14, height: 1.4)),
                ),
              for (final t in tasks) _taskTile(context, t),
            ],
          ),
        );
      },
    );
  }

  Widget _classRow(BuildContext context, ClassSlot s) {
    final p = Pal.of(context);
    final c = app.courseById(s.courseId)!;
    final sq = app.isSurprise(c.id, day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: AccentCard(
        accent: c.color,
        background: p.card,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 74,
              child: Text(fmtMin(s.startMin), style: TextStyle(color: p.muted, fontSize: 13)),
            ),
            Expanded(
              child: Text('${c.short} · ${s.kind}${s.room.isEmpty ? '' : ' · ${s.room}'}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.text, fontSize: 14.5, fontWeight: FontWeight.w500)),
            ),
            if (sq) const Pill('Surprise quiz?', color: kPartial, icon: Icons.bolt),
          ],
        ),
      ),
    );
  }

  Widget _taskTile(BuildContext context, Task t) {
    final p = Pal.of(context);
    final done = t.status == TaskStatus.done;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showTaskSheet(context, t),
        child: AccentCard(
          accent: t.cat.color,
          background: p.card,
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title,
                        style: TextStyle(
                          color: done ? p.muted : p.text,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w500,
                          decoration: done ? TextDecoration.lineThrough : null,
                        )),
                    const SizedBox(height: 3),
                    Text(taskSubtitle(t), style: TextStyle(color: p.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusButtons(task: t),
            ],
          ),
        ),
      ),
    );
  }
}
