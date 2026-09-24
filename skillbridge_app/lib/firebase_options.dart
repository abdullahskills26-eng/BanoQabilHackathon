import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Firebase configuration for the SkillBridge project (`skillbridge-32f45`).
///
/// These values are not secrets: they ship inside every built web bundle and
/// are public by design. Access is controlled by the Firestore and Storage
/// security rules (see firestore.rules / storage.rules at the repo root),
/// not by hiding this file.
///
/// Only the **web** app is registered in the Firebase project today —
/// `firebase apps:list --project skillbridge-32f45` returns a single WEB
/// entry. Android, iOS and desktop therefore have no credentials of their
/// own, and are reported as unconfigured rather than being handed the web
/// app's values: a web `appId` on Android does not identify a real Android
/// app, and Firebase would fail later with a far less obvious error.
///
/// To add a platform, register it in the Firebase console (or with
/// `firebase apps:create`) and then regenerate this file:
///
///     dart pub global activate flutterfire_cli
///     flutterfire configure --project=skillbridge-32f45
class DefaultFirebaseOptions {
  /// The web app registered in the Firebase console.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDMxdiscRn7jhZgav8LYtjUPqLeiDn_OHA',
    authDomain: 'skillbridge-32f45.firebaseapp.com',
    projectId: 'skillbridge-32f45',
    storageBucket: 'skillbridge-32f45.firebasestorage.app',
    messagingSenderId: '1068190447078',
    appId: '1:1068190447078:web:0a287ed9a8783f40fb9227',
    measurementId: 'G-STVMLVWEDJ',
  );

  /// Options for the platform the app is currently running on.
  ///
  /// Throws [UnsupportedError] with actionable instructions on a platform
  /// that has not been registered yet. `main()` catches this and the login
  /// screen displays the message, so a misconfigured platform explains
  /// itself instead of failing somewhere deep inside the SDK.
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        throw UnsupportedError(_notConfigured('Android'));
      case TargetPlatform.iOS:
        throw UnsupportedError(_notConfigured('iOS'));
      case TargetPlatform.macOS:
        throw UnsupportedError(_notConfigured('macOS'));
      case TargetPlatform.windows:
        throw UnsupportedError(_notConfigured('Windows'));
      case TargetPlatform.linux:
        throw UnsupportedError(_notConfigured('Linux'));
      default:
        throw UnsupportedError(
          _notConfigured(defaultTargetPlatform.name),
        );
    }
  }

  static String _notConfigured(String platform) =>
      'Firebase is not configured for $platform.\n\n'
      'Only the web app is registered in project skillbridge-32f45, so this '
      'platform has no Firebase credentials of its own.\n\n'
      'To add it, run:\n'
      '  dart pub global activate flutterfire_cli\n'
      '  flutterfire configure --project=skillbridge-32f45\n\n'
      'That registers the app in Firebase, writes the platform config file '
      '(google-services.json on Android) and regenerates this file.';

  /// True when the current platform has real Firebase credentials.
  ///
  /// Never throws — callers use it to decide whether to attempt
  /// initialisation at all.
  static bool get isConfigured {
    try {
      return !currentPlatform.projectId.startsWith('REPLACE_WITH');
    } on UnsupportedError {
      return false;
    }
  }
}
