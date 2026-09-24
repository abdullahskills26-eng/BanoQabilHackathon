import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/state_renderers.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../models/report_metrics_model.dart';
import '../../../services/firestore_service.dart';
import '../../../services/seed_service.dart';
import '../batches/batch_management_screen.dart';
import 'post_campus_notice_screen.dart';
import 'widgets/seed_demo_button.dart';

/// Screen 13 — coordinator dashboard and campus reports.
class CoordinatorReportsScreen extends StatefulWidget {
  const CoordinatorReportsScreen({super.key});

  @override
  State<CoordinatorReportsScreen> createState() =>
      _CoordinatorReportsScreenState();
}

class _CoordinatorReportsScreenState extends State<CoordinatorReportsScreen> {
  late Future<ReportMetricsModel> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _reload() => setState(() => _future = _load());

  Future<ReportMetricsModel> _load() =>
      FirebaseService.fetchCampusMetrics(campusName: SeedService.demoCampus);

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Reports')),
      body: SafeArea(
        child: FutureBuilder<ReportMetricsModel>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const ShimmerListSkeleton(itemCount: 4);
            }
            if (snap.hasError) {
              return ErrorRetry(
                  message: snap.error.toString(), onRetry: _reload);
            }

            final m = snap.data!;
            final isEmpty = m.totalApplications == 0 &&
                m.totalStudents == 0 &&
                m.activeBatches == 0;

            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const _ExecutiveHeader(),
                      const SizedBox(height: 16),
                      _ActionToolbar(
                        onSeeded: _reload,
                        onNewBatch: () =>
                            _open(const BatchManagementScreen()),
                        onNotice: () =>
                            _open(const PostCampusNoticeScreen()),
                      ),
                      const SizedBox(height: 16),
                      if (isEmpty)
                        CustomCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.info_outline,
                                      color: AppColors.info),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'This campus has no data yet',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Use "Seed Demo Data" above to populate '
                                'courses, campuses, a batch of 12 students, '
                                'assignments and applications.',
                                style:
                                    Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        )
                      else ...[
                        _MetricsGrid(metrics: m),
                        const SizedBox(height: 16),
                        _SecondaryStats(metrics: m),
                      ],
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

class _ExecutiveHeader extends StatelessWidget {
  const _ExecutiveHeader();

  @override
  Widget build(BuildContext context) {
    return AccentCard(
      accent: AppColors.primary,
      accentSoft: AppColors.primarySoft,
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.apartment,
                color: AppColors.primary, size: 27),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lahore Campus Office',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontSize: 22)),
                const SizedBox(height: 4),
                Text(
                  'Campus coordinator dashboard · applications, batches and '
                  'reporting',
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

class _ActionToolbar extends StatelessWidget {
  final VoidCallback onSeeded;
  final VoidCallback onNewBatch;
  final VoidCallback onNotice;

  const _ActionToolbar({
    required this.onSeeded,
    required this.onNewBatch,
    required this.onNotice,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SeedDemoButton(onSeeded: onSeeded),
              _ToolbarButton(
                icon: Icons.add_box_outlined,
                label: 'New Batch',
                color: AppColors.primary,
                onTap: onNewBatch,
              ),
              _ToolbarButton(
                icon: Icons.campaign_outlined,
                label: 'Campus Notice',
                color: AppColors.warning,
                onTap: onNotice,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ToolbarButton({
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 9),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final ReportMetricsModel metrics;
  const _MetricsGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      StatTile(
        icon: Icons.inbox_outlined,
        label: 'Applications this month',
        value: '${metrics.applicationsThisMonth}',
        color: AppColors.primary,
      ),
      StatTile(
        icon: Icons.how_to_reg_outlined,
        label: 'Accepted students',
        value: '${metrics.acceptedStudentsCount}',
        color: AppColors.success,
      ),
      StatTile(
        icon: Icons.fact_check_outlined,
        label: 'Average attendance',
        value: metrics.formattedAttendance,
        color: AppColors.secondary,
      ),
      StatTile(
        icon: Icons.pending_actions_outlined,
        label: 'Pending assignments',
        value: '${metrics.pendingAssignmentsCount}',
        color: AppColors.warning,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 820
            ? 4
            : (constraints.maxWidth > 460 ? 2 : 1);
        final width = (constraints.maxWidth - (columns - 1) * 14) / columns;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: tiles
              .map((t) => SizedBox(width: width, child: CustomCard(child: t)))
              .toList(),
        );
      },
    );
  }
}

class _SecondaryStats extends StatelessWidget {
  final ReportMetricsModel metrics;
  const _SecondaryStats({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Campus overview',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          _Row(
              label: 'Total applications',
              value: '${metrics.totalApplications}'),
          _Row(
              label: 'Acceptance rate',
              value: '${metrics.acceptanceRate.toStringAsFixed(0)}%'),
          _Row(label: 'Active batches', value: '${metrics.activeBatches}'),
          _Row(
              label: 'Enrolled students',
              value: '${metrics.totalStudents}'),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child:
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15)),
        ],
      ),
    );
  }
}
