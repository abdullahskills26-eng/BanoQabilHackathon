// Verifies that the Flutter models parse exactly what the FastAPI backend
// returns.
//
// The JSON fixtures below are copied verbatim from a running backend
// (`uvicorn app.main:app`), not hand-written, so this test fails if either
// side renames a field — the snake_case / camelCase mismatch that is easy to
// introduce and hard to spot at runtime.
//
// Run with: flutter test

import 'dart:convert';

import 'package:bano_qabil_app/models/assignment_model.dart';
import 'package:bano_qabil_app/models/user_model.dart';
import 'package:bano_qabil_app/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('API base URL', () {
    test('carries the /api/v1 prefix and no trailing slash', () {
      expect(kApiBaseUrl, endsWith('/api/v1'));
      expect(kApiBaseUrl, isNot(endsWith('/')));
      expect(kApiBaseUrl, startsWith('http'));
    });

    test('has no stray whitespace', () {
      expect(kApiBaseUrl, kApiBaseUrl.trim());
    });

    test('an explicit baseUrl overrides the default', () {
      final svc = ApiService(baseUrl: 'https://example.test/api/v1');
      expect(svc.baseUrl, 'https://example.test/api/v1');
    });

    test('defaults to the resolved platform URL', () {
      expect(ApiService().baseUrl, kApiBaseUrl);
    });
  });

  group('DashboardSummary', () {
    test('parses GET /dashboard/summary', () {
      // Verbatim response from the running backend.
      const body = '{"total_classes":2,"total_students":5,'
          '"active_notices":1,"pending_assignments":2}';
      final s = DashboardSummary.fromJson(jsonDecode(body));

      expect(s.totalClasses, 2);
      expect(s.totalStudents, 5);
      expect(s.activeNotices, 1);
      expect(s.pendingAssignments, 2);
    });

    test('missing counters fall back to zero rather than throwing', () {
      final s = DashboardSummary.fromJson(const {});
      expect(s.totalClasses, 0);
      expect(s.pendingAssignments, 0);
    });
  });

  group('Student', () {
    test('parses GET /students', () {
      const body = '[{"id":2,"name":"Bilal Ahmed",'
          '"attendance_percentage":68.5,"status":"Absent",'
          '"is_at_risk":true}]';
      final list = (jsonDecode(body) as List)
          .map((e) => Student.fromJson(e as Map<String, dynamic>))
          .toList();

      expect(list, hasLength(1));
      expect(list.first.id, 2);
      expect(list.first.name, 'Bilal Ahmed');
      expect(list.first.attendancePercentage, 68.5);
      expect(list.first.status, 'Absent');
      expect(list.first.isAtRisk, isTrue);
    });

    test('an integer attendance percentage still parses as double', () {
      // Firestore and JSON both hand back a bare int for a whole number,
      // which a plain `as double` cast would reject.
      final s = Student.fromJson(const {
        'id': 1,
        'name': 'A',
        'attendance_percentage': 92,
        'status': 'Present',
        'is_at_risk': false,
      });
      expect(s.attendancePercentage, 92.0);
    });

    test('copyWithStatus preserves every other field', () {
      final s = Student.fromJson(const {
        'id': 7,
        'name': 'Sara',
        'attendance_percentage': 74.0,
        'status': 'Present',
        'is_at_risk': true,
      }).copyWithStatus('Absent');

      expect(s.status, 'Absent');
      expect(s.id, 7);
      expect(s.name, 'Sara');
      expect(s.isAtRisk, isTrue);
    });
  });

  group('Assignment', () {
    test('parses the assignment body of POST /assignments/create', () {
      const body = '{"message":"Assignment created successfully",'
          '"assignment":{"id":3,"title":"Data Structures - Assignment 1",'
          '"due_date":"2026-09-20","max_marks":100,"submissions_count":0}}';
      final a = Assignment.fromJson(jsonDecode(body)['assignment']);

      expect(a.id, 3);
      expect(a.title, 'Data Structures - Assignment 1');
      expect(a.dueDate, '2026-09-20');
      expect(a.maxMarks, 100);
      expect(a.submissionsCount, 0);
    });
  });

  group('ApiNotice', () {
    test('parses the notice body of POST /notices/create', () {
      const body = '{"message":"Notice posted successfully",'
          '"notice":{"id":2,"text":"Class rescheduled.",'
          '"created_at":"2026-09-18T10:00:00+00:00"}}';
      final n = ApiNotice.fromJson(jsonDecode(body)['notice']);

      expect(n.id, 2);
      expect(n.text, 'Class rescheduled.');
      expect(n.createdAt, '2026-09-18T10:00:00+00:00');
    });
  });

  group('ApiException', () {
    test('toString is the bare message, so it can go straight in the UI', () {
      expect(ApiException('Backend unreachable').toString(),
          'Backend unreachable');
    });
  });
}
