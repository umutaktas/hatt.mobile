import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_token_store.dart';

class ApiResponse {
  ApiResponse({
    required this.statusCode,
    required this.data,
    this.error,
  });

  final int statusCode;
  final dynamic data;
  final String? error;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

class ApiClient {
  ApiClient({
    required this.tokenStore,
    this.config = ApiConfig.defaults,
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  final AuthTokenStore tokenStore;
  final ApiConfig config;
  final http.Client _client;

  Uri _uri(String path) => Uri.parse('${config.baseUrl}$path');

  Map<String, String> _headers({String? idempotencyKey}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (tokenStore.accessToken != null) {
      headers['Authorization'] = 'Bearer ${tokenStore.accessToken}';
    }
    if (idempotencyKey != null) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    return headers;
  }

  /// Ensures an active session exists (calls anonymous auth if needed).
  Future<bool> ensureAuthenticated() async {
    if (tokenStore.isAuthenticated) {
      return true;
    }
    return await loginAnonymous();
  }

  Future<bool> loginAnonymous() async {
    try {
      final response = await _client.post(
        _uri('/v1/auth/anonymous'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'installationId': tokenStore.installationId,
          'platform': Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'other'),
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        await tokenStore.saveAuth(
          userId: body['userId'],
          accessToken: body['accessToken'],
          refreshToken: body['refreshToken'],
          refreshExpiresAt: DateTime.parse(body['refreshExpiresAt']),
        );
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> refreshToken() async {
    final currentRefresh = tokenStore.refreshToken;
    if (currentRefresh == null) return false;

    try {
      final response = await _client.post(
        _uri('/v1/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': currentRefresh}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        await tokenStore.saveAuth(
          userId: body['userId'],
          accessToken: body['accessToken'],
          refreshToken: body['refreshToken'],
          refreshExpiresAt: DateTime.parse(body['refreshExpiresAt']),
        );
        return true;
      }
    } catch (_) {}

    await tokenStore.clear();
    return false;
  }

  Future<ApiResponse> get(String path) async {
    return _sendWithRetry((headers) => _client.get(_uri(path), headers: headers));
  }

  Future<ApiResponse> post(String path, {Object? body, String? idempotencyKey}) async {
    return _sendWithRetry(
      (headers) => _client.post(
        _uri(path),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ),
      idempotencyKey: idempotencyKey,
    );
  }

  Future<ApiResponse> put(String path, {Object? body}) async {
    return _sendWithRetry(
      (headers) => _client.put(
        _uri(path),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  Future<ApiResponse> patch(String path, {Object? body}) async {
    return _sendWithRetry(
      (headers) => _client.patch(
        _uri(path),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  Future<ApiResponse> delete(String path) async {
    return _sendWithRetry((headers) => _client.delete(_uri(path), headers: headers));
  }

  Future<ApiResponse> _sendWithRetry(
    Future<http.Response> Function(Map<String, String> headers) requestFn, {
    String? idempotencyKey,
  }) async {
    await ensureAuthenticated();
    var headers = _headers(idempotencyKey: idempotencyKey);
    
    try {
      var response = await requestFn(headers);

      if (response.statusCode == 401 && tokenStore.refreshToken != null) {
        final refreshed = await refreshToken();
        if (refreshed) {
          headers = _headers(idempotencyKey: idempotencyKey);
          response = await requestFn(headers);
        }
      }

      dynamic data;
      String? error;
      if (response.body.isNotEmpty) {
        try {
          data = jsonDecode(response.body);
          if (data is Map && data.containsKey('error')) {
            error = data['error'].toString();
          }
        } catch (_) {
          data = response.body;
        }
      }

      return ApiResponse(
        statusCode: response.statusCode,
        data: data,
        error: error,
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 0,
        data: null,
        error: e.toString(),
      );
    }
  }
}
