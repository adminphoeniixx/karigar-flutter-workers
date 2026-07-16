import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

class ApiException implements Exception {
  ApiException(this.message, {required this.statusCode, this.errors = const {}});
  final String message;
  final int statusCode;
  final Map<String, dynamic> errors;
  @override String toString() => message;
}

class ApiClient {
  ApiClient._();
  static final instance = ApiClient._();
  String? _token;
  static const _tokenKey = 'auth_token';
  Future<void> initialize() async => _token = (await SharedPreferences.getInstance()).getString(_tokenKey);
  bool get isAuthenticated => _token != null;
  Future<void> setToken(String? value) async {
    _token = value;
    final prefs = await SharedPreferences.getInstance();
    value == null ? await prefs.remove(_tokenKey) : await prefs.setString(_tokenKey, value);
  }
  Map<String, String> get _headers => {'Accept': 'application/json', 'Content-Type': 'application/json', if (_token != null) 'Authorization': 'Bearer $_token'};
  Uri _uri(String path, [Map<String, dynamic>? query]) => Uri.parse('${ApiConstants.baseUrl}$path').replace(queryParameters: query?.map((k, v) => MapEntry(k, v.toString())));
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) {
    final uri = _uri(path, query);
    return _send('GET', uri, () => http.get(uri, headers: _headers));
  }

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) {
    final uri = _uri(path);
    return _send(
      'POST',
      uri,
      () => http.post(uri, headers: _headers, body: jsonEncode(body ?? {})),
      body: body,
    );
  }

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) {
    final uri = _uri(path);
    return _send(
      'PATCH',
      uri,
      () => http.patch(uri, headers: _headers, body: jsonEncode(body)),
      body: body,
    );
  }

  Future<Map<String, dynamic>> delete(String path, [Map<String, dynamic>? body]) {
    final uri = _uri(path);
    return _send(
      'DELETE',
      uri,
      () => http.delete(uri, headers: _headers, body: jsonEncode(body ?? {})),
      body: body,
    );
  }
  Future<Map<String, dynamic>> multipart(String path, Map<String, String> fields, Map<String, File> files) async {
    final uri = _uri(path);
    _logRequest('POST MULTIPART', uri, fields);
    final request = http.MultipartRequest('POST', uri)..headers.addAll({'Accept': 'application/json', if (_token != null) 'Authorization': 'Bearer $_token'})..fields.addAll(fields);
    for (final entry in files.entries) { request.files.add(await http.MultipartFile.fromPath(entry.key, entry.value.path)); }
    final response = await http.Response.fromStream(await request.send());
    _logResponse('POST MULTIPART', uri, response);
    return _decode(response);
  }
  Future<Map<String, dynamic>> _send(String method, Uri uri, Future<http.Response> Function() request, {Map<String, dynamic>? body}) async {
    _logRequest(method, uri, body);
    try {
      final response = await request();
      _logResponse(method, uri, response);
      return _decode(response);
    } on SocketException {
      debugPrint('[API] $method $uri -> NO INTERNET');
      throw ApiException('Please check your internet connection.', statusCode: 0);
    } on http.ClientException catch (error) {
      debugPrint('[API] $method $uri -> CLIENT ERROR: $error');
      throw ApiException('Unable to connect to the server.', statusCode: 0);
    }
  }

  void _logRequest(String method, Uri uri, Object? body) {
    if (!kDebugMode) return;
    debugPrint('[API REQUEST] $method $uri');
    if (body != null) debugPrint('[API REQUEST BODY] ${jsonEncode(_redact(body))}');
  }

  void _logResponse(String method, Uri uri, http.Response response) {
    if (!kDebugMode) return;
    Object? printable = response.body;
    try {
      printable = _redact(jsonDecode(response.body));
    } catch (_) {}
    debugPrint('[API RESPONSE] $method $uri -> ${response.statusCode}');
    debugPrint('[API RESPONSE BODY] ${printable is String ? printable : jsonEncode(printable)}');
  }

  Object? _redact(Object? value) {
    if (value is List) return value.map(_redact).toList();
    if (value is Map) {
      return value.map((key, item) {
        final name = key.toString().toLowerCase();
        final hidden = name == 'token' || name == 'otp' || name.contains('aadhaar') || name.contains('pan_number');
        return MapEntry(key.toString(), hidden ? '***' : _redact(item));
      });
    }
    return value;
  }
  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body = {};
    if (response.body.isNotEmpty) { try { body = Map<String, dynamic>.from(jsonDecode(response.body) as Map); } catch (_) { if (response.statusCode >= 400) throw ApiException('Server returned an invalid response.', statusCode: response.statusCode); } }
    if (response.statusCode < 200 || response.statusCode >= 300) throw ApiException(body['message']?.toString() ?? 'Request failed.', statusCode: response.statusCode, errors: Map<String, dynamic>.from(body['errors'] as Map? ?? {}));
    return body;
  }
}
