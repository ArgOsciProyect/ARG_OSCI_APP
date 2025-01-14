// lib/features/http/domain/services/http_service.dart
import 'dart:convert';
import '../repository/http_repository.dart';
import '../models/http_config.dart';

class HttpService implements HttpRepository {
  final HttpConfig config;

  HttpService(this.config);

  @override
  Future<dynamic> get(String endpoint) async {
    try {
      final response =
          await config.client!.get(Uri.parse('${config.baseUrl}$endpoint'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      throw Exception('Failed to load data: $e');
    }
  }

  @override
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await config.client!.post(
        Uri.parse('${config.baseUrl}$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to post data');
      }
    } catch (e) {
      throw Exception('Failed to post data: $e');
    }
  }
}
