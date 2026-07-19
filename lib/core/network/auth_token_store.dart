import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class AuthTokenStore {
  AuthTokenStore(this._prefs);

  final SharedPreferences _prefs;

  static const _keyInstallationId = 'hatt_auth_installation_id';
  static const _keyAccessToken = 'hatt_auth_access_token';
  static const _keyRefreshToken = 'hatt_auth_refresh_token';
  static const _keyRefreshExpiresAt = 'hatt_auth_refresh_expires_at';
  static const _keyUserId = 'hatt_auth_user_id';
  static const _keyAccountType = 'hatt_auth_account_type';
  static const _keyNickname = 'hatt_auth_nickname';
  static const _keyTier = 'hatt_auth_tier';
  static const _keyLinkedProviders = 'hatt_auth_linked_providers';

  String get installationId {
    var id = _prefs.getString(_keyInstallationId);
    if (id == null || id.isEmpty) {
      id = _generateRandomId();
      _prefs.setString(_keyInstallationId, id);
    }
    return id;
  }

  String? get accessToken => _prefs.getString(_keyAccessToken);
  String? get refreshToken => _prefs.getString(_keyRefreshToken);
  String? get userId => _prefs.getString(_keyUserId);
  String? get accountType => _prefs.getString(_keyAccountType);
  String? get nickname => _prefs.getString(_keyNickname);
  String? get tier => _prefs.getString(_keyTier);
  List<String> get linkedProviders => _prefs.getStringList(_keyLinkedProviders) ?? [];

  DateTime? get refreshExpiresAt {
    final str = _prefs.getString(_keyRefreshExpiresAt);
    return str != null ? DateTime.tryParse(str) : null;
  }

  bool get isAuthenticated =>
      accessToken != null && accessToken!.isNotEmpty;

  Future<void> saveAuth({
    required String userId,
    required String accessToken,
    required String refreshToken,
    required DateTime refreshExpiresAt,
  }) async {
    await _prefs.setString(_keyUserId, userId);
    await _prefs.setString(_keyAccessToken, accessToken);
    await _prefs.setString(_keyRefreshToken, refreshToken);
    await _prefs.setString(_keyRefreshExpiresAt, refreshExpiresAt.toIso8601String());
  }

  Future<void> updateProfile({
    String? accountType,
    String? nickname,
    String? tier,
    List<String>? linkedProviders,
  }) async {
    if (accountType != null) await _prefs.setString(_keyAccountType, accountType);
    if (nickname != null) await _prefs.setString(_keyNickname, nickname);
    if (tier != null) await _prefs.setString(_keyTier, tier);
    if (linkedProviders != null) await _prefs.setStringList(_keyLinkedProviders, linkedProviders);
  }

  Future<void> clear() async {
    await _prefs.remove(_keyAccessToken);
    await _prefs.remove(_keyRefreshToken);
    await _prefs.remove(_keyRefreshExpiresAt);
    await _prefs.remove(_keyUserId);
    await _prefs.remove(_keyAccountType);
    await _prefs.remove(_keyNickname);
    await _prefs.remove(_keyTier);
    await _prefs.remove(_keyLinkedProviders);
  }

  static String _generateRandomId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
