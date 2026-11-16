import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/components/empty_state.dart';
import '../../../core/components/skeleton_loader.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/services/cloudflare_r2_service.dart';
import '../../../core/services/cloud_storage_service.dart';
import '../../../core/services/session_draft_service.dart';
import '../../../core/utils/file_download_helper.dart';
import '../../../core/utils/image_compress_helper.dart';
import '../../auth/application/auth_provider.dart';
import '../data/submissions_repository.dart';

class SubmissionsScreen extends ConsumerStatefulWidget {
  final String assignmentId;

  const SubmissionsScreen({super.key, required this.assignmentId});

  @override
  ConsumerState<SubmissionsScreen> createState() => _SubmissionsScreenState();
}

class _SubmissionsScreenState extends ConsumerState<SubmissionsScreen> {
  final TextEditingController _textResponseController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String? _pickedFileName;
  int _pickedFileSize = 0;
  String? _pickedFilePath;
  Uint8List? _pickedFileBytes;

  String? _pickedImageName;
  int _pickedImageSize = 0;
  String? _pickedImagePath;
  Uint8List? _pickedImageBytes;

  bool _isSubmitting = false;
  bool _isEditingExisting = false;
  double _uploadProgress = 0.0;
  String? _uploadStatusMessage;
  final SessionDraftDisposer _draftDisposer = SessionDraftDisposer();

