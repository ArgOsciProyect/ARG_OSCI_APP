// lib/features/http/domain/repository/http_repository.dart

abstract class HttpRepository {
  Future<dynamic> get(String endpoint);
  Future<dynamic> post(String endpoint, Map<String, dynamic> body);
}