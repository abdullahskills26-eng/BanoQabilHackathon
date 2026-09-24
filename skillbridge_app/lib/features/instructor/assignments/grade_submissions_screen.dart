import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/supabase_config.dart';
import '../../../core/utils/state_renderers.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/custom_chip.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../../../models/assignment_model.dart';
import '../../../models/batch_model.dart';
import '../../../models/submission_model.dart';
import '../../../services/firestore_service.dart';
import '../../../services/supabase_storage_service.dart';

/// Screen 11 (cont.) — grade submissions and leave feedback.
class GradeSubmissionsScreen extends StatefulWidget {
  final List<BatchModel> batches;

  const GradeSubmissionsScreen({super.key, required this.batches});

  @override
  State<GradeSubmissionsScreen> createState() =>
      _GradeSubmissionsScreenState();
}

/// One assignment with its submissions and the batch roster it belongs to.
class _AssignmentBundle {
  final AssignmentModel assignment;
  final List<SubmissionModel> submissions;
  final int enrolled;

  const _AssignmentBundle(this.assignment, this.submissions, this.enrolled);

  int get submittedCount =>
      submissions.where((s) => s.status != SubmissionStatus.pending).length;
  int get markedCount => submissions.where((s) => s.isMarked).length;
  int get pendingCount => enrolled - submittedCount;
}

class _GradeSubmissionsScreenState extends State<GradeSubmissionsScreen> {
  BatchModel? _batch;
  late Future<List<_AssignmentBundle>> _future;

  @override
  void initState() {
    super.initState();
    _batch = widget.batches.isNotEmpty ? widget.batches.first : null;
    _future = _load();
  }

  void _reload() => setState(() => _future = _load());

