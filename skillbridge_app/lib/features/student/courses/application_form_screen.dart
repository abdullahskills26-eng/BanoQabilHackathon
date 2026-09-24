import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../../../models/application_model.dart';
import '../../../models/campus_model.dart';
import '../../../models/course_model.dart';
import '../../../services/firestore_service.dart';
import 'application_status_screen.dart';

/// Screen 5 — course application form.
class ApplicationFormScreen extends StatefulWidget {
  final CourseModel course;
  final List<CampusModel> campuses;
  final CampusModel? preselectedCampus;

  const ApplicationFormScreen({
    super.key,
    required this.course,
    required this.campuses,
    this.preselectedCampus,
  });

  @override
  State<ApplicationFormScreen> createState() => _ApplicationFormScreenState();
}

class _ApplicationFormScreenState extends State<ApplicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _cnic = TextEditingController();
  final _city = TextEditingController();
  final _motivation = TextEditingController();

  String? _education;
  CampusModel? _campus;
  bool _submitting = false;
  String? _error;

  static const List<String> _educationLevels = [
    'Matric',
    'Intermediate',
    'Diploma',
    'Bachelors',
    'Masters',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _campus = widget.preselectedCampus ??
        (widget.campuses.isNotEmpty ? widget.campuses.first : null);
  }

  @override
  void dispose() {
    _fullName.dispose();
    _cnic.dispose();
    _city.dispose();
    _motivation.dispose();
    super.dispose();
  }

  String? _required(String? v, String field) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  /// Pakistani CNIC: 13 digits, with or without dashes.
  String? _validateCnic(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'CNIC is required';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 13) return 'CNIC must be 13 digits';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_campus == null) {
      setState(() => _error = 'Please choose a campus.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final application = ApplicationModel(
        applicationId: '',
        uid: FirebaseService.currentUid,
        fullName: _fullName.text.trim(),
        cnic: _cnic.text.trim(),
        education: _education ?? '',
        city: _city.text.trim(),
        courseId: widget.course.courseId,
        courseName: widget.course.title,
        campusId: _campus!.campusId,
        campusName: _campus!.name,
        motivation: _motivation.text.trim(),
      );

      await FirebaseService.submitApplication(application);
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ApplicationStatusScreen()),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application submitted successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Course Application')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  AccentCard(
                    accent: AppColors.primary,
                    accentSoft: AppColors.primarySoft,
                    child: Row(
                      children: [
                        const Icon(Icons.menu_book_rounded,
                            color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.course.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium),
                              Text(
                                '${widget.course.level} · '
                                '${widget.course.duration}',
                                style:
                                    Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  Text('Your details',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _fullName,
                    label: 'Full Name',
                    prefixIcon: Icons.person_outline,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => _required(v, 'Full name'),
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _cnic,
                    label: 'CNIC',
                    hint: '35202-1234567-1',
                    prefixIcon: Icons.badge_outlined,
                    keyboardType: TextInputType.number,
                    validator: _validateCnic,
                  ),
                  const SizedBox(height: 16),

                  CustomDropdown<String>(
                    value: _education,
                    label: 'Education Level',
                    prefixIcon: Icons.school_outlined,
                    items: _educationLevels
                        .map((e) =>
                            DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _education = v),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Education level is required'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _city,
                    label: 'City',
                    prefixIcon: Icons.location_city_outlined,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => _required(v, 'City'),
                  ),
                  const SizedBox(height: 16),

                  CustomDropdown<CampusModel>(
                    value: _campus,
                    label: 'Preferred Campus',
                    prefixIcon: Icons.apartment,
                    items: widget.campuses
                        .map((c) => DropdownMenuItem(
                            value: c, child: Text('${c.name} · ${c.province}')))
                        .toList(),
                    onChanged: (v) => setState(() => _campus = v),
                    validator: (v) =>
                        v == null ? 'Please choose a campus' : null,
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _motivation,
                    label: 'Motivation',
                    hint: 'Why do you want to take this course?',
                    prefixIcon: Icons.lightbulb_outline,
                    maxLines: 4,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Motivation is required';
                      }
                      if (v.trim().length < 20) {
                        return 'Please write at least 20 characters';
                      }
                      return null;
                    },
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.errorSoft,
                        borderRadius:
                            BorderRadius.circular(AppColors.radiusField),
                        border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.error, size: 19),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                  color: AppColors.error, fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 26),
                  CustomButton(
                    label: 'Submit Application',
                    icon: Icons.send_rounded,
                    expand: true,
                    isLoading: _submitting,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
