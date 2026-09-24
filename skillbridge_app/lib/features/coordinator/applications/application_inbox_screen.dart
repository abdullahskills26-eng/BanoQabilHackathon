import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/state_renderers.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/custom_chip.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../../../models/application_model.dart';
import '../../../services/firestore_service.dart';

/// Screen 12 — application inbox and status review.
class ApplicationInboxScreen extends StatefulWidget {
  const ApplicationInboxScreen({super.key});

  @override
  State<ApplicationInboxScreen> createState() =>
      _ApplicationInboxScreenState();
}

class _ApplicationInboxScreenState extends State<ApplicationInboxScreen> {
  String _filter = 'All';

  static const _filters = ['All', ...ApplicationStatus.all];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Application Inbox')),
      body: SafeArea(
        child: StreamBuilder<List<ApplicationModel>>(
          stream: FirebaseService.watchAllApplications(),
          builder: (context, snap) {
            if (snap.hasError) {
              return ErrorRetry(
                message: snap.error.toString(),
                onRetry: () => setState(() {}),
              );
            }
            if (!snap.hasData) {
              return const ShimmerListSkeleton(itemCount: 4);
            }

            final all = snap.data!;
            if (all.isEmpty) {
              return const EmptyState(
                message: 'No applications yet',
                subtitle:
                    'Student applications land here as soon as they are '
                    'submitted. Seed demo data to see examples.',
                icon: Icons.inbox_outlined,
              );
            }

            final shown = _filter == 'All'
                ? all
                : all.where((a) => a.status == _filter).toList();

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _filters.map((f) {
                            final count = f == 'All'
                                ? all.length
                                : all.where((a) => a.status == f).length;
                            final selected = _filter == f;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text('$f ($count)'),
                                selected: selected,
                                onSelected: (_) =>
                                    setState(() => _filter = f),
                                selectedColor: AppColors.primary,
                                backgroundColor: AppColors.surface,
                                side: BorderSide(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                                labelStyle: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: shown.isEmpty
                          ? EmptyState(
                              message: 'Nothing under "$_filter"',
                              subtitle:
                                  'No applications currently have this status.',
                              icon: Icons.filter_alt_outlined,
                              actionLabel: 'Show all',
                              onAction: () =>
                                  setState(() => _filter = 'All'),
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 8, 20, 24),
                              itemCount: shown.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, index) =>
                                  _ApplicationCard(
                                      application: shown[index]),
                            ),
                    ),
                  ],
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
      onTap: () => showDialog(
        context: context,
        builder: (_) => _ApplicationDetailDialog(application: application),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  application.fullName.isNotEmpty
                      ? application.fullName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.fullName.isEmpty
                          ? 'Unnamed applicant'
                          : application.fullName,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontSize: 15.5),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${application.courseName} · '
                      '${application.campusName}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              CustomChip(label: application.status),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Meta(icon: Icons.badge_outlined, text: application.cnic),
              _Meta(
                  icon: Icons.school_outlined, text: application.education),
              _Meta(
                  icon: Icons.location_city_outlined,
                  text: application.city),
            ],
          ),
          if (application.isRejected &&
              application.rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: BorderRadius.circular(AppColors.radiusField),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 15, color: AppColors.error),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(application.rejectionReason,
                        style: const TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Review',
                    style: Theme.of(context).textTheme.bodySmall),
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 5),
        Text(text.isEmpty ? '—' : text,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Full detail plus Accept / Wait List / Reject.
class _ApplicationDetailDialog extends StatefulWidget {
  final ApplicationModel application;
  const _ApplicationDetailDialog({required this.application});

  @override
  State<_ApplicationDetailDialog> createState() =>
      _ApplicationDetailDialogState();
}

class _ApplicationDetailDialogState
    extends State<_ApplicationDetailDialog> {
  bool _saving = false;
  String? _error;

  Future<void> _update(String status) async {
    String reason = '';

    if (status == ApplicationStatus.rejected) {
      reason = await _askRejectionReason() ?? '';
      if (reason.isEmpty) return; // cancelled or left blank
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await FirebaseService.updateApplicationStatus(
        applicationId: widget.application.applicationId,
        status: status,
        rejectionReason: reason,
        applicantUid: widget.application.uid,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Application marked "$status".')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _askRejectionReason() async {
    final controller = TextEditingController(
        text: 'Course seats are currently full.');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reason for rejection'),
        content: SizedBox(
          width: 420,
          child: CustomTextField(
            controller: controller,
            label: 'Reason',
            hint: 'Shown to the applicant',
            maxLines: 3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx, text);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.application;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(a.fullName.isEmpty ? 'Application' : a.fullName),
          ),
          CustomChip(label: a.status, dense: true),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(label: 'CNIC', value: a.cnic),
              _DetailRow(label: 'Education', value: a.education),
              _DetailRow(label: 'City', value: a.city),
              _DetailRow(label: 'Course', value: a.courseName),
              _DetailRow(label: 'Preferred campus', value: a.campusName),
              const SizedBox(height: 12),
              Text('Motivation',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius:
                      BorderRadius.circular(AppColors.radiusField),
                ),
                child: Text(
                  a.motivation.isEmpty ? 'Not provided.' : a.motivation,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              if (a.isRejected && a.rejectionReason.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorSoft,
                    borderRadius:
                        BorderRadius.circular(AppColors.radiusField),
                  ),
                  child: Text('Rejected: ${a.rejectionReason}',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.error)),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        CustomButton.outlined(
          label: 'Wait List',
          icon: Icons.pending_actions,
          isLoading: _saving,
          onPressed: () => _update(ApplicationStatus.waitingList),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed:
              _saving ? null : () => _update(ApplicationStatus.rejected),
          icon: const Icon(Icons.close, size: 18),
          label: const Text('Reject'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.success),
          onPressed:
              _saving ? null : () => _update(ApplicationStatus.accepted),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Accept'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child:
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(value.isEmpty ? '—' : value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}
