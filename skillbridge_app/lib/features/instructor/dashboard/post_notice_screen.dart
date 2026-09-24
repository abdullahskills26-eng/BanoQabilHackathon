import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/demo_credentials.dart';
import '../../../core/utils/state_renderers.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../../../models/batch_model.dart';
import '../../../models/notice_model.dart';
import '../../../services/firestore_service.dart';

/// Screen 10 (cont.) — post a class notice.
class PostNoticeScreen extends StatefulWidget {
  final List<BatchModel> batches;

  const PostNoticeScreen({super.key, required this.batches});

  @override
  State<PostNoticeScreen> createState() => _PostNoticeScreenState();
}

class _PostNoticeScreenState extends State<PostNoticeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();

  BatchModel? _batch;
  bool _saving = false;
  String? _error;

  static const _quickTemplates = [
    'Lab shifted to Room 2 today.',
    'Class cancelled — we will reschedule.',
    'Bring your laptops to the next session.',
    'Quiz next week: revise the last three modules.',
  ];

  @override
  void initState() {
    super.initState();
    _batch = widget.batches.isNotEmpty ? widget.batches.first : null;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final batch = _batch;
    if (batch == null) {
      setState(() => _error = 'Choose a batch.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final students = await FirebaseService.fetchBatchStudents(batch);
      final uids = students.map((s) => s['uid'].toString()).toList();

      await FirebaseService.postNotice(
        NoticeModel(
          noticeId: '',
          campusId: batch.campusName,
          batchId: batch.label,
          title: _title.text.trim(),
          content: _content.text.trim(),
          postedBy: batch.instructorName.isEmpty
              ? DemoCredentials.instructor.name
              : batch.instructorName,
          targetAudience: NoticeAudience.batch,
        ),
        uids,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Notice posted · ${uids.length} students notified.')),
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
    if (widget.batches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Post Notice')),
        body: const EmptyState(
          message: 'No batches assigned',
          subtitle: 'You need a batch before posting a class notice.',
          icon: Icons.groups_outlined,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Post Class Notice')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  CustomDropdown<BatchModel>(
                    value: _batch,
                    label: 'Batch',
                    prefixIcon: Icons.groups,
                    items: widget.batches
                        .map((b) => DropdownMenuItem(
                            value: b,
                            child: Text('${b.label} · ${b.courseName}')))
                        .toList(),
                    onChanged: (b) => setState(() => _batch = b),
                    validator: (v) => v == null ? 'Choose a batch' : null,
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _title,
                    label: 'Title',
                    hint: 'e.g. Room change',
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
                    hint: 'What do students need to know?',
                    prefixIcon: Icons.campaign_outlined,
                    maxLines: 4,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Notice text is required'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  CustomCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quick templates',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _quickTemplates
                              .map((t) => ActionChip(
                                    label: Text(
                                      t.length > 34
                                          ? '${t.substring(0, 32)}…'
                                          : t,
                                      style: const TextStyle(fontSize: 11.5),
                                    ),
                                    onPressed: () =>
                                        setState(() => _content.text = t),
                                    backgroundColor: AppColors.warningSoft,
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
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
                            child: Text(_error!,
                                style: const TextStyle(
                                    color: AppColors.error, fontSize: 12.5)),
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
                  const SizedBox(height: 8),
                  Text(
                    'Every student in the batch receives a notification.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
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
