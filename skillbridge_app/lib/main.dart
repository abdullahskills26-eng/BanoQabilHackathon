import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/constants/supabase_config.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------- Firebase
  // Guarded so the app still starts with placeholder Firebase credentials.
  // Without this, an invalid config throws here and nothing renders at all.
  bool firebaseReady = false;
  String? firebaseError;
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    firebaseReady = true;
  } catch (e) {
    firebaseError = e.toString();
  }

  // ---------------------------------------------------------------- Supabase
  // Used for file storage only — Firebase Storage is unavailable on the Spark
  // plan. Authentication and all data stay on Firebase.
  //
  // `accessToken` hands Supabase the caller's Firebase ID token instead of a
  // Supabase session, so Storage RLS policies can match on
  // `auth.jwt() ->> 'sub'`, which is the Firebase UID. This requires Firebase
  // to be registered as a third-party auth provider in the Supabase
  // dashboard. Supabase Auth itself is intentionally unused.
  //
  // Guarded the same way as Firebase: a Supabase misconfiguration must not
  // stop the app — sign-in, dashboards and Firestore all work without it,
  // only uploads are affected.
  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
        accessToken: () async {
          if (!firebaseReady) return null;
          try {
            return await FirebaseAuth.instance.currentUser?.getIdToken();
          } catch (_) {
            // A token refresh failure must not crash a storage call; the
            // request simply goes out unauthenticated and RLS rejects it.
            return null;
          }
        },
      );
    } catch (e) {
      // Storage is the only thing affected; the upload screens surface a
      // precise message of their own, so this just aids debugging.
      debugPrint('Supabase initialisation failed: $e');
    }
  } else {
    debugPrint(SupabaseConfig.setupHint);
  }

  runApp(BanoQabilApp(
    firebaseReady: firebaseReady,
    firebaseError: firebaseError,
  ));
}
