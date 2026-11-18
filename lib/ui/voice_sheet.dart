import 'package:flutter/material.dart';

import '../models.dart';
import '../parser.dart';
import '../speech.dart';
import '../store.dart';
import 'common.dart';

/// Mic sheet: speak (or type), see the tasks it understood, fix them, add them.
Future<void> showVoiceSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => const _VoiceSheet(),
  );
}

const _locales = {'en_IN': 'English / Hinglish', 'hi_IN': 'हिंदी'};

class _VoiceSheet extends StatefulWidget {
  const _VoiceSheet();

  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<_VoiceSheet> {
  final Dictation dict = Dictation();
  final TextEditingController ctl = TextEditingController();
  String prefix = '';
  String parsedFor = '';
  List<Draft> drafts = [];

  @override
  void initState() {
    super.initState();
    dict.addListener(_onDict);
    ctl.addListener(_reparse);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    dict.removeListener(_onDict);
    dict.dispose();
    ctl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    prefix = ctl.text.trim();
    await dict.start(app.settings.speechLocale);
  }

  void _onDict() {
    if (!mounted) return;
    final heard = dict.text;
    if (heard.isNotEmpty) {
      final joined = prefix.isEmpty ? heard : '$prefix. $heard';
      if (ctl.text != joined) {
        ctl.value = TextEditingValue(
          text: joined,
          selection: TextSelection.collapsed(offset: joined.length),
        );
      }
    }
    setState(() {});
  }

  void _reparse() {
    if (ctl.text == parsedFor) return;
    parsedFor = ctl.text;
    setState(() {
      drafts = parseTasks(ctl.text, now: DateTime.now(), courses: app.courses, vocab: app.vocab);
    });
  }

  Future<void> _toggle() async {
    if (dict.active) {
      await dict.stop();
    } else {
      await _start();
    }
  }

  Future<void> _switchLocale() async {
    final next = app.settings.speechLocale == 'en_IN' ? 'hi_IN' : 'en_IN';
    app.settings.speechLocale = next;
    app.touch();
    if (dict.active) {
      await dict.stop();
      await _start();
    } else {
      setState(() {});
    }
  }

  void _add() {
    final msg = app.commitDrafts(drafts);
    Navigator.pop(context);
    toast(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final now = DateTime.now();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(dict.active ? 'Listening…' : 'Tell me your tasks',
                        style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                  Pill(_locales[app.settings.speechLocale] ?? app.settings.speechLocale,
                      color: p.accent, icon: Icons.translate, onTap: _switchLocale),
                ],
              ),
              const SizedBox(height: 4),
              Text('Try: "DD quiz next Friday at 5 pm and kal subah 7 baje gym"',
                  style: TextStyle(color: p.muted, fontSize: 12.5)),
              const SizedBox(height: 12),
              TextField(
                controller: ctl,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Speak, or type here'),
              ),
              if (dict.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(dict.error!, style: const TextStyle(color: kMissed, fontSize: 12.5)),
                ),
              const SizedBox(height: 14),
              Center(
                child: GestureDetector(
                  onTap: _toggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: dict.active ? 76 : 64,
                    height: dict.active ? 76 : 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dict.active ? kMissed : p.accent,
                      boxShadow: [
                        if (dict.active)
                          BoxShadow(color: kMissed.withValues(alpha: 0.45), blurRadius: 22, spreadRadius: 4),
                      ],
                    ),
                    child: Icon(dict.active ? Icons.stop : Icons.mic,
                        size: 32, color: const Color(0xFF0F1115)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (drafts.isNotEmpty)
                Text('I understood', style: TextStyle(color: p.muted, fontSize: 12.5)),
              for (var i = 0; i < drafts.length; i++) _draftCard(context, i, now),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: drafts.isEmpty ? null : _add,
                  child: Text(drafts.isEmpty
                      ? 'Nothing to add yet'
                      : 'Add ${drafts.length} item${drafts.length == 1 ? '' : 's'}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _draftCard(BuildContext context, int i, DateTime now) {
    final p = Pal.of(context);
    final d = drafts[i];
    final c = app.courseById(d.courseId);
    final weekOf = weekStart(d.date);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: AccentCard(
      accent: d.cat.color,
      background: p.card2,
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    d.surprise
                        ? 'Watch for a surprise quiz${c != null ? ' in ${c.short}' : ''}'
                        : d.title,
                    style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (d.surprise)
                  Text(
                      c == null
                          ? 'I could not tell which course. Add its abbreviation under More → Courses.'
                          : 'Marks every ${c.short} class in the week of ${weekOf.day} ${monShort[weekOf.month - 1]}.',
                      style: TextStyle(color: p.muted, fontSize: 12.5))
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Pill(relDate(d.date, now), color: p.accent, icon: Icons.event, onTap: () async {
                        final x = await pickDate(context, d.date);
                        if (x != null) setState(() => d.date = dateOnly(x));
                      }),
                      Pill(d.startMin == null ? 'Any time' : fmtMin(d.startMin!),
                          color: p.accent, icon: Icons.schedule, onTap: () async {
                        final x = await pickMinutes(context, d.startMin ?? 17 * 60);
                        if (x != null) setState(() => d.startMin = x);
                      }),
                      PopupMenuButton<Cat>(
                        tooltip: 'Change type',
                        onSelected: (v) => setState(() => d.cat = v),
                        itemBuilder: (_) => [
                          for (final k in Cat.values) PopupMenuItem(value: k, child: Text(k.label)),
                        ],
                        child: Pill(d.cat.label, color: d.cat.color, icon: d.cat.icon),
                      ),
                      if (c != null) Pill(c.short, color: c.color),
                    ],
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: Icon(Icons.close, size: 18, color: p.muted),
            onPressed: () => setState(() => drafts.removeAt(i)),
          ),
        ],
      ),
      ),
    );
  }
}
