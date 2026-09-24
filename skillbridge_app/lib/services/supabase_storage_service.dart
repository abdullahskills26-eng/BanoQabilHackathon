import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_config.dart';

/// What an upload returns, and what gets recorded in Firestore.
///
/// Only the [path] is durable. The bucket is private, so a URL is always a
/// short-lived signed link generated on demand — never store one.
class StoredFile {
  final String path;
  final String fileName;
  final int sizeBytes;
  final String contentType;

  const StoredFile({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    required this.contentType,
  });

  Map<String, dynamic> toMap() => {
        'storagePath': path,
        'fileName': fileName,
        'fileSize': sizeBytes,
        'contentType': contentType,
      };

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Raised for anything the user needs to read and act on.
class SupabaseStorageException implements Exception {
  final String message;
  SupabaseStorageException(this.message);
  @override
  String toString() => message;
}

/// File storage on Supabase, for a Firebase-authenticated user.
///
/// Firebase Auth and Firestore are untouched: this only replaces Firebase
/// Storage, which is unavailable on the Spark plan. The Supabase client is
/// authenticated by handing it the caller's Firebase ID token (see
/// `main.dart`), so `auth.jwt() ->> 'sub'` inside a Storage policy is the
/// Firebase UID and per-user folder rules work as expected.
class SupabaseStorageService {
  SupabaseStorageService._();

  static const int maxProfileBytes = 5 * 1024 * 1024; // 5 MB
  static const int maxAssignmentBytes = 10 * 1024 * 1024; // 10 MB

  static SupabaseClient get _client {
    if (!SupabaseConfig.isConfigured) {
      throw SupabaseStorageException(SupabaseConfig.setupHint);
    }
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw SupabaseStorageException(
        'Supabase was not initialised. Restart the app with the '
        'SUPABASE_URL and SUPABASE_ANON_KEY dart-defines set.',
      );
    }
  }

  static StorageFileApi get _bucket =>
      _client.storage.from(SupabaseConfig.bucket);

  // -------------------------------------------------------------- uploads

  /// Uploads a profile picture to `profile_pictures/{uid}/{fileName}`.
  static Future<StoredFile> uploadProfilePicture({
    required String uid,
    required Uint8List bytes,
    required String fileName,
  }) async {
    _requireNonEmpty(uid);
    _requireSize(bytes.length, maxProfileBytes, 'Profile picture', 5);

    final contentType = _contentTypeFor(fileName);
    if (!contentType.startsWith('image/')) {
      throw SupabaseStorageException(
        'Profile pictures must be an image (JPG, PNG, GIF or WebP).',
      );
    }

    // One stable name per user, so a new upload replaces the old picture
    // instead of leaving orphans in the bucket.
    final safeName = 'avatar${_extensionOf(fileName)}';
    final path = SupabaseConfig.profilePicture(uid, safeName);

    return _upload(
      path: path,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      upsert: true,
    );
  }

