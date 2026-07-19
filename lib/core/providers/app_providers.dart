import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/league/data/api_league_service.dart';
import '../../features/league/data/league_service.dart';
import '../../features/paywall/domain/entitlement_service.dart';
import '../../features/profile/data/user_repository.dart';
import '../../features/settings/data/account_linking_service.dart';
import '../audio/sound_service.dart';
import '../config/api_config.dart';
import '../config/feature_flags.dart';
import '../db/database.dart';
import '../network/api_client.dart';
import '../network/auth_token_store.dart';
import '../network/progress_sync_service.dart';
import '../network/telemetry_service.dart';
import '../notifications/streak_reminder_service.dart';

/// The Drift database. Overridden in tests with [AppDatabase.forTesting].
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize sharedPreferencesProvider in ProviderScope overrides');
});

final authTokenStoreProvider = Provider<AuthTokenStore>((ref) {
  return AuthTokenStore(ref.watch(sharedPreferencesProvider));
});

final apiConfigProvider = Provider<ApiConfig>((ref) => ApiConfig.defaults);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokenStore: ref.watch(authTokenStoreProvider),
    config: ref.watch(apiConfigProvider),
  );
});

final progressSyncServiceProvider = Provider<ProgressSyncService>((ref) {
  return ProgressSyncService(
    apiClient: ref.watch(apiClientProvider),
    db: ref.watch(databaseProvider),
  );
});

final accountLinkingServiceProvider = Provider<AccountLinkingService>((ref) {
  return AccountLinkingService(
    apiClient: ref.watch(apiClientProvider),
    tokenStore: ref.watch(authTokenStoreProvider),
  );
});

final telemetryServiceProvider = Provider<TelemetryService>((ref) {
  return TelemetryService(
    apiClient: ref.watch(apiClientProvider),
  );
});

final featureFlagsProvider = Provider<FeatureFlags>(
  (ref) => FeatureFlags.defaults,
);

final leagueServiceProvider = Provider<LeagueService>((ref) {
  final flags = ref.watch(featureFlagsProvider);
  return flags.leagueEnabled && flags.backendEnabled
      ? ApiLeagueService(ref.watch(apiClientProvider))
      : const OfflineLeagueService();
});

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.watch(databaseProvider)),
);

final streakReminderProvider = Provider<StreakReminderService>(
  (ref) => StreakReminderService(),
);

final soundServiceProvider = Provider<SoundService>((ref) {
  final service = SoundService();
  ref.onDispose(service.dispose);
  return service;
});

/// Streams the singleton user_state row.
final userStateProvider = StreamProvider<UserStateRow>((ref) {
  return ref.watch(databaseProvider).watchUserState();
});

/// Entitlement derived from the persisted premium flag. Wraps
/// [LocalEntitlementService]; persists changes back to the DB.
final entitlementProvider = Provider<EntitlementService>((ref) {
  final db = ref.watch(databaseProvider);
  final flags = ref.watch(featureFlagsProvider);
  final premium =
      ref.watch(userStateProvider).value?.premium ?? false;
  final service = LocalEntitlementService(
    premium: premium,
    flags: flags,
    onChanged: (value) =>
        db.updateUserState(UserStateTableCompanion(premium: Value(value))),
  );
  // Keep the sound service in sync with the user's toggle.
  final soundEnabled = ref.watch(userStateProvider).value?.soundEnabled ?? true;
  ref.watch(soundServiceProvider).enabled = soundEnabled;
  return service;
});
