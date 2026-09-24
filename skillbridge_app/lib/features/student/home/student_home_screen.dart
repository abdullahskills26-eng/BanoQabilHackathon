import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/state_renderers.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../models/attendance_model.dart';
import '../../../models/submission_model.dart';
import '../../../services/firestore_service.dart';

/// Screen 2 — student dashboard home.
class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentDashboardData {
  final Map<String, dynamic> user;
  final Map<String, dynamic>? batch;
  final AttendanceSummary attendance;
  final int pendingAssignments;
  final int totalAssignments;
  final double assignmentAverage;
  final List<Map<String, dynamic>> notices;

  const _StudentDashboardData({
    required this.user,
    required this.batch,
    required this.attendance,
    required this.pendingAssignments,
    required this.totalAssignments,
    required this.assignmentAverage,
    required this.notices,
  });

  /// Overall = attendance, assignment average and completion, evenly weighted.
  double get overallProgress {
    final completion = totalAssignments == 0
        ? 0.0
        : ((totalAssignments - pendingAssignments) / totalAssignments) * 100;
    return (attendance.percentage + assignmentAverage + completion) / 3;
  }
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  late Future<_StudentDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _reload() => setState(() => _future = _load());

  Future<_StudentDashboardData> _load() async {
    final uid = FirebaseService.currentUid;

    final userDoc = await FirebaseService.db.collection('users').doc(uid).get();
    final batch = await FirebaseService.fetchStudentBatch(uid);
    final attendanceRecords = await FirebaseService.fetchAttendance(uid);
    final assignments = await FirebaseService.fetchAssignments(
        batchId: batch?['batchId']?.toString());
    final submissions = await FirebaseService.fetchSubmissions(uid);
    final notices = await FirebaseService.fetchNotices();

    final submissionByAssignment = {
      for (final s in submissions) s.assignmentId: s,
    };

    final pending = assignments
        .where((a) => (submissionByAssignment[a.assignmentId]?.status ??
            SubmissionStatus.pending) ==
            SubmissionStatus.pending)
        .length;

    final marked = submissions.where((s) => s.isMarked && s.marks != null);
    double average = 0;
    if (marked.isNotEmpty) {
      double total = 0;
      int counted = 0;
      for (final s in marked) {
        final assignment = assignments
            .where((a) => a.assignmentId == s.assignmentId)
            .firstOrNull;
        final max = assignment?.maxMarks ?? 0;
        final pct = s.percentageOf(max);
        if (pct != null) {
          total += pct;
          counted++;
        }
      }
      if (counted > 0) average = total / counted;
    }

    return _StudentDashboardData(
      user: userDoc.data() ?? const {},
      batch: batch,
      attendance: AttendanceSummary.fromRecords(attendanceRecords),
      pendingAssignments: pending,
      totalAssignments: assignments.length,
      assignmentAverage: average,
      notices: notices,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: SafeArea(
        child: FutureBuilder<_StudentDashboardData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const ShimmerListSkeleton(itemCount: 4);
            }
            if (snap.hasError) {
              return ErrorRetry(
                message: snap.error.toString(),
                onRetry: _reload,
              );
            }

            final data = snap.data!;
            final name = (data.user['name'] ?? 'Student').toString();

            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _WelcomeBanner(name: name, user: data.user),
                      const SizedBox(height: 16),
                      _QuickStats(data: data),
                      const SizedBox(height: 16),
                      _ActiveBatchCard(batch: data.batch),
                      const SizedBox(height: 16),
                      _TodayClassCard(batch: data.batch),
                      const SizedBox(height: 16),
                      _NoticesCard(notices: data.notices),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  final String name;
  final Map<String, dynamic> user;

  const _WelcomeBanner({required this.name, required this.user});

  @override
  Widget build(BuildContext context) {
    final campus = (user['campus'] ?? '—').toString();
    final city = (user['city'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryBright],
        ),
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.secondary,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WELCOME BACK',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.secondary,
                        letterSpacing: 1.2,
                        fontSize: 11,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontSize: 24, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    _InlineMeta(icon: Icons.apartment, text: campus, dark: true),
                    if (city.isNotEmpty)
                      _InlineMeta(
                        icon: Icons.location_on_outlined,
                        text: city,
                        dark: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool dark;
  const _InlineMeta({
    required this.icon,
    required this.text,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: dark
              ? Colors.white.withValues(alpha: 0.75)
              : AppColors.textSecondary,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: dark
                    ? Colors.white.withValues(alpha: 0.78)
                    : AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}

class _QuickStats extends StatelessWidget {
  final _StudentDashboardData data;
  const _QuickStats({required this.data});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      StatTile(
        icon: Icons.fact_check_outlined,
        label: 'Attendance',
        value: data.attendance.formattedPercentage,
        color: AppColors.success,
      ),
      StatTile(
        icon: Icons.assignment_late_outlined,
        label: 'Pending work',
        value: '${data.pendingAssignments}',
        color: AppColors.warning,
      ),
      StatTile(
        icon: Icons.trending_up,
        label: 'Overall progress',
        value: '${data.overallProgress.toStringAsFixed(0)}%',
        color: AppColors.primary,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 700;
        if (wide) {
          return Row(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                Expanded(child: CustomCard(child: tiles[i])),
                if (i < tiles.length - 1) const SizedBox(width: 14),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              CustomCard(child: tiles[i]),
              if (i < tiles.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _ActiveBatchCard extends StatelessWidget {
  final Map<String, dynamic>? batch;
  const _ActiveBatchCard({required this.batch});

  @override
  Widget build(BuildContext context) {
    if (batch == null) {
      return CustomCard(
        child: Row(
          children: [
            const Icon(Icons.school_outlined, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'You are not enrolled in a batch yet. Apply to a course to '
                'get started.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    final b = batch!;
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('Active course',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            (b['courseName'] ?? 'Course').toString(),
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _InlineMeta(
                  icon: Icons.badge_outlined,
                  text: 'Batch ${b['batchId'] ?? '—'}'),
              _InlineMeta(
                  icon: Icons.apartment, text: (b['campus'] ?? '—').toString()),
              _InlineMeta(
                  icon: Icons.person_outline,
                  text: (b['instructorName'] ?? '—').toString()),
              _InlineMeta(
                  icon: Icons.event_outlined,
                  text: 'Starts ${b['startDate'] ?? '—'}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayClassCard extends StatelessWidget {
  final Map<String, dynamic>? batch;
  const _TodayClassCard({required this.batch});

  @override
  Widget build(BuildContext context) {
    final b = batch;
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, color: AppColors.secondary, size: 20),
              const SizedBox(width: 8),
              Text("Today's class",
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 14),
          if (b == null)
            Text('No class scheduled.',
                style: Theme.of(context).textTheme.bodyMedium)
          else
            Row(
              children: [
                Container(
                  width: 4,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((b['courseName'] ?? 'Class').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        '${b['room'] ?? 'Lab 1'} · '
                        '${b['instructorName'] ?? '—'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.secondarySoft,
                    borderRadius:
                        BorderRadius.circular(AppColors.radiusPill),
                  ),
                  child: Text(
                    (b['classTime'] ?? '10:00 AM').toString(),
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _NoticesCard extends StatelessWidget {
  final List<Map<String, dynamic>> notices;
  const _NoticesCard({required this.notices});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign, color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Text('Recent notices',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 14),
          if (notices.isEmpty)
            Text('No notices right now.',
                style: Theme.of(context).textTheme.bodyMedium)
          else
            ...notices.map(
              (n) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (n['title'] ?? 'Notice').toString(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (n['body'] ?? n['message'] ?? '').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
