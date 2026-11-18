import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'more_page.dart' show TimetablePage;
import 'task_sheets.dart';

enum CalView { day, three, week, month }

const double _gutter = 44;
const int _mid = 10000;

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => CalendarPageState();
}

class CalendarPageState extends State<CalendarPage> {
  CalView view = CalView.week;
  late DateTime base; // first day shown on page [_mid]
  late DateTime focus; // first day of the page on screen
  PageController pc = PageController(initialPage: _mid);
  double scrollY = 7 * 56.0 - 12;
  Timer? _tick;
  int _gen = 0;

  int get _n => view == CalView.day ? 1 : (view == CalView.three ? 3 : 7);

  @override
  void initState() {
    super.initState();
    _rebase(dateOnly(DateTime.now()));
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    pc.dispose();
    super.dispose();
  }

  void _rebase(DateTime d) {
    if (view == CalView.week) {
      base = weekStart(d);
    } else if (view == CalView.month) {
      base = DateTime(d.year, d.month, 1);
    } else {
      base = dateOnly(d);
    }
    focus = base;
  }

  DateTime _pageStart(int i) {
    final k = i - _mid;
    if (view == CalView.month) return DateTime(base.year, base.month + k, 1);
    return addDays(base, k * _n);
  }

  void _go(CalView v, DateTime d) {
    final old = pc;
    setState(() {
      view = v;
      _rebase(d);
      pc = PageController(initialPage: _mid);
      _gen++;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  /// Used by the home screen when another tab wants to show a date.
  void showDay(DateTime d) => _go(CalView.day, d);

  String get _title {
    if (view == CalView.month) return '${monLong[focus.month - 1]} ${focus.year}';
    final end = addDays(focus, _n - 1);
    if (focus.month == end.month) return '${monLong[focus.month - 1]} ${focus.year}';
    return '${monShort[focus.month - 1]} – ${monShort[end.month - 1]} ${end.year}';
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: InkWell(
          onTap: () async {
            final d = await pickDate(context, focus);
            if (d != null) _go(view, d);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(_title, overflow: TextOverflow.ellipsis)),
              Icon(Icons.arrow_drop_down, color: p.muted),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Today',
            icon: const Icon(Icons.today),
            onPressed: () => _go(view, DateTime.now()),
          ),
          PopupMenuButton<CalView>(
            tooltip: 'View',
            icon: const Icon(Icons.view_week_outlined),
            initialValue: view,
            onSelected: (v) => _go(v, view == CalView.month ? DateTime.now() : focus),
            itemBuilder: (_) => const [
              PopupMenuItem(value: CalView.day, child: Text('Day')),
              PopupMenuItem(value: CalView.three, child: Text('3 days')),
              PopupMenuItem(value: CalView.week, child: Text('Week')),
              PopupMenuItem(value: CalView.month, child: Text('Month')),
            ],
          ),
          IconButton(
            tooltip: 'New task',
            icon: const Icon(Icons.add),
            onPressed: () => showTaskEditor(context,
                date: view == CalView.day ? focus : DateTime.now()),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) => PageView.builder(
          key: ValueKey(_gen),
          controller: pc,
          onPageChanged: (i) => setState(() => focus = _pageStart(i)),
          itemBuilder: (context, i) {
            final start = _pageStart(i);
            if (view == CalView.month) {
              return _MonthPage(month: start, onDay: (d) => _go(CalView.day, d));
            }
            return _GridPage(
              key: ValueKey(dkey(start)),
              start: start,
              days: _n,
              initialScroll: scrollY,
              onScroll: (y) => scrollY = y,
              onDay: (d) => _go(CalView.day, d),
            );
          },
        ),
      ),
    );
  }
}

// ---------------- time grid (day / 3 days / week) ----------------

class _Item {
  final int start;
  final int end;
  final Task? task;
  final ClassSlot? slot;
  int col = 0;
  int cols = 1;
  _Item(this.start, this.end, {this.task, this.slot});
}

void _layout(List<_Item> items) {
  items.sort((a, b) => a.start != b.start ? a.start.compareTo(b.start) : b.end.compareTo(a.end));
  var cluster = <_Item>[];
  var clusterEnd = -1;
  void flush() {
    final ends = <int>[];
    for (final it in cluster) {
      var c = ends.indexWhere((e) => e <= it.start);
      if (c == -1) {
        ends.add(it.end);
        c = ends.length - 1;
      } else {
        ends[c] = it.end;
      }
      it.col = c;
    }
    for (final it in cluster) {
      it.cols = ends.length;
    }
    cluster = <_Item>[];
  }

  for (final it in items) {
    if (cluster.isNotEmpty && it.start >= clusterEnd) {
      flush();
      clusterEnd = -1;
    }
    cluster.add(it);
    if (it.end > clusterEnd) clusterEnd = it.end;
  }
  if (cluster.isNotEmpty) flush();
}

class _GridPage extends StatefulWidget {
  final DateTime start;
  final int days;
  final double initialScroll;
  final ValueChanged<double> onScroll;
  final ValueChanged<DateTime> onDay;
  const _GridPage({
    super.key,
    required this.start,
    required this.days,
    required this.initialScroll,
    required this.onScroll,
    required this.onDay,
  });

