import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/demo_credentials.dart';
import '../../../core/utils/state_renderers.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../../../models/campus_model.dart';
import '../../../models/notice_model.dart';
import '../../../services/firestore_service.dart';
import '../../../services/seed_service.dart';

/// Screen 13 — campus-wide notice board.
class PostCampusNoticeScreen extends StatefulWidget {
  const PostCampusNoticeScreen({super.key});

  @override
  State<PostCampusNoticeScreen> createState() =>
      _PostCampusNoticeScreenState();
}

class _PostCampusNoticeScreenState extends State<PostCampusNoticeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();

  late Future<List<CampusModel>> _campusesFuture;
  CampusModel? _campus;
  String _audience = NoticeAudience.campus;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _campusesFuture = _loadCampuses();
  }

  Future<List<CampusModel>> _loadCampuses() async {
    final campuses = await FirebaseService.fetchCampuses();
    if (campuses.isNotEmpty && mounted) {
      // Default to Lahore, the coordinator's own campus.
      _campus = campuses.firstWhere(
        (c) => c.name == SeedService.demoCampus,
        orElse: () => campuses.first,
      );
    }
    return campuses;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_campus == null) {
      setState(() => _error = 'Choose a campus.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await FirebaseService.postCampusNotice(
        notice: NoticeModel(
          noticeId: '',
          campusId: _campus!.campusId,
          batchId: '',
          title: _title.text.trim(),
          content: _content.text.trim(),
          postedBy: DemoCredentials.coordinator.name,
          targetAudience: _audience,
        ),
        campusName: _campus!.name,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_audience == NoticeAudience.campus
              ? 'Notice posted to ${_campus!.name}.'
              : 'Notice posted to all campuses.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Notice')),
      body: SafeArea(
        child: FutureBuilder<List<CampusModel>>(
          future: _campusesFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const LoadingState(message: 'Loading campuses…');
            }
            if (snap.hasError) {
              return ErrorRetry(
                message: snap.error.toString(),
                onRetry: () =>
                    setState(() => _campusesFuture = _loadCampuses()),
              );
            }

            final campuses = snap.data!;
            if (campuses.isEmpty) {
              return const EmptyState(
                message: 'No campuses yet',
                subtitle:
                    'Seed demo data first — notices are posted against a '
                    'campus.',
                icon: Icons.apartment,
              );
            }

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      CustomDropdown<CampusModel>(
                        value: _campus,
                        label: 'Campus',
                        prefixIcon: Icons.apartment,
                        items: campuses
                            .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text('${c.name} · ${c.province}')))
                            .toList(),
                        onChanged: (c) => setState(() => _campus = c),
                        validator: (v) =>
                            v == null ? 'Choose a campus' : null,
                      ),
                      const SizedBox(height: 16),

                      CustomCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Audience',
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 12),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: NoticeAudience.campus,
                                  label: Text('This campus'),
                                  icon: Icon(Icons.apartment),
                                ),
                                ButtonSegment(
                                  value: 'all',
                                  label: Text('All campuses'),
                                  icon: Icon(Icons.public),
                                ),
                              ],
                              selected: {_audience},
                              onSelectionChanged: (s) =>
                                  setState(() => _audience = s.first),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _audience == NoticeAudience.campus
                                  ? 'Students and instructors at the selected '
                                      'campus are notified.'
                                  : 'Everyone in the system is notified.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      CustomTextField(
                        controller: _title,
                        label: 'Title',
                        hint: 'e.g. Campus closed on Friday',
                        prefixIcon: Icons.title,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Title is required'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      CustomTextField(
                        controller: _content,
                        label: 'Notice',
                        hint: 'What does everyone need to know?',
                        prefixIcon: Icons.campaign_outlined,
                        maxLines: 5,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Notice text is required'
                            : null,
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.errorSoft,
                            borderRadius: BorderRadius.circular(
                                AppColors.radiusField),
                            border: Border.all(
                                color: AppColors.error
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppColors.error, size: 19),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(_error!,
                                    style: const TextStyle(
                                        color: AppColors.error,
                                        fontSize: 12.5)),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      CustomButton(
                        label: 'Post notice',
                        icon: Icons.send_rounded,
                        expand: true,
                        isLoading: _saving,
                        onPressed: _save,
                      ),
                      const SizedBox(height: 12),
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
