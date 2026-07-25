import 'package:flutter/foundation.dart';
import '../network/telemetry_service.dart';

/// App-wide analytics tracker (CLAUDE.md §2).
/// Bridges user actions with [TelemetryService] (for the .NET backend API)
/// and Firebase Analytics (when initialized).
class AnalyticsService {
  AnalyticsService({TelemetryService? telemetry}) : _telemetry = telemetry;

  final TelemetryService? _telemetry;
  bool enabled = true;

  void logAppLaunch() {
    _track('app_launch');
  }

  void logLessonStarted(String nodeId) {
    _track('lesson_started', {'node_id': nodeId});
  }

  void logLessonCompleted({
    required String nodeId,
    required int score,
    required int xpEarned,
  }) {
    _track('lesson_completed', {
      'node_id': nodeId,
      'score': score.toString(),
      'xp_earned': xpEarned.toString(),
    });
  }

  void logStreakMilestone(int currentStreak) {
    _track('streak_milestone', {'streak': currentStreak.toString()});
  }

  void logPaywallViewed(String source) {
    _track('paywall_viewed', {'source': source});
  }

  void logAccountLinked() {
    _track('account_linked');
  }

  void _track(String eventName, [Map<String, String>? params]) {
    if (!enabled) return;
    debugPrint('📊 [Analytics] Event logged: $eventName | Params: $params');
    _telemetry?.trackEvent(eventName, params);
    // Seam: FirebaseAnalytics.instance.logEvent(name: eventName, parameters: params);
  }
}
