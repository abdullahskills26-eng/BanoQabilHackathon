import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Colour + icon pairing for one status value.
class StatusStyle {
  final Color fg;
  final Color bg;
  final IconData icon;

  const StatusStyle(this.fg, this.bg, this.icon);

  /// Maps every status string used across the app to its style.
  ///
  /// Covers the six application statuses, the four submission statuses and
  /// the three attendance statuses; unknown values fall back to neutral.
  static StatusStyle of(String status) {
    switch (status.toLowerCase().replaceAll(' ', '').replaceAll('/', '')) {
      // --- Applications ---
      case 'submitted':
        return const StatusStyle(
            AppColors.info, AppColors.infoSoft, Icons.send_rounded);
      case 'underreview':
        return const StatusStyle(
            AppColors.warning, AppColors.warningSoft, Icons.hourglass_top);
      case 'interviewtest':
        return const StatusStyle(
            AppColors.purple, AppColors.purpleSoft, Icons.record_voice_over);
      case 'accepted':
        return const StatusStyle(
            AppColors.success, AppColors.successSoft, Icons.check_circle);
      case 'waitinglist':
        return const StatusStyle(
            AppColors.warning, AppColors.warningSoft, Icons.pending_actions);
      case 'rejected':
        return const StatusStyle(
            AppColors.error, AppColors.errorSoft, Icons.cancel);

      // --- Submissions ---
      case 'pending':
        return const StatusStyle(
            AppColors.warning, AppColors.warningSoft, Icons.schedule);
      case 'late':
        return const StatusStyle(
            AppColors.error, AppColors.errorSoft, Icons.running_with_errors);
      case 'marked':
        return const StatusStyle(
            AppColors.success, AppColors.successSoft, Icons.verified);

      // --- Attendance ---
      case 'present':
        return const StatusStyle(
            AppColors.success, AppColors.successSoft, Icons.check_circle);
      case 'absent':
        return const StatusStyle(
            AppColors.error, AppColors.errorSoft, Icons.cancel);
      case 'leave':
        return const StatusStyle(
            AppColors.info, AppColors.infoSoft, Icons.event_busy);

      default:
        return const StatusStyle(
            AppColors.textSecondary, AppColors.fieldFill, Icons.info_outline);
    }
  }
}

/// Pill-shaped status badge.
class CustomChip extends StatelessWidget {
  final String label;
  final bool showIcon;
  final bool dense;

  const CustomChip({
    super.key,
    required this.label,
    this.showIcon = true,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = StatusStyle.of(label);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 10 : 12,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: isDark ? style.fg.withValues(alpha: 0.18) : style.bg,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
        border: Border.all(color: style.fg.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(style.icon, size: dense ? 12 : 14, color: style.fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: style.fg,
              fontWeight: FontWeight.w700,
              fontSize: dense ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
