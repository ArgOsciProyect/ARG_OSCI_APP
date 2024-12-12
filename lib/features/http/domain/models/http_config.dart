// lib/features/http/domain/models/http_config.dart
import 'package:http/http.dart' as http;

class HttpConfig {
  final String baseUrl;
  final http.Client? client;

  HttpConfig(this.baseUrl, {http.Client? client})
      : client = client ?? http.Client();

  // JSON to/from Dart helper functions
  factory HttpConfig.fromJson(Map<String, dynamic> json) {
    return HttpConfig(
      json['baseUrl'],
      client: json['client'] != null ? http.Client() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'baseUrl': baseUrl,
      'client': client != null ? true : null,
    };
  }
}