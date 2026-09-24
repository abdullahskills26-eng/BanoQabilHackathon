import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../core/constants/firestore_collections.dart';

/// Firebase Storage uploads.
///
/// Web-safe: everything takes bytes rather than a `File`, because on Flutter
/// web the browser gives you bytes and `PlatformFile.path` is always null.
class StorageService {
  static final FirebaseStorage storage = FirebaseStorage.instance;

  /// Uploads an assignment file to `submissions/{assignmentId}/{uid}` and
  /// returns its download URL.
  static Future<String> uploadSubmission({
    required String assignmentId,
    required String uid,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final ref = storage.ref(StoragePaths.submission(assignmentId, uid));
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: _contentTypeFor(fileName),
        customMetadata: {'fileName': fileName},
      ),
    );
    return ref.getDownloadURL();
  }

  /// Uploads a profile picture to `profiles/{uid}.jpg` and returns its URL.
  static Future<String> uploadProfilePicture({
    required String uid,
    required Uint8List bytes,
  }) async {
    final ref = storage.ref(StoragePaths.profile(uid));
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  /// Best-effort MIME type from the file extension. Storage needs this set
  /// explicitly or everything is served as application/octet-stream.
  static String _contentTypeFor(String fileName) {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
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
}
