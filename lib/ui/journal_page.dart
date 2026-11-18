import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../journal_rules.dart';
import '../models.dart';
import '../speech.dart';
import '../store.dart';
import 'common.dart';

/// Daily journal. Speak or type freely; the text is sorted into coloured sections.
class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  DateTime day = dateOnly(DateTime.now());
  final TextEditingController ctl = TextEditingController();
  final Dictation dict = Dictation();
  String prefix = '';
  JSection? target; // null = sort automatically

  @override
  void initState() {
    super.initState();
    dict.addListener(_onDict);
  }

  @override
  void dispose() {
    dict.removeListener(_onDict);
    dict.dispose();
    ctl.dispose();
    super.dispose();
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

  Future<void> _toggleMic() async {
    if (dict.active) {
      await dict.stop();
    } else {
      prefix = ctl.text.trim();
      FocusScope.of(context).unfocus();
      await dict.start(app.settings.speechLocale);
    }
  }

  Future<void> _send() async {
    if (dict.active) await dict.stop();
    final text = ctl.text.trim();
    if (text.isEmpty) return;
    List<JournalBlock> blocks;
    if (target == null) {
      blocks = sortJournal(text, vocab: app.vocab);
    } else {
      blocks = [
        JournalBlock(id: newId(), section: target!, text: text, star: target == JSection.mistakes)
      ];
    }
    app.addJournalBlocks(dkey(day), blocks);
    ctl.clear();
    prefix = '';
  }

  void _share() {
    final blocks = app.journalOn(dkey(day));
    if (blocks.isEmpty) {
      toast(context, 'Nothing written for this day yet');
      return;
    }
    SharePlus.instance.share(ShareParams(text: journalAsText(day, blocks)));
  }

  void _history() {
    final keys = app.journal.keys.toList()..sort((a, b) => b.compareTo(a));
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) {
        final p = Pal.of(ctx);
        if (keys.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(28),
            child: Text('No journal entries yet.', style: TextStyle(color: p.muted)),
          );
        }
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 10),
          children: [
            for (final k in keys)
              ListTile(
                title: Text(fmtDate(parseKey(k)) + ' ${parseKey(k).year}'),
                subtitle: Text(
                  app.journalOn(k).map((b) => b.text).join(' '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.muted),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => day = parseKey(k));
                },
              ),
          ],
        );
      },
    );
  }

  void _blockMenu(JournalBlock b) {
    final key = dkey(day);
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) {
        final p = Pal.of(ctx);
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit text'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final t = await _editText(b.text);
                  if (t != null && t.trim().isNotEmpty) {
                    b.text = t.trim();
                    app.touch();
                  }
                },
              ),
              ListTile(
                leading: Icon(b.star ? Icons.star : Icons.star_border, color: kPartial),
                title: Text(b.star ? 'Remove highlight' : 'Highlight (keep in mind)'),
                onTap: () {
                  Navigator.pop(ctx);
                  b.star = !b.star;
                  app.touch();
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Text('Move to', style: TextStyle(color: p.muted, fontSize: 12.5)),
              ),
              for (final s in JSection.values)
                if (s != b.section)
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(backgroundColor: s.color, radius: 7),
                    title: Text(s.label),
                    onTap: () {
                      Navigator.pop(ctx);
                      b.section = s;
                      if (s == JSection.mistakes) b.star = true;
                      app.touch();
                    },
                  ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: kMissed),
                title: const Text('Delete', style: TextStyle(color: kMissed)),
                onTap: () {
                  Navigator.pop(ctx);
                  app.removeJournalBlock(key, b.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _editText(String initial) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit'),
        content: TextField(controller: c, minLines: 3, maxLines: 10, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Save')),
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
        final now = DateTime.now();
        final blocks = app.journalOn(dkey(day));
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: InkWell(
              onTap: () async {
                final d = await pickDate(context, day);
                if (d != null) setState(() => day = dateOnly(d));
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Journal'),
                  Text('${relDate(day, now)} · ${day.day} ${monLong[day.month - 1]}',
                      style: TextStyle(color: p.muted, fontSize: 12.5, fontWeight: FontWeight.w400)),
                ],
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Previous day',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => day = addDays(day, -1)),
              ),
              IconButton(
                tooltip: 'Next day',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => day = addDays(day, 1)),
              ),
              IconButton(tooltip: 'All entries', icon: const Icon(Icons.history), onPressed: _history),
              IconButton(tooltip: 'Share', icon: const Icon(Icons.share_outlined), onPressed: _share),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: blocks.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                              'Tell me about your day: what happened, who you talked to, what you '
                              'learned, what went wrong and what you will do better.\n\n'
                              'I will sort it into sections and highlight what to keep in mind.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: p.muted, fontSize: 14.5, height: 1.45)),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        children: [
                          for (final s in JSection.values)
                            if (blocks.any((b) => b.section == s))
                              _section(context, s, blocks.where((b) => b.section == s).toList()),
                        ],
                      ),
              ),
              _composer(context),
            ],
          ),
        );
      },
    );
  }

  Widget _section(BuildContext context, JSection s, List<JournalBlock> items) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AccentCard(
        accent: s.color,
        background: s.color.withValues(alpha: 0.10),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
        radius: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${s.emoji}  ${s.label}',
                style: TextStyle(color: s.color, fontSize: 13.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final b in items)
              InkWell(
                onTap: () => _blockMenu(b),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: EdgeInsets.symmetric(horizontal: b.star ? 10 : 0, vertical: b.star ? 8 : 2),
                  decoration: BoxDecoration(
                    color: b.star ? kPartial.withValues(alpha: 0.20) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (b.star)
                        const Padding(
                          padding: EdgeInsets.only(right: 8, top: 2),
                          child: Icon(Icons.star, size: 16, color: kPartial),
                        ),
                      Expanded(
                        child: Text(b.text,
                            style: TextStyle(
                                color: p.text,
                                fontSize: 15,
                                height: 1.4,
                                fontWeight: b.star ? FontWeight.w600 : FontWeight.w400)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _composer(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.line))),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PopupMenuButton<String>(
                tooltip: 'Where should this go?',
                onSelected: (v) => setState(() => target = v == 'auto' ? null : sectionFromName(v)),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'auto', child: Text('Sort automatically')),
                  for (final s in JSection.values) PopupMenuItem(value: s.name, child: Text(s.label)),
                ],
                child: Pill(target == null ? 'Sort automatically' : target!.label,
                    color: target?.color ?? p.accent, icon: Icons.arrow_drop_down),
              ),
              const Spacer(),
              if (dict.active)
                const Text('Listening…', style: TextStyle(color: kMissed, fontSize: 12.5)),
            ],
          ),
          if (dict.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(dict.error!, style: const TextStyle(color: kMissed, fontSize: 12)),
            ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: ctl,
                  minLines: 1,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Speak or write about your day'),
                ),
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                tooltip: dict.active ? 'Stop' : 'Speak',
                style: IconButton.styleFrom(backgroundColor: dict.active ? kMissed : p.accent),
                icon: Icon(dict.active ? Icons.stop : Icons.mic, color: const Color(0xFF0F1115)),
                onPressed: _toggleMic,
              ),
              IconButton(
                tooltip: 'Add to journal',
                icon: Icon(Icons.send, color: p.accent),
                onPressed: _send,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
