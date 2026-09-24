import 'package:flutter/material.dart';

import '../../../core/constants/demo_credentials.dart';
import '../../../core/utils/state_renderers.dart';
import '../../../core/widgets/account_menu.dart';
import '../../shared/profile/profile_screen.dart';
import '../../../models/batch_model.dart';
import '../../../services/firestore_service.dart';
import '../assignments/create_assignment_screen.dart';
import '../assignments/grade_submissions_screen.dart';
import '../attendance/mark_attendance_screen.dart';
import 'batch_progress_screen.dart';
import 'instructor_home_screen.dart';
import 'post_notice_screen.dart';

/// Navigation host for the instructor role (Screens 10–11).
///
/// Batches are loaded once here and handed to the screens that need them,
/// so each tab does not re-query the roster.
class InstructorShell extends StatefulWidget {
  const InstructorShell({super.key});

  @override
  State<InstructorShell> createState() => _InstructorShellState();
}

class _InstructorShellState extends State<InstructorShell> {
  int _index = 0;
  late Future<List<BatchModel>> _batchesFuture;

  static const _destinations = [
    (Icons.space_dashboard_outlined, Icons.space_dashboard, 'Home'),
    (Icons.fact_check_outlined, Icons.fact_check, 'Attendance'),
    (Icons.post_add_outlined, Icons.post_add, 'Set work'),
    (Icons.grading_outlined, Icons.grading, 'Grading'),
    (Icons.campaign_outlined, Icons.campaign, 'Notices'),
    (Icons.trending_up_outlined, Icons.trending_up, 'Progress'),
    (Icons.person_outline, Icons.person, 'Profile'),
  ];

  static const int _profileIndex = 6;

  void _openProfile() => setState(() => _index = _profileIndex);

  @override
  void initState() {
    super.initState();
    _batchesFuture = _loadBatches();
  }

  Future<List<BatchModel>> _loadBatches() =>
      FirebaseService.fetchInstructorBatches(
        instructorId: FirebaseService.auth.currentUser?.uid ?? '',
        instructorName: DemoCredentials.instructor.name,
      );

  void _reload() => setState(() => _batchesFuture = _loadBatches());

  Widget _screenAt(int i, List<BatchModel> batches) {
    switch (i) {
      case 0:
        return const InstructorHomeScreen();
      case 1:
        return MarkAttendanceScreen(batches: batches);
      case 2:
        return CreateAssignmentScreen(batches: batches);
      case 3:
        return GradeSubmissionsScreen(batches: batches);
      case 4:
        return PostNoticeScreen(batches: batches);
      case 6:
        return const ProfileScreen();
      default:
        return batches.isEmpty
            ? const EmptyState(
                message: 'No batch assigned',
                subtitle:
                    'Batch progress appears once a coordinator assigns you '
                    'to a batch.',
                icon: Icons.groups_outlined,
              )
            : BatchProgressScreen(batch: batches.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BatchModel>>(
      future: _batchesFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: LoadingState(message: 'Loading batches…'));
        }
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Instructor')),
            body: ErrorRetry(
              message: snap.error.toString(),
              onRetry: _reload,
            ),
          );
        }

        final batches = snap.data ?? const <BatchModel>[];

        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;

            // Each destination supplies its own Scaffold and AppBar; the
            // shell only wraps them in navigation chrome.
            final body = AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(
                key: ValueKey(_index),
                child: _screenAt(_index, batches),
              ),
            );

            if (wide) {
              return Scaffold(
                body: Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _index,
                      onDestinationSelected: (i) =>
                          setState(() => _index = i),
                      labelType: NavigationRailLabelType.all,
                      // Sign-out is always one tap away, on every dashboard.
                      trailing: Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: AccountMenu(
                              roleLabel: 'Instructor',
                              showLabel: true,
                              onOpenProfile: _openProfile,
                            ),
                          ),
                        ),
                      ),
                      destinations: _destinations
                          .map((d) => NavigationRailDestination(
                                icon: Icon(d.$1),
                                selectedIcon: Icon(d.$2),
                                label: Text(d.$3),
                              ))
                          .toList(),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                ),
              );
            }

            return Scaffold(
              body: body,
              bottomNavigationBar: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                destinations: _destinations
                    .map((d) => NavigationDestination(
                          icon: Icon(d.$1),
                          selectedIcon: Icon(d.$2),
                          label: d.$3,
                        ))
                    .toList(),
              ),
            );
          },
        );
      },
    );
  }
}
