import 'package:flutter_test/flutter_test.dart';
import 'package:hatt/core/analytics/analytics_service.dart';
import 'package:hatt/core/analytics/crash_reporter_service.dart';

void main() {
  group('Analytics & CrashReporter Tests', () {
    test('CrashReporterService initializes and logs errors without throwing', () {
      final crashReporter = CrashReporterService.instance;
      crashReporter.initialize();
      expect(crashReporter.enabled, isTrue);

      expect(
        () => crashReporter.recordError(
          Exception('Test non-fatal error'),
          StackTrace.current,
          reason: 'Unit test',
        ),
        returnsNormally,
      );

      expect(
        () => crashReporter.setUserIdentifier('user_123'),
        returnsNormally,
      );

      expect(
        () => crashReporter.logCustomKey('league_tier', 'bronze'),
        returnsNormally,
      );
    });

    test('AnalyticsService logs standard app events', () {
      final analytics = AnalyticsService();
      expect(analytics.enabled, isTrue);

      expect(() => analytics.logAppLaunch(), returnsNormally);
      expect(() => analytics.logLessonStarted('unit_1_lesson_1'), returnsNormally);
      expect(
        () => analytics.logLessonCompleted(
          nodeId: 'unit_1_lesson_1',
          score: 100,
          xpEarned: 15,
        ),
        returnsNormally,
      );
      expect(() => analytics.logStreakMilestone(7), returnsNormally);
      expect(() => analytics.logPaywallViewed('profile_button'), returnsNormally);
      expect(() => analytics.logAccountLinked(), returnsNormally);
    });
  });
}