  @override
  State<_GridPage> createState() => _GridPageState();
}

class _GridPageState extends State<_GridPage> {
  late final ScrollController sc;
  static const double hourH = 56;

  @override
  void initState() {
    super.initState();
    sc = ScrollController(initialScrollOffset: widget.initialScroll);
    sc.addListener(() => widget.onScroll(sc.offset));
  }

  @override
  void dispose() {
    sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final now = DateTime.now();
    final days = [for (var i = 0; i < widget.days; i++) addDays(widget.start, i)];
    final compact = widget.days > 3;
    final untimed = {
      for (final d in days) dkey(d): app.tasksOn(dkey(d)).where((t) => t.startMin == null).toList()
    };
    final anyUntimed = untimed.values.any((l) => l.isNotEmpty);

    return Column(
      children: [
        // Day headers
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: Row(
            children: [
              const SizedBox(width: _gutter),
              for (final d in days)
                Expanded(
                  child: InkWell(
                    onTap: () => widget.onDay(d),
                    child: Column(
                      children: [
                        Text(wdShort[d.weekday - 1].toUpperCase(),
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: sameDay(d, now) ? p.accent : p.muted)),
                        const SizedBox(height: 4),
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: sameDay(d, now) ? p.accent : Colors.transparent,
                          ),
                          child: Text('${d.day}',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: sameDay(d, now) ? p.bg : p.text)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Tasks without a time
        if (anyUntimed)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _gutter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3, right: 6),
                    child: Text('any\ntime',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 9, color: p.muted, height: 1.1)),
                  ),
                ),
                for (final d in days)
                  Expanded(child: _untimedCell(context, untimed[dkey(d)]!, compact, d)),
              ],
            ),
          ),
        Divider(height: 1, color: p.line),
        Expanded(
          child: SingleChildScrollView(
            controller: sc,
            child: SizedBox(
              height: 24 * hourH,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: _gutter,
                    child: Stack(
                      children: [
                        for (var h = 1; h < 24; h++)
                          Positioned(
                            top: h * hourH - 7,
                            right: 6,
                            child: Text(fmtMin(h * 60),
                                style: TextStyle(fontSize: 10, color: p.muted)),
                          ),
                      ],
                    ),
                  ),
                  for (final d in days)
                    Expanded(child: _DayColumn(day: d, hourH: hourH, compact: compact)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _untimedCell(BuildContext context, List<Task> list, bool compact, DateTime d) {
    final p = Pal.of(context);
    final show = list.take(compact ? 2 : 3).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final t in show)
            GestureDetector(
              onTap: () => showTaskSheet(context, t),
              child: Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: t.cat.color.withValues(alpha: t.status == TaskStatus.done ? 0.25 : 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(t.title,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: compact ? 9.5 : 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      decoration: t.status == TaskStatus.done ? TextDecoration.lineThrough : null,
                    )),
              ),
            ),
          if (list.length > show.length)
            GestureDetector(
              onTap: () => widget.onDay(d),
              child: Text('+${list.length - show.length}',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: p.muted)),
            ),
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  final DateTime day;
  final double hourH;
  final bool compact;
  const _DayColumn({required this.day, required this.hourH, required this.compact});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final now = DateTime.now();
    final items = <_Item>[
      for (final s in app.classesOn(day)) _Item(s.startMin, s.endMin, slot: s),
      for (final t in app.tasksOn(dkey(day)))
        if (t.startMin != null)
          _Item(t.startMin!, (t.startMin! + (t.durationMin < 20 ? 20 : t.durationMin)).clamp(0, 1440).toInt(),
              task: t),
    ];
    _layout(items);

    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _GridPainter(p.line, hourH)),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) {
                  final m = ((d.localPosition.dy / hourH * 60) ~/ 30) * 30;
                  showTaskEditor(context, date: day, startMin: m.clamp(0, 23 * 60 + 30).toInt());
                },
              ),
            ),
            for (final it in items)
              Positioned(
                top: it.start / 60 * hourH + 1,
                left: it.col * w / it.cols + 1,
                width: w / it.cols - 2,
                height: ((it.end - it.start) / 60 * hourH - 2).clamp(16.0, 24 * hourH).toDouble(),
                child: it.task != null
                    ? _TaskBlock(task: it.task!, compact: compact)
                    : _ClassBlock(slot: it.slot!, day: day, compact: compact),
              ),
            if (sameDay(day, now))
              Positioned(
                top: (now.hour * 60 + now.minute) / 60 * hourH - 1,
                left: 0,
                right: 0,
                child: Container(height: 2, color: const Color(0xFFEA4335)),
              ),
          ],
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color line;
  final double hourH;
  _GridPainter(this.line, this.hourH);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (var h = 1; h < 24; h++) {
      canvas.drawLine(Offset(0, h * hourH), Offset(size.width, h * hourH), paint);
    }
    canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.line != line || old.hourH != hourH;
}

