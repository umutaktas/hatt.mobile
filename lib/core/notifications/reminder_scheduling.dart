/// Pure scheduling rule for the streak reminder (CLAUDE.md §7: yalnız local
/// notification — seri hatırlatıcı). Separated from the plugin wrapper so the
/// logic is unit-testable without platform channels.
library;

/// Returns the next instant a "your streak is at risk" reminder should fire,
/// or `null` if no reminder is needed (no streak to protect).
///
/// Rules:
///   * Reminders fire at [reminderHour] local time (default 20:00).
///   * If the user already practiced today, remind tomorrow (to protect the
///     streak they extended today).
///   * If they haven't practiced today and today's slot is still ahead, remind
///     today; if the slot already passed, remind tomorrow (today's streak may
///     already be lost — tomorrow's reminder protects what remains).
///   * With no activity ever and no streak, there is nothing to protect →
///     `null` (don't nag fresh installs).
DateTime? nextStreakReminder({
  required DateTime now,
  required DateTime? lastActiveDay,
  required int currentStreak,
  int reminderHour = 20,
}) {
  if (lastActiveDay == null || currentStreak <= 0) return null;

  final today = DateTime(now.year, now.month, now.day);
  final last = DateTime(lastActiveDay.year, lastActiveDay.month, lastActiveDay.day);
  final practicedToday = last == today;

  final todaySlot = DateTime(now.year, now.month, now.day, reminderHour);
  if (practicedToday || !now.isBefore(todaySlot)) {
    return todaySlot.add(const Duration(days: 1));
  }
  return todaySlot;
}
