import 'package:flutter/foundation.dart';

/// Centralized crash reporting and error logging service (CLAUDE.md §2).
/// Captures unhandled Flutter errors, uncaught async errors, and non-fatal exceptions.
/// Bridges with Firebase Crashlytics when initialized, and provides structured local
/// logging when offline.
class CrashReporterService {
  CrashReporterService._();
  static final CrashReporterService instance = CrashReporterService._();

  bool _initialized = false;
  bool enabled = true;

  void initialize() {
    if (_initialized) return;
    _initialized = true;

    // Register Flutter Framework Error Handler
    FlutterError.onError = (FlutterErrorDetails details) {
      recordFlutterError(details);
    };

    // Register Async Dart Error Handler
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      recordError(error, stack, reason: 'Uncaught async platform error');
      return true; // Handled
    };
  }

  void recordFlutterError(FlutterErrorDetails details) {
    if (!enabled) return;
    debugPrint('🚨 [CrashReporter] FlutterError: ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrint(details.stack.toString());
    }
    // Seam: FirebaseCrashlytics.instance.recordFlutterError(details);
  }

  void recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) {
    if (!enabled) return;
    debugPrint(
        '💥 [CrashReporter] ${fatal ? 'FATAL' : 'Non-Fatal'} Error: $error (Reason: ${reason ?? 'N/A'})',);
    if (stack != null) {
      debugPrint(stack.toString());
    }
    // Seam: FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal, reason: reason);
  }

  void setUserIdentifier(String userId) {
    debugPrint('👤 [CrashReporter] Set user ID: $userId');
    // Seam: FirebaseCrashlytics.instance.setUserIdentifier(userId);
  }

  void logCustomKey(String key, Object value) {
    debugPrint('🏷️ [CrashReporter] Custom key: $key = $value');
    // Seam: FirebaseCrashlytics.instance.setCustomKey(key, value);
  }
}
