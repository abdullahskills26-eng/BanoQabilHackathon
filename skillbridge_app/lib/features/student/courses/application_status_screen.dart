import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/state_renderers.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/custom_chip.dart';
import '../../../models/application_model.dart';
import '../../../services/firestore_service.dart';

/// Screen 6 — my application status.
class ApplicationStatusScreen extends StatelessWidget {
  const ApplicationStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseService.currentUid;

    return Scaffold(
      appBar: AppBar(title: const Text('My Applications')),
      body: SafeArea(
        child: StreamBuilder<List<ApplicationModel>>(
          stream: FirebaseService.watchApplications(uid),
          builder: (context, snap) {
            if (snap.hasError) {
              return ErrorRetry(
                message: snap.error.toString(),
                // A stream rebuilds itself; popping back and re-entering is
                // the retry.
                onRetry: () => (context as Element).markNeedsBuild(),
              );
            }
            if (!snap.hasData) {
              return const ShimmerListSkeleton(itemCount: 2);
            }

            final applications = snap.data!;
            if (applications.isEmpty) {
              return const EmptyState(
                message: 'No applications yet',
                subtitle:
                    'Browse the course catalog and apply — your status will '
                    'appear here.',
                icon: Icons.description_outlined,
              );
            }

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: applications.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) =>
                      _ApplicationCard(application: applications[index]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final ApplicationModel application;
  const _ApplicationCard({required this.application});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.courseName.isEmpty
                          ? 'Course application'
                          : application.courseName,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      application.campusName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              CustomChip(label: application.status),
            ],
          ),
          const SizedBox(height: 20),
          _StatusTracker(application: application),
          if (application.isRejected &&
              application.rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: BorderRadius.circular(AppColors.radiusField),
                border:
                    Border.all(color: AppColors.error.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.info_outline,
                          size: 16, color: AppColors.error),
                      SizedBox(width: 7),
                      Text('Reason for rejection',
                          style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(application.rejectionReason,
                      style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
          if (application.isWaitingList) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(AppColors.radiusField),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.pending_actions,
                      size: 16, color: AppColors.warning),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'You are on the waiting list. We will contact you if a '
                      'seat becomes available.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Horizontal step tracker: Submitted → Under Review → Interview/Test →
/// Accepted, with terminal statuses colouring the final node.
class _StatusTracker extends StatelessWidget {
  final ApplicationModel application;
  const _StatusTracker({required this.application});

  @override
  Widget build(BuildContext context) {
    final steps = ApplicationStatus.flow;
    final current = application.stepIndex;
    final isRejected = application.isRejected;
    final isWaiting = application.isWaitingList;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              Expanded(
                child: _StepNode(
                  label: _labelFor(i, steps, isRejected, isWaiting),
                  isDone: i < current,
                  isCurrent: i == current,
                  color: _colorFor(i, current, isRejected, isWaiting),
                ),
              ),
              if (i < steps.length - 1)
                Container(
                  width: 18,
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 22),
                  color: i < current
                      ? AppColors.success
                      : AppColors.border,
                ),
            ],
          ],
        );
      },
    );
  }

  String _labelFor(
      int i, List<String> steps, bool isRejected, bool isWaiting) {
    final isFinal = i == steps.length - 1;
    if (isFinal && isRejected) return ApplicationStatus.rejected;
    if (isFinal && isWaiting) return ApplicationStatus.waitingList;
    return steps[i];
  }

  Color _colorFor(int i, int current, bool isRejected, bool isWaiting) {
    if (i > current) return AppColors.textSecondary;
    final isFinal = i == ApplicationStatus.flow.length - 1;
    if (i == current && isFinal && isRejected) return AppColors.error;
    if (i == current && isFinal && isWaiting) return AppColors.warning;
    return AppColors.success;
  }
}

class _StepNode extends StatelessWidget {
  final String label;
  final bool isDone;
  final bool isCurrent;
  final Color color;

  const _StepNode({
    required this.label,
    required this.isDone,
    required this.isCurrent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final active = isDone || isCurrent;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: isCurrent ? 30 : 24,
          height: isCurrent ? 30 : 24,
          decoration: BoxDecoration(
            color: active ? color : AppColors.fieldFill,
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? color : AppColors.border,
              width: 2,
            ),
          ),
          child: Icon(
            isDone
                ? Icons.check
                : (isCurrent ? Icons.radio_button_checked : null),
            size: 14,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 30,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.25,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? color : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
