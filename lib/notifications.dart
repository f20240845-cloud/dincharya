import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

/// Local reminders. Everything is scheduled on the phone; nothing needs the internet.
class Notifier {
  static final FlutterLocalNotificationsPlugin _p = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static const int _reviewId = 9000;
  static const int maxScheduled = 60;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'Task, study and class reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _p.initialize(const InitializationSettings(android: android));
      _ready = true;
    } catch (e) {
      debugPrint('Notifier.init failed: $e');
    }
  }

  static Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final a = _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final ok = await a?.requestNotificationsPermission();
      return ok ?? false;
    } catch (e) {
      debugPrint('Notifier.requestPermission failed: $e');
      return false;
    }
  }

  static Future<void> showNow(String title, String body) async {
    if (!_ready) return;
    try {
      await _p.show(9999, title, body, _details);
    } catch (e) {
      debugPrint('Notifier.showNow failed: $e');
    }
  }

  /// Replaces every scheduled reminder with [items] (soonest first, capped) plus the
  /// optional daily evening review at [dailyReviewMin] minutes after midnight.
  static Future<void> sync(List<Reminder> items, {int? dailyReviewMin}) async {
    if (!_ready) return;
    try {
      await _p.cancelAll();
      final now = DateTime.now();
      final upcoming = items.where((r) => r.when.isAfter(now.add(const Duration(seconds: 20)))).toList()
        ..sort((a, b) => a.when.compareTo(b.when));
      var id = 1;
      for (final r in upcoming.take(maxScheduled)) {
        await _schedule(id++, r.title, r.body, r.when, null);
      }
      if (dailyReviewMin != null) {
        var t = DateTime(now.year, now.month, now.day, dailyReviewMin ~/ 60, dailyReviewMin % 60);
        if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
        await _schedule(
          _reviewId,
          'Evening review',
          'Mark how much of each task you finished and move what is left.',
          t,
          DateTimeComponents.time,
        );
      }
    } catch (e) {
      debugPrint('Notifier.sync failed: $e');
    }
  }

  static Future<void> _schedule(
      int id, String title, String body, DateTime when, DateTimeComponents? repeat) async {
    // Scheduling the absolute instant in UTC avoids needing the device's zone name.
    final t = tz.TZDateTime.from(when, tz.UTC);
    try {
      await _p.zonedSchedule(
        id,
        title,
        body,
        t,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: repeat,
      );
    } catch (e) {
      try {
        await _p.zonedSchedule(
          id,
          title,
          body,
          t,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: repeat,
        );
      } catch (e2) {
        debugPrint('Notifier schedule failed: $e2');
      }
    }
  }
}