class _TaskBlock extends StatelessWidget {
  final Task task;
  final bool compact;
  const _TaskBlock({required this.task, required this.compact});

  @override
  Widget build(BuildContext context) {
    final done = task.status == TaskStatus.done;
    final col = task.cat.color;
    final mark = task.status == TaskStatus.done
        ? '✓ '
        : task.status == TaskStatus.partial
            ? '~ '
            : task.status == TaskStatus.missed
                ? '✕ '
                : '';
    return GestureDetector(
      onTap: () => showTaskSheet(context, task),
      child: Container(
        clipBehavior: Clip.hardEdge,
        padding: EdgeInsets.symmetric(horizontal: compact ? 3 : 8, vertical: 2),
        decoration: BoxDecoration(
          color: col.withValues(alpha: done ? 0.3 : 0.85),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: '$mark${task.title}'),
            if (!compact) TextSpan(text: '\n${fmtMin(task.startMin!)}', style: const TextStyle(fontSize: 11)),
          ]),
          overflow: TextOverflow.clip,
          style: TextStyle(
            fontSize: compact ? 10 : 13,
            height: 1.2,
            color: Colors.white,
            fontWeight: FontWeight.w600,
            decoration: done ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}

class _ClassBlock extends StatelessWidget {
  final ClassSlot slot;
  final DateTime day;
  final bool compact;
  const _ClassBlock({required this.slot, required this.day, required this.compact});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final c = app.courseById(slot.courseId)!;
    final surprise = app.isSurprise(c.id, day);
    return GestureDetector(
      onTap: () => _showClassSheet(context, slot, day),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 3 : 8, vertical: 2),
        decoration: BoxDecoration(
          color: c.color.withValues(alpha: 0.28),
          border: Border(
            left: BorderSide(color: c.color, width: 3),
            top: surprise ? const BorderSide(color: kPartial, width: 2) : BorderSide.none,
            right: surprise ? const BorderSide(color: kPartial, width: 2) : BorderSide.none,
            bottom: surprise ? const BorderSide(color: kPartial, width: 2) : BorderSide.none,
          ),
        ),
        child: Text.rich(
          TextSpan(children: [
            if (surprise) const TextSpan(text: '⚡', style: TextStyle(color: kPartial)),
            TextSpan(text: c.short),
            if (!compact)
              TextSpan(
                  text: '\n${slot.kind}${slot.room.isEmpty ? '' : ' · ${slot.room}'}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: p.muted)),
            if (surprise && !compact)
              const TextSpan(
                  text: '\nSurprise quiz possible', style: TextStyle(fontSize: 11, color: kPartial)),
          ]),
          overflow: TextOverflow.clip,
          style: TextStyle(
              fontSize: compact ? 10 : 13, height: 1.2, color: p.text, fontWeight: FontWeight.w600),
        ),
        ),
      ),
    );
  }
}

