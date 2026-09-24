// Regression tests for the sign-up role policy and the per-platform Firebase
// configuration.
//
// Both encode security decisions that are easy to undo by accident:
//   - public sign-up must never grant a privileged role
//   - an unconfigured platform must not silently receive the web app's
//     credentials
//
// Run with: flutter test

import 'package:bano_qabil_app/firebase_options.dart';
import 'package:bano_qabil_app/services/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sign-up role policy', () {
    test('only student is self-assignable at sign-up', () {
      expect(AuthService.isSelfAssignable(UserRole.student), isTrue);
      expect(AuthService.isSelfAssignable(UserRole.instructor), isFalse);
      expect(AuthService.isSelfAssignable(UserRole.coordinator), isFalse);
    });

    test('every known role is covered, and only one is self-assignable', () {
      // Guards against a fourth role being added and silently defaulting to
      // self-assignable.
      final selfAssignable =
          UserRole.all.where(AuthService.isSelfAssignable).toList();
      expect(selfAssignable, [UserRole.student]);
    });

    test('an unknown role is not self-assignable', () {
      expect(AuthService.isSelfAssignable('admin'), isFalse);
      expect(AuthService.isSelfAssignable(''), isFalse);
    });
  });

  group('UserRole', () {
    test('validates only the three known roles', () {
      for (final r in UserRole.all) {
        expect(UserRole.isValid(r), isTrue, reason: r);
      }
      expect(UserRole.isValid('superuser'), isFalse);
      expect(UserRole.isValid(null), isFalse);
    });
  });

  group('AuthProfile.fromMap', () {
    test('an unrecognised role falls back to student, never upward', () {
      final p = AuthProfile.fromMap('u1', 'a@b.com', {'role': 'superuser'});
      expect(p.role, UserRole.student);
    });

    test('a missing role falls back to student', () {
      final p = AuthProfile.fromMap('u1', 'a@b.com', {});
      expect(p.role, UserRole.student);
    });

    test('a legitimate staff role is preserved', () {
      final p = AuthProfile.fromMap('u1', 'a@b.com', {
        'role': UserRole.coordinator,
        'name': 'Coord',
      });
      expect(p.role, UserRole.coordinator);
      expect(p.name, 'Coord');
    });

    test('campusName is accepted as an alias for campus', () {
      final p = AuthProfile.fromMap('u1', 'a@b.com', {
        'campusName': 'Lahore Campus',
      });
      expect(p.campus, 'Lahore Campus');
    });
  });

  group('DefaultFirebaseOptions', () {
    test('web options point at the real project', () {
      expect(DefaultFirebaseOptions.web.projectId, 'skillbridge-32f45');
      expect(DefaultFirebaseOptions.web.appId, contains(':web:'));
    });

    test('Android does not silently receive the web credentials', () {
      // Only a web app is registered in the Firebase project, so Android must
      // report itself unconfigured rather than hand out a web appId.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(
        () => DefaultFirebaseOptions.currentPlatform,
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('the Android error says exactly what to run', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      try {
        DefaultFirebaseOptions.currentPlatform;
        fail('expected UnsupportedError');
      } on UnsupportedError catch (e) {
        final message = e.message ?? '';
        expect(message, contains('Android'));
        expect(message, contains('flutterfire configure'));
        expect(message, contains('skillbridge-32f45'));
      }
    });

    test('isConfigured reports false instead of throwing', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      // main() relies on this never throwing.
      expect(DefaultFirebaseOptions.isConfigured, isFalse);
    });

    test('iOS is reported unconfigured too', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(
        () => DefaultFirebaseOptions.currentPlatform,
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
