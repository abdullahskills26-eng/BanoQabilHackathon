import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/demo_credentials.dart';
import '../../../core/utils/state_renderers.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../models/batch_model.dart';
import '../../../models/notice_model.dart';
import '../../../models/submission_model.dart';
import '../../../services/firestore_service.dart';
import '../assignments/create_assignment_screen.dart';
import '../attendance/mark_attendance_screen.dart';
import 'batch_progress_screen.dart';
import 'post_notice_screen.dart';

/// Screen 10 — instructor dashboard home.
class InstructorHomeScreen extends StatefulWidget {
  const InstructorHomeScreen({super.key});

  @override
  State<InstructorHomeScreen> createState() => _InstructorHomeScreenState();
}

class _InstructorDashboardData {
  final List<BatchModel> batches;
  final BatchModel? activeBatch;
  final int studentCount;
  final int pendingGrading;
  final List<NoticeModel> notices;

  const _InstructorDashboardData({
    required this.batches,
    required this.activeBatch,
    required this.studentCount,
    required this.pendingGrading,
    required this.notices,
  });
}

class _InstructorHomeScreenState extends State<InstructorHomeScreen> {
  late Future<_InstructorDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _reload() => setState(() => _future = _load());

  Future<_InstructorDashboardData> _load() async {
    final batches = await FirebaseService.fetchInstructorBatches(
      instructorId: FirebaseService.auth.currentUser?.uid ?? '',
      instructorName: DemoCredentials.instructor.name,
    );

    if (batches.isEmpty) {
      return const _InstructorDashboardData(
        batches: [],
        activeBatch: null,
        studentCount: 0,
        pendingGrading: 0,
        notices: [],
      );
    }

    final active = batches.first;
    final students = await FirebaseService.fetchBatchStudents(active);
    final assignments =
        await FirebaseService.fetchAssignments(batchId: active.label);

    // Count submissions that are in but not yet marked.
    int pending = 0;
    for (final a in assignments) {
      final subs =
          await FirebaseService.fetchAssignmentSubmissions(a.assignmentId);
      pending += subs.where((s) => s.status != SubmissionStatus.marked).length;
    }

    final notices = await FirebaseService.fetchBatchNotices(active.label);

    return _InstructorDashboardData(
      batches: batches,
      activeBatch: active,
      studentCount: students.length,
      pendingGrading: pending,
      notices: notices,
    );
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Instructor Dashboard')),
      body: SafeArea(
        child: FutureBuilder<_InstructorDashboardData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const ShimmerListSkeleton(itemCount: 4);
            }
            if (snap.hasError) {
              return ErrorRetry(
                  message: snap.error.toString(), onRetry: _reload);
            }

            final data = snap.data!;
            if (data.activeBatch == null) {
              return EmptyState(
                message: 'No batch assigned yet',
                subtitle:
                    'A campus coordinator needs to assign you to a batch '
                    'before your dashboard fills in.',
                icon: Icons.groups_outlined,
                actionLabel: 'Refresh',
                onAction: _reload,
              );
            }

            final batch = data.activeBatch!;

            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _WelcomeBanner(batch: batch),
                      const SizedBox(height: 16),
                      _QuickStats(data: data),
                      const SizedBox(height: 16),
                      _ActionToolbar(
                        onAttendance: () => _open(
                            MarkAttendanceScreen(batches: data.batches)),
                        onAssignment: () => _open(
                            CreateAssignmentScreen(batches: data.batches)),
                        onNotice: () =>
                            _open(PostNoticeScreen(batches: data.batches)),
                        onProgress: () =>
                            _open(BatchProgressScreen(batch: batch)),
                      ),
                      const SizedBox(height: 16),
                      _TodayScheduleCard(batch: batch),
                      const SizedBox(height: 16),
                      _RecentNoticesCard(notices: data.notices),
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
  final BatchModel batch;
  const _WelcomeBanner({required this.batch});

  @override
  Widget build(BuildContext context) {
    final name = batch.instructorName.isEmpty
        ? DemoCredentials.instructor.name
        : batch.instructorName;

    return AccentCard(
      accent: AppColors.primary,
      accentSoft: AppColors.primarySoft,
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 22),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back,',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(name,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontSize: 22)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    _InlineMeta(
                        icon: Icons.apartment,
                        text: batch.campusName.isEmpty
                            ? 'Lahore Campus'
                            : batch.campusName),
                    _InlineMeta(
                        icon: Icons.badge_outlined, text: batch.label),
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
  const _InlineMeta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _QuickStats extends StatelessWidget {
  final _InstructorDashboardData data;
  const _QuickStats({required this.data});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      const StatTile(
        icon: Icons.today_outlined,
        label: "Today's classes",
        value: '1',
        color: AppColors.primary,
      ),
      StatTile(
        icon: Icons.groups_outlined,
        label: 'Enrolled students',
        value: '${data.studentCount}',
        color: AppColors.success,
      ),
      StatTile(
        icon: Icons.layers_outlined,
        label: 'Active batches',
        value: '${data.batches.where((b) => b.isOpen).length}',
        color: AppColors.secondary,
      ),
      StatTile(
        icon: Icons.rate_review_outlined,
        label: 'Pending grading',
        value: '${data.pendingGrading}',
        color: AppColors.warning,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 820
            ? 4
            : (constraints.maxWidth > 460 ? 2 : 1);
        final width =
            (constraints.maxWidth - (columns - 1) * 14) / columns;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: tiles
              .map((t) => SizedBox(
                    width: width,
                    child: CustomCard(child: t),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _ActionToolbar extends StatelessWidget {
  final VoidCallback onAttendance;
  final VoidCallback onAssignment;
  final VoidCallback onNotice;
  final VoidCallback onProgress;

  const _ActionToolbar({
    required this.onAttendance,
    required this.onAssignment,
    required this.onNotice,
    required this.onProgress,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.fact_check_outlined, 'Mark Attendance', AppColors.success,
          onAttendance),
      (Icons.post_add_outlined, 'Add Assignment', AppColors.primary,
          onAssignment),
      (Icons.campaign_outlined, 'Post Notice', AppColors.warning, onNotice),
      (Icons.trending_down, 'At-Risk Students', AppColors.error, onProgress),
    ];

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick actions',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: actions
                .map((a) => _ActionButton(
                      icon: a.$1,
                      label: a.$2,
                      color: a.$3,
                      onTap: a.$4,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppColors.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayScheduleCard extends StatelessWidget {
  final BatchModel batch;
  const _TodayScheduleCard({required this.batch});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, color: AppColors.secondary, size: 20),
              const SizedBox(width: 8),
              Text("Today's schedule",
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 4,
                height: 46,
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
                    Text(
                      batch.courseName.isEmpty
                          ? 'Flutter Development'
                          : batch.courseName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${batch.label} · ${batch.room}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.secondarySoft,
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                ),
                child: Text(
                  batch.classTime,
                  style: const TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentNoticesCard extends StatelessWidget {
  final List<NoticeModel> notices;
  const _RecentNoticesCard({required this.notices});

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
              Text('Class notices',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 14),
          if (notices.isEmpty)
            Text('No notices posted for this batch yet.',
                style: Theme.of(context).textTheme.bodyMedium)
          else
            ...notices.take(5).map(
                  (n) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(n.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                            ),
                            Text(n.formattedCreatedAt,
                                style:
                                    Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(n.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
