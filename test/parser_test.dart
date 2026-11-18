import 'package:dincharya/journal_rules.dart';
import 'package:dincharya/models.dart';
import 'package:dincharya/parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Monday 16 November 2026, 3:00 PM
  final now = DateTime(2026, 11, 16, 15, 0);
  final courses = [
    Course(id: 'dd', name: 'Digital Design', abbrs: ['DD']),
    Course(id: 'oop', name: 'Object Oriented Programming', abbrs: ['OOP']),
    Course(id: 'os', name: 'Operating Systems', abbrs: ['OS']),
    Course(id: 'or', name: 'Operations Research', abbrs: ['OR']),
  ];

  List<Draft> p(String t, {Map<String, String> vocab = const {}}) =>
      parseTasks(t, now: now, courses: courses, vocab: vocab);

  test('quiz with course, weekday and time', () {
    final d = p('DD quiz next Friday at 5 pm');
    expect(d.length, 1);
    expect(d[0].cat, Cat.quiz);
    expect(d[0].courseId, 'dd');
    expect(dkey(d[0].date), '2026-11-27');
    expect(d[0].startMin, 17 * 60);
    expect(d[0].title, 'DD Quiz');
  });

  test('plain weekday means the coming one', () {
    final d = p('OOP lab test on Thursday');
    expect(d.length, 1);
    expect(d[0].cat, Cat.labTest);
    expect(d[0].courseId, 'oop');
    expect(dkey(d[0].date), '2026-11-19');
  });

  test('hinglish: kal subah 7 baje gym', () {
    final d = p('kal subah 7 baje gym');
    expect(d.length, 1);
    expect(dkey(d[0].date), '2026-11-17');
    expect(d[0].startMin, 7 * 60);
    expect(d[0].cat, Cat.health);
    expect(d[0].title, 'Gym');
  });

  test('two tasks joined by and', () {
    final d = p('I have to submit OOP assignment tomorrow and call mom at 9 pm');
    expect(d.length, 2);
    expect(d[0].cat, Cat.assignment);
    expect(d[0].courseId, 'oop');
    expect(dkey(d[0].date), '2026-11-17');
    expect(d[0].title, 'OOP Assignment');
    expect(d[1].title, 'Call mom');
    expect(d[1].startMin, 21 * 60);
    expect(d[1].cat, Cat.social);
  });

  test('devanagari with a custom word', () {
    final d = p('कल शाम 6 बजे डीडी क्विज़', vocab: {'डीडी': 'DD'});
    expect(d.length, 1);
    expect(d[0].cat, Cat.quiz);
    expect(d[0].courseId, 'dd');
    expect(dkey(d[0].date), '2026-11-17');
    expect(d[0].startMin, 18 * 60);
  });

  test('surprise quiz flags the course', () {
    final d = p('OS has a surprise quiz this week');
    expect(d.length, 1);
    expect(d[0].surprise, true);
    expect(d[0].courseId, 'os');
  });

  test('time range gives a duration', () {
    final d = p('study DD from 5 to 7 pm');
    expect(d.length, 1);
    expect(d[0].startMin, 17 * 60);
    expect(d[0].durationMin, 120);
    expect(d[0].cat, Cat.study);
    expect(d[0].courseId, 'dd');
    expect(d[0].title, 'Study DD');
  });

  test('numeric date and p.m. with dots', () {
    final a = p('compre on 5/12');
    expect(a.length, 1);
    expect(a[0].cat, Cat.compre);
    expect(dkey(a[0].date), '2026-12-05');
    final b = p('DD quiz at 5 p.m. tomorrow');
    expect(b.length, 1);
    expect(b[0].startMin, 17 * 60);
    expect(dkey(b[0].date), '2026-11-17');
  });

  test('a two-letter course name that is also a word', () {
    final a = p('buy milk or bread');
    expect(a.length, 1);
    expect(a[0].courseId, null);
    final b = p('OR midsem on 25 November');
    expect(b.length, 1);
    expect(b[0].courseId, 'or');
    expect(b[0].cat, Cat.midsem);
    expect(dkey(b[0].date), '2026-11-25');
  });

  test('non-study task without a date lands on today', () {
    final d = p('buy groceries');
    expect(d.length, 1);
    expect(d[0].cat, Cat.errand);
    expect(dkey(d[0].date), '2026-11-16');
    expect(d[0].startMin, null);
    expect(d[0].title, 'Buy groceries');
  });

  test('journal is sorted into sections', () {
    final blocks = sortJournal('Today I met Rahul in the library. I learned that starting early helps. '
        'My mistake was not revising, next time I will revise daily.');
    expect(blocks.length, 3);
    expect(blocks[0].section, JSection.interactions);
    expect(blocks[1].section, JSection.learnings);
    expect(blocks[2].section, JSection.mistakes);
    expect(blocks[2].star, true);
    final text = journalAsText(DateTime(2026, 11, 16), blocks);
    expect(text.contains('Keep in mind next time'), true);
  });
}
