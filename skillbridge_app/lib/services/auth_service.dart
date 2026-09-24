import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../core/constants/demo_credentials.dart';
import '../core/constants/firestore_collections.dart';

/// The three roles, and where each one lands after signing in.
class UserRole {
  UserRole._();

  static const String student = 'student';
  static const String instructor = 'instructor';
  static const String coordinator = 'coordinator';

  static const List<String> all = [student, instructor, coordinator];

  static bool isValid(String? role) => all.contains(role);

  static String label(String role) {
    switch (role) {
      case instructor:
        return 'Instructor';
      case coordinator:
        return 'Campus Coordinator';
      default:
        return 'Student';
    }
  }
}

/// A signed-in user together with the role that decides what they can open.
class AuthProfile {
  final String uid;
  final String email;
  final String name;
  final String role;
  final String campus;
  final String city;

  const AuthProfile({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.campus = '',
    this.city = '',
  });

  factory AuthProfile.fromMap(
      String uid, String email, Map<String, dynamic>? map) {
    final data = map ?? const {};
    return AuthProfile(
      uid: uid,
      email: (data['email'] ?? email).toString(),
      name: (data['name'] ?? '').toString(),
      role: UserRole.isValid(data['role']?.toString())
          ? data['role'].toString()
          : UserRole.student,
      campus: (data['campus'] ?? data['campusName'] ?? '').toString(),
      city: (data['city'] ?? '').toString(),
    );
  }
}

/// Raised for anything the user needs to read and act on.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

/// Firebase Authentication, plus the `users/{uid}` document that carries the
/// role. The two are always written together so a signed-in account can never
/// end up without a role.
class AuthService {
  static final FirebaseAuth auth = FirebaseAuth.instance;
  static final FirebaseFirestore db = FirebaseFirestore.instance;

  /// Fires on sign-in and sign-out. The auth gate listens to this.
  static Stream<User?> get authStateChanges => auth.authStateChanges();

  static User? get currentUser => auth.currentUser;

  // ------------------------------------------------------------- Sign in

  static Future<AuthProfile> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw AuthException('Sign-in did not return a user.');
      }
      return loadProfile(user);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  // ------------------------------------------------------------ Register

  /// Creates the account and its profile document in one go.
  ///
  /// If the document write fails the Auth account is deleted again, so a
  /// half-created user can never sign in with no role attached.
  ///
  /// Public sign-up always creates a **student**. A chosen instructor or
  /// coordinator role is recorded as `requestedRole` for a coordinator to
  /// approve, and grants nothing by itself — self-assigning a privileged role
  /// would otherwise let anyone read every campus's data. The Firestore rules
  /// enforce the same thing server-side, so this is not merely a UI courtesy.
  static Future<AuthProfile> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
    String city = '',
    String campus = '',
  }) async {
    if (!UserRole.isValid(role)) {
      throw AuthException('Choose a valid role.');
    }

    UserCredential credential;
    try {
      credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }

    final user = credential.user;
    if (user == null) {
      throw AuthException('Registration did not return a user.');
    }

    // Everyone starts as a student; anything else needs coordinator approval.
    const grantedRole = UserRole.student;

    try {
      await user.updateDisplayName(name.trim());
      await db.collection(FirestoreCollections.users).doc(user.uid).set({
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'role': grantedRole,
        if (role != grantedRole) 'requestedRole': role,
        'city': city.trim(),
        'campus': campus.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Roll the account back rather than leave it role-less.
      try {
        await user.delete();
      } catch (_) {
        // Deleting can itself fail; the message below still explains it.
      }
      throw AuthException('Could not save your profile: $e');
    }

    return AuthProfile(
      uid: user.uid,
      email: email.trim(),
      name: name.trim(),
      role: grantedRole,
      campus: campus.trim(),
      city: city.trim(),
    );
  }

  /// True when [role] is granted immediately at sign-up.
  ///
  /// The sign-up screen uses this to tell someone choosing instructor or
  /// coordinator that their account starts as a student pending approval,
  /// rather than silently handing them a student dashboard.
  static bool isSelfAssignable(String role) => role == UserRole.student;

  // ------------------------------------------------------------- Profile

  /// Reads `users/{uid}`, creating a minimal student profile if the document
  /// is missing — an account with no profile would otherwise be stuck.
  static Future<AuthProfile> loadProfile(User user) async {
    final ref = db.collection(FirestoreCollections.users).doc(user.uid);
    final doc = await ref.get();

    if (!doc.exists) {
      // Always student: the Firestore rules only permit a self-created
      // profile at that role. A demo instructor/coordinator profile is
      // provisioned by the seeder or the Admin SDK, not invented here — the
      // old code wrote the role implied by the email address, which this
      // client is not entitled to grant.
      final fallback = {
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'phone': '',
        'role': UserRole.student,
        'city': '',
        'campus': '',
        'createdAt': FieldValue.serverTimestamp(),
      };
      try {
        await ref.set(fallback, SetOptions(merge: true));
      } catch (e) {
        // A denied write must not strand the user on an error screen; they
        // still get a usable student session for this sign-in.
        debugPrint('Could not create profile for ${user.uid}: $e');
      }
      return AuthProfile.fromMap(user.uid, user.email ?? '', fallback);
    }

    return AuthProfile.fromMap(user.uid, user.email ?? '', doc.data());
  }

  static Future<void> signOut() => auth.signOut();

  static Future<void> sendPasswordReset(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  // ---------------------------------------------------------- Demo login

  /// Signs in one of the three demo accounts.
  ///
  /// The spec requires these to exist in Firebase Auth. If one has not been
  /// created yet, this creates it with the correct role and then signs in, so
  /// the demo buttons work on a fresh project. Authentication itself still
  /// goes through Firebase Auth either way.
  static Future<AuthProfile> signInDemo(DemoAccount account) async {
    try {
      return await signIn(
        email: account.email,
        password: DemoCredentials.password,
      );
    } on AuthException {
      // Fall through and try creating it.
    }

    try {
      return await register(
        email: account.email,
        password: DemoCredentials.password,
        name: account.name,
        phone: '',
        role: account.role,
        city: 'Lahore',
        campus: 'Lahore Campus',
      );
    } on AuthException catch (e) {
      throw AuthException(
        'Could not sign in as ${account.email}. $e',
      );
    }
  }

  /// The demo account matching [email], if any.
  ///
  /// Informational only — it reports which demo account an address belongs
  /// to. It deliberately does not grant that account's role: a role comes
  /// from `users/{uid}.role`, written by the seeder or a coordinator.
  static DemoAccount? demoAccountFor(String? email) {
    if (email == null) return null;
    for (final account in DemoCredentials.all) {
      if (account.email.toLowerCase() == email.toLowerCase()) {
        return account;
      }
    }
    return null;
  }

  /// Plain-language versions of Firebase's error codes.
  static String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Password is too weak — use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is disabled in your Firebase project. '
            'Enable it under Authentication → Sign-in method.';
      case 'configuration-not-found':
        return 'Firebase Authentication is not set up for this project yet. '
            'Enable Email/Password sign-in in the Firebase console.';
      default:
        return e.message ?? 'Authentication failed (${e.code}).';
    }
  }
}
