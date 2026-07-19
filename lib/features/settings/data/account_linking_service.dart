import '../../../core/network/api_client.dart';
import '../../../core/network/auth_token_store.dart';

class AccountLinkingResult {
  const AccountLinkingResult({
    required this.success,
    this.error,
  });

  final bool success;
  final String? error;
}

class AccountLinkingService {
  AccountLinkingService({
    required ApiClient apiClient,
    required AuthTokenStore tokenStore,
  })  : _apiClient = apiClient,
        _tokenStore = tokenStore;

  final ApiClient _apiClient;
  final AuthTokenStore _tokenStore;

  /// Links email & password to current anonymous user.
  Future<AccountLinkingResult> linkEmail({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/v1/account/link/email',
      body: {'email': email, 'password': password},
    );

    if (response.isSuccess && response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      await _tokenStore.updateProfile(
        accountType: data['accountType'] as String?,
        nickname: data['nickname'] as String?,
        tier: data['tier'] as String?,
        linkedProviders: (data['linkedProviders'] as List?)?.cast<String>(),
      );
      return const AccountLinkingResult(success: true);
    }

    return AccountLinkingResult(
      success: false,
      error: response.error ?? 'Hesap bağlama başarısız oldu.',
    );
  }

  /// Links OAuth provider (Apple / Google) to current anonymous user.
  Future<AccountLinkingResult> linkOAuth({
    required String provider,
    required String subject,
  }) async {
    final response = await _apiClient.post(
      '/v1/account/link/oauth',
      body: {'provider': provider, 'subject': subject},
    );

    if (response.isSuccess && response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      await _tokenStore.updateProfile(
        accountType: data['accountType'] as String?,
        nickname: data['nickname'] as String?,
        tier: data['tier'] as String?,
        linkedProviders: (data['linkedProviders'] as List?)?.cast<String>(),
      );
      return const AccountLinkingResult(success: true);
    }

    return AccountLinkingResult(
      success: false,
      error: response.error ?? 'Sosyal hesap bağlama başarısız oldu.',
    );
  }

  /// Logs into an existing email account from another device.
  Future<AccountLinkingResult> loginEmail({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/v1/auth/login/email',
      body: {
        'email': email,
        'password': password,
        'installationId': _tokenStore.installationId,
      },
    );

    if (response.isSuccess && response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      await _tokenStore.saveAuth(
        userId: data['userId'],
        accessToken: data['accessToken'],
        refreshToken: data['refreshToken'],
        refreshExpiresAt: DateTime.parse(data['refreshExpiresAt']),
      );
      return const AccountLinkingResult(success: true);
    }

    return AccountLinkingResult(
      success: false,
      error: response.error ?? 'E-posta veya şifre hatalı.',
    );
  }

  /// Deletes user account on backend (KVKK compliance).
  Future<bool> deleteAccount() async {
    final response = await _apiClient.delete('/v1/account');
    if (response.isSuccess) {
      await _tokenStore.clear();
      return true;
    }
    return false;
  }
}
