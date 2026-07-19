import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatt/core/config/api_config.dart';
import 'package:hatt/core/network/api_client.dart';
import 'package:hatt/core/network/auth_token_store.dart';
import 'package:hatt/core/network/telemetry_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TelemetryService', () {
    test('enqueues allowed events and drops unallowed events', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = AuthTokenStore(prefs);

      final apiClient = ApiClient(
        tokenStore: store,
        config: const ApiConfig(baseUrl: 'http://test.local'),
      );

      final telemetry = TelemetryService(apiClient: apiClient);

      telemetry.trackEvent('app_launch');
      telemetry.trackEvent('unauthorized_event_type'); // should be ignored

      // Only app_launch is allowed
      expect(TelemetryService.allowedEvents.contains('app_launch'), isTrue);
      expect(TelemetryService.allowedEvents.contains('unauthorized_event_type'), isFalse);
    });

    test('flush sends event batch to backend endpoint', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = AuthTokenStore(prefs);
      await store.saveAuth(
        userId: 'user-1',
        accessToken: 'valid-access-token',
        refreshToken: 'valid-refresh-token',
        refreshExpiresAt: DateTime.now().add(const Duration(days: 30)),
      );

      var posted = false;
      final mockHttpClient = MockClient((request) async {
        if (request.url.path == '/v1/telemetry/events') {
          posted = true;
          final body = jsonDecode(request.body);
          expect(body['events'], isList);
          return http.Response(jsonEncode({'processed': 1}), 200);
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(
        tokenStore: store,
        config: const ApiConfig(baseUrl: 'http://test.local'),
        httpClient: mockHttpClient,
      );

      final telemetry = TelemetryService(apiClient: apiClient);
      telemetry.trackEvent('lesson_started', {'node_id': 'n1'});

      final success = await telemetry.flush();

      expect(success, isTrue);
      expect(posted, isTrue);
    });
  });
}
