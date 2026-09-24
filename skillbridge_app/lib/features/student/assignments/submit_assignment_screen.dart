import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../../../models/assignment_model.dart';
import '../../../models/submission_model.dart';
import '../../../services/firestore_service.dart';
import '../../../services/supabase_storage_service.dart';

/// Screen 8b — submit work for one assignment.
///
/// Uploads the chosen file to `submissions/{assignmentId}/{uid}` in Firebase
/// Storage, then writes the submission metadata to Firestore.
class SubmitAssignmentScreen extends StatefulWidget {
  final AssignmentModel assignment;
  final SubmissionModel? existing;

  const SubmitAssignmentScreen({
    super.key,
    required this.assignment,
    this.existing,
  });

  @override
  State<SubmitAssignmentScreen> createState() => _SubmitAssignmentScreenState();
}

class _SubmitAssignmentScreenState extends State<SubmitAssignmentScreen> {
  final _textAnswer = TextEditingController();

  String? _fileName;
  Uint8List? _fileBytes;
  int? _fileSize;

  bool _submitting = false;

  /// True only while bytes are going to Supabase, so the button can say
  /// "Uploading file…" rather than a generic spinner.
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _textAnswer.text = widget.existing?.textAnswer ?? '';
  }

  @override
  void dispose() {
    _textAnswer.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      // withData is required on web: the browser returns bytes and
      // PlatformFile.path is always null there.
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        withData: true,
        allowedExtensions: const [
          'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx',
          'zip', 'txt', 'jpg', 'jpeg', 'png',
        ],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (!mounted) return;
      setState(() {
        _fileName = file.name;
        _fileBytes = file.bytes;
        _fileSize = file.size;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not read that file: $e');
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _submit() async {
    final text = _textAnswer.text.trim();
    final hasFile = _fileBytes != null && _fileName != null;

    if (text.isEmpty && !hasFile) {
      setState(() => _error = 'Add a written answer or attach a file.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final uid = FirebaseService.currentUid;

      // `fileUrl` holds the Supabase storage PATH, not a link. The bucket is
      // private, so a viewable URL is signed on demand at read time.
      String storagePath = widget.existing?.fileUrl ?? '';
      String storedName = widget.existing?.fileName ?? '';

      if (hasFile) {
        setState(() => _uploading = true);
        final stored = await SupabaseStorageService.uploadAssignmentFile(
          uid: uid,
          assignmentId: widget.assignment.assignmentId,
          bytes: _fileBytes!,
          fileName: _fileName!,
        );
        storagePath = stored.path;
        storedName = stored.fileName;
        if (mounted) setState(() => _uploading = false);
      }

      // Late once the due date has passed.
      final status = widget.assignment.isOverdue
          ? SubmissionStatus.late
          : SubmissionStatus.submitted;

      // Only the path and metadata go to Firestore — never the file bytes.
      await FirebaseService.saveSubmission(
        SubmissionModel(
          submissionId: '',
          assignmentId: widget.assignment.assignmentId,
          uid: uid,
          textAnswer: text,
          fileUrl: storagePath,
          fileName: storedName,
          submittedAt: DateTime.now(),
          status: status,
        ),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == SubmissionStatus.late
              ? 'Submitted late — your instructor has been notified.'
              : 'Assignment submitted successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _uploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;

    return Scaffold(
      appBar: AppBar(title: const Text('Submit Assignment')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                AccentCard(
                  accent: a.isOverdue ? AppColors.error : AppColors.primary,
                  accentSoft:
                      a.isOverdue ? AppColors.errorSoft : AppColors.primarySoft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        'Due ${a.formattedDueDate} · ${a.maxMarks} marks'
                        '${a.isOverdue ? ' · OVERDUE' : ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (a.instructions.isNotEmpty) ...[
                  CustomCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Instructions',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),
                        Text(a.instructions,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                CustomCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your answer',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 14),
                      CustomTextField(
                        controller: _textAnswer,
                        label: 'Written answer',
                        hint: 'Type your answer, notes or a repository link…',
                        maxLines: 6,
                      ),
                      const SizedBox(height: 20),
                      Text('Attachment',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      if (_fileName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius:
                                BorderRadius.circular(AppColors.radiusField),
                            border: Border.all(
                                color: AppColors.primary
                                    .withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.insert_drive_file_outlined,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(_fileName!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13)),
                                    if (_fileSize != null)
                                      Text(_formatSize(_fileSize!),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                tooltip: 'Remove file',
                                onPressed: _submitting
                                    ? null
                                    : () => setState(() {
                                          _fileName = null;
                                          _fileBytes = null;
                                          _fileSize = null;
                                        }),
                              ),
                            ],
                          ),
                        )
                      else
                        CustomButton.outlined(
                          label: 'Choose file or photo',
                          icon: Icons.upload_file_outlined,
                          onPressed: _submitting ? null : _pickFile,
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'PDF, DOC, PPT, XLS, ZIP, TXT, JPG or PNG.',
                        style: Theme.of(context).textTheme.bodySmall,
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
                  label: _uploading ? 'Uploading file…' : 'Submit',
                  icon: Icons.send_rounded,
                  expand: true,
                  isLoading: _submitting,
                  onPressed: _submit,
                ),
                if (_uploading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(minHeight: 3),
                  const SizedBox(height: 6),
                  Text(
                    'Sending ${_fileName ?? 'file'} to secure storage…',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
