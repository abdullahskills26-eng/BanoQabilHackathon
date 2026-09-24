import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/assignment_model.dart';
import '../models/user_model.dart';

/// A notice as the FastAPI mock backend returns it.
///
/// Deliberately separate from [NoticeModel], which is the Firestore document
/// the app itself uses — this one only mirrors the REST response shape.
class ApiNotice {
  final int id;
  final String text;
  final String createdAt;

  ApiNotice({required this.id, required this.text, required this.createdAt});

  factory ApiNotice.fromJson(Map<String, dynamic> json) {
    return ApiNotice(
      id: json['id'],
      text: json['text'] ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

/// Build-time override for the backend URL. Takes precedence over everything
/// below, so a hosted backend needs no code change:
///
///   flutter run --dart-define=API_BASE_URL=https://api.example.com/api/v1
const String _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

/// Host that reaches the development machine from wherever the app is running.
///
/// `localhost` inside an Android emulator refers to the emulator itself, not
/// to the computer running the backend — the emulator reaches its host through
/// the special alias 10.0.2.2. The Genymotion equivalent is 10.0.3.2.
///
/// A physical device on the same Wi-Fi reaches neither; pass the machine's LAN
/// address explicitly with --dart-define=API_BASE_URL=http://192.168.x.x:8000/api/v1
String _defaultHost() {
  if (kIsWeb) return '127.0.0.1';
  try {
    if (Platform.isAndroid) return '10.0.2.2';
  } catch (_) {
    // Platform is unavailable on some targets; fall through to the default.
  }
  return '127.0.0.1';
}

/// Base URL of the FastAPI backend (see skillbridge_backend/). No trailing
/// slash.
///
/// Routers mount under the `/api/v1` prefix, so this carries the prefix and
/// every call site passes only the endpoint path.
final String kApiBaseUrl = _apiBaseUrlOverride.isNotEmpty
    ? _apiBaseUrlOverride
    : 'http://${_defaultHost()}:8000/api/v1';

/// Aggregate counters for the dashboard home.
///
/// A response shape rather than a Firestore document, so it lives with the
/// client instead of in models/.
class DashboardSummary {
  final int totalClasses;
  final int totalStudents;
  final int activeNotices;
  final int pendingAssignments;

  DashboardSummary({
    required this.totalClasses,
    required this.totalStudents,
    required this.activeNotices,
    required this.pendingAssignments,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      totalClasses: json['total_classes'] ?? 0,
      totalStudents: json['total_students'] ?? 0,
      activeNotices: json['active_notices'] ?? 0,
      pendingAssignments: json['pending_assignments'] ?? 0,
    );
  }
}

/// Error surfaced to the UI when a request fails or the backend is unreachable.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// Centralised REST client for the FastAPI backend.
class ApiService {
  final String baseUrl;

  /// Defaults to [kApiBaseUrl], which is resolved at runtime rather than
  /// compile time, so it cannot be a const parameter default.
  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? kApiBaseUrl;

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  /// Rethrows an [ApiException] unchanged and wraps anything else.
  ///
  /// Without this, `throw ApiException(...)` inside a `try` is caught by that
  /// same block's `catch` and wrapped a second time, producing messages like
  /// "Error fetching students: Failed to load students (500)".
  Never _fail(Object error, String action) {
    if (error is ApiException) throw error;
    throw ApiException('$action: $error');
  }

  /// FastAPI reports failures as `{"detail": ...}` — surface that text rather
  /// than a bare status code, so the UI can show what actually went wrong.
  String _detail(http.Response res, String fallback) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['detail'] != null) {
        return '${body['detail']} (${res.statusCode})';
      }
    } catch (_) {
      // Not JSON — fall back to the generic message below.
    }
    return '$fallback (${res.statusCode})';
  }

  /// GET /dashboard/summary
  Future<DashboardSummary> fetchDashboardSummary() async {
    try {
      final res = await http.get(_u('/dashboard/summary'));
      if (res.statusCode == 200) {
        return DashboardSummary.fromJson(jsonDecode(res.body));
      }
      throw ApiException(_detail(res, 'Failed to load summary'));
    } catch (e) {
      _fail(e, 'Error fetching dashboard summary');
    }
  }

  /// GET /students
  Future<List<Student>> fetchStudents() async {
    try {
      final res = await http.get(_u('/students'));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((e) => Student.fromJson(e)).toList();
      }
      throw ApiException(_detail(res, 'Failed to load students'));
    } catch (e) {
      _fail(e, 'Error fetching students');
    }
  }

  /// POST /attendance/mark
  Future<void> markAttendance(int studentId, String status) async {
    try {
      final res = await http.post(
        _u('/attendance/mark'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'student_id': studentId, 'status': status}),
      );
      if (res.statusCode != 200) {
        throw ApiException(_detail(res, 'Failed to update attendance'));
      }
    } catch (e) {
      _fail(e, 'Error marking attendance');
    }
  }

  /// GET /assignments
  Future<List<Assignment>> fetchAssignments() async {
    try {
      final res = await http.get(_u('/assignments'));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((e) => Assignment.fromJson(e)).toList();
      }
      throw ApiException(_detail(res, 'Failed to load assignments'));
    } catch (e) {
      _fail(e, 'Error fetching assignments');
    }
  }

  /// POST /assignments/create
  Future<Assignment> createAssignment({
    required String title,
    required String dueDate,
    required int maxMarks,
  }) async {
    try {
      final res = await http.post(
        _u('/assignments/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'due_date': dueDate,
          'max_marks': maxMarks,
        }),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return Assignment.fromJson(body['assignment']);
      }
      throw ApiException(_detail(res, 'Failed to create assignment'));
    } catch (e) {
      _fail(e, 'Error creating assignment');
    }
  }

  /// POST /notices/create
  Future<ApiNotice> createNotice(String text) async {
    try {
      final res = await http.post(
        _u('/notices/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return ApiNotice.fromJson(body['notice']);
      }
      throw ApiException(_detail(res, 'Failed to post notice'));
    } catch (e) {
      _fail(e, 'Error posting notice');
    }
  }

  /// GET /batch/progress
  Future<int> fetchAtRiskCount() async {
    try {
      final res = await http.get(_u('/batch/progress'));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return body['at_risk_count'] ?? 0;
      }
      throw ApiException(_detail(res, 'Failed to load batch progress'));
    } catch (e) {
      _fail(e, 'Error fetching batch progress');
    }
  }
}