  Future<List<_AssignmentBundle>> _load() async {
    final batch = _batch;
    if (batch == null) return [];

    final students = await FirebaseService.fetchBatchStudents(batch);
    final assignments =
        await FirebaseService.fetchAssignments(batchId: batch.label);

    final bundles = <_AssignmentBundle>[];
    for (final a in assignments) {
      final subs =
          await FirebaseService.fetchAssignmentSubmissions(a.assignmentId);
      bundles.add(_AssignmentBundle(a, subs, students.length));
    }
    return bundles;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.batches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Grade Submissions')),
        body: const EmptyState(
          message: 'No batches assigned',
          icon: Icons.groups_outlined,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Grade Submissions')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: CustomDropdown<BatchModel>(
                    value: _batch,
                    label: 'Batch',
                    prefixIcon: Icons.groups,
                    items: widget.batches
                        .map((b) => DropdownMenuItem(
                            value: b,
                            child: Text('${b.label} · ${b.courseName}')))
                        .toList(),
                    onChanged: (b) {
                      setState(() => _batch = b);
                      _reload();
                    },
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<_AssignmentBundle>>(
                    future: _future,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const ShimmerListSkeleton(itemCount: 3);
                      }
                      if (snap.hasError) {
                        return ErrorRetry(
                            message: snap.error.toString(),
                            onRetry: _reload);
                      }

                      final bundles = snap.data!;
                      if (bundles.isEmpty) {
                        return const EmptyState(
                          message: 'No assignments set yet',
                          subtitle:
                              'Create an assignment or quiz and submissions '
                              'will show up here for grading.',
                          icon: Icons.assignment_outlined,
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async => _reload(),
                        child: ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          itemCount: bundles.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) =>
                              _AssignmentBundleCard(
                            bundle: bundles[index],
                            onGraded: _reload,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssignmentBundleCard extends StatelessWidget {
  final _AssignmentBundle bundle;
  final VoidCallback onGraded;

  const _AssignmentBundleCard(
      {required this.bundle, required this.onGraded});

  @override
  Widget build(BuildContext context) {
    final a = bundle.assignment;

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
                    const SizedBox(height: 3),
                    Text(
                      '${a.type} · ${a.maxMarks} marks · '
                      'due ${a.formattedDueDate}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                ),
                child: Text(
                  'Submitted: ${bundle.submittedCount}/${bundle.enrolled}',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Pill(
                  label: 'Marked ${bundle.markedCount}',
                  color: AppColors.success),
              const SizedBox(width: 8),
              _Pill(
                  label: 'Not submitted ${bundle.pendingCount}',
                  color: AppColors.warning),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 8),
          if (bundle.submissions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.inbox_outlined,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('No submissions yet.',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ],
              ),
            )
          else
            ...bundle.submissions.map(
              (s) => _SubmissionRow(
                submission: s,
                maxMarks: a.maxMarks,
                onGraded: onGraded,
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 11.5)),
    );
  }
}

class _SubmissionRow extends StatelessWidget {
  final SubmissionModel submission;
  final int maxMarks;
  final VoidCallback onGraded;

  const _SubmissionRow({
    required this.submission,
    required this.maxMarks,
    required this.onGraded,
  });

  Future<void> _openGradingDialog(BuildContext context) async {
    final graded = await showDialog<bool>(
      context: context,
      builder: (_) => _GradingDialog(
        submission: submission,
        maxMarks: maxMarks,
      ),
    );
    if (graded == true) onGraded();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openGradingDialog(context),
      borderRadius: BorderRadius.circular(AppColors.radiusField),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                submission.uid.isNotEmpty
                    ? submission.uid[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(submission.uid,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(
                    'Submitted ${submission.formattedSubmittedAt}'
                    '${submission.hasFile ? ' · file attached' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (submission.isMarked && submission.marks != null) ...[
              Text('${submission.marks}/$maxMarks',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.success)),
              const SizedBox(width: 10),
            ],
            CustomChip(label: submission.status, dense: true),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Shows a submitted attachment and mints a time-limited link on demand.
///
/// The Supabase bucket is private, so Firestore holds only the object path.
/// A signed URL is generated when the instructor asks for it and expires
/// after [SupabaseConfig.signedUrlTtl].
class _AttachmentLink extends StatefulWidget {
  final String fileName;
  final String storagePath;

  const _AttachmentLink({required this.fileName, required this.storagePath});

  @override
  State<_AttachmentLink> createState() => _AttachmentLinkState();
}

class _AttachmentLinkState extends State<_AttachmentLink> {
  bool _loading = false;
  String? _url;
  String? _error;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = await SupabaseStorageService.signedUrl(widget.storagePath);
      if (!mounted) return;
      setState(() {
        _url = url;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.attach_file, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.fileName.isEmpty
                    ? widget.storagePath.split('/').last
                    : widget.fileName,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              onPressed: _loading ? null : _generate,
              icon: _loading
                  ? const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.link, size: 15),
              label: Text(_url == null ? 'Get link' : 'Refresh link',
                  style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
        if (_url != null) ...[
          const SizedBox(height: 4),
          SelectableText(
            _url!,
            style: const TextStyle(fontSize: 11, color: AppColors.primary),
          ),
          Text(
            'Copy into a browser tab. Expires in '
            '${SupabaseConfig.signedUrlTtl.inMinutes} minutes.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(_error!,
              style: const TextStyle(fontSize: 11, color: AppColors.error)),
        ],
      ],
    );
  }
}

/// Marks + feedback entry for one submission.
class _GradingDialog extends StatefulWidget {
  final SubmissionModel submission;
  final int maxMarks;

  const _GradingDialog({required this.submission, required this.maxMarks});

  @override
  State<_GradingDialog> createState() => _GradingDialogState();
}

class _GradingDialogState extends State<_GradingDialog> {
  late final TextEditingController _marks;
  late final TextEditingController _feedback;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _marks = TextEditingController(
        text: widget.submission.marks?.toString() ?? '');
    _feedback = TextEditingController(text: widget.submission.feedback);
  }

  @override
  void dispose() {
    _marks.dispose();
    _feedback.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final marks = int.tryParse(_marks.text.trim());
    if (marks == null) {
      setState(() => _error = 'Enter the marks as a number.');
      return;
    }
    if (marks < 0 || marks > widget.maxMarks) {
      setState(() =>
          _error = 'Marks must be between 0 and ${widget.maxMarks}.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await FirebaseService.gradeSubmission(
        submissionId: widget.submission.submissionId,
        marks: marks,
        feedback: _feedback.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.submission;

    return AlertDialog(
      title: const Text('Grade submission'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      s.uid.isNotEmpty ? s.uid[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.uid,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        Text('Submitted ${s.formattedSubmittedAt}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  CustomChip(label: s.status, dense: true),
                ],
              ),
              const SizedBox(height: 18),

              // ---- Submitted content ----
              Text('Submitted work',
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (s.hasText)
                      Text(s.textAnswer,
                          style: const TextStyle(fontSize: 13))
                    else
                      Text('No written answer.',
                          style: Theme.of(context).textTheme.bodySmall),
                    if (s.hasFile) ...[
                      const SizedBox(height: 10),
                      _AttachmentLink(
                        fileName: s.fileName,
                        storagePath: s.fileUrl,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              CustomTextField(
                controller: _marks,
                label: 'Marks (out of ${widget.maxMarks})',
                hint: 'e.g. 18',
                prefixIcon: Icons.military_tech_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),
              CustomTextField(
                controller: _feedback,
                label: 'Feedback',
                hint: 'e.g. Good implementation. Improve UI responsiveness.',
                prefixIcon: Icons.comment_outlined,
                maxLines: 3,
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.errorSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 16, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        CustomButton(
          label: 'Mark as graded',
          icon: Icons.check,
          isLoading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}
