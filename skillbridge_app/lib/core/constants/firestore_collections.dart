/// Firestore collection names. Use these instead of string literals so a
/// rename is a one-line change.
class FirestoreCollections {
  FirestoreCollections._();

  static const String users = 'users';
  static const String courses = 'courses';
  static const String campuses = 'campuses';
  static const String batches = 'batches';
  static const String applications = 'applications';
  static const String attendance = 'attendance';
  static const String assignments = 'assignments';
  static const String submissions = 'submissions';
  static const String notices = 'notices';
  static const String notifications = 'notifications';
}

/// Firebase Storage paths.
class StoragePaths {
  StoragePaths._();

  /// Profile picture for a user: `profiles/{uid}.jpg`
  static String profile(String uid) => 'profiles/$uid.jpg';

  /// Assignment submission: `submissions/{assignmentId}/{uid}`
  static String submission(String assignmentId, String uid) =>
      'submissions/$assignmentId/$uid';
}

/// The provinces and regions a campus can belong to.
class Provinces {
  Provinces._();

  static const List<String> all = [
    'Punjab',
    'Sindh',
    'Khyber Pakhtunkhwa',
    'Balochistan',
    'Islamabad',
    'Azad Jammu & Kashmir',
    'Gilgit-Baltistan',
  ];
}
