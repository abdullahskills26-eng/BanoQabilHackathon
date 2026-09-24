import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/state_renderers.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../models/attendance_model.dart';
import '../../../models/career_checklist_model.dart';
import '../../../services/firestore_service.dart';

/// Screen 9 — learning progress and career readiness.
class ProgressChecklistScreen extends StatefulWidget {
  const ProgressChecklistScreen({super.key});

  @override
  State<ProgressChecklistScreen> createState() =>
      _ProgressChecklistScreenState();
}

class _ProgressData {
  final int modulesCompleted;
  final int modulesTotal;
  final AttendanceSummary attendance;
  final double assignmentAverage;
  final CareerChecklistModel checklist;

  const _ProgressData({
    required this.modulesCompleted,
    required this.modulesTotal,
    required this.attendance,
    required this.assignmentAverage,
    required this.checklist,
  });

  double get modulePercentage =>
      modulesTotal == 0 ? 0 : (modulesCompleted / modulesTotal) * 100;

  /// Even weighting across modules, attendance and assignment marks.
  double get overall =>
      (modulePercentage + attendance.percentage + assignmentAverage) / 3;
}

class _ProgressChecklistScreenState extends State<ProgressChecklistScreen> {
  late Future<_ProgressData> _future;
  CareerChecklistModel? _checklist;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _reload() => setState(() {
        _checklist = null;
        _future = _load();
      });

  Future<_ProgressData> _load() async {
    final uid = FirebaseService.currentUid;
    final batch = await FirebaseService.fetchStudentBatch(uid);
    final attendance = await FirebaseService.fetchAttendance(uid);
    final assignments = await FirebaseService.fetchAssignments(
        batchId: batch?['batchId']?.toString());
    final submissions = await FirebaseService.fetchSubmissions(uid);
    final checklist = await FirebaseService.fetchCareerChecklist(uid);

    // A module is "completed" when its assignment has been marked.
    final marked = submissions.where((s) => s.isMarked).toList();

    double average = 0;
    if (marked.isNotEmpty) {
      double total = 0;
      int counted = 0;
      for (final s in marked) {
        final max = assignments
                .where((a) => a.assignmentId == s.assignmentId)
                .firstOrNull
                ?.maxMarks ??
            0;
        final pct = s.percentageOf(max);
        if (pct != null) {
          total += pct;
          counted++;
        }
      }
      if (counted > 0) average = total / counted;
    }

    return _ProgressData(
      modulesCompleted: marked.length,
      modulesTotal: assignments.isEmpty ? 0 : assignments.length,
      attendance: AttendanceSummary.fromRecords(attendance),
      assignmentAverage: average,
      checklist: checklist,
    );
  }

