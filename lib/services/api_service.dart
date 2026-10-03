import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/constants/api_endpoints.dart';

/// Response wrapper standar untuk komunikasi API Backend Laravel
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final int statusCode;

  const ApiResponse({
    required this.success,
    required this.message,
    this.data,
    required this.statusCode,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json)? fromJsonT,
  ) {
    dynamic rawData = json['data'] ?? json['member'] ?? json['result'];

    // Tangani respons paginasi Laravel { "data": { "data": [...] } }
    if (rawData is Map && rawData.containsKey('data')) {
      final innerData = rawData['data'];
      if (fromJsonT != null && innerData != null) {
        try {
          return ApiResponse<T>(
            success: json['success'] as bool? ?? (json['status'] == 'success' || (json['status_code'] != null && (json['status_code'] as int) < 400)),
            message: json['message'] as String? ?? '',
            data: fromJsonT(innerData),
            statusCode: json['status_code'] as int? ?? (json['code'] as int? ?? 200),
          );
        } catch (_) {}
      } else if (innerData is T) {
        rawData = innerData;
      }
    }

    T? parsedData;
    if (rawData != null && fromJsonT != null) {
      try {
        parsedData = fromJsonT(rawData);
      } catch (e) {
        debugPrint('[API_PARSE_ERROR] Failed parsing $T: $e');
      }
    } else if (rawData is T) {
      parsedData = rawData;
    }

    final bool isSuccess = json['success'] as bool? ?? (json['status'] == 'success' || (json['status_code'] != null && (json['status_code'] as int) < 400));

    return ApiResponse<T>(
      success: isSuccess,
      message: json['message'] as String? ?? '',
      data: parsedData,
      statusCode: json['status_code'] as int? ?? (json['code'] as int? ?? 200),
    );
  }
}

/// Service Layer terpusat (Base Client) untuk REST API Laravel Backend
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String get baseUrl => ApiEndpoints.baseUrl;

  String? _authToken;

  void setAuthToken(String token) {
    _authToken = token;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  /// HTTP GET Request
  Future<ApiResponse<T>> get<T>({
    required String endpoint,
    T Function(dynamic json)? fromJson,
    bool isMock = false,
    dynamic mockData,
  }) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 30);
      final request = await client.getUrl(Uri.parse('$baseUrl$endpoint'));
      _headers.forEach((key, value) => request.headers.set(key, value));

      final response =
          await request.close().timeout(const Duration(seconds: 30));
      final responseBody = await response.transform(utf8.decoder).join();
      final jsonMap = jsonDecode(responseBody) as Map<String, dynamic>;

      return ApiResponse<T>.fromJson(jsonMap, fromJson);
    } on SocketException {
      return ApiResponse<T>(
        success: false,
        message: 'Koneksi ke server gagal. Periksa jaringan internet Anda.',
        statusCode: 503,
      );
    } on TimeoutException {
      return ApiResponse<T>(
        success: false,
        message: 'Waktu koneksi ke server habis (Timeout).',
        statusCode: 408,
      );
    } catch (e) {
      debugPrint('API GET Error: $e');
      return ApiResponse<T>(
        success: false,
        message: 'Terjadi kesalahan sistem: $e',
        statusCode: 500,
      );
    }
  }

  /// HTTP POST Request
  Future<ApiResponse<T>> post<T>({
    required String endpoint,
    required Map<String, dynamic> body,
    T Function(dynamic json)? fromJson,
    bool isMock = false,
    dynamic mockData,
  }) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 30);
      final request = await client.postUrl(Uri.parse('$baseUrl$endpoint'));
      _headers.forEach((key, value) => request.headers.set(key, value));
      request.write(jsonEncode(body));

      final response =
          await request.close().timeout(const Duration(seconds: 30));
      final responseBody = await response.transform(utf8.decoder).join();
      final jsonMap = jsonDecode(responseBody) as Map<String, dynamic>;

      return ApiResponse<T>.fromJson(jsonMap, fromJson);
    } on SocketException {
      return ApiResponse<T>(
        success: false,
        message: 'Tidak ada koneksi internet.',
        statusCode: 503,
      );
    } catch (e) {
      return ApiResponse<T>(
        success: false,
        message: 'Gagal mengirim data ke server: $e',
        statusCode: 500,
      );
    }
  }
}
