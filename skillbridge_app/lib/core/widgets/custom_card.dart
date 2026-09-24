import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Reusable surface card: white background, 1px neutral outline, soft shadow.
///
/// Pass [onTap] to get ripple feedback and a pointer cursor.
class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  const CustomCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.onTap,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = color ?? (isDark ? AppColors.darkSurface : AppColors.surface);
    final line =
        borderColor ?? (isDark ? AppColors.darkBorder : AppColors.border);
    final radius = BorderRadius.circular(AppColors.radiusCard);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: Border.all(color: line),
        boxShadow: isDark ? null : AppColors.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Card with a tinted background and matching outline — for highlight panels
/// such as the dashboard welcome banner or a status callout.
class AccentCard extends StatelessWidget {
  final Widget child;
  final Color accent;
  final Color accentSoft;
  final EdgeInsetsGeometry padding;

  const AccentCard({
    super.key,
    required this.child,
    required this.accent,
    required this.accentSoft,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? accent.withValues(alpha: 0.14) : accentSoft,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: child,
    );
  }
}

/// Label + value pair used inside stat rows.
class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
