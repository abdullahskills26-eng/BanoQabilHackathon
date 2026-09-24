import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../services/seed_service.dart';

/// Runs the Firestore demo seeder with a progress dialog.
class SeedDemoButton extends StatefulWidget {
  /// Called after a successful seed so the dashboard can refresh.
  final VoidCallback? onSeeded;

  const SeedDemoButton({super.key, this.onSeeded});

  @override
  State<SeedDemoButton> createState() => _SeedDemoButtonState();
}

class _SeedDemoButtonState extends State<SeedDemoButton> {
  bool _seeding = false;

  Future<void> _run() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seed demo data?'),
        content: const Text(
          'This writes the demo dataset into Firestore: 6 courses, '
          '8 campuses, batch FL-2026-01 with 12 students, 4 assignments and '
          '5 applications.\n\n'
          'Documents use fixed ids, so running it again overwrites the '
          'previous demo data rather than duplicating it. Any edits you made '
          'to those same documents will be replaced.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Seed'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _seeding = true);

    final progress = ValueNotifier<({String step, double fraction})>(
        (step: 'Starting', fraction: 0));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProgressDialog(progress: progress),
    );

    try {
      await SeedService.seed(
        onProgress: (step, fraction) =>
            progress.value = (step: step, fraction: fraction),
      );

      if (!mounted) return;
      Navigator.pop(context); // close progress dialog

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle,
              color: AppColors.success, size: 40),
          title: const Text('Demo data seeded'),
          content: const Text(
            '6 courses · 8 campuses · batch FL-2026-01 with 12 students · '
            '4 assignments · 5 applications covering every status.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      );

      widget.onSeeded?.call();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close progress dialog
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.error_outline,
              color: AppColors.error, size: 40),
          title: const Text('Seeding failed'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } finally {
      progress.dispose();
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomButton.secondary(
      label: 'Seed Demo Data',
      icon: Icons.storage_rounded,
      isLoading: _seeding,
      onPressed: _run,
    );
  }
}

class _ProgressDialog extends StatelessWidget {
  final ValueNotifier<({String step, double fraction})> progress;

  const _ProgressDialog({required this.progress});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seeding demo data'),
      content: ValueListenableBuilder<({String step, double fraction})>(
        valueListenable: progress,
        builder: (context, value, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value.step, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: value.fraction,
                minHeight: 8,
                backgroundColor: AppColors.fieldFill,
              ),
            ),
            const SizedBox(height: 8),
            Text('${(value.fraction * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
