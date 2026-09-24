import 'package:flutter/material.dart';

import '../../core/widgets/account_menu.dart';
import '../shared/profile/profile_screen.dart';
import 'assignments/assignments_screen.dart';
import 'courses/application_status_screen.dart';
import 'courses/course_list_screen.dart';
import 'home/student_home_screen.dart';
import 'progress/progress_checklist_screen.dart';
import 'timetable/timetable_attendance_screen.dart';

/// Navigation host for the student role (Screens 2–9).
///
/// NavigationRail at >= 900px, NavigationBar below that.
class StudentShell extends StatefulWidget {
  const StudentShell({super.key});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _index = 0;

  static const _destinations = [
    (Icons.space_dashboard_outlined, Icons.space_dashboard, 'Home'),
    (Icons.menu_book_outlined, Icons.menu_book, 'Courses'),
    (Icons.description_outlined, Icons.description, 'Applications'),
    (Icons.calendar_month_outlined, Icons.calendar_month, 'Timetable'),
    (Icons.assignment_outlined, Icons.assignment, 'Assignments'),
    (Icons.trending_up_outlined, Icons.trending_up, 'Progress'),
    (Icons.person_outline, Icons.person, 'Profile'),
  ];

  static const int _profileIndex = 6;

  Widget _screenAt(int i) {
    switch (i) {
      case 0:
        return const StudentHomeScreen();
      case 1:
        return const CourseListScreen();
      case 2:
        return const ApplicationStatusScreen();
      case 3:
        return const TimetableAttendanceScreen();
      case 4:
        return const AssignmentsScreen();
      case 5:
        return const ProgressChecklistScreen();
      default:
        return const ProfileScreen();
    }
  }

  void _openProfile() => setState(() => _index = _profileIndex);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        // Each destination is a full Scaffold with its own AppBar, so the
        // shell only supplies navigation chrome around it.
        final body = AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
            key: ValueKey(_index),
            child: _screenAt(_index),
          ),
        );

        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelType: NavigationRailLabelType.all,
                  // Sign-out is always one tap away, on every dashboard.
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: AccountMenu(
                          roleLabel: 'Student',
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
  }
}
