import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'task_sheets.dart';

/// GitHub-style grid: each day gets greener the more of its tasks you finished.
class ProgressPage extends StatefulWidget {
  final ValueChanged<DateTime>? onOpenDay;
  const ProgressPage({super.key, this.onOpenDay});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

const _greensDark = [
  Color(0xFF1B1F27),
  Color(0xFF0E4429),
  Color(0xFF006D32),
  Color(0xFF26A641),
  Color(0xFF39D353),
];
const _greensLight = [
  Color(0xFFE6E8EC),
  Color(0xFF9BE9A8),
  Color(0xFF40C463),
  Color(0xFF30A14E),
  Color(0xFF216E39),
];

int _level(double? score) {
  if (score == null) return -1; // no tasks that day
  if (score <= 0) return 0;
  if (score < 0.3) return 1;
  if (score < 0.55) return 2;
  if (score < 0.8) return 3;
  return 4;
}

class _ProgressPageState extends State<ProgressPage> {
  DateTime selected = dateOnly(DateTime.now());
  final ScrollController sc = ScrollController();
  static const int weeks = 26;
  static const double cell = 17;
  static const double gap = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (sc.hasClients) sc.jumpTo(sc.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final greens = dark ? _greensDark : _greensLight;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final today = dateOnly(DateTime.now());
        final start = addDays(weekStart(today), -(weeks - 1) * 7);

        // Streak: consecutive days (ending today or yesterday) with a score of 50% or more.
        var streak = 0;
        var d = today;
        if ((app.dayScore(dkey(d)) ?? 0) < 0.5) d = addDays(d, -1);
        while ((app.dayScore(dkey(d)) ?? 0) >= 0.5) {
          streak++;
          d = addDays(d, -1);
        }
        // This week
        var wkSum = 0.0;
        var wkDays = 0;
        var wkDone = 0;
        var wkTotal = 0;
        for (var i = 0; i < 7; i++) {
          final k = dkey(addDays(weekStart(today), i));
          final s = app.dayScore(k);
          if (s != null) {
            wkSum += s;
            wkDays++;
          }
          for (final t in app.tasksOn(k)) {
            wkTotal++;
            if (t.status == TaskStatus.done) wkDone++;
          }
        }
        final selTasks = app.tasksOn(dkey(selected));
        final selScore = app.dayScore(dkey(selected));

        return Scaffold(
          appBar: AppBar(titleSpacing: 16, title: const Text('Progress')),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 110),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Row(
                  children: [
                    _stat(p, '$streak', 'day streak'),
                    const SizedBox(width: 10),
                    _stat(p, wkDays == 0 ? '–' : '${(wkSum / wkDays * 100).round()}%', 'this week'),
                    const SizedBox(width: 10),
                    _stat(p, '$wkDone/$wkTotal', 'tasks ticked'),
                  ],
                ),
              ),
              const SectionTitle('Last 6 months'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 18, right: 6),
                      child: Column(
                        children: [
                          for (var r = 0; r < 7; r++)
                            SizedBox(
                              height: cell + gap,
                              child: Text(r.isEven ? wdShort[r] : '',
                                  style: TextStyle(fontSize: 9.5, color: p.muted)),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: sc,
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var w = 0; w < weeks; w++)
                              _weekColumn(p, greens, addDays(start, w * 7), today),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('Less ', style: TextStyle(fontSize: 11, color: p.muted)),
                    for (final g in greens)
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(color: g, borderRadius: BorderRadius.circular(3)),
                      ),
                    Text(' More', style: TextStyle(fontSize: 11, color: p.muted)),
                  ],
                ),
              ),
              SectionTitle(
                '${relDate(selected, today)} · ${selected.day} ${monShort[selected.month - 1]}',
                trailing: widget.onOpenDay == null
                    ? null
                    : TextButton(
                        onPressed: () => widget.onOpenDay!(selected),
                        child: const Text('Open in calendar'),
                      ),
              ),
              if (selTasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('No tasks on this day.', style: TextStyle(color: p.muted, fontSize: 14)),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('${((selScore ?? 0) * 100).round()}% complete',
                      style: TextStyle(color: p.muted, fontSize: 13)),
                ),
                for (final t in selTasks)
                  ListTile(
                    dense: true,
                    onTap: () => showTaskSheet(context, t),
                    leading: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.status == TaskStatus.none
                            ? Colors.transparent
                            : statusColor(t.status).withValues(alpha: 0.9),
                        border: Border.all(
                            color: t.status == TaskStatus.none ? p.line : statusColor(t.status)),
                      ),
                      child: Text(
                          t.status == TaskStatus.done
                              ? '✓'
                              : t.status == TaskStatus.partial
                                  ? '~'
                                  : t.status == TaskStatus.missed
                                      ? '✕'
                                      : '',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F1115))),
                    ),
                    title: Text(t.title, style: TextStyle(color: p.text, fontSize: 14.5)),
                    subtitle: Text(taskSubtitle(t), style: TextStyle(color: p.muted, fontSize: 12)),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _stat(Pal p, String big, String small) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(big, style: TextStyle(color: p.text, fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(small, style: TextStyle(color: p.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _weekColumn(Pal p, List<Color> greens, DateTime monday, DateTime today) {
    // Month label above the column that contains the 1st of a month.
    var label = '';
    for (var i = 0; i < 7; i++) {
      final d = addDays(monday, i);
      if (d.day == 1) label = monShort[d.month - 1];
    }
    return Padding(
      padding: const EdgeInsets.only(right: gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 18,
            width: cell,
            child: OverflowBox(
              alignment: Alignment.topLeft,
              maxWidth: 40,
              child: Text(label, softWrap: false, style: TextStyle(fontSize: 9.5, color: p.muted)),
            ),
          ),
          for (var i = 0; i < 7; i++) _dayCell(p, greens, addDays(monday, i), today),
        ],
      ),
    );
  }

  Widget _dayCell(Pal p, List<Color> greens, DateTime d, DateTime today) {
    if (d.isAfter(today) && app.dayCount(dkey(d)) == 0) {
      return const SizedBox(width: cell, height: cell + gap);
    }
    final lvl = _level(app.dayScore(dkey(d)));
    final isSel = sameDay(d, selected);
    return GestureDetector(
      onTap: () => setState(() => selected = d),
      child: Container(
        width: cell,
        height: cell,
        margin: const EdgeInsets.only(bottom: gap),
        decoration: BoxDecoration(
          color: lvl < 0 ? greens[0].withValues(alpha: 0.45) : greens[lvl],
          borderRadius: BorderRadius.circular(4),
          border: isSel
              ? Border.all(color: p.text, width: 1.5)
              : (sameDay(d, today) ? Border.all(color: p.accent, width: 1.2) : null),
        ),
      ),
    );
  }
}
