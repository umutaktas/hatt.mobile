import 'dart:io';

class ApiConfig {
  const ApiConfig({
    String? baseUrl,
  }) : _baseUrl = baseUrl;

  final String? _baseUrl;

  String get baseUrl => _baseUrl ?? defaultBaseUrl;

  static String get defaultBaseUrl {
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:5273';
    }
    return 'http://localhost:5273';
  }

  static const ApiConfig defaults = ApiConfig();
}
