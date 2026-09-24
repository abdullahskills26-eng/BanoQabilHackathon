import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../constants/app_colors.dart';

/// Avatar button with the signed-in user's details, a link to their profile
/// and a sign-out action.
///
/// Lives in every dashboard shell so signing out is always one tap away,
/// rather than buried inside the profile screen.
class AccountMenu extends StatelessWidget {
  /// Human-readable role label, e.g. "Student". Each shell knows its own.
  final String roleLabel;

  /// Opens the profile tab within the current shell.
  final VoidCallback? onOpenProfile;

  /// Rail layouts stack the label under the avatar; app bars do not.
  final bool showLabel;

  const AccountMenu({
    super.key,
    required this.roleLabel,
    this.onOpenProfile,
    this.showLabel = false,
  });

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.logout, color: AppColors.error, size: 32),
        title: const Text('Sign out?'),
        content: const Text(
          'You will be returned to the sign-in screen. Any unsaved changes '
          'on this page will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Pop back to the shell root first: the auth gate swaps in the login
    // screen as soon as the stream fires, and any pushed detail route on top
    // would otherwise be left orphaned above it.
    if (context.mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
    await AuthService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final name = (user?.displayName?.isNotEmpty ?? false)
        ? user!.displayName!
        : (user?.email?.split('@').first ?? 'Account');
    final email = user?.email ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    final avatar = CircleAvatar(
      radius: showLabel ? 18 : 16,
      backgroundColor: showLabel
          ? AppColors.secondary
          : AppColors.primary.withValues(alpha: 0.12),
      child: Text(
        initial,
        style: TextStyle(
          color: showLabel ? AppColors.primary : AppColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: showLabel ? 15 : 13,
        ),
      ),
    );

    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 8),
      position: PopupMenuPosition.under,
      onSelected: (value) {
        if (value == 'profile') {
          onOpenProfile?.call();
        } else if (value == 'signout') {
          _confirmSignOut(context);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              if (email.isNotEmpty)
                Text(email,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                ),
                child: Text(
                  roleLabel.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (onOpenProfile != null)
          const PopupMenuItem<String>(
            value: 'profile',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.person_outline, size: 20),
              title: Text('My profile'),
            ),
          ),
        const PopupMenuItem<String>(
          value: 'signout',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout, size: 20, color: AppColors.error),
            title: Text('Sign out',
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: showLabel ? 0 : 10, vertical: showLabel ? 10 : 0),
        child: showLabel
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  avatar,
                  const SizedBox(height: 4),
                  const Text(
                    'Account',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70),
                  ),
                ],
              )
            : avatar,
      ),
    );
  }
}
