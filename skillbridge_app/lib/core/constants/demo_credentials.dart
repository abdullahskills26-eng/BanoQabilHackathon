/// Demo accounts used by the quick-login buttons.
///
/// These exist in Firebase Authentication on project `skillbridge-32f45`.
/// The [uid] values are the real Auth UIDs — the seeder writes each demo
/// account's Firestore documents against them, so signing in as a demo user
/// lands on a dashboard with actual data rather than an empty one.
class DemoCredentials {
  DemoCredentials._();

  static const String password = 'skillbridge123';

  static const DemoAccount student = DemoAccount(
    uid: 'phxpBxchb1TDv3ZxbgPEsRGE7CU2',
    email: 'student@skillbridge.org',
    name: 'Ayesha Khan',
    role: 'student',
    description: 'Flutter student — Lahore Campus',
  );

  static const DemoAccount instructor = DemoAccount(
    uid: 'YvKxpyVjqfPicIsV4pp0E5n1CIs2',
    email: 'instructor@skillbridge.org',
    name: 'Sir Hamza',
    role: 'instructor',
    description: 'Flutter instructor — Lahore Campus',
  );

  static const DemoAccount coordinator = DemoAccount(
    uid: 'xRaLAojCVmgHbcvr9VY2wsrR3Kg2',
    email: 'admin@skillbridge.org',
    name: 'Campus Coordinator',
    role: 'coordinator',
    description: 'Campus coordinator — Lahore',
  );

  static const List<DemoAccount> all = [student, instructor, coordinator];
}

class DemoAccount {
  /// Firebase Auth UID. Empty when the account has not been created yet.
  final String uid;
  final String email;
  final String name;
  final String role;
  final String description;

  const DemoAccount({
    required this.email,
    required this.name,
    required this.role,
    required this.description,
    this.uid = '',
  });
}
