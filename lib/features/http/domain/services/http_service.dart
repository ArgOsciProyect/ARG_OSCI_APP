import 'dart:convert';
import 'dart:io';

import 'package:arg_osci_app/features/http/domain/models/http_config.dart';
import 'package:arg_osci_app/features/http/domain/repository/http_repository.dart';

/// [HttpService] implements the [HttpRepository] to provide HTTP request functionality.
class HttpService implements HttpRepository {
  final HttpConfig config;

  HttpService(this.config);

  @override
  String get baseUrl => config.baseUrl;

  @override
  Future<dynamic> get(String endpoint) async {
    try {
      // Perform a GET request to the specified endpoint
      final response = await config.client!.get(Uri.parse('$baseUrl$endpoint'));
      return _handleResponse(response);
    } catch (e) {
      throw HttpException('GET request failed: $e');
    }
  }

  @override
  Future<dynamic> post(String endpoint, [Map<String, dynamic>? body]) async {
    try {
      // Perform a POST request to the specified endpoint with an optional JSON body
      final response = await config.client!.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      throw HttpException('POST request failed: $e');
    }
  }

  @override
  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    try {
      // Perform a PUT request to the specified endpoint with a JSON body
      final response = await config.client!.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      throw HttpException('PUT request failed: $e');
    }
  }

  @override
  Future<dynamic> delete(String endpoint) async {
    try {
      // Perform a DELETE request to the specified endpoint
      final response =
          await config.client!.delete(Uri.parse('$baseUrl$endpoint'));
      return _handleResponse(response);
    } catch (e) {
      throw HttpException('DELETE request failed: $e');
    }
  }

  /// Handles the HTTP response and parses the JSON body.
  dynamic _handleResponse(dynamic response) {
    if (response.statusCode == 200) {
      try {
        // Attempt to decode the JSON response
        return jsonDecode(response.body);
      } catch (e) {
        throw FormatException('Invalid JSON response: $e');
      }
    } else {
      throw HttpException('Request failed with status: ${response.statusCode}');
    }
  }
}
