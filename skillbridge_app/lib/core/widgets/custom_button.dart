import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

enum ButtonVariant { primary, secondary, outlined }

/// Pill button with three variants and a built-in loading spinner.
///
/// While [isLoading] is true the button is disabled and shows a spinner in
/// place of its icon, so callers never need to manage that themselves.
class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonVariant variant;
  final bool isLoading;
  final bool expand;

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.isLoading = false,
    this.expand = false,
  });

  const CustomButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = false,
  }) : variant = ButtonVariant.secondary;

  const CustomButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = false,
  }) : variant = ButtonVariant.outlined;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;

    final spinnerColor = variant == ButtonVariant.secondary ||
            variant == ButtonVariant.outlined
        ? AppColors.primary
        : Colors.white;

    final leading = isLoading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2.2, color: spinnerColor),
          )
        : (icon != null ? Icon(icon, size: 19) : null);

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[leading, const SizedBox(width: 10)],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );

    final Widget button;
    switch (variant) {
      case ButtonVariant.primary:
        button = FilledButton(
          onPressed: effectiveOnPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: content,
        );
        break;
      case ButtonVariant.secondary:
        button = FilledButton(
          onPressed: effectiveOnPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: AppColors.primary,
          ),
          child: content,
        );
        break;
      case ButtonVariant.outlined:
        button = OutlinedButton(
          onPressed: effectiveOnPressed,
          child: content,
        );
        break;
    }

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
