import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../data/models/activity_log_model.dart';
import 'auth_service.dart';

//SERVICE BACKEND REST API UNTUK AUDIT TRAIL / LOG AKTIVITAS
class ActivityLogService {
  static final String endpoint = '${AuthService.staticBaseUrl}/v1/admin/audit-logs';

  /// Fetch Audit Logs dengan Filter & Search Query
  static Future<List<ActivityLogModel>> fetchAuditLogs({
    String? searchQuery,
    String? moduleFilter,
    String? actionFilter,
    String? startDate,
    String? endDate,
    int page = 1,
  }) async {
    try {
      final token = await AuthService().getToken();

      if (token != null && token.isNotEmpty) {
        final queryParams = <String, String>{
          'page': page.toString(),
          if (searchQuery != null && searchQuery.isNotEmpty) 'q': searchQuery,
          if (moduleFilter != null && moduleFilter.toLowerCase() != 'semua') 'module': moduleFilter,
          if (actionFilter != null && actionFilter.toLowerCase() != 'semua') 'action': actionFilter,
          if (startDate != null && startDate.isNotEmpty) 'start_date': startDate,
          if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
        };

        final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);
        final response = await http.get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final List rawList = body['data'] ?? body['logs'] ?? [];
          return rawList.map((item) => ActivityLogModel.fromJson(item)).toList();
        }
      }
    } catch (e) {
      debugPrint('Info ActivityLogService (Fallback Mode): $e');
    }

    // Fallback Mock Data Filtered
    var mockList = ActivityLogModel.getDummyLogs();

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      mockList = mockList.where((log) {
        return log.userName.toLowerCase().contains(q) ||
            log.description.toLowerCase().contains(q) ||
            log.id.toLowerCase().contains(q);
      }).toList();
    }

    if (moduleFilter != null && moduleFilter.toLowerCase() != 'semua') {
      mockList = mockList.where((log) => log.module.toLowerCase() == moduleFilter.toLowerCase()).toList();
    }

    if (actionFilter != null && actionFilter.toLowerCase() != 'semua') {
      mockList = mockList.where((log) => log.action.toLowerCase() == actionFilter.toLowerCase()).toList();
    }

    return mockList;
  }
}
