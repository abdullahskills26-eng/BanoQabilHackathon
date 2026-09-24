import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/state_renderers.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/custom_chip.dart';
import '../../../models/assignment_model.dart';
import '../../../models/submission_model.dart';
import '../../../services/firestore_service.dart';
import 'submit_assignment_screen.dart';

/// Screen 8 — assignments list, filterable by status.
class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

/// One assignment paired with this student's submission (if any).
class _AssignmentEntry {
  final AssignmentModel assignment;
  final SubmissionModel? submission;

  const _AssignmentEntry(this.assignment, this.submission);

  String get status {
    final s = submission;
    if (s == null) {
      return assignment.isOverdue
          ? SubmissionStatus.late
          : SubmissionStatus.pending;
    }
    return s.status;
  }

  bool get canSubmit =>
      status == SubmissionStatus.pending || status == SubmissionStatus.late;
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  late Future<List<_AssignmentEntry>> _future;
  String _filter = 'All';

  static const _filters = [
    'All',
    SubmissionStatus.pending,
    SubmissionStatus.submitted,
    SubmissionStatus.late,
    SubmissionStatus.marked,
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _reload() => setState(() => _future = _load());

  Future<List<_AssignmentEntry>> _load() async {
    final uid = FirebaseService.currentUid;
    final batch = await FirebaseService.fetchStudentBatch(uid);
    final assignments = await FirebaseService.fetchAssignments(
        batchId: batch?['batchId']?.toString());
    final submissions = await FirebaseService.fetchSubmissions(uid);

    final byAssignment = {for (final s in submissions) s.assignmentId: s};
    return assignments
        .map((a) => _AssignmentEntry(a, byAssignment[a.assignmentId]))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assignments')),
      body: SafeArea(
        child: FutureBuilder<List<_AssignmentEntry>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const ShimmerListSkeleton();
            }
            if (snap.hasError) {
              return ErrorRetry(
                  message: snap.error.toString(), onRetry: _reload);
            }

            final all = snap.data!;
            if (all.isEmpty) {
              return const EmptyState(
                message: 'No assignments yet',
                subtitle:
                    'Work set by your instructor will appear here with its '
                    'due date and marks.',
                icon: Icons.assignment_outlined,
              );
            }

            final filtered = _filter == 'All'
                ? all
                : all.where((e) => e.status == _filter).toList();

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _filters.map((f) {
                            final count = f == 'All'
                                ? all.length
                                : all.where((e) => e.status == f).length;
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
                      child: filtered.isEmpty
                          ? EmptyState(
                              message: 'Nothing $_filter',
                              subtitle:
                                  'No assignments match this filter right now.',
                              icon: Icons.filter_alt_outlined,
                              actionLabel: 'Show all',
                              onAction: () =>
                                  setState(() => _filter = 'All'),
                            )
                          : RefreshIndicator(
                              onRefresh: () async => _reload(),
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                    20, 8, 20, 24),
                                itemCount: filtered.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 14),
                                itemBuilder: (context, index) =>
                                    _AssignmentCard(
                                  entry: filtered[index],
                                  onSubmit: () async {
                                    final done = await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            SubmitAssignmentScreen(
                                          assignment:
                                              filtered[index].assignment,
                                          existing:
                                              filtered[index].submission,
                                        ),
                                      ),
                                    );
                                    if (done == true) _reload();
                                  },
                                ),
                              ),
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

class _AssignmentCard extends StatelessWidget {
  final _AssignmentEntry entry;
  final VoidCallback onSubmit;

  const _AssignmentCard({required this.entry, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final a = entry.assignment;
    final s = entry.submission;

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
                    Text(a.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontSize: 16)),
                    if (a.instructions.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(a.instructions,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              CustomChip(label: entry.status),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Meta(
                icon: Icons.event_outlined,
                text: 'Due ${a.formattedDueDate}',
                color: a.isOverdue && entry.canSubmit
                    ? AppColors.error
                    : AppColors.textSecondary,
              ),
              _Meta(
                  icon: Icons.military_tech_outlined,
                  text: '${a.maxMarks} marks'),
              if (s != null && s.isMarked && s.marks != null)
                _Meta(
                  icon: Icons.grade_outlined,
                  text: 'Scored ${s.marks}/${a.maxMarks}',
                  color: AppColors.success,
                ),
            ],
          ),

          // ---- Marks and feedback for evaluated work ----
          if (s != null && s.isMarked) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(AppColors.radiusField),
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified,
                          size: 16, color: AppColors.success),
                      const SizedBox(width: 7),
                      Text(
                        'Marked · ${s.marks ?? 0} / ${a.maxMarks}',
                        style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5),
                      ),
                    ],
                  ),
                  if (s.hasFeedback) ...[
                    const SizedBox(height: 8),
                    Text('Instructor feedback',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 3),
                    Text(s.feedback,
                        style: const TextStyle(fontSize: 13)),
                  ],
                ],
              ),
            ),
          ],

          // ---- Submission receipt ----
          if (s != null && !s.isPending && !s.isMarked) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Submitted ${s.formattedSubmittedAt}'
                    '${s.hasFile ? ' · ${s.fileName}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: entry.canSubmit
                ? CustomButton(
                    label: s == null ? 'Submit work' : 'Resubmit',
                    icon: Icons.upload_file_outlined,
                    onPressed: onSubmit,
                  )
                : CustomButton.outlined(
                    label: s != null && s.isMarked
                        ? 'Graded'
                        : 'Awaiting grading',
                    icon: s != null && s.isMarked
                        ? Icons.verified_outlined
                        : Icons.hourglass_top,
                    onPressed: null,
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
  final Color? color;
  const _Meta({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: c),
        const SizedBox(width: 5),
        Text(text,
            style: TextStyle(
                fontSize: 12.5, color: c, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
