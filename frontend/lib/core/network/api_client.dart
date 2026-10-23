import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../security/auth_token_store.dart';
import 'api_exceptions.dart';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, String>> _headers(Map<String, String>? extra, {bool json = false}) async {
    final result = <String, String>{'Accept': 'application/json', ...?extra};
    if (json) result['Content-Type'] = 'application/json';
    final token = await AuthTokenStore.instance.read();
    if (token != null && token.isNotEmpty) result['Authorization'] = 'Bearer $token';
    return result;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _client
          .get(
            _uri(path, query),
            headers: await _headers(headers),
          )
          .timeout(AppConfig.requestTimeout);
      return _decode(response);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Não foi possível conectar ao LEGIS. Verifique a conexão e tente novamente.',
      );
    }
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _client
          .post(
            _uri(path),
            headers: await _headers(headers, json: true),
            body: jsonEncode(body ?? <String, dynamic>{}),
          )
          .timeout(AppConfig.requestTimeout);
      return _decode(response);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Não foi possível conectar ao LEGIS. Verifique a conexão e tente novamente.',
      );
    }
  }

  Future<dynamic> patch(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _client
          .patch(
            _uri(path),
            headers: await _headers(headers, json: true),
            body: jsonEncode(body ?? <String, dynamic>{}),
          )
          .timeout(AppConfig.requestTimeout);
      return _decode(response);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Não foi possível conectar ao LEGIS. Verifique a conexão e tente novamente.',
      );
    }
  }

  Future<dynamic> delete(
    String path, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _client
          .delete(
            _uri(path),
            headers: await _headers(headers),
          )
          .timeout(AppConfig.requestTimeout);
      return _decode(response);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Não foi possível conectar ao LEGIS. Verifique a conexão e tente novamente.',
      );
    }
  }

  dynamic _decode(http.Response response) {
    final body = response.body.trim();
    dynamic data;
    if (body.isNotEmpty) {
      try {
        data = jsonDecode(body);
      } catch (_) {
        data = body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return data;

    String message = 'Não foi possível concluir a solicitação.';
    if (data is Map) {
      final detail = data['detail'] ?? data['message'] ?? data['mensagem'];
      if (detail is String && detail.trim().isNotEmpty) message = detail;
    }
    if (response.statusCode == 404) {
      message = 'Não foi possível encontrar as informações solicitadas.';
    } else if (response.statusCode == 422) {
      message = 'Alguns filtros são inválidos. Revise os dados e tente novamente.';
    } else if (response.statusCode >= 500) {
      message = 'O serviço está temporariamente indisponível. Tente novamente.';
    }
    throw ApiException(message, statusCode: response.statusCode);
  }
}
