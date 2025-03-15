/// Repository interface for making HTTP requests to the oscilloscope API
///
/// Defines standardized methods for HTTP operations (GET, POST, PUT, DELETE)
/// with navigation control for error handling.
abstract class HttpRepository {
  /// Performs a GET request.
  /// [endpoint] - API endpoint to call
  /// [skipNavigation] - if true, won't navigate to setup screen on error
  Future<dynamic> get(String endpoint, {bool skipNavigation});

  /// Performs a POST request.
  /// [endpoint] - API endpoint to call
  /// [body] - Optional request body
  /// [skipNavigation] - if true, won't navigate to setup screen on error
  Future<dynamic> post(String endpoint,
      [Map<String, dynamic>? body, bool skipNavigation]);

  /// Performs a PUT request.
  /// [endpoint] - API endpoint to call
  /// [body] - Request body
  /// [skipNavigation] - if true, won't navigate to setup screen on error
  Future<dynamic> put(String endpoint, Map<String, dynamic> body,
      {bool skipNavigation});

  /// Performs a DELETE request.
  /// [endpoint] - API endpoint to call
  /// [skipNavigation] - if true, won't navigate to setup screen on error
  Future<dynamic> delete(String endpoint, {bool skipNavigation});

  /// Base URL for all requests
  String get baseUrl;
}
