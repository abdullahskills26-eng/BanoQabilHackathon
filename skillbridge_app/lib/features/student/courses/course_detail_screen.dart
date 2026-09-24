import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/custom_chip.dart';
import '../../../models/campus_model.dart';
import '../../../models/course_model.dart';
import 'application_form_screen.dart';

/// Screen 4 — course + campus detail, with Apply Now.
class CourseDetailScreen extends StatefulWidget {
  final CourseModel course;
  final List<CampusModel> campuses;

  const CourseDetailScreen({
    super.key,
    required this.course,
    required this.campuses,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  CampusModel? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.campuses.isNotEmpty ? widget.campuses.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;

    return Scaffold(
      appBar: AppBar(title: const Text('Course Details')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                AccentCard(
                  accent: AppColors.primary,
                  accentSoft: AppColors.primarySoft,
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              course.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontSize: 23),
                            ),
                          ),
                          const SizedBox(width: 12),
                          CustomChip(label: course.level, showIcon: false),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        course.description.isEmpty
                            ? 'No description provided.'
                            : course.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                CustomCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Course information',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      _DetailRow(
                          icon: Icons.timer_outlined,
                          label: 'Duration',
                          value: course.duration.isEmpty
                              ? '—'
                              : course.duration),
                      _DetailRow(
                          icon: Icons.event_seat_outlined,
                          label: 'Seats available',
                          value: '${course.seatsAvailable}',
                          valueColor: course.hasSeats
                              ? AppColors.success
                              : AppColors.error),
                      _DetailRow(
                          icon: Icons.bar_chart,
                          label: 'Level',
                          value: course.level),
                      _DetailRow(
                          icon: Icons.person_outline,
                          label: 'Instructor',
                          value: 'Sir Hamza'),
                      _DetailRow(
                          icon: Icons.event_outlined,
                          label: 'Start date',
                          value: '15 October 2026'),
                      _DetailRow(
                          icon: Icons.schedule,
                          label: 'Class timings',
                          value: 'Mon–Fri · 10:00 AM – 1:00 PM'),
                      _DetailRow(
                          icon: Icons.meeting_room_outlined,
                          label: 'Room / Lab',
                          value: 'Lab 2'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (course.topics.isNotEmpty) ...[
                  CustomCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('What you will learn',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: course
                              .topics
                              .map((t) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: AppColors.fieldFill,
                                      borderRadius: BorderRadius.circular(
                                          AppColors.radiusPill),
                                    ),
                                    child: Text(t,
                                        style: const TextStyle(fontSize: 12)),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                CustomCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Choose a campus',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 14),
                      if (widget.campuses.isEmpty)
                        Text('No campuses available.',
                            style: Theme.of(context).textTheme.bodyMedium)
                      else
                        DropdownButtonFormField<CampusModel>(
                          initialValue: _selected,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Preferred campus',
                            prefixIcon: Icon(Icons.apartment, size: 20),
                          ),
                          items: widget.campuses
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text('${c.name} · ${c.province}'),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _selected = v),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                CustomButton(
                  label: 'Apply Now',
                  icon: Icons.send_rounded,
                  expand: true,
                  onPressed: course.hasSeats
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ApplicationFormScreen(
                                course: course,
                                campuses: widget.campuses,
                                preselectedCampus: _selected,
                              ),
                            ),
                          )
                      : null,
                ),
                if (!course.hasSeats) ...[
                  const SizedBox(height: 10),
                  Text(
                    'This course is currently full.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}
