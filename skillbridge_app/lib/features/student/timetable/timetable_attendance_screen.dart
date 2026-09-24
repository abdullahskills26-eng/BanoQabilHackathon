import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/state_renderers.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../models/attendance_model.dart';
import '../../../services/firestore_service.dart';

/// Screen 7 — timetable and attendance.
class TimetableAttendanceScreen extends StatefulWidget {
  const TimetableAttendanceScreen({super.key});

  @override
  State<TimetableAttendanceScreen> createState() =>
      _TimetableAttendanceScreenState();
}

class _TimetableData {
  final Map<String, dynamic>? batch;
  final List<AttendanceModel> records;
  const _TimetableData(this.batch, this.records);
}

class _TimetableAttendanceScreenState extends State<TimetableAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<_TimetableData> _future;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _future = _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<_TimetableData> _load() async {
    final uid = FirebaseService.currentUid;
    final batch = await FirebaseService.fetchStudentBatch(uid);
    final records = await FirebaseService.fetchAttendance(uid);
    return _TimetableData(batch, records);
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable & Attendance'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Timetable', icon: Icon(Icons.calendar_view_week)),
            Tab(text: 'Attendance', icon: Icon(Icons.fact_check_outlined)),
          ],
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<_TimetableData>(
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
            return TabBarView(
              controller: _tabs,
              children: [
                _TimetableTab(batch: data.batch),
                _AttendanceTab(
                  records: data.records,
                  visibleMonth: _visibleMonth,
                  onMonthChanged: (m) => setState(() => _visibleMonth = m),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- Timetable

class _TimetableTab extends StatelessWidget {
  final Map<String, dynamic>? batch;
  const _TimetableTab({required this.batch});

  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];

  @override
  Widget build(BuildContext context) {
    if (batch == null) {
      return const EmptyState(
        message: 'No timetable yet',
        subtitle:
            'Your schedule appears once a coordinator enrols you in a batch.',
        icon: Icons.calendar_month_outlined,
      );
    }

    final b = batch!;
    final course = (b['courseName'] ?? 'Class').toString();
    final instructor = (b['instructorName'] ?? '—').toString();
    final room = (b['room'] ?? 'Lab 2').toString();
    final time = (b['classTime'] ?? '10:00 AM – 1:00 PM').toString();
    final todayIndex = DateTime.now().weekday - 1;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: _days.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final isToday = index == todayIndex;
            return CustomCard(
              borderColor: isToday ? AppColors.primary : null,
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 46,
                    decoration: BoxDecoration(
                      color:
                          isToday ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _days[index],
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontSize: 15),
                            ),
                            if (isToday) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(
                                      AppColors.radiusPill),
                                ),
                                child: const Text('Today',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(course,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13.5)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 14,
                          runSpacing: 4,
                          children: [
                            _Meta(
                                icon: Icons.meeting_room_outlined, text: room),
                            _Meta(
                                icon: Icons.person_outline, text: instructor),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.secondarySoft,
                      borderRadius:
                          BorderRadius.circular(AppColors.radiusPill),
                    ),
                    child: Text(
                      time,
                      style: const TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
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
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

// ------------------------------------------------------------- Attendance

class _AttendanceTab extends StatelessWidget {
  final List<AttendanceModel> records;
  final DateTime visibleMonth;
  final ValueChanged<DateTime> onMonthChanged;

  const _AttendanceTab({
    required this.records,
    required this.visibleMonth,
    required this.onMonthChanged,
  });

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const EmptyState(
        message: 'No attendance recorded',
        subtitle:
            'Once your instructor starts marking attendance, your monthly '
            'record shows up here.',
        icon: Icons.event_available_outlined,
      );
    }

    final summary = AttendanceSummary.fromRecords(records);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _OverallCard(summary: summary),
            const SizedBox(height: 16),
            _MonthCalendar(
              records: records,
              month: visibleMonth,
              onMonthChanged: onMonthChanged,
              monthNames: _monthNames,
            ),
          ],
        ),
      ),
    );
  }
}

class _OverallCard extends StatelessWidget {
  final AttendanceSummary summary;
  const _OverallCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final pct = summary.percentage;
    final color = pct >= 85
        ? AppColors.success
        : (pct >= 75 ? AppColors.warning : AppColors.error);

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 66,
                height: 66,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 66,
                      height: 66,
                      child: CircularProgressIndicator(
                        value: (pct / 100).clamp(0.0, 1.0),
                        strokeWidth: 7,
                        backgroundColor: AppColors.fieldFill,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                    Text(
                      summary.formattedPercentage,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: color),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overall attendance',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      pct >= 75
                          ? 'You are meeting the 75% requirement.'
                          : 'Below the 75% requirement — attend more classes.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _Count(
                  label: 'Present',
                  value: summary.present,
                  color: AppColors.success),
              _Count(
                  label: 'Absent',
                  value: summary.absent,
                  color: AppColors.error),
              _Count(
                  label: 'Leave',
                  value: summary.leave,
                  color: AppColors.info),
            ],
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Count(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  final List<AttendanceModel> records;
  final DateTime month;
  final ValueChanged<DateTime> onMonthChanged;
  final List<String> monthNames;

  const _MonthCalendar({
    required this.records,
    required this.month,
    required this.onMonthChanged,
    required this.monthNames,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // weekday: Mon=1 … Sun=7 — shift so Monday is column 0.
    final leadingBlanks = firstDay.weekday - 1;

    final byDay = <int, String>{};
    for (final r in records) {
      if (r.date.year == month.year && r.date.month == month.month) {
        byDay[r.date.day] = r.status;
      }
    }

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${monthNames[month.month - 1]} ${month.year}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous month',
                onPressed: () => onMonthChanged(
                    DateTime(month.year, month.month - 1)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next month',
                onPressed: () => onMonthChanged(
                    DateTime(month.year, month.month + 1)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leadingBlanks + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              if (index < leadingBlanks) return const SizedBox.shrink();
              final day = index - leadingBlanks + 1;
              final status = byDay[day];
              return _DayCell(day: day, status: status);
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: const [
              _Legend(letter: 'P', label: 'Present', color: AppColors.success),
              _Legend(letter: 'A', label: 'Absent', color: AppColors.error),
              _Legend(letter: 'L', label: 'Leave', color: AppColors.info),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final String? status;
  const _DayCell({required this.day, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.transparent;
    Color fg = AppColors.textSecondary;
    String? marker;

    if (status != null) {
      marker = AttendanceStatusValues.letter(status!);
      switch (status) {
        case AttendanceStatusValues.present:
          bg = AppColors.successSoft;
          fg = AppColors.success;
          break;
        case AttendanceStatusValues.absent:
          bg = AppColors.errorSoft;
          fg = AppColors.error;
          break;
        case AttendanceStatusValues.leave:
          bg = AppColors.infoSoft;
          fg = AppColors.info;
          break;
      }
    }

    return Tooltip(
      message: status == null ? 'Day $day — not marked' : 'Day $day — $status',
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: status == null
                ? AppColors.border
                : fg.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$day',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: status == null ? AppColors.textSecondary : fg)),
            if (marker != null)
              Text(marker,
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800, color: fg)),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String letter;
  final String label;
  final Color color;
  const _Legend(
      {required this.letter, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Text(letter,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w800, color: color)),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