  /// Uploads an assignment file to
  /// `assignments/{uid}/{assignmentId}_{fileName}`.
  static Future<StoredFile> uploadAssignmentFile({
    required String uid,
    required String assignmentId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    _requireNonEmpty(uid);
    if (assignmentId.isEmpty) {
      throw SupabaseStorageException('Missing assignment id for the upload.');
    }
    _requireSize(bytes.length, maxAssignmentBytes, 'Assignment file', 10);

    final path = SupabaseConfig.assignmentFile(
      uid,
      assignmentId,
      _sanitise(fileName),
    );

    return _upload(
      path: path,
      bytes: bytes,
      fileName: fileName,
      contentType: _contentTypeFor(fileName),
      // Resubmitting should overwrite the previous attempt.
      upsert: true,
    );
  }

  static Future<StoredFile> _upload({
    required String path,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required bool upsert,
  }) async {
    try {
      await _bucket.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: contentType,
          upsert: upsert,
        ),
      );
      return StoredFile(
        path: path,
        fileName: fileName,
        sizeBytes: bytes.length,
        contentType: contentType,
      );
    } on StorageException catch (e) {
      throw SupabaseStorageException(_friendly(e));
    } catch (e) {
      throw SupabaseStorageException('Upload failed: $e');
    }
  }

  // ----------------------------------------------------------------- read

  /// A time-limited link for a private object.
  ///
  /// The bucket stays private; this mints a signed URL valid for
  /// [SupabaseConfig.signedUrlTtl]. Generate one when you need to display or
  /// download the file — do not persist it.
  static Future<String> signedUrl(
    String path, {
    Duration? expiresIn,
  }) async {
    if (path.isEmpty) {
      throw SupabaseStorageException('No file path was provided.');
    }
    try {
      return await _bucket.createSignedUrl(
        path,
        (expiresIn ?? SupabaseConfig.signedUrlTtl).inSeconds,
      );
    } on StorageException catch (e) {
      throw SupabaseStorageException(_friendly(e));
    } catch (e) {
      throw SupabaseStorageException('Could not open that file: $e');
    }
  }

  /// Signed URL, or null when the path is empty or the link cannot be made.
  /// Useful in widgets that should fall back to a placeholder rather than
  /// surface an error.
  static Future<String?> signedUrlOrNull(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      return await signedUrl(path);
    } catch (_) {
      return null;
    }
  }

  /// Raw bytes of a stored object.
  static Future<Uint8List> download(String path) async {
    try {
      return await _bucket.download(path);
    } on StorageException catch (e) {
      throw SupabaseStorageException(_friendly(e));
    } catch (e) {
      throw SupabaseStorageException('Download failed: $e');
    }
  }

  // --------------------------------------------------------------- delete

  static Future<void> delete(String path) async {
    if (path.isEmpty) return;
    try {
      await _bucket.remove([path]);
    } on StorageException catch (e) {
      throw SupabaseStorageException(_friendly(e));
    } catch (e) {
      throw SupabaseStorageException('Could not delete that file: $e');
    }
  }

  /// Best-effort delete — swallows failures. For cleaning up a replaced file
  /// where failing the whole operation would be worse than leaving an orphan.
  static Future<void> deleteQuietly(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      await delete(path);
    } catch (_) {
      // Intentionally ignored.
    }
  }

  // -------------------------------------------------------------- helpers

  static void _requireNonEmpty(String uid) {
    if (uid.isEmpty) {
      throw SupabaseStorageException(
        'You must be signed in to upload files.',
      );
    }
  }

  static void _requireSize(int actual, int limit, String label, int limitMb) {
    if (actual == 0) {
      throw SupabaseStorageException('That file is empty.');
    }
    if (actual > limit) {
      throw SupabaseStorageException(
        '$label must be under $limitMb MB '
        '(yours is ${(actual / (1024 * 1024)).toStringAsFixed(1)} MB).',
      );
    }
  }

  /// Strips path separators and anything Storage would reject in a key.
  static String _sanitise(String fileName) {
    final base = fileName.split(RegExp(r'[\\/]')).last;
    return base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  static String _extensionOf(String fileName) {
    final i = fileName.lastIndexOf('.');
    if (i <= 0 || i == fileName.length - 1) return '.jpg';
    return fileName.substring(i).toLowerCase();
  }

  /// Storage needs an explicit content type or everything is served as
  /// application/octet-stream.
  static String _contentTypeFor(String fileName) {
    switch (_extensionOf(fileName).replaceFirst('.', '')) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument'
            '.wordprocessingml.document';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument'
            '.presentationml.presentation';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument'
            '.spreadsheetml.sheet';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }

  /// Turns Supabase's error strings into something a student can act on.
  static String _friendly(StorageException e) {
    final message = e.message.toLowerCase();
    if (message.contains('bucket not found')) {
      return 'Storage bucket "${SupabaseConfig.bucket}" does not exist. '
          'Create it in the Supabase dashboard.';
    }
    if (message.contains('row-level security') ||
        message.contains('unauthorized') ||
        e.statusCode == '403') {
      return 'Storage denied the upload. Check that the Supabase Storage '
          'policies for "${SupabaseConfig.bucket}" allow authenticated users '
          'to write their own folder, and that Firebase is registered as a '
          'third-party auth provider in Supabase.';
    }
    if (e.statusCode == '404') {
      return 'That file no longer exists in storage.';
    }
    if (message.contains('exceeded') || message.contains('too large')) {
      return 'That file is larger than the bucket allows.';
    }
    return 'Storage error: ${e.message}';
  }
}
