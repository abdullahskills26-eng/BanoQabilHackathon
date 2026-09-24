import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/state_renderers.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../models/attendance_record_model.dart';
import '../../../models/batch_model.dart';
import '../../../services/firestore_service.dart';

/// Screen 10 (cont.) — one-tap attendance marking.
class MarkAttendanceScreen extends StatefulWidget {
  final List<BatchModel> batches;

  const MarkAttendanceScreen({super.key, required this.batches});

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  BatchModel? _batch;
  DateTime _date = DateTime.now();
  late Future<List<Map<String, dynamic>>> _future;

  /// uid -> status, edited locally until Save.
  final Map<String, String> _statuses = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _batch = widget.batches.isNotEmpty ? widget.batches.first : null;
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final batch = _batch;
    if (batch == null) return [];

    final students = await FirebaseService.fetchBatchStudents(batch);

    // Preload anything already marked for this date so re-opening the screen
    // shows the saved state rather than resetting everyone.
    final existing = await FirebaseService.fetchBatchAttendance(
      batchId: batch.label,
      date: _date,
    );

    _statuses
      ..clear()
      ..addAll({
        for (final s in students)
          s['uid'].toString(): existing?.statusMap[s['uid'].toString()] ??
              InstructorAttendanceStatus.present,
      });

    return students;
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = picked);
      _reload();
    }
  }

  void _markAllPresent() {
    setState(() {
      for (final uid in _statuses.keys.toList()) {
        _statuses[uid] = InstructorAttendanceStatus.present;
      }
    });
  }

  Future<void> _save() async {
    final batch = _batch;
    if (batch == null || _statuses.isEmpty) return;

    setState(() => _saving = true);
    try {
      await FirebaseService.saveBatchAttendance(
        batchId: batch.label,
        date: _date,
        statusMap: Map<String, String>.from(_statuses),
      );
      await FirebaseService.recalculateAttendancePercentages(
          _statuses.keys.toList());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Attendance saved for ${_statuses.length} students.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _dateLabel =>
      '${_date.day.toString().padLeft(2, '0')}/'
      '${_date.month.toString().padLeft(2, '0')}/${_date.year}';

  @override
  Widget build(BuildContext context) {
    if (widget.batches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mark Attendance')),
        body: const EmptyState(
          message: 'No batches assigned',
          subtitle: 'You need a batch before attendance can be marked.',
          icon: Icons.groups_outlined,
        ),
      );
    }

    final present = _statuses.values
        .where((s) => s == InstructorAttendanceStatus.present)
        .length;
    final absent = _statuses.values
        .where((s) => s == InstructorAttendanceStatus.absent)
        .length;
    final late = _statuses.values
        .where((s) => s == InstructorAttendanceStatus.late)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Mark Attendance')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: CustomCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final batchField =
                                DropdownButtonFormField<BatchModel>(
                              initialValue: _batch,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Batch',
                                prefixIcon: Icon(Icons.groups, size: 20),
                              ),
                              items: widget.batches
                                  .map((b) => DropdownMenuItem(
                                      value: b,
                                      child: Text(
                                          '${b.label} · ${b.courseName}')))
                                  .toList(),
                              onChanged: (b) {
                                setState(() => _batch = b);
                                _reload();
                              },
                            );

                            final dateField = InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(
                                  AppColors.radiusField),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Date',
                                  prefixIcon: Icon(
                                      Icons.calendar_today, size: 18),
                                ),
                                child: Text(_dateLabel),
                              ),
                            );

                            if (constraints.maxWidth > 560) {
                              return Row(
                                children: [
                                  Expanded(flex: 3, child: batchField),
                                  const SizedBox(width: 12),
                                  Expanded(flex: 2, child: dateField),
                                ],
                              );
                            }
                            return Column(children: [
                              batchField,
                              const SizedBox(height: 12),
                              dateField,
                            ]);
                          },
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _Tally(
                                label: 'P',
                                count: present,
                                color: AppColors.success),
                            const SizedBox(width: 8),
                            _Tally(
                                label: 'A',
                                count: absent,
                                color: AppColors.error),
                            const SizedBox(width: 8),
                            _Tally(
                                label: 'L',
                                count: late,
                                color: AppColors.warning),
                            const Spacer(),
                            CustomButton.outlined(
                              label: 'Mark all present',
                              icon: Icons.done_all,
                              onPressed:
                                  _statuses.isEmpty ? null : _markAllPresent,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _future,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const ShimmerListSkeleton(itemCount: 6);
                      }
                      if (snap.hasError) {
                        return ErrorRetry(
                            message: snap.error.toString(),
                            onRetry: _reload);
                      }

                      final students = snap.data!;
                      if (students.isEmpty) {
                        return const EmptyState(
                          message: 'No students in this batch',
                          subtitle:
                              'Students appear once a coordinator enrols '
                              'them into this batch.',
                          icon: Icons.person_off_outlined,
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                        itemCount: students.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final student = students[index];
                          final uid = student['uid'].toString();
                          return _StudentRow(
                            name: (student['name'] ?? 'Student').toString(),
                            photoUrl:
                                (student['photoUrl'] ?? '').toString(),
                            rollNo: uid,
                            status: _statuses[uid] ??
                                InstructorAttendanceStatus.present,
                            onCycle: () => setState(() {
                              _statuses[uid] =
                                  InstructorAttendanceStatus.next(
                                      _statuses[uid] ??
                                          InstructorAttendanceStatus.present);
                            }),
                            onSet: (s) =>
                                setState(() => _statuses[uid] = s),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: CustomButton(
            label: 'Save attendance',
            icon: Icons.save_outlined,
            expand: true,
            isLoading: _saving,
            onPressed: _statuses.isEmpty ? null : _save,
          ),
        ),
      ),
    );
  }
}

class _Tally extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _Tally(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
      ),
      child: Text('$label $count',
          style: TextStyle(
              color: color, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final String name;
  final String photoUrl;
  final String rollNo;
  final String status;
  final VoidCallback onCycle;
  final ValueChanged<String> onSet;

  const _StudentRow({
    required this.name,
    required this.photoUrl,
    required this.rollNo,
    required this.status,
    required this.onCycle,
    required this.onSet,
  });

  Color _colorFor(String s) {
    switch (s) {
      case InstructorAttendanceStatus.present:
        return AppColors.success;
      case InstructorAttendanceStatus.absent:
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: onCycle,
      child: Row(
        children: [
          // Falls back to an initial when there is no profile picture.
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            foregroundImage:
                photoUrl.isEmpty ? null : NetworkImage(photoUrl),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text(rollNo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: InstructorAttendanceStatus.all.map((s) {
              final selected = status == s;
              final color = _colorFor(s);
              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: InkWell(
                  onTap: () => onSet(s),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? color
                          : color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: selected
                              ? color
                              : color.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      InstructorAttendanceStatus.letter(s),
                      style: TextStyle(
                        color: selected ? Colors.white : color,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
