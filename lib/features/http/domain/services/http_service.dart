// lib/features/http/domain/services/http_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../repository/http_repository.dart';
import '../models/http_config.dart';

class HttpService implements HttpRepository {
  final HttpConfig config;

  HttpService(this.config);

  @override
  Future<dynamic> get(String endpoint) async {
    try {
      final response = await http.get(Uri.parse('${config.baseUrl}$endpoint'));
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
    print(body);
    try {
      final response = await http.post(
        Uri.parse('${config.baseUrl}$endpoint'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
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