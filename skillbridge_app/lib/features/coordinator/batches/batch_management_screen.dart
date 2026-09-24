import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/state_renderers.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../../../models/batch_model.dart';
import '../../../models/campus_model.dart';
import '../../../models/course_model.dart';
import '../../../services/firestore_service.dart';

/// Screen 12 — batch management and instructor assignment.
class BatchManagementScreen extends StatefulWidget {
  const BatchManagementScreen({super.key});

  @override
  State<BatchManagementScreen> createState() => _BatchManagementScreenState();
}

class _BatchData {
  final List<BatchModel> batches;
  final List<CourseModel> courses;
  final List<CampusModel> campuses;
  final List<Map<String, dynamic>> instructors;

  const _BatchData(
      this.batches, this.courses, this.campuses, this.instructors);
}

class _BatchManagementScreenState extends State<BatchManagementScreen> {
  late Future<_BatchData> _future;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _reload() => setState(() => _future = _load());

  Future<_BatchData> _load() async {
    final batches = await FirebaseService.fetchAllBatches();
    final courses = await FirebaseService.fetchCourses();
    final campuses = await FirebaseService.fetchCampuses();
    final instructors = await FirebaseService.fetchUsersByRole('instructor');
    return _BatchData(batches, courses, campuses, instructors);
  }

