import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/utils/state_renderers.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/custom_chip.dart';
import '../../../models/campus_model.dart';
import '../../../models/course_model.dart';
import '../../../services/firestore_service.dart';
import 'course_detail_screen.dart';

/// Screen 3 — browse courses and find a campus.
class CourseListScreen extends StatefulWidget {
  const CourseListScreen({super.key});

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CatalogData {
  final List<CourseModel> courses;
  final List<CampusModel> campuses;
  const _CatalogData(this.courses, this.campuses);
}

class _CourseListScreenState extends State<CourseListScreen> {
  late Future<_CatalogData> _future;
  final _cityController = TextEditingController();
  String _province = 'All';
  String _city = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<_CatalogData> _load() async {
    final courses = await FirebaseService.fetchCourses();
    final campuses = await FirebaseService.fetchCampuses();
    return _CatalogData(courses, campuses);
  }

  void _reload() => setState(() => _future = _load());

  List<CampusModel> _filterCampuses(List<CampusModel> all) {
    return all.where((c) {
      final matchesProvince = _province == 'All' || c.province == _province;
      final matchesCity = _city.isEmpty ||
          c.city.toLowerCase().contains(_city.toLowerCase()) ||
          c.name.toLowerCase().contains(_city.toLowerCase());
      return matchesProvince && matchesCity;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Browse Courses')),
      body: SafeArea(
        child: FutureBuilder<_CatalogData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const ShimmerListSkeleton();
            }
            if (snap.hasError) {
              return ErrorRetry(
                  message: snap.error.toString(), onRetry: _reload);
            }

            final data = snap.data!;
            final campuses = _filterCampuses(data.campuses);

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _FilterBar(
                      province: _province,
                      cityController: _cityController,
                      onProvinceChanged: (v) =>
                          setState(() => _province = v ?? 'All'),
                      onCityChanged: (v) => setState(() => _city = v.trim()),
                    ),
                    const SizedBox(height: 22),

                    // ---- Campuses ----
                    _SectionHeading(
                      title: 'Campuses',
                      trailing: '${campuses.length} found',
                    ),
                    const SizedBox(height: 12),
                    if (campuses.isEmpty)
                      CustomCard(
                        child: Text(
                          'No campuses match that filter.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: campuses
                            .map((c) => _CampusPill(campus: c))
                            .toList(),
                      ),
                    const SizedBox(height: 28),

                    // ---- Courses ----
                    _SectionHeading(
                      title: 'Available courses',
                      trailing: '${data.courses.length} total',
                    ),
                    const SizedBox(height: 12),
                    if (data.courses.isEmpty)
                      const EmptyState(
                        message: 'No courses published yet',
                        subtitle:
                            'Ask a campus coordinator to seed demo data, or '
                            'check back shortly.',
                        icon: Icons.menu_book_outlined,
                      )
                    else
                      ...data.courses.map(
                        (course) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _CourseCard(
                            course: course,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CourseDetailScreen(
                                  course: course,
                                  campuses: campuses.isEmpty
                                      ? data.campuses
                                      : campuses,
                                ),
                              ),
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

class _SectionHeading extends StatelessWidget {
  final String title;
  final String trailing;
  const _SectionHeading({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        Text(trailing, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String province;
  final TextEditingController cityController;
  final ValueChanged<String?> onProvinceChanged;
  final ValueChanged<String> onCityChanged;

  const _FilterBar({
    required this.province,
    required this.cityController,
    required this.onProvinceChanged,
    required this.onCityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final provinceField = DropdownButtonFormField<String>(
            initialValue: province,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Province / Region',
              prefixIcon: Icon(Icons.map_outlined, size: 20),
            ),
            items: [
              const DropdownMenuItem(value: 'All', child: Text('All regions')),
              ...Provinces.all.map(
                (p) => DropdownMenuItem(value: p, child: Text(p)),
              ),
            ],
            onChanged: onProvinceChanged,
          );

          final cityField = TextFormField(
            controller: cityController,
            onChanged: onCityChanged,
            decoration: const InputDecoration(
              labelText: 'Search by city',
              hintText: 'e.g. Lahore',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          );

          if (constraints.maxWidth > 620) {
            return Row(
              children: [
                Expanded(child: provinceField),
                const SizedBox(width: 14),
                Expanded(child: cityField),
              ],
            );
          }
          return Column(
            children: [
              provinceField,
              const SizedBox(height: 14),
              cityField,
            ],
          );
        },
      ),
    );
  }
}

class _CampusPill extends StatelessWidget {
  final CampusModel campus;
  const _CampusPill({required this.campus});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.secondarySoft,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.apartment, size: 15, color: AppColors.secondary),
          const SizedBox(width: 7),
          Text(
            campus.name,
            style: const TextStyle(
              color: AppColors.secondary,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            campus.province,
            style: TextStyle(
              color: AppColors.secondary.withValues(alpha: 0.75),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final CourseModel course;
  final VoidCallback onTap;

  const _CourseCard({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_book_rounded,
                    color: AppColors.primary, size: 23),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      course.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              CustomChip(label: course.level, showIcon: false, dense: true),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Meta(
                  icon: Icons.timer_outlined,
                  text: course.duration.isEmpty ? '—' : course.duration),
              _Meta(
                icon: Icons.event_seat_outlined,
                text: '${course.seatsAvailable} seats',
                color: course.hasSeats ? AppColors.success : AppColors.error,
              ),
              const _Meta(icon: Icons.arrow_forward, text: 'View details'),
            ],
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
