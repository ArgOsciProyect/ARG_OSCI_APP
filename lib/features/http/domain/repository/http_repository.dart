// lib/features/http/domain/repository/http_repository.dart

abstract class HttpRepository {
  /// Makes a GET request to the specified endpoint
  /// 
  /// [endpoint] is the path to append to the base URL
  /// Returns parsed JSON response on success
  /// Throws Exception if request fails or status code is not 200
  Future<dynamic> get(String endpoint);

  /// Makes a POST request to the specified endpoint with JSON body
  /// 
  /// [endpoint] is the path to append to the base URL
  /// [body] is the request body that will be JSON encoded
  /// Returns parsed JSON response on success
  /// Throws Exception if request fails or status code is not 200
  Future<dynamic> post(String endpoint, Map<String, dynamic> body);
}