import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';

class Pal {
  final Color bg, card, card2, line, text, muted, accent;
  const Pal({
    required this.bg,
    required this.card,
    required this.card2,
    required this.line,
    required this.text,
    required this.muted,
    required this.accent,
  });

  static const dark = Pal(
    bg: Color(0xFF0F1115),
    card: Color(0xFF181B22),
    card2: Color(0xFF21252E),
    line: Color(0xFF2B303B),
    text: Color(0xFFE7E9EE),
    muted: Color(0xFF98A1B0),
    accent: Color(0xFF8AB4F8),
  );
  static const light = Pal(
    bg: Color(0xFFF6F7F9),
    card: Color(0xFFFFFFFF),
    card2: Color(0xFFEDEFF3),
    line: Color(0xFFD9DCE3),
    text: Color(0xFF1C1E23),
    muted: Color(0xFF5F6673),
    accent: Color(0xFF1A73E8),
  );

  static Pal of(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? dark : light;
}

const kDone = Color(0xFF57C785);
const kPartial = Color(0xFFF2A93B);
const kMissed = Color(0xFFEF6B6B);

Color statusColor(TaskStatus s) {
  switch (s) {
    case TaskStatus.done:
      return kDone;
    case TaskStatus.partial:
      return kPartial;
    case TaskStatus.missed:
      return kMissed;
    case TaskStatus.none:
      return const Color(0xFF98A1B0);
  }
}

String statusLabel(TaskStatus s) {
  switch (s) {
    case TaskStatus.done:
      return 'Done (70–100%)';
    case TaskStatus.partial:
      return 'Partly (20–70%)';
    case TaskStatus.missed:
      return 'Not done (0–20%)';
    case TaskStatus.none:
      return 'Not marked';
  }
}

ThemeData themeFor(Brightness b) {
  final p = b == Brightness.dark ? Pal.dark : Pal.light;
  final scheme = ColorScheme.fromSeed(seedColor: p.accent, brightness: b)
      .copyWith(surface: p.bg, primary: p.accent);
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    dividerColor: p.line,
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(color: p.text, fontSize: 20, fontWeight: FontWeight.w600),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.accent.withValues(alpha: 0.22),
      height: 64,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.accent,
      foregroundColor: b == Brightness.dark ? const Color(0xFF0F1115) : Colors.white,
    ),
    listTileTheme: ListTileThemeData(iconColor: p.muted, textColor: p.text),
  );
}

/// Tick, ~ and cross. Tapping the selected one clears it.
class StatusButtons extends StatelessWidget {
  final Task task;
  final double size;
  const StatusButtons({super.key, required this.task, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(context, TaskStatus.done),
        const SizedBox(width: 6),
        _btn(context, TaskStatus.partial),
        const SizedBox(width: 6),
        _btn(context, TaskStatus.missed),
      ],
    );
  }

  Widget _btn(BuildContext context, TaskStatus s) {
    final p = Pal.of(context);
    final on = task.status == s;
    final col = statusColor(s);
    final fg = on ? const Color(0xFF0F1115) : p.muted;
    Widget glyph;
    if (s == TaskStatus.done) {
      glyph = Icon(Icons.check, size: size * 0.56, color: fg);
    } else if (s == TaskStatus.missed) {
      glyph = Icon(Icons.close, size: size * 0.56, color: fg);
    } else {
      glyph = Text('~',
          style: TextStyle(fontSize: size * 0.62, height: 1.0, fontWeight: FontWeight.w700, color: fg));
    }
    return Tooltip(
      message: statusLabel(s),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => app.setStatus(task, s),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? col : Colors.transparent,
            border: Border.all(color: on ? col : p.line, width: 1.5),
          ),
          child: glyph,
        ),
      ),
    );
  }
}

/// Rounded card with a coloured strip on the left edge.
class AccentCard extends StatelessWidget {
  final Color accent;
  final Color background;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double strip;
  const AccentCard({
    super.key,
    required this.accent,
    required this.background,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = 12,
    this.strip = 4,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: background,
          border: Border(left: BorderSide(color: accent, width: strip)),
        ),
        child: child,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text.toUpperCase(),
                style: TextStyle(
                    color: p.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;
  const Pill(this.text, {super.key, required this.color, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 5)],
          Flexible(
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.text, fontSize: 12.5, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: child);
  }
}

Future<int?> pickMinutes(BuildContext context, int initial) async {
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: (initial ~/ 60) % 24, minute: initial % 60),
  );
  if (t == null) return null;
  return t.hour * 60 + t.minute;
}

Future<DateTime?> pickDate(BuildContext context, DateTime initial) {
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(initial.year - 2),
    lastDate: DateTime(initial.year + 3),
  );
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
}

String taskSubtitle(Task t) {
  final c = app.courseById(t.courseId);
  final bits = <String>[
    if (t.startMin != null) '${fmtMin(t.startMin!)} – ${fmtMin(t.startMin! + t.durationMin)}',
    t.cat.label,
    if (c != null) c.short,
  ];
  return bits.join(' · ');
}
