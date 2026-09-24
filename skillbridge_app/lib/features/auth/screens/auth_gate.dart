import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/state_renderers.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../services/auth_service.dart';
import '../../coordinator/coordinator_shell.dart';
import '../../instructor/dashboard/instructor_shell.dart';
import '../../student/student_shell.dart';
import 'login_screen.dart';

/// The single entry point into the app.
///
/// Role-based access is enforced here rather than in each dashboard: the
/// shells are never constructed until the signed-in user's role has been read
/// from `users/{uid}`, and each role can only ever reach its own shell. There
/// is no route that lets a student open the instructor dashboard, because
/// nothing else in the app constructs one.
class AuthGate extends StatelessWidget {
  final bool firebaseReady;
  final String? firebaseError;

  const AuthGate({
    super.key,
    this.firebaseReady = true,
    this.firebaseError,
  });

  @override
  Widget build(BuildContext context) {
    // Without Firebase there is no auth at all — show the login screen with
    // its configuration warning rather than an infinite spinner.
    if (!firebaseReady) {
      return LoginScreen(
        firebaseReady: false,
        firebaseError: firebaseError,
      );
    }

    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: LoadingState(message: 'Checking your session…'),
          );
        }

        final user = snapshot.data;
        if (user == null) return const LoginScreen();

        return _RoleRouter(user: user);
      },
    );
  }
}

/// Reads the role for a signed-in user and hands them the matching shell.
class _RoleRouter extends StatefulWidget {
  final User user;
  const _RoleRouter({required this.user});

  @override
  State<_RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<_RoleRouter> {
  late Future<AuthProfile> _future;

  @override
  void initState() {
    super.initState();
    _future = AuthService.loadProfile(widget.user);
  }

  @override
  void didUpdateWidget(_RoleRouter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different account signed in — re-read the role.
    if (oldWidget.user.uid != widget.user.uid) {
      _future = AuthService.loadProfile(widget.user);
    }
  }

  void _reload() =>
      setState(() => _future = AuthService.loadProfile(widget.user));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthProfile>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: LoadingState(message: 'Loading your dashboard…'),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ErrorRetry(
                      title: 'Could not load your profile',
                      message: snapshot.error.toString(),
                      onRetry: _reload,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: CustomButton.outlined(
                      label: 'Sign out',
                      icon: Icons.logout,
                      onPressed: AuthService.signOut,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final profile = snapshot.data!;

        switch (profile.role) {
          case UserRole.instructor:
            return const InstructorShell();
          case UserRole.coordinator:
            return const CoordinatorShell();
          case UserRole.student:
            return const StudentShell();
          default:
            // A role we do not recognise — never guess, since guessing would
            // hand someone a dashboard they are not entitled to.
            return _UnknownRoleScreen(profile: profile);
        }
      },
    );
  }
}

class _UnknownRoleScreen extends StatelessWidget {
  final AuthProfile profile;
  const _UnknownRoleScreen({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.help_outline,
                        size: 40, color: AppColors.warning),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No dashboard for this account',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your account has the role "${profile.role}", which does '
                    'not match student, instructor or coordinator. Ask a '
                    'campus coordinator to correct it.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 22),
                  CustomButton.outlined(
                    label: 'Sign out',
                    icon: Icons.logout,
                    onPressed: AuthService.signOut,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