void _showClassSheet(BuildContext context, ClassSlot slot, DateTime day) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (ctx) => ListenableBuilder(
      listenable: app,
      builder: (ctx, _) {
        final p = Pal.of(ctx);
        final c = app.courseById(slot.courseId);
        if (c == null) return const SizedBox(height: 40);
        final ws = weekStart(day);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(backgroundColor: c.color, radius: 7),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(c.name,
                        style: TextStyle(color: p.text, fontSize: 19, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                  '${slot.kind} · ${fmtDate(day)} · ${fmtMin(slot.startMin)} – ${fmtMin(slot.endMin)}'
                  '${slot.room.isEmpty ? '' : ' · ${slot.room}'}',
                  style: TextStyle(color: p.muted, fontSize: 14)),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: app.isSurprise(c.id, day),
                onChanged: (v) => app.setSurprise(c.id, day, v),
                title: Text('Surprise quiz may come this week',
                    style: TextStyle(color: p.text, fontSize: 15)),
                subtitle: Text(
                    'Marks every ${c.short} class from ${ws.day} ${monShort[ws.month - 1]} to '
                    '${addDays(ws, 6).day} ${monShort[addDays(ws, 6).month - 1]}',
                    style: TextStyle(color: p.muted, fontSize: 12.5)),
              ),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.add_task, size: 18),
                    label: const Text('Add task for this course'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      showTaskEditor(context, date: day, courseId: c.id);
                    },
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                          context, MaterialPageRoute<void>(builder: (_) => const TimetablePage()));
                    },
                    child: const Text('Timetable'),
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

// ---------------- month ----------------

class _MonthPage extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onDay;
  const _MonthPage({required this.month, required this.onDay});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final now = DateTime.now();
    final first = weekStart(DateTime(month.year, month.month, 1));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              for (final w in wdShort)
                Expanded(
                  child: Text(w.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: p.muted)),
                ),
            ],
          ),
        ),
        for (var r = 0; r < 6; r++)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < 7; c++) Expanded(child: _cell(context, addDays(first, r * 7 + c), now, p)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(BuildContext context, DateTime d, DateTime now, Pal p) {
    final inMonth = d.month == month.month;
    final tasks = app.tasksOn(dkey(d));
    final show = tasks.take(3).toList();
    final today = sameDay(d, now);
    return InkWell(
      onTap: () => onDay(d),
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: p.line), left: BorderSide(color: p.line, width: 0.5)),
        ),
        padding: const EdgeInsets.fromLTRB(2, 3, 2, 0),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: today ? p.accent : Colors.transparent),
                  child: Text('${d.day}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: today ? p.bg : (inMonth ? p.text : p.muted.withValues(alpha: 0.5)))),
                ),
              ),
              const SizedBox(height: 2),
              for (final t in show)
                Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: t.cat.color.withValues(alpha: t.status == TaskStatus.done ? 0.25 : 0.75),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(t.title,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w500)),
                ),
              if (tasks.length > show.length)
                Text('+${tasks.length - show.length}',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: p.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
