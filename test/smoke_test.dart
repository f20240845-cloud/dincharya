import 'package:dincharya/main.dart';
import 'package:dincharya/models.dart';
import 'package:dincharya/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('every tab builds with data in it', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // The test font is much wider than a real one, so ignore pure overflow warnings.
    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) return;
      old?.call(d);
    };
    addTearDown(() => FlutterError.onError = old);

    final today = dateOnly(DateTime.now());
    app.courses = [Course(id: 'dd', name: 'Digital Design', abbrs: ['DD'])];
    app.slots = [
      ClassSlot(id: 's1', courseId: 'dd', weekday: today.weekday, startMin: 9 * 60, endMin: 9 * 60 + 50),
    ];
    app.surprises = {'dd|${dkey(weekStart(today))}'};
    app.tasks = [
      Task(id: 't1', title: 'DD Quiz', date: dkey(today), startMin: 17 * 60, cat: Cat.quiz, courseId: 'dd'),
      Task(id: 't2', title: 'Revise K-maps', date: dkey(today), startMin: 17 * 60 + 30, cat: Cat.study,
          status: TaskStatus.partial),
      Task(id: 't3', title: 'Buy groceries', date: dkey(today), cat: Cat.errand, status: TaskStatus.done),
      Task(id: 't4', title: 'Old task', date: dkey(addDays(today, -1)), cat: Cat.personal),
    ];
    app.journal = {
      dkey(today): [
        JournalBlock(id: 'j1', section: JSection.learnings, text: 'I learned to start early.'),
        JournalBlock(id: 'j2', section: JSection.mistakes, text: 'Next time revise daily.', star: true),
      ],
    };
    app.manifests = [Manifestation(id: 'm1', text: 'I finish what I start.', created: dkey(today))];

    await tester.pumpWidget(const DincharyaApp());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Calendar'), findsWidgets);

    for (final label in ['Today', 'Journal', 'Progress', 'More', 'Calendar']) {
      await tester.tap(find.text(label).last);
      await tester.pump(const Duration(milliseconds: 400));
    }

    // Dispose the tree so the calendar's clock timer is cancelled.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
