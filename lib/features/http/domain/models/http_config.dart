// lib/features/http/domain/models/http_config.dart
class HttpConfig {
  final String baseUrl;

  HttpConfig(this.baseUrl);

  // JSON to/from Dart helper functions
  factory HttpConfig.fromJson(Map<String, dynamic> json) {
    return HttpConfig(
      json['baseUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'baseUrl': baseUrl,
    };
  }
}