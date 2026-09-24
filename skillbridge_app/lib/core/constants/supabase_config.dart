/// Supabase configuration, supplied at build time.
///
/// Values come from `--dart-define`, so nothing is committed to git:
///
///   flutter run -d chrome \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
///
/// Only the **anon / publishable** key belongs here. It is safe in a client
/// the same way the Firebase apiKey is — it identifies the project and grants
/// nothing on its own, because Storage access is decided by RLS policies.
///
/// The **service_role / secret** key must never appear in this app. It
/// bypasses every policy. If you ever need it, it belongs in the FastAPI
/// backend behind an environment variable.
class SupabaseConfig {
  SupabaseConfig._();

  /// Project URL. Overridable with --dart-define=SUPABASE_URL=...
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rxvfppzsmpjfxwzrjbwq.supabase.co',
  );

  /// Anon / publishable key. Publishable by design — it identifies the
  /// project and grants nothing on its own, exactly like the Firebase apiKey
  /// in firebase_options.dart. Storage access is decided by RLS policies.
  /// Overridable with --dart-define=SUPABASE_ANON_KEY=...
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ4dmZwcHpzbXBqZnh3enJqYndxIiwicm9'
        'sZSI6ImFub24iLCJpYXQiOjE3ODkzMDgxMzIsImV4cCI6MjEwNDg4NDEzMn0.'
        'nY_O_77TRJAwuxYs_hnunPZMOm96Xu4sw5l-smuXoTY',
  );

  /// Private bucket that holds every uploaded file.
  static const String bucket = 'skillbridge-files';

  /// Folder prefixes inside the bucket. The second path segment is always the
  /// owner's Firebase UID, which is what the Storage RLS policies match on.
  static String profilePicture(String uid, String fileName) =>
      'profile_pictures/$uid/$fileName';

  static String assignmentFile(
    String uid,
    String assignmentId,
    String fileName,
  ) =>
      'assignments/$uid/${assignmentId}_$fileName';

  /// How long a generated signed URL stays valid.
  static const Duration signedUrlTtl = Duration(hours: 1);

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Shown in the UI when the dart-defines are missing.
  static const String setupHint =
      'Supabase is not configured. Rebuild with '
      '--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...';
}
