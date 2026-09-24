import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../services/auth_service.dart';

/// Role chooser on the sign-up form.
///
/// The role picked here is written to `users/{uid}.role` and is what decides
/// which dashboard the account can open — so it is a selection, not a hint.
class RolePicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const RolePicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const _options = [
    (
      UserRole.student,
      Icons.school_rounded,
      'Student',
      'Apply, attend and submit work',
      AppColors.primary,
    ),
    (
      UserRole.instructor,
      Icons.co_present_rounded,
      'Instructor',
      'Mark attendance and grade work',
      AppColors.secondary,
    ),
    (
      UserRole.coordinator,
      Icons.admin_panel_settings_rounded,
      'Coordinator',
      'Manage applications and batches',
      AppColors.warning,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('I am joining as',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 10),
        ..._options.map((o) {
          final isSelected = selected == o.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: isSelected
                  ? o.$5.withValues(alpha: 0.08)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(AppColors.radiusField),
              child: InkWell(
                onTap: () => onChanged(o.$1),
                borderRadius: BorderRadius.circular(AppColors.radiusField),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(AppColors.radiusField),
                    border: Border.all(
                      color: isSelected ? o.$5 : AppColors.border,
                      width: isSelected ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: o.$5.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(o.$2, color: o.$5, size: 19),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              o.$3,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: isSelected
                                    ? o.$5
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(o.$4,
                                style:
                                    Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      AnimatedScale(
                        scale: isSelected ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Icon(Icons.check_circle,
                            color: o.$5, size: 21),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