  @override
  void initState() {
    super.initState();
    final formId = 'submission_${widget.assignmentId}';
    _draftDisposer.add(
      _textResponseController.bindSessionDraft(
        formId: formId,
        fieldKey: 'text',
        onDraftRestored: () => setState(() {}),
      ),
    );
    _draftDisposer.add(
      _linkController.bindSessionDraft(
        formId: formId,
        fieldKey: 'link',
        onDraftRestored: () => setState(() {}),
      ),
    );
    _draftDisposer.add(
      _notesController.bindSessionDraft(
        formId: formId,
        fieldKey: 'notes',
        onDraftRestored: () => setState(() {}),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        SharedPreferences? prefs;
        try {
          prefs = await SharedPreferences.getInstance();
        } catch (_) {}
        final savedUserId = prefs?.getString('auth_session_user_id');
        final user = ref.read(authProvider);
        final studentId = user?.id ?? savedUserId ?? 'S-100-0001';

        await DatabaseHelper().syncCloudSubmissionsToLocal(
          assignmentId: _parsedId,
          force: true,
        );
        if (mounted) {
          ref.invalidate(
            studentSubmissionProvider((
              assignmentId: _parsedId,
              studentId: studentId,
            )),
          );
          ref.invalidate(assignmentDetailProvider(_parsedId));
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _draftDisposer.dispose();
    _textResponseController.dispose();
    _linkController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int get _parsedId => int.tryParse(widget.assignmentId) ?? 1;

  bool _isImageFile(String? name) {
    if (name == null || name.isEmpty) return false;
    final ext = name.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(ext);
  }

  Future<void> _pickAttachment() async {
    try {
      final files = await FilePicker.pickFiles();
      if (files.isNotEmpty) {
        final file = files.first;
        final size = await file.length();
        if (size <= 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Selected file is empty (0 bytes). Please choose a valid file.',
                ),
              ),
            );
          }
          return;
        }
        if (size > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'File size (${_formatFileSize(size)}) exceeds the 10 MB limit. Please select a file under 10 MB.',
                ),
                backgroundColor: AppTheme.error,
              ),
            );
          }
          return;
        }
        Uint8List? bytes;
        try {
          bytes = await file.readAsBytes();
        } catch (_) {}

        final isImage = _isImageFile(file.name);
        Uint8List? processedBytes = bytes;
        if (isImage && bytes != null) {
          try {
            processedBytes = await ImageCompressHelper.compressImage(
              bytes,
              maxDimension: 1200,
            );
          } catch (_) {
            processedBytes = bytes;
          }
        }

        final finalSize = processedBytes?.lengthInBytes ?? size;
        setState(() {
          _pickedFileName = file.name;
          _pickedFileSize = finalSize;
          _pickedFilePath = file.path;
          _pickedFileBytes = processedBytes;
          if (isImage) {
            _pickedImageName = file.name;
            _pickedImageSize = finalSize;
            _pickedImagePath = file.path;
            _pickedImageBytes = processedBytes;
          } else {
            _pickedImageName = null;
            _pickedImageSize = 0;
            _pickedImagePath = null;
            _pickedImageBytes = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick file: $e')));
      }
    }
  }

  void _removeAttachment() {
    setState(() {
      _pickedFileName = null;
      _pickedFileSize = 0;
      _pickedFilePath = null;
      _pickedFileBytes = null;
      _pickedImageName = null;
      _pickedImageSize = 0;
      _pickedImagePath = null;
      _pickedImageBytes = null;
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'No due date';
    try {
      final dt = DateTime.parse(isoString);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} $hour:$minute $amPm';
    } catch (_) {
      return isoString;
    }
  }

  static const Duration gracePeriod = Duration(days: 3);

  bool _isOverdue(String? isoString) {
    if (isoString == null || isoString.isEmpty) return false;
    try {
      final due = DateTime.parse(isoString);
      return DateTime.now().isAfter(due);
    } catch (_) {
      return false;
    }
  }

  bool _isGracePeriodExpired(String? isoString) {
    if (isoString == null || isoString.isEmpty) return false;
    try {
      final due = DateTime.parse(isoString);
      final graceEnd = due.add(gracePeriod);
      return DateTime.now().isAfter(graceEnd);
    } catch (_) {
      return false;
    }
  }

  DateTime? _getGracePeriodEnd(String? isoString) {
    if (isoString == null || isoString.isEmpty) return null;
    try {
      final due = DateTime.parse(isoString);
      return due.add(gracePeriod);
    } catch (_) {
      return null;
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $amPm';
  }

  void _confirmAndSubmit(Assignment assignment, Submission? existing) {
    final canResubmit = existing?.status == 'resubmission_allowed';
    final isGraceExpired = _isGracePeriodExpired(assignment.dueDate);

    if (existing != null && !canResubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Submission locked: Your teacher has not allowed resubmission.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (isGraceExpired && existing == null && !canResubmit) {
      final graceEnd = _getGracePeriodEnd(assignment.dueDate);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Submission closed: The deadline passed and the 3-day grace period ended on ${_formatDate(graceEnd?.toIso8601String())}.',
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final isEditing = _isEditingExisting || canResubmit;
    final link = _linkController.text.trim();
    final hasAttachment = _pickedFileName != null || _pickedImageName != null;
    final hasExistingAttachment =
        (existing?.fileName != null || existing?.imagePath != null) && isEditing;
    final hasExistingLink =
        existing?.contentLink != null && existing!.contentLink!.isNotEmpty && isEditing;

    final hasContent =
        hasAttachment ||
        hasExistingAttachment ||
        link.isNotEmpty ||
        hasExistingLink;

    if (!hasContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please attach a file or provide a project link.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final isLate = _isOverdue(assignment.dueDate);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isLate
                      ? AppTheme.error.withValues(alpha: 0.15)
                      : AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isLate
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  color: isLate ? AppTheme.error : AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isEditingExisting ? 'Confirm Update' : 'Confirm Submission',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isLate
                          ? AppTheme.error.withValues(alpha: 0.12)
                          : AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isLate
                            ? AppTheme.error.withValues(alpha: 0.3)
                            : AppTheme.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isLate
                              ? Icons.access_time_filled
                              : Icons.check_circle,
                          size: 18,
                          color: isLate ? AppTheme.error : AppTheme.success,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isLate
                                    ? 'LATE SUBMISSION WARNING'
                                    : 'ON-TIME SUBMISSION',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isLate
                                      ? AppTheme.error
                                      : AppTheme.success,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isLate
                                    ? 'The deadline was ${_formatDate(assignment.dueDate)}. Your activity will be marked as LATE.'
                                    : 'Due date: ${_formatDate(assignment.dueDate)}.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isLate
                                      ? AppTheme.error
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Included in this submission:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (_pickedFileName != null ||
                      _pickedImageName != null ||
                      (hasExistingAttachment && _isEditingExisting)) ...[
                    _buildSummaryItem(
                      icon:
                          _isImageFile(
                            _pickedFileName ??
                                _pickedImageName ??
                                existing?.fileName ??
                                existing?.imagePath,
                          )
                          ? Icons.image_outlined
                          : Icons.insert_drive_file_outlined,
                      label: 'Attachment',
                      detail:
                          _pickedFileName ??
                          _pickedImageName ??
                          existing?.fileName ??
                          existing?.imagePath ??
                          'File attached',
                    ),
                    const SizedBox(height: 6),
                  ],

                  if (link.isNotEmpty ||
                      (hasExistingLink && _isEditingExisting)) ...[
                    _buildSummaryItem(
                      icon: Icons.link,
                      label: 'Project Link',
                      detail: link.isNotEmpty
                          ? link
                          : (existing?.contentLink ?? ''),
                    ),
                    const SizedBox(height: 6),
                  ],

                  const SizedBox(height: 14),
                  Text(
                    'Once turned in, your faculty teacher will be notified immediately to review and grade your work.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                'Review / Cancel',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _submit(existing, assignment);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isLate
                    ? Colors.amber.shade700
                    : AppTheme.primary,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                _isEditingExisting ? 'Confirm & Update' : 'Confirm & Submit',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String detail,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          Expanded(
            child: Text(
              detail,
              style: TextStyle(
                color: AppTheme.text,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(Submission? existing, [Assignment? assignment]) async {
    final canResubmit = existing?.status == 'resubmission_allowed';
    final isGraceExpired = _isGracePeriodExpired(assignment?.dueDate);

    if (existing != null && !canResubmit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Submission locked: Your teacher has not allowed resubmission.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (isGraceExpired && existing == null && !canResubmit) {
      final graceEnd = _getGracePeriodEnd(assignment?.dueDate);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Submission closed: The deadline passed and the 3-day grace period ended on ${_formatDate(graceEnd?.toIso8601String())}.',
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return;
    }

    final isEditing = _isEditingExisting || canResubmit;
    final link = _linkController.text.trim();
    final hasFile = _pickedFileName != null;
    final hasExistingFile = existing?.fileName != null && isEditing;
    final hasImage = _pickedImageName != null;
    final hasExistingImage = existing?.imagePath != null && isEditing;

    if (_pickedFileSize > 10 * 1024 * 1024 ||
        _pickedImageSize > 10 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Selected attachment exceeds the 10 MB limit. Please select a smaller file.',
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return;
    }

    final user = ref.read(authProvider);
    final studentId = user?.id ?? 'student_1';
    final studentName = user?.fullName ?? 'Student';

    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0.0;
      _uploadStatusMessage = null;
    });

    try {
      final List<String> types = [];
      if (hasImage || hasExistingImage) types.add('image');
      if (hasFile || hasExistingFile) types.add('file');
      if (link.isNotEmpty ||
          (existing?.contentLink != null && isEditing)) {
        types.add('link');
      }

      final submissionType = types.isEmpty ? 'file' : types.join('+');

      String? uploadedStorageUrl = isEditing ? existing?.storageUrl : null;
      String? linkToSave = link.isNotEmpty ? link : (isEditing ? existing?.contentLink : null);

      // Upload attachment directly to Cloud Storage (Cloudflare R2 / Supabase)
      final bytesToUpload = _pickedFileBytes ?? _pickedImageBytes;
      final nameToUpload = _pickedFileName ?? _pickedImageName;
      if (bytesToUpload != null && nameToUpload != null) {
        if (mounted) {
          setState(
            () => _uploadStatusMessage =
                'Uploading attachment to cloud storage...',
          );
        }
        final res = await CloudStorageService().uploadSubmissionFile(
          assignmentId: _parsedId,
          studentId: studentId,
          fileName: nameToUpload,
          bytes: bytesToUpload,
          onProgress: (pct) {
            if (mounted) setState(() => _uploadProgress = pct);
          },
        );
        if (res.success && res.downloadUrl != null) {
          uploadedStorageUrl = res.downloadUrl;
        }
      }

      final repo = ref.read(submissionsRepositoryProvider);
      await repo.submitAssignment(
        assignmentId: _parsedId,
        studentId: studentId,
        studentName: studentName,
        submissionType: submissionType,
        contentLink: linkToSave,
        fileName:
            _pickedFileName ?? (isEditing ? existing?.fileName : null),
        fileSize: _pickedFileSize > 0
            ? _pickedFileSize
            : (isEditing ? existing?.fileSize : null),
        filePath:
            _pickedFilePath ?? (isEditing ? existing?.filePath : null),
        fileBytes: _pickedFileBytes != null
            ? base64Encode(_pickedFileBytes!)
            : (isEditing ? existing?.fileBytes : null),
        textResponse: isEditing ? existing?.textResponse : null,
        imagePath: _pickedImageName != null
            ? (_pickedImagePath ?? _pickedImageName)
            : (isEditing ? existing?.imagePath : null),
        imageBytes: _pickedImageBytes != null
            ? base64Encode(_pickedImageBytes!)
            : (isEditing ? existing?.imageBytes : null),
        storageUrl: uploadedStorageUrl,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : (isEditing ? existing?.notes : null),
      );

      ref.invalidate(
        studentSubmissionProvider((
          assignmentId: _parsedId,
          studentId: studentId,
        )),
      );
      ref.invalidate(assignmentDetailProvider(_parsedId));
      ref.invalidate(
        studentAssignmentsProvider((studentId: studentId, subjectId: null)),
      );
      ref.invalidate(activityRosterProvider(_parsedId));
      ref.invalidate(assignmentSubmissionsProvider(_parsedId));

      SessionDraftService.instance.clearForm(
        'submission_${widget.assignmentId}',
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isEditingExisting = false;
        });
        final isLate = assignment != null && _isOverdue(assignment.dueDate);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isLate
                  ? 'Activity submitted (Late - within 3-day grace period). Logged at ${_formatTime(DateTime.now())}.'
                  : 'Activity submitted successfully! Logged at ${_formatTime(DateTime.now())}.',
            ),
            backgroundColor: isLate ? Colors.orange : AppTheme.success,
          ),
        );
        context.go('/student/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final errText = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errText), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Widget _buildClosedState(Assignment assignment) {
    final graceEnd = _getGracePeriodEnd(assignment.dueDate);
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(28),
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_busy_outlined,
                color: AppTheme.error,
                size: 48,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Submissions Closed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'The deadline for "${assignment.title}" was ${_formatDate(assignment.dueDate)}.\n\nThe 3-day grace period expired on ${_formatDate(graceEnd?.toIso8601String())}. Late submissions are no longer accepted unless your teacher unlocks permission.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Go Back',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final user = ref.watch(authProvider);
    final studentId = user?.id ?? 'S-100-0001';

    final assignmentAsync = ref.watch(assignmentDetailProvider(_parsedId));
    final submissionAsync = ref.watch(
      studentSubmissionProvider((
        assignmentId: _parsedId,
        studentId: studentId,
      )),
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Submit Assignment',
          style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.text),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Sync Submissions with Cloud',
            onPressed: () async {
              try {
                await DatabaseHelper().pushLocalSubmissionsToCloud();
                await DatabaseHelper().syncCloudSubmissionsToLocal(
                  assignmentId: _parsedId,
                  force: true,
                );
                ref.invalidate(
                  studentSubmissionProvider((
                    assignmentId: _parsedId,
                    studentId: studentId,
                  )),
                );
                ref.invalidate(assignmentDetailProvider(_parsedId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Offline submissions synced successfully!'),
                      backgroundColor: Colors.teal,
                    ),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Offline: Saved locally and will sync once connected.',
                      ),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: assignmentAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(20),
          child: SkeletonListView(itemCount: 4),
        ),
        error: (err, stack) => AppErrorState(
          error: err,
          title: 'Failed to Load Activity',
          onRetry: () => ref.refresh(assignmentDetailProvider(_parsedId)),
          secondaryActionLabel: 'Go Back',
          onSecondaryAction: () => context.pop(),
        ),
        data: (assignment) {
          if (assignment == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.assignment_late_outlined,
                    color: AppTheme.textMuted,
                    size: 56,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Activity not found',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final submission = submissionAsync.value;
          final canResubmit = submission?.status == 'resubmission_allowed';
          final isSubmitted =
              submission != null && !canResubmit && !_isEditingExisting;
          final isGraceExpired = _isGracePeriodExpired(assignment.dueDate);
          final isClosed = !isSubmitted && isGraceExpired && !canResubmit;

          if (isClosed) {
            return _buildClosedState(assignment);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                _buildHeaderCard(assignment),
                const SizedBox(height: 20),

                // Instructions Card
                _buildInstructionsCard(assignment),
                const SizedBox(height: 24),

                // Submission or Success state
                if (isSubmitted)
                  _buildSubmittedState(assignment, submission)
                else
                  _buildSubmissionForm(assignment, submission),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(Assignment assignment) {
    final isOverdue = _isOverdue(assignment.dueDate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (assignment.subjectCode != null &&
                  assignment.subjectCode!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    assignment.subjectCode!,
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              if (assignment.subjectName != null &&
                  assignment.subjectName!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    assignment.subjectName!,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${assignment.totalPoints} pts',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            assignment.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: isOverdue ? AppTheme.error : AppTheme.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                'Due: ${_formatDate(assignment.dueDate)}',
                style: TextStyle(
                  color: isOverdue ? AppTheme.error : AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (isOverdue) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Text(
                    'LATE (3-DAY GRACE PERIOD)',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (assignment.teacherName != null &&
              assignment.teacherName!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Instructor: ${assignment.teacherName}',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInstructionsCard(Assignment assignment) {
    final instructions =
        (assignment.description != null && assignment.description!.isNotEmpty)
        ? assignment.description!
        : 'Please complete your activity according to your teacher\'s guidelines. You may type a response, attach screenshots/images, upload files, or provide project links below.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'Instructions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            instructions,
            style: TextStyle(
              color: AppTheme.textSecondary,
              height: 1.5,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionForm(Assignment assignment, Submission? existing) {
    final canResubmit = existing?.status == 'resubmission_allowed';
    final isEditing = _isEditingExisting || canResubmit;

    if (isEditing && existing != null) {
      if (_textResponseController.text.isEmpty &&
          existing.textResponse != null) {
        _textResponseController.text = existing.textResponse!;
      }
      if (_linkController.text.isEmpty && existing.contentLink != null) {
        _linkController.text = existing.contentLink!;
      }
      if (_notesController.text.isEmpty && existing.notes != null) {
        _notesController.text = existing.notes!;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: canResubmit
              ? Colors.amber.shade700.withValues(alpha: 0.5)
              : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                canResubmit
                    ? 'Resubmit Assignment'
                    : (_isEditingExisting ? 'Edit Your Submission' : 'Submit Activity'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: canResubmit ? Colors.amber.shade700 : AppTheme.text,
                ),
              ),
              if (_isEditingExisting && !canResubmit)
                TextButton(
                  onPressed: () => setState(() => _isEditingExisting = false),
                  child: const Text('Cancel Edit'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (canResubmit) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_open_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your teacher has unlocked this activity for resubmission. You can replace your file or update your link/notes and submit again.',
                      style: TextStyle(
                        color: AppTheme.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'Provide your submission using a file attachment or project link.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
          const SizedBox(height: 18),

          // 1. PROJECT LINK SECTION
          Text(
            'Project Link (URL)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _linkController,
            maxLength: 250,
            buildCounter:
                (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
            style: TextStyle(color: AppTheme.text),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.link, color: AppTheme.primary),
              hintText:
                  'e.g. https://github.com/username/project or Google Drive',
              counterText: '',
              hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 2. ATTACHMENT SECTION (UNIFIED SINGLE ATTACHMENT PICKER)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Attach File / Document / Image',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'MAX 10 MB',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_pickedFileName != null || _pickedImageName != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_pickedImageBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _pickedImageBytes!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Icon(
                        _pickedImageBytes != null
                            ? Icons.image
                            : Icons.insert_drive_file_outlined,
                        color: AppTheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _pickedFileName ?? _pickedImageName!,
                              style: TextStyle(
                                color: AppTheme.text,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${_formatFileSize(_pickedFileSize > 0 ? _pickedFileSize : _pickedImageSize)} • Within 10 MB limit',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: AppTheme.error,
                          size: 20,
                        ),
                        onPressed: _removeAttachment,
                        tooltip: 'Remove Attachment',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ] else if ((existing?.fileName != null ||
                  existing?.imagePath != null) &&
              isEditing) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Icon(
                    _isImageFile(existing!.fileName ?? existing.imagePath)
                        ? Icons.image
                        : Icons.attach_file,
                    color: AppTheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Keep existing: ${existing.fileName ?? existing.imagePath} ${existing.fileSize != null ? "(${_formatFileSize(existing.fileSize!)})" : ""}',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _pickAttachment,
                    child: const Text(
                      'Replace',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ] else ...[
            OutlinedButton.icon(
              onPressed: _pickAttachment,
              icon: Icon(Icons.upload_file_outlined, color: AppTheme.primary),
              label: Text(
                'Browse or Pick File (PDF, DOCX, Images, ZIP • Max 10 MB)',
                style: TextStyle(color: AppTheme.primary),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: AppTheme.primary.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 18),
          ],

          // 5. NOTES SECTION
          Text(
            'Notes or Comments (Optional)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLength: 200,
            style: TextStyle(color: AppTheme.text),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Add remarks for your teacher...',
              hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // UPLOAD PROGRESS BAR (When transmitting documents/media)
          if (_isSubmitting && _uploadStatusMessage != null) ...[
            Text(
              _uploadProgress > 0
                  ? '$_uploadStatusMessage (${(_uploadProgress * 100).toInt()}%)'
                  : _uploadStatusMessage!,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _uploadProgress > 0 ? _uploadProgress : null,
                backgroundColor: AppTheme.border,
                color: AppTheme.primary,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // SUBMIT ACTION BUTTON
          ElevatedButton(
            onPressed: _isSubmitting
                ? null
                : () => _confirmAndSubmit(assignment, existing),
            style: ElevatedButton.styleFrom(
              backgroundColor: canResubmit
                  ? Colors.amber.shade700
                  : AppTheme.primary,
              foregroundColor: canResubmit ? Colors.white : Colors.black,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: canResubmit ? 2 : 0,
            ),
            child: _isSubmitting
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: canResubmit ? Colors.white : Colors.black,
                    ),
                  )
                : Text(
                    canResubmit
                        ? 'Submit Resubmission'
                        : (_isEditingExisting
                            ? 'Update Submission'
                            : 'Submit Assignment'),
                    style: TextStyle(
                      color: canResubmit ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittedState(Assignment assignment, Submission submission) {
    final isGraded = submission.status == 'graded' && submission.grade != null;
    final isLate = submission.status == 'late';
    final isResubAllowed = submission.status == 'resubmission_allowed';

    Color bannerColor = AppTheme.success;
    Color bannerBg = AppTheme.successSoft;
    String bannerTitle = 'Submitted Successfully!';
    IconData bannerIcon = Icons.check_circle;

    if (isGraded) {
      bannerTitle = 'Assignment Graded';
      bannerIcon = Icons.stars;
      bannerColor = AppTheme.primary;
      bannerBg = AppTheme.primary.withValues(alpha: 0.12);
    } else if (isResubAllowed) {
      bannerTitle = 'Resubmission Allowed';
      bannerIcon = Icons.lock_open_rounded;
      bannerColor = Colors.amber.shade700;
      bannerBg = Colors.amber.shade900.withValues(alpha: 0.15);
    } else if (isLate) {
      bannerTitle = 'Submitted Late';
      bannerIcon = Icons.access_time_filled;
      bannerColor = Colors.amber.shade600;
      bannerBg = Colors.amber.shade900.withValues(alpha: 0.15);
    }

    return Column(
      children: [
        // Status Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: bannerBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: bannerColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Icon(bannerIcon, color: bannerColor, size: 48),
              const SizedBox(height: 10),
              Text(
                bannerTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: bannerColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Submitted on ${_formatDate(submission.submittedAt)}',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (isResubAllowed) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your teacher has unlocked this activity for resubmission.',
                        style: TextStyle(
                          color: AppTheme.text,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isEditingExisting = true;
                        _textResponseController.text =
                            submission.textResponse ?? '';
                        _linkController.text =
                            submission.contentLink ?? '';
                        _notesController.text = submission.notes ?? '';
                      });
                    },
                    icon: const Icon(Icons.edit_note_rounded, size: 20),
                    label: const Text(
                      'Edit & Resubmit Assignment Now',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Score Card if Graded
        if (isGraded) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.15),
                  AppTheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Score & Evaluation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.text,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${submission.grade!.toStringAsFixed(0)} / ${assignment.totalPoints} pts',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                if (submission.feedback != null &&
                    submission.feedback!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Faculty Feedback:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      submission.feedback!,
                      style: TextStyle(
                        color: AppTheme.text,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                if (submission.gradedAt != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Graded on ${_formatDate(submission.gradedAt)}${submission.gradedBy != null ? " by ${submission.gradedBy}" : ""}',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Submission Details Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Submission Artifacts',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 14),

              // Written text response
              if (submission.textResponse != null &&
                  submission.textResponse!.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Written Response:',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      color: AppTheme.textMuted,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: submission.textResponse!),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Written response copied!'),
                          ),
                        );
                      },
                      tooltip: 'Copy Response',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    submission.textResponse!,
                    style: TextStyle(
                      color: AppTheme.text,
                      height: 1.4,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Attached Image
              if (submission.imagePath != null &&
                  submission.imagePath!.isNotEmpty) ...[
                Text(
                  'Attached Image:',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.image_outlined,
                        color: AppTheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          submission.imagePath!,
                          style: TextStyle(
                            color: AppTheme.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Attached File
              if (submission.fileName != null) ...[
                Text(
                  'Attached File:',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.insert_drive_file_outlined,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              submission.fileName!,
                              style: TextStyle(
                                color: AppTheme.text,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (submission.fileSize != null)
                              Text(
                                _formatFileSize(submission.fileSize!),
                                style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (submission.storageUrl != null ||
                          submission.fileBytes != null ||
                          submission.filePath != null) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _openSubmittedFile(submission),
                          icon: const Icon(Icons.open_in_new, size: 14),
                          label: const Text(
                            'View',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Link
              if (submission.contentLink != null &&
                  submission.contentLink!.isNotEmpty) ...[
                Text(
                  'Project Link:',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.link, color: AppTheme.primary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          submission.contentLink!,
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 18),
                        color: AppTheme.primary,
                        onPressed: () async {
                          try {
                            final target = submission.contentLink!.trim();
                            final uri = Uri.parse(
                              target.startsWith('http://') ||
                                      target.startsWith('https://')
                                  ? target
                                  : 'https://$target',
                            );
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Could not open link: $e'),
                                ),
                              );
                            }
                          }
                        },
                        tooltip: 'Open Link',
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        color: AppTheme.textMuted,
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: submission.contentLink!),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Link copied to clipboard!'),
                            ),
                          );
                        },
                        tooltip: 'Copy Link',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Notes
              if (submission.notes != null && submission.notes!.isNotEmpty) ...[
                Text(
                  'Your Notes:',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    submission.notes!,
                    style: TextStyle(color: AppTheme.text, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Resubmission Lock Status Card
              Builder(
                builder: (context) {
                  final canResubmit =
                      submission.status == 'resubmission_allowed';
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: canResubmit
                          ? AppTheme.success.withValues(alpha: 0.12)
                          : Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: canResubmit
                            ? AppTheme.success.withValues(alpha: 0.4)
                            : Colors.amber.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          canResubmit
                              ? Icons.lock_open_rounded
                              : Icons.lock_outline_rounded,
                          color: canResubmit ? AppTheme.success : Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            canResubmit
                                ? 'Resubmission Allowed: Your teacher has unlocked this activity. You may update and resubmit your work.'
                                : 'Submission Locked: You have submitted this assignment. Editing is disabled unless your teacher unlocks it.',
                            style: TextStyle(
                              color: canResubmit
                                  ? AppTheme.success
                                  : AppTheme.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Actions: Edit / Resubmit (only if teacher allowed) or Go Back
              Builder(
                builder: (context) {
                  final canResubmit =
                      submission.status == 'resubmission_allowed';
                  return Row(
                    children: [
                      if (canResubmit) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isEditingExisting = true;
                                _textResponseController.text =
                                    submission.textResponse ?? '';
                                _linkController.text =
                                    submission.contentLink ?? '';
                                _notesController.text = submission.notes ?? '';
                              });
                            },
                            icon: const Icon(Icons.edit_note_rounded, size: 20),
                            label: const Text(
                              'Edit & Resubmit',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => context.pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canResubmit
                                ? AppTheme.surface
                                : AppTheme.primary,
                            foregroundColor: canResubmit
                                ? AppTheme.text
                                : Colors.black,
                            side: canResubmit
                                ? BorderSide(color: AppTheme.border)
                                : null,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Go Back',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openSubmittedFile(Submission submission) async {
    try {
      final cleanName = submission.fileName ?? 'submission.pdf';
      final isPdf = cleanName.toLowerCase().endsWith('.pdf');
      final mimeType = isPdf ? 'application/pdf' : 'application/octet-stream';

      // 1. If Cloud Storage URL is present
      if (submission.storageUrl != null &&
          (submission.storageUrl!.startsWith('http://') ||
              submission.storageUrl!.startsWith('https://'))) {
        final accessibleUrl = CloudflareR2Service.instance.getAccessibleUrl(
          submission.storageUrl!,
        );
        if (kIsWeb) {
          triggerWebUrlDownload(accessibleUrl, cleanName);
          return;
        }
        final uri = Uri.parse(accessibleUrl);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }

      // 2. If Base64 bytes are stored locally
      if (submission.fileBytes != null &&
          submission.fileBytes!.trim().isNotEmpty) {
        final cleanB64 = ImageCompressHelper.cleanBase64(submission.fileBytes!);
        final rawBytes = base64Decode(cleanB64);
        if (kIsWeb) {
          downloadBinaryFileWeb(rawBytes, cleanName, mimeType);
          return;
        }
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$cleanName');
        await file.writeAsBytes(rawBytes);
        final uri = Uri.file(file.path);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }

      // 3. If local file path exists
      if (!kIsWeb &&
          submission.filePath != null &&
          File(submission.filePath!).existsSync()) {
        final uri = Uri.file(submission.filePath!);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File content not available')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open file: $e')));
      }
    }
  }
}
