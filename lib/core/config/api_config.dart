import 'dart:io';

class ApiConfig {
  const ApiConfig({
    String? baseUrl,
  }) : _baseUrl = baseUrl;

  final String? _baseUrl;

  String get baseUrl => _baseUrl ?? defaultBaseUrl;

  static String get defaultBaseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000';
    }
    return 'http://localhost:5000';
  }

  static const ApiConfig defaults = ApiConfig();
}
