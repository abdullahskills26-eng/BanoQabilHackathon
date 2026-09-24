import 'package:flutter/material.dart';

import '../../core/widgets/account_menu.dart';
import '../shared/notifications/notifications_screen.dart';
import '../shared/profile/profile_screen.dart';
import 'applications/application_inbox_screen.dart';
import 'batches/batch_management_screen.dart';
import 'reports/coordinator_reports_screen.dart';
import 'reports/post_campus_notice_screen.dart';

/// Navigation host for the coordinator role (Screens 12–13).
class CoordinatorShell extends StatefulWidget {
  const CoordinatorShell({super.key});

  @override
  State<CoordinatorShell> createState() => _CoordinatorShellState();
}

class _CoordinatorShellState extends State<CoordinatorShell> {
  int _index = 0;

  static const _destinations = [
    (Icons.insights_outlined, Icons.insights, 'Reports'),
    (Icons.inbox_outlined, Icons.inbox, 'Applications'),
    (Icons.groups_outlined, Icons.groups, 'Batches'),
    (Icons.campaign_outlined, Icons.campaign, 'Notices'),
    (Icons.notifications_outlined, Icons.notifications, 'Alerts'),
    (Icons.person_outline, Icons.person, 'Profile'),
  ];

  Widget _screenAt(int i) {
    switch (i) {
      case 0:
        return const CoordinatorReportsScreen();
      case 1:
        return const ApplicationInboxScreen();
      case 2:
        return const BatchManagementScreen();
      case 3:
        return const PostCampusNoticeScreen();
      case 4:
        return const NotificationsScreen();
      default:
        return const ProfileScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        // Each destination supplies its own Scaffold and AppBar.
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
                          roleLabel: 'Coordinator',
                          showLabel: true,
                          onOpenProfile: () => setState(() => _index = 5),
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