  Future<void> _updateChecklist(CareerChecklistModel next) async {
    setState(() {
      _checklist = next;
      _saving = true;
    });
    try {
      await FirebaseService.saveCareerChecklist(
          FirebaseService.currentUid, next);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress & Career'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 18),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<_ProgressData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const ShimmerListSkeleton(itemCount: 3);
            }
            if (snap.hasError) {
              return ErrorRetry(
                  message: snap.error.toString(), onRetry: _reload);
            }

            final data = snap.data!;
            final checklist = _checklist ?? data.checklist;

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _OverallCard(data: data),
                    const SizedBox(height: 16),
                    _BreakdownCard(data: data),
                    const SizedBox(height: 16),
                    _ChecklistCard(
                      checklist: checklist,
                      onChanged: _updateChecklist,
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

class _OverallCard extends StatelessWidget {
  final _ProgressData data;
  const _OverallCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final pct = data.overall;
    return AccentCard(
      accent: AppColors.primary,
      accentSoft: AppColors.primarySoft,
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            height: 78,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 78,
                  height: 78,
                  child: CircularProgressIndicator(
                    value: (pct / 100).clamp(0.0, 1.0),
                    strokeWidth: 8,
                    backgroundColor: Colors.white,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Course progress',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontSize: 18)),
                const SizedBox(height: 6),
                Text(
                  'Modules ${data.modulesCompleted} / ${data.modulesTotal} · '
                  'Attendance ${data.attendance.formattedPercentage} · '
                  'Assignments ${data.assignmentAverage.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final _ProgressData data;
  const _BreakdownCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Breakdown', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 18),
          _Bar(
            label: 'Modules completed',
            trailing: '${data.modulesCompleted} / ${data.modulesTotal}',
            value: data.modulePercentage,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          _Bar(
            label: 'Attendance',
            trailing: data.attendance.formattedPercentage,
            value: data.attendance.percentage,
            color: AppColors.success,
          ),
          const SizedBox(height: 16),
          _Bar(
            label: 'Assignment average',
            trailing: '${data.assignmentAverage.toStringAsFixed(0)}%',
            value: data.assignmentAverage,
            color: AppColors.secondary,
          ),
          const SizedBox(height: 16),
          _Bar(
            label: 'Overall',
            trailing: '${data.overall.toStringAsFixed(0)}%',
            value: data.overall,
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final String trailing;
  final double value;
  final Color color;

  const _Bar({
    required this.label,
    required this.trailing,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13.5)),
            ),
            Text(trailing,
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 13.5, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: (value / 100).clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 9,
              backgroundColor: AppColors.fieldFill,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  final CareerChecklistModel checklist;
  final ValueChanged<CareerChecklistModel> onChanged;

  const _ChecklistCard({required this.checklist, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Career readiness',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: checklist.isJobReady
                      ? AppColors.successSoft
                      : AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                ),
                child: Text(
                  checklist.isJobReady
                      ? 'Job ready'
                      : '${checklist.completedCount}/'
                          '${CareerChecklistModel.totalItems} done',
                  style: TextStyle(
                    color: checklist.isJobReady
                        ? AppColors.success
                        : AppColors.warning,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _CheckRow(
            label: 'Create CV',
            checked: checklist.cvCreated,
            onChanged: (v) => onChanged(checklist.copyWith(cvCreated: v)),
          ),
          _CheckRow(
            label: 'Create GitHub profile',
            checked: checklist.githubCreated,
            onChanged: (v) => onChanged(checklist.copyWith(githubCreated: v)),
          ),
          _CheckRow(
            label: 'Complete 3 projects',
            checked: checklist.projectsCompleted,
            subtitle:
                '${checklist.projectsCompletedCount} of '
                '${CareerChecklistModel.requiredProjects} completed',
            onChanged: (v) => onChanged(checklist.copyWith(
                projectsCompletedCount:
                    v ? CareerChecklistModel.requiredProjects : 0)),
            trailing: _ProjectStepper(
              count: checklist.projectsCompletedCount,
              onChanged: (n) =>
                  onChanged(checklist.copyWith(projectsCompletedCount: n)),
            ),
          ),
          _CheckRow(
            label: 'Attend mock interview',
            checked: checklist.mockInterviewAttended,
            onChanged: (v) =>
                onChanged(checklist.copyWith(mockInterviewAttended: v)),
          ),
          _CheckRow(
            label: 'Apply for jobs',
            checked: checklist.jobsApplied,
            onChanged: (v) => onChanged(checklist.copyWith(jobsApplied: v)),
          ),

          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: checklist.percentage / 100,
              minHeight: 8,
              backgroundColor: AppColors.fieldFill,
              valueColor: AlwaysStoppedAnimation(
                  checklist.isJobReady
                      ? AppColors.success
                      : AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final Widget? trailing;

  const _CheckRow({
    required this.label,
    required this.checked,
    required this.onChanged,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!checked),
      borderRadius: BorderRadius.circular(AppColors.radiusField),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Checkbox(
              value: checked,
              onChanged: (v) => onChanged(v ?? false),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration:
                          checked ? TextDecoration.lineThrough : null,
                      color: checked
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _ProjectStepper extends StatelessWidget {
  final int count;
  final ValueChanged<int> onChanged;

  const _ProjectStepper({required this.count, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 20),
          tooltip: 'One fewer project',
          onPressed: count > 0 ? () => onChanged(count - 1) : null,
        ),
        Text('$count',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 20),
          tooltip: 'One more project',
          onPressed: count < CareerChecklistModel.requiredProjects
              ? () => onChanged(count + 1)
              : null,
        ),
      ],
    );
  }
}
