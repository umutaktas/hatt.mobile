import 'package:flutter_test/flutter_test.dart';
import 'package:hatt/core/notifications/reminder_scheduling.dart';

void main() {
  final today1400 = DateTime(2026, 7, 15, 14); // Wednesday 14:00
  final today2100 = DateTime(2026, 7, 15, 21); // after the 20:00 slot
  final yesterday = DateTime(2026, 7, 14, 9);
  final today = DateTime(2026, 7, 15, 8);

  test('no reminder without any streak to protect', () {
    expect(
      nextStreakReminder(now: today1400, lastActiveDay: null, currentStreak: 0),
      isNull,
    );
    expect(
      nextStreakReminder(
          now: today1400, lastActiveDay: yesterday, currentStreak: 0,),
      isNull,
    );
  });

  test('not practiced today, before slot → today 20:00', () {
    final next = nextStreakReminder(
        now: today1400, lastActiveDay: yesterday, currentStreak: 3,);
    expect(next, DateTime(2026, 7, 15, 20));
  });

  test('not practiced today, after slot → tomorrow 20:00', () {
    final next = nextStreakReminder(
        now: today2100, lastActiveDay: yesterday, currentStreak: 3,);
    expect(next, DateTime(2026, 7, 16, 20));
  });

  test('already practiced today → tomorrow 20:00', () {
    final next = nextStreakReminder(
        now: today1400, lastActiveDay: today, currentStreak: 4,);
    expect(next, DateTime(2026, 7, 16, 20));
  });

  test('custom reminder hour is respected', () {
    final next = nextStreakReminder(
      now: today1400,
      lastActiveDay: yesterday,
      currentStreak: 1,
      reminderHour: 9, // slot already passed at 14:00
    );
    expect(next, DateTime(2026, 7, 16, 9));
  });
}
