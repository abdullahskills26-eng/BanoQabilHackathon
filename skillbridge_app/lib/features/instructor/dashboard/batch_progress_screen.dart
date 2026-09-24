import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/state_renderers.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../models/attendance_model.dart';
import '../../../models/batch_model.dart';
import '../../../models/submission_model.dart';
import '../../../services/firestore_service.dart';

/// Screen 10 (cont.) — at-risk student monitor.
class BatchProgressScreen extends StatefulWidget {
  final BatchModel batch;

  const BatchProgressScreen({super.key, required this.batch});

  @override
  State<BatchProgressScreen> createState() => _BatchProgressScreenState();
}

/// One student's computed standing within the batch.
class _StudentProgress {
  final String uid;
  final String name;
  final String photoUrl;
  final double attendancePercentage;
  final double submissionRate;
  final double assignmentAverage;

  const _StudentProgress({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.attendancePercentage,
    required this.submissionRate,
    required this.assignmentAverage,
  });

  /// Even weighting of attendance, submission rate and marks.
  double get overall =>
      (attendancePercentage + submissionRate + assignmentAverage) / 3;

  /// Below 60% on the overall score or on attendance alone.
  bool get isAtRisk => overall < 60 || attendancePercentage < 60;
}

class _BatchProgressScreenState extends State<BatchProgressScreen> {
  late Future<List<_StudentProgress>> _future;
  bool _onlyAtRisk = true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _reload() => setState(() => _future = _load());

  Future<List<_StudentProgress>> _load() async {
    final batch = widget.batch;
    final students = await FirebaseService.fetchBatchStudents(batch);
    final assignments =
        await FirebaseService.fetchAssignments(batchId: batch.label);
    final maxMarksById = {
      for (final a in assignments) a.assignmentId: a.maxMarks
    };

    final results = <_StudentProgress>[];

    for (final student in students) {
      final uid = student['uid'].toString();

      final attendance = await FirebaseService.fetchAttendance(uid);
      final summary = AttendanceSummary.fromRecords(attendance);

      final submissions = await FirebaseService.fetchSubmissions(uid);
      final submitted = submissions
          .where((s) => s.status != SubmissionStatus.pending)
          .length;
      final rate = assignments.isEmpty
          ? 0.0
          : (submitted / assignments.length) * 100;

      double average = 0;
      final marked = submissions.where((s) => s.isMarked).toList();
      if (marked.isNotEmpty) {
        double total = 0;
        int counted = 0;
        for (final s in marked) {
          final pct = s.percentageOf(maxMarksById[s.assignmentId] ?? 0);
          if (pct != null) {
            total += pct;
            counted++;
          }
        }
        if (counted > 0) average = total / counted;
      }

      results.add(_StudentProgress(
        uid: uid,
        name: (student['name'] ?? 'Student').toString(),
        photoUrl: (student['photoUrl'] ?? '').toString(),
        attendancePercentage: summary.percentage,
        submissionRate: rate,
        assignmentAverage: average,
      ));
    }

    // Weakest first — that is who the instructor needs to see.
    results.sort((a, b) => a.overall.compareTo(b.overall));
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Batch Progress')),
      body: SafeArea(
        child: FutureBuilder<List<_StudentProgress>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const ShimmerListSkeleton(itemCount: 5);
            }
            if (snap.hasError) {
              return ErrorRetry(
                  message: snap.error.toString(), onRetry: _reload);
            }

            final all = snap.data!;
            if (all.isEmpty) {
              return const EmptyState(
                message: 'No students in this batch',
                subtitle:
                    'Progress appears once students are enrolled and work '
                    'has been marked.',
                icon: Icons.person_off_outlined,
              );
            }

            final atRisk = all.where((s) => s.isAtRisk).toList();
            final shown = _onlyAtRisk ? atRisk : all;

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    AccentCard(
                      accent: atRisk.isEmpty
                          ? AppColors.success
                          : AppColors.error,
                      accentSoft: atRisk.isEmpty
                          ? AppColors.successSoft
                          : AppColors.errorSoft,
                      child: Row(
                        children: [
                          Icon(
                            atRisk.isEmpty
                                ? Icons.verified_outlined
                                : Icons.warning_amber_rounded,
                            color: atRisk.isEmpty
                                ? AppColors.success
                                : AppColors.error,
                            size: 30,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  atRisk.isEmpty
                                      ? 'Everyone is on track'
                                      : '${atRisk.length} of ${all.length} '
                                          'students falling behind',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Flagged below 60% overall or attendance.',
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _onlyAtRisk
                                ? 'At-risk students'
                                : 'All students',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Switch(
                          value: _onlyAtRisk,
                          onChanged: (v) =>
                              setState(() => _onlyAtRisk = v),
                        ),
                        const Text('At-risk only',
                            style: TextStyle(fontSize: 12.5)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (shown.isEmpty)
                      CustomCard(
                        child: Row(
                          children: [
                            const Icon(Icons.celebration_outlined,
                                color: AppColors.success),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No students are currently at risk.',
                                style:
                                    Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...shown.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ProgressCard(student: s),
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

class _ProgressCard extends StatelessWidget {
  final _StudentProgress student;
  const _ProgressCard({required this.student});

  Color _scoreColor(double v) {
    if (v >= 75) return AppColors.success;
    if (v >= 60) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(student.overall);

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.12),
                foregroundImage: student.photoUrl.isEmpty
                    ? null
                    : NetworkImage(student.photoUrl),
                child: Text(
                  student.name.isNotEmpty
                      ? student.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            student.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                        if (student.isAtRisk) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.errorSoft,
                              borderRadius: BorderRadius.circular(
                                  AppColors.radiusPill),
                              border: Border.all(
                                  color: AppColors.error
                                      .withValues(alpha: 0.3)),
                            ),
                            child: const Text('At risk',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.error)),
                          ),
                        ],
                      ],
                    ),
                    Text(student.uid,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Text(
                '${student.overall.toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MiniBar(
              label: 'Attendance',
              value: student.attendancePercentage,
              color: AppColors.success),
          const SizedBox(height: 10),
          _MiniBar(
              label: 'Submission rate',
              value: student.submissionRate,
              color: AppColors.primary),
          const SizedBox(height: 10),
          _MiniBar(
              label: 'Assignment average',
              value: student.assignmentAverage,
              color: AppColors.secondary),
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MiniBar(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 132,
          child: Text(label,
              style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (value / 100).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 550),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 7,
                backgroundColor: AppColors.fieldFill,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 38,
          child: Text('${value.toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ),
      ],
    );
  }
}
