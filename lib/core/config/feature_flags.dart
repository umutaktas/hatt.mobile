/// Compile-time / runtime feature flags (CLAUDE.md §2, §9, docs/ANALIZ-BACKEND-2026-07-16.md).
///
/// The backend (.NET 9 + PostgreSQL) and in-app purchases (RevenueCat) are gated so the
/// app boots and is fully usable offline. When [backendEnabled] is false the
/// League tab shows a "bağlantı yok" state and progress stays local-only.
class FeatureFlags {
  const FeatureFlags({
    this.backendEnabled = true,
    this.leagueEnabled = true,
    this.cloudBackupEnabled = true,
    this.purchasesEnabled = false,
    this.localNotificationsEnabled = true,
  });

  /// Gated .NET 9 API integration.
  final bool backendEnabled;
  final bool leagueEnabled;
  final bool cloudBackupEnabled;

  /// Compatibility getter for legacy references.
  bool get firebaseEnabled => backendEnabled;

  /// Enable once RevenueCat products are configured. Paywall is visible either
  /// way; only the purchase call is gated.
  final bool purchasesEnabled;

  final bool localNotificationsEnabled;

  static const FeatureFlags defaults = FeatureFlags();
}
