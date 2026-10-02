import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code, this.data});

  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, dynamic>? data;

  bool get isNetwork => statusCode == null;
  bool get isUnauthorized => statusCode == 401;
  bool get isConflict => statusCode == 409;
  bool get needsPasswordChange => code == 'password_change_required';

  @override
  String toString() => message;
}

class ApiService {
  ApiService({
    http.Client? client,
    required Future<String?> Function() tokenProvider,
    required Future<void> Function() onUnauthorized,
    Future<String?> Function()? deviceIdProvider,
  })  : _client = client ?? http.Client(),
        _tokenProvider = tokenProvider,
        _onUnauthorized = onUnauthorized,
        _deviceIdProvider = deviceIdProvider;

  final http.Client _client;
  final Future<String?> Function() _tokenProvider;
  final Future<void> Function() _onUnauthorized;
  final Future<String?> Function()? _deviceIdProvider;

  bool _disposed = false;

  bool _handlingUnauthorized = false;

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<Map<String, dynamic>> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<Map<String, dynamic>> delete(String path, {Object? body}) =>
      _send('DELETE', path, body: body);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    if (_disposed) {
      throw ApiException('La sesión se cerró.');
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}$path')
        .replace(queryParameters: query?.isEmpty ?? true ? null : query);

    if (kReleaseMode && uri.scheme != 'https') {
      throw ApiException('Configuración insegura.');
    }

    final token = await _tokenProvider();
    final deviceId = await _deviceIdProvider?.call();

    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json; charset=utf-8',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (deviceId != null) 'X-Device-Id': deviceId,
    };

    http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);

      final streamed = await _client.send(request).timeout(ApiConfig.timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado. Revisa tu conexión.');
    } on http.ClientException {
      throw ApiException('Sin conexión. Revisa tu señal e intenta de nuevo.');
    } on Exception {
      throw ApiException('Sin conexión. Revisa tu señal e intenta de nuevo.');
    }

    return _parse(response, uri);
  }

  Future<Map<String, dynamic>> _parse(http.Response response, Uri uri) async {
    Map<String, dynamic> json = const {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) json = decoded;
      } on FormatException {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          throw ApiException('Respuesta inesperada del servidor.');
        }
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return json;

    final code = json['error'] as String?;
    final message = (json['message'] as String?) ?? _defaultMessage(response.statusCode);

    if (response.statusCode == 401) {
      if (!_handlingUnauthorized) {
        _handlingUnauthorized = true;
        try {
          await _onUnauthorized();
        } finally {
          _handlingUnauthorized = false;
        }
      }
    }

    if (kDebugMode) {
      debugPrint('[api] ${response.statusCode} ${uri.path} ($code)');
    }

    throw ApiException(
      message,
      statusCode: response.statusCode,
      code: code,
      data: json,
    );
  }

  String _defaultMessage(int status) {
    if (status == 429) return 'Demasiados intentos. Espera un momento.';
    if (status >= 500) return 'El servidor no está disponible. Intenta de nuevo.';
    return 'No pudimos completar la acción.';
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _client.close();
  }
}
