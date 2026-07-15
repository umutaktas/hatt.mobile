import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../db/database.dart';
import 'reminder_scheduling.dart';

/// Streak-risk local notification (CLAUDE.md §7, Phase 6). One pending
/// notification at a time; rescheduled on app start and after each completed
/// lesson. All failures are swallowed with a debug log — notifications are a
/// nicety and must never break the app (e.g. permission denied, simulators).
class StreakReminderService {
  StreakReminderService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const _notificationId = 1001;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings);
    // iOS explicit permission prompt (Android <13 needs none; 13+ handled by
    // the plugin's requestNotificationsPermission below).
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  /// Recomputes and (re)schedules the single streak reminder from the current
  /// [user] state. Cancels the previous one first so at most one is pending.
  Future<void> reschedule(UserStateRow user, {DateTime? now}) async {
    try {
      await _ensureInitialized();
      await _plugin.cancel(_notificationId);

      final next = nextStreakReminder(
        now: now ?? DateTime.now(),
        lastActiveDay: user.lastActiveDay,
        currentStreak: user.streakCurrent,
      );
      if (next == null) return;

      await _plugin.zonedSchedule(
        _notificationId,
        'Serin risk altında! 🔥',
        '${user.streakCurrent} günlük serini korumak için bugün kısa bir ders yap.',
        tz.TZDateTime.from(next, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'streak',
            'Seri hatırlatıcı',
            channelDescription: 'Günlük seri koruma hatırlatması',
            importance: Importance.defaultImportance,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('StreakReminderService: scheduling skipped: $e');
    }
  }
}
