import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/state_renderers.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../../../models/assignment_model.dart';
import '../../../models/batch_model.dart';
import '../../../services/firestore_service.dart';

/// Screen 11 — create an assignment or quiz.
class CreateAssignmentScreen extends StatefulWidget {
  final List<BatchModel> batches;

  const CreateAssignmentScreen({super.key, required this.batches});

  @override
  State<CreateAssignmentScreen> createState() =>
      _CreateAssignmentScreenState();
}

class _CreateAssignmentScreenState extends State<CreateAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _marks = TextEditingController(text: '20');
  final _instructions = TextEditingController();

  String _type = AssignmentType.assignment;
  BatchModel? _batch;
  DateTime? _dueDate;
  TimeOfDay _dueTime = const TimeOfDay(hour: 23, minute: 59);
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _batch = widget.batches.isNotEmpty ? widget.batches.first : null;
    _dueDate = DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _title.dispose();
    _marks.dispose();
    _instructions.dispose();
    super.dispose();
  }

  DateTime get _dueDateTime {
    final d = _dueDate ?? DateTime.now().add(const Duration(days: 7));
    return DateTime(d.year, d.month, d.day, _dueTime.hour, _dueTime.minute);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _dueTime);
    if (picked != null) setState(() => _dueTime = picked);
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

      await FirebaseService.createAssignment(
        AssignmentModel(
          assignmentId: '',
          batchId: batch.label,
          title: _title.text.trim(),
          type: _type,
          instructions: _instructions.text.trim(),
          maxMarks: int.tryParse(_marks.text.trim()) ?? 0,
          dueDate: _dueDateTime,
        ),
        uids,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '$_type created and ${uids.length} students notified.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _dateLabel {
    final d = _dueDate;
    if (d == null) return 'Select a date';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.batches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('New Assignment')),
        body: const EmptyState(
          message: 'No batches assigned',
          subtitle: 'You need a batch before setting work.',
          icon: Icons.groups_outlined,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('New $_type')),
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
                  // ---- Assignment vs Quiz ----
                  CustomCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Type',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: AssignmentType.assignment,
                              label: Text('Assignment'),
                              icon: Icon(Icons.assignment_outlined),
                            ),
                            ButtonSegment(
                              value: AssignmentType.quiz,
                              label: Text('Quiz'),
                              icon: Icon(Icons.quiz_outlined),
                            ),
                          ],
                          selected: {_type},
                          onSelectionChanged: (s) =>
                              setState(() => _type = s.first),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _title,
                    label: 'Title',
                    hint: 'e.g. Flutter UI Assignment 2',
                    prefixIcon: Icons.title,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Title is required'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  CustomDropdown<BatchModel>(
                    value: _batch,
                    label: 'Target batch',
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
                    controller: _marks,
                    label: 'Maximum marks',
                    hint: 'e.g. 20',
                    prefixIcon: Icons.military_tech_outlined,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null) return 'Enter a number';
                      if (n <= 0 || n > 1000) {
                        return 'Must be between 1 and 1000';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius:
                              BorderRadius.circular(AppColors.radiusField),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Due date',
                              prefixIcon:
                                  Icon(Icons.calendar_today, size: 18),
                            ),
                            child: Text(_dateLabel),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _pickTime,
                          borderRadius:
                              BorderRadius.circular(AppColors.radiusField),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Due time',
                              prefixIcon:
                                  Icon(Icons.schedule, size: 18),
                            ),
                            child: Text(_dueTime.format(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _instructions,
                    label: 'Instructions',
                    hint: 'What should students do, and how is it marked?',
                    prefixIcon: Icons.notes,
                    maxLines: 5,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Instructions are required'
                        : null,
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
                    label: 'Create $_type',
                    icon: Icons.check,
                    expand: true,
                    isLoading: _saving,
                    onPressed: _save,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Students in the batch are notified automatically.',
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
