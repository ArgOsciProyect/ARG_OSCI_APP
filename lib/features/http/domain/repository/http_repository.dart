/// Repository interface for making HTTP requests to the oscilloscope API
abstract class HttpRepository {
  /// Makes a GET request to the specified endpoint
  ///
  /// [endpoint] The path to append to the base URL
  /// Returns parsed JSON response on success
  /// Throws [HttpException] if request fails
  /// Throws [FormatException] if response is not valid JSON
  Future<dynamic> get(String endpoint);

  /// Makes a POST request to the specified endpoint with optional JSON body
  ///
  /// [endpoint] The path to append to the base URL
  /// [body] Optional request body that will be JSON encoded
  /// Returns parsed JSON response on success
  /// Throws [HttpException] if request fails
  /// Throws [FormatException] if response is not valid JSON
  Future<dynamic> post(String endpoint, [Map<String, dynamic>? body]);

  /// Makes a PUT request to the specified endpoint with JSON body
  ///
  /// [endpoint] The path to append to the base URL
  /// [body] Request body that will be JSON encoded
  /// Returns parsed JSON response on success
  /// Throws [HttpException] if request fails
  /// Throws [FormatException] if response is not valid JSON
  Future<dynamic> put(String endpoint, Map<String, dynamic> body);

  /// Makes a DELETE request to the specified endpoint
  ///
  /// [endpoint] The path to append to the base URL
  /// Returns parsed JSON response on success
  /// Throws [HttpException] if request fails
  /// Throws [FormatException] if response is not valid JSON
  Future<dynamic> delete(String endpoint);

  /// Base URL for all requests
  String get baseUrl;
}
