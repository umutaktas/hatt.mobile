import 'api_client.dart';

class TelemetryEventItem {
  const TelemetryEventItem({
    required this.eventName,
    this.properties,
    required this.timestamp,
  });

  final String eventName;
  final Map<String, String>? properties;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'properties': properties,
        'timestamp': timestamp.toUtc().toIso8601String(),
      };
}

class TelemetryService {
  TelemetryService({
    required ApiClient apiClient,
    this.enabled = true,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;
  bool enabled;

  final List<TelemetryEventItem> _queue = [];

  static const allowedEvents = {
    'app_launch',
    'lesson_started',
    'lesson_completed',
    'review_session_completed',
    'streak_milestone',
    'paywall_viewed',
    'account_linked',
  };

  void trackEvent(String eventName, [Map<String, String>? properties]) {
    if (!enabled) return;
    if (!allowedEvents.contains(eventName.trim().toLowerCase())) return;

    _queue.add(TelemetryEventItem(
      eventName: eventName.trim().toLowerCase(),
      properties: properties,
      timestamp: DateTime.now(),
    ),);

    if (_queue.length >= 10) {
      flush();
    }
  }

  Future<bool> flush() async {
    if (!enabled || _queue.isEmpty) return false;

    final batch = List<TelemetryEventItem>.from(_queue);
    _queue.clear();

    try {
      final response = await _apiClient.post(
        '/v1/telemetry/events',
        body: {
          'events': batch.map((e) => e.toJson()).toList(),
        },
      );
      return response.isSuccess;
    } catch (_) {
      // Re-queue on network failure
      _queue.insertAll(0, batch);
      return false;
    }
  }
}
