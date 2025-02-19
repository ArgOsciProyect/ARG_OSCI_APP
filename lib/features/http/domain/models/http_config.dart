import 'package:http/http.dart' as http;

/// Configuration model for HTTP client settings
///
/// Provides base URL and client instance for making HTTP requests
/// to the oscilloscope API endpoints
class HttpConfig {
  /// Base URL for all API requests
  ///
  /// Example: "http://192.168.1.100:8080"
  /// Should include protocol and port if needed
  final String baseUrl;

  /// HTTP client instance for making requests
  ///
  /// If not provided, a default client will be created
  /// Can be injected for testing or custom configuration
  final http.Client? client;

  /// Creates a new HTTP configuration
  ///
  /// [baseUrl] The base URL for all API requests
  /// [client] Optional HTTP client instance
  /// If client is null, creates a new default client
  HttpConfig(this.baseUrl, {http.Client? client})
      : client = client ?? http.Client();

  /// Creates HttpConfig from JSON map
  ///
  /// [json] Map containing configuration values
  /// Must include 'baseUrl' key
  /// Optional 'client' key to indicate if client should be created
  ///
  /// Example:
  /// ```dart
  /// HttpConfig.fromJson({
  ///   'baseUrl': 'http://192.168.1.100:8080',
  ///   'client': true
  /// });
  /// ```
  factory HttpConfig.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('baseUrl')) {
      throw FormatException('Missing required baseUrl in JSON');
    }
    return HttpConfig(
      json['baseUrl'] as String,
      client: json['client'] != null ? http.Client() : null,
    );
  }

  /// Converts HttpConfig to JSON map
  ///
  /// Returns map with 'baseUrl' and optional 'client' flag
  /// Used for serialization and persistence
  Map<String, dynamic> toJson() {
    return {
      'baseUrl': baseUrl,
      'client': client != null ? true : null,
    };
  }

  /// Creates a copy of this config with optional new values
  ///
  /// [baseUrl] Optional new base URL
  /// [client] Optional new client instance
  HttpConfig copyWith({
    String? baseUrl,
    http.Client? client,
  }) {
    return HttpConfig(
      baseUrl ?? this.baseUrl,
      client: client ?? this.client,
    );
  }

  @override
  String toString() => 'HttpConfig(baseUrl: $baseUrl)';
}