  Future<void> _openCreate(_BatchData data) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateBatchDialog(data: data),
    );
    if (created == true) _reload();
  }

  Future<void> _closeBatch(BatchModel batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Close ${batch.label}?'),
        content: const Text(
          'Closing a batch stops new enrolments. Existing students keep '
          'their timetable, attendance and assignments.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Close batch')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirebaseService.updateBatchStatus(
          batch.batchId, BatchStatus.closed);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not close: $e')));
    }
  }

  Future<void> _reopenBatch(BatchModel batch) async {
    try {
      await FirebaseService.updateBatchStatus(
          batch.batchId, BatchStatus.active);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not reopen: $e')));
    }
  }

  Future<void> _reassign(
      BatchModel batch, List<Map<String, dynamic>> instructors) async {
    if (instructors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No instructor accounts exist yet.')),
      );
      return;
    }

    final chosen = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Assign instructor to ${batch.label}'),
        children: instructors
            .map((i) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, i),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.12),
                      child: Text(
                        (i['name'] ?? '?').toString().isNotEmpty
                            ? i['name'].toString()[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    title: Text((i['name'] ?? 'Instructor').toString()),
                    subtitle: Text((i['email'] ?? '').toString()),
                    trailing: batch.instructorId == i['uid']
                        ? const Icon(Icons.check,
                            color: AppColors.success)
                        : null,
                  ),
                ))
            .toList(),
      ),
    );

    if (chosen == null) return;

    try {
      await FirebaseService.assignInstructor(
        batchDocId: batch.batchId,
        instructorId: chosen['uid'].toString(),
        instructorName: (chosen['name'] ?? '').toString(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${chosen['name']} assigned to '
            '${batch.label}.')),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not assign: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Batch Management')),
      body: SafeArea(
        child: FutureBuilder<_BatchData>(
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
            final shown = _filter == 'All'
                ? data.batches
                : data.batches.where((b) => b.status == _filter).toList();

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          ...['All', ...BatchStatus.all].map((f) {
                            final count = f == 'All'
                                ? data.batches.length
                                : data.batches
                                    .where((b) => b.status == f)
                                    .length;
                            final selected = _filter == f;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text('$f ($count)'),
                                selected: selected,
                                onSelected: (_) =>
                                    setState(() => _filter = f),
                                selectedColor: AppColors.primary,
                                backgroundColor: AppColors.surface,
                                side: BorderSide(
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.border),
                                labelStyle: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                            );
                          }),
                          const Spacer(),
                          CustomButton(
                            label: 'New Batch',
                            icon: Icons.add,
                            onPressed: () => _openCreate(data),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: shown.isEmpty
                          ? EmptyState(
                              message: data.batches.isEmpty
                                  ? 'No batches yet'
                                  : 'Nothing under "$_filter"',
                              subtitle: data.batches.isEmpty
                                  ? 'Create a batch, or seed demo data to '
                                      'get FL-2026-01 with 12 students.'
                                  : 'No batches currently have this status.',
                              icon: Icons.groups_outlined,
                              actionLabel: data.batches.isEmpty
                                  ? 'Create batch'
                                  : 'Show all',
                              onAction: data.batches.isEmpty
                                  ? () => _openCreate(data)
                                  : () => setState(() => _filter = 'All'),
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 8, 20, 24),
                              itemCount: shown.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, index) => _BatchCard(
                                batch: shown[index],
                                onClose: () => _closeBatch(shown[index]),
                                onReopen: () => _reopenBatch(shown[index]),
                                onReassign: () => _reassign(
                                    shown[index], data.instructors),
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

class _BatchCard extends StatelessWidget {
  final BatchModel batch;
  final VoidCallback onClose;
  final VoidCallback onReopen;
  final VoidCallback onReassign;

  const _BatchCard({
    required this.batch,
    required this.onClose,
    required this.onReopen,
    required this.onReassign,
  });

  @override
  Widget build(BuildContext context) {
    final active = batch.isActive;
    final color = active ? AppColors.success : AppColors.textSecondary;

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(batch.label,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontSize: 16)),
                    const SizedBox(height: 3),
                    Text(
                      '${batch.courseName} · ${batch.campusName}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(batch.status,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Meta(
                  icon: Icons.person_outline,
                  text: batch.instructorName.isEmpty
                      ? 'No instructor'
                      : batch.instructorName,
                  color: batch.instructorName.isEmpty
                      ? AppColors.warning
                      : null),
              _Meta(
                  icon: Icons.event_seat_outlined,
                  text: '${batch.enrolledCount}/${batch.maxSeats} seats'),
              _Meta(
                  icon: Icons.event_outlined,
                  text: 'Starts ${batch.startDate}'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CustomButton.outlined(
                label: 'Re-assign instructor',
                icon: Icons.swap_horiz,
                onPressed: onReassign,
              ),
              const Spacer(),
              if (active)
                TextButton.icon(
                  onPressed: onClose,
                  icon: const Icon(Icons.lock_outline, size: 17),
                  label: const Text('Close batch'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.error),
                )
              else
                TextButton.icon(
                  onPressed: onReopen,
                  icon: const Icon(Icons.lock_open, size: 17),
                  label: const Text('Reopen'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.success),
                ),
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
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 5),
        Text(text,
            style: TextStyle(
                fontSize: 12.5, color: c, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

/// Batch creation form.
class _CreateBatchDialog extends StatefulWidget {
  final _BatchData data;
  const _CreateBatchDialog({required this.data});

  @override
  State<_CreateBatchDialog> createState() => _CreateBatchDialogState();
}

class _CreateBatchDialogState extends State<_CreateBatchDialog> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController(text: 'FL-2026-01');
  final _seats = TextEditingController(text: '30');

  CourseModel? _course;
  CampusModel? _campus;
  Map<String, dynamic>? _instructor;
  DateTime _startDate = DateTime.now().add(const Duration(days: 30));

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _course = d.courses.isNotEmpty ? d.courses.first : null;
    _campus = d.campuses.isNotEmpty ? d.campuses.first : null;
    _instructor = d.instructors.isNotEmpty ? d.instructors.first : null;
  }

  @override
  void dispose() {
    _code.dispose();
    _seats.dispose();
    super.dispose();
  }

  String get _dateLabel =>
      '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-'
      '${_startDate.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_course == null || _campus == null) {
      setState(() => _error = 'Choose a course and a campus.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await FirebaseService.createBatch(BatchModel(
        batchId: _code.text.trim(),
        batchCode: _code.text.trim(),
        courseId: _course!.courseId,
        courseName: _course!.title,
        campusId: _campus!.campusId,
        campusName: _campus!.name,
        instructorId: (_instructor?['uid'] ?? '').toString(),
        instructorName: (_instructor?['name'] ?? '').toString(),
        seats: int.tryParse(_seats.text.trim()) ?? 0,
        startDate: _dateLabel,
        status: BatchStatus.active,
      ));

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Batch ${_code.text.trim()} created.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;

    return AlertDialog(
      title: const Text('Create batch'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomDropdown<CourseModel>(
                  value: _course,
                  label: 'Course',
                  prefixIcon: Icons.menu_book_outlined,
                  items: d.courses
                      .map((c) => DropdownMenuItem(
                          value: c, child: Text(c.title)))
                      .toList(),
                  onChanged: (c) => setState(() => _course = c),
                  validator: (v) => v == null ? 'Choose a course' : null,
                ),
                const SizedBox(height: 14),
                CustomDropdown<CampusModel>(
                  value: _campus,
                  label: 'Campus',
                  prefixIcon: Icons.apartment,
                  items: d.campuses
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text('${c.name} · ${c.province}')))
                      .toList(),
                  onChanged: (c) => setState(() => _campus = c),
                  validator: (v) => v == null ? 'Choose a campus' : null,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _code,
                  label: 'Batch code',
                  hint: 'e.g. FL-2026-01',
                  prefixIcon: Icons.badge_outlined,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Batch code is required'
                      : null,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _seats,
                  label: 'Total seats',
                  hint: 'e.g. 30',
                  prefixIcon: Icons.event_seat_outlined,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null) return 'Enter a number';
                    if (n <= 0 || n > 500) return 'Must be 1–500';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _pickDate,
                  borderRadius:
                      BorderRadius.circular(AppColors.radiusField),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Start date',
                      prefixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(_dateLabel),
                  ),
                ),
                const SizedBox(height: 14),
                if (d.instructors.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft,
                      borderRadius:
                          BorderRadius.circular(AppColors.radiusField),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: AppColors.warning),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No instructor accounts yet — you can assign '
                            'one later from the batch list.',
                            style: TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  CustomDropdown<Map<String, dynamic>>(
                    value: _instructor,
                    label: 'Assign instructor',
                    prefixIcon: Icons.person_outline,
                    items: d.instructors
                        .map((i) => DropdownMenuItem(
                            value: i,
                            child:
                                Text((i['name'] ?? 'Instructor').toString())))
                        .toList(),
                    onChanged: (i) => setState(() => _instructor = i),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: AppColors.errorSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12.5)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        CustomButton(
          label: 'Create batch',
          icon: Icons.check,
          isLoading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}
