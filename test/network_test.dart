import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatt/core/config/api_config.dart';
import 'package:hatt/core/config/feature_flags.dart';
import 'package:hatt/core/network/api_client.dart';
import 'package:hatt/core/network/auth_token_store.dart';
import 'package:hatt/features/league/data/api_league_service.dart';
import 'package:hatt/features/league/domain/league_logic.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthTokenStore', () {
    test('generates installationId on first read and reuses it', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = AuthTokenStore(prefs);

      final id1 = store.installationId;
      final id2 = store.installationId;

      expect(id1, isNotEmpty);
      expect(id1, equals(id2));
    });

    test('saves and clears authentication tokens', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = AuthTokenStore(prefs);

      expect(store.isAuthenticated, isFalse);

      await store.saveAuth(
        userId: 'user-123',
        accessToken: 'access-jwt',
        refreshToken: 'refresh-jwt',
        refreshExpiresAt: DateTime.now().add(const Duration(days: 30)),
      );

      expect(store.isAuthenticated, isTrue);
      expect(store.userId, equals('user-123'));
      expect(store.accessToken, equals('access-jwt'));

      await store.clear();
      expect(store.isAuthenticated, isFalse);
    });
  });

  group('ApiClient & ApiLeagueService', () {
    test('ApiLeagueService parses currentSnapshot correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = AuthTokenStore(prefs);
      await store.saveAuth(
        userId: 'u1',
        accessToken: 'valid-token',
        refreshToken: 'valid-refresh',
        refreshExpiresAt: DateTime.now().add(const Duration(days: 1)),
      );

      final mockHttpClient = MockClient((request) async {
        if (request.url.path == '/v1/leagues/current') {
          return http.Response(
            jsonEncode({
              'weekId': '2026-W29',
              'tier': 'Gold',
              'weekEnd': '2026-07-20T00:00:00Z',
              'promoteCount': 3,
              'relegateCount': 3,
              'standings': [
                {'rank': 1, 'nickname': 'Ahmet', 'weeklyXp': 150, 'isMe': false},
                {'rank': 2, 'nickname': 'Mehmet', 'weeklyXp': 120, 'isMe': true},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(
        tokenStore: store,
        config: const ApiConfig(baseUrl: 'http://test.local'),
        httpClient: mockHttpClient,
      );

      final leagueService = ApiLeagueService(apiClient);
      final snapshot = await leagueService.currentSnapshot();

      expect(snapshot, isNotNull);
      expect(snapshot!.weekId, equals('2026-W29'));
      expect(snapshot.tier, equals(LeagueTier.gold));
      expect(snapshot.standings.length, equals(2));
      expect(snapshot.standings[1].isMe, isTrue);
    });
  });

  group('FeatureFlags', () {
    test('backendEnabled activates API league service', () {
      const flags = FeatureFlags(backendEnabled: true);
      expect(flags.firebaseEnabled, isTrue);
      expect(flags.leagueEnabled, isTrue);
    });
  });
}
