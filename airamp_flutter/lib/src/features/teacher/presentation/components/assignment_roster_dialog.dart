import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/components/user_avatar_widget.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/services/session_draft_service.dart';
import '../../../../core/utils/file_download_helper.dart';
import '../../../../core/utils/image_compress_helper.dart';
import '../../../auth/application/auth_provider.dart';
import '../../../submissions/data/submissions_repository.dart';

class AssignmentRosterDialog extends ConsumerStatefulWidget {
  final int assignmentId;
  final String assignmentTitle;
  final int totalPoints;
  final String? dueDate;
  final String? gdriveFolderUrl;

  const AssignmentRosterDialog({
    super.key,
    required this.assignmentId,
    required this.assignmentTitle,
    required this.totalPoints,
    this.dueDate,
    this.gdriveFolderUrl,
  });

  @override
  ConsumerState<AssignmentRosterDialog> createState() => _AssignmentRosterDialogState();
}

class _AssignmentRosterDialogState extends ConsumerState<AssignmentRosterDialog> {
  List<Map<String, dynamic>> _roster = [];
  bool _loading = true;
  String _activeFilter = 'all'; // 'all', 'not submitted', 'submitted', 'late', 'graded'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRoster() async {
    setState(() => _loading = true);
    final list = await DatabaseHelper().getActivityRosterForTeacher(widget.assignmentId);
    if (mounted) {
      setState(() {
        _roster = list;
        _loading = false;
      });
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(isoString);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} $hour:$min $amPm';
    } catch (_) {
      return isoString;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  List<Map<String, dynamic>> get _filteredRoster {
    return _roster.where((student) {
      final status = (student['computed_status'] as String? ?? 'not submitted').toLowerCase();
      if (_activeFilter != 'all' && status != _activeFilter) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (student['full_name'] as String? ?? '').toLowerCase();
        final email = (student['email'] as String? ?? '').toLowerCase();
        final section = (student['section'] as String? ?? '').toLowerCase();
        return name.contains(q) || email.contains(q) || section.contains(q);
      }

      return true;
    }).toList();
  }

  Future<void> _openLink(String url) async {
    try {
      final target = url.trim();
      final uri = Uri.parse(target.startsWith('http://') || target.startsWith('https://') ? target : 'https://$target');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open link: $e')));
      }
    }
  }

  void _openImagePreview(String? imagePath, String? imageBytes, String? storageUrl, String studentName) {
    Widget imageWidget;
    final decodedBytes = ImageCompressHelper.safeDecodeBase64(imageBytes);
    if (decodedBytes != null && decodedBytes.isNotEmpty) {
      imageWidget = Image.memory(
        decodedBytes,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 60, color: Colors.grey),
      );
    } else if (storageUrl != null && (storageUrl.startsWith('http://') || storageUrl.startsWith('https://'))) {
      imageWidget = Image.network(
        storageUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 60, color: Colors.grey),
      );
    } else if (imagePath != null && imagePath.isNotEmpty) {
      if (!kIsWeb && File(imagePath).existsSync()) {
        imageWidget = Image.file(File(imagePath), fit: BoxFit.contain);
      } else if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        imageWidget = Image.network(
          imagePath,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 60, color: Colors.grey),
        );
      } else {
        imageWidget = Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.photo_outlined, size: 56, color: Colors.white70),
              const SizedBox(height: 12),
              Text(
                'Submitted: ${imagePath.split("/").last}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Image file is stored on student device. Once the student device syncs with AIRAMP, the compressed image displays here automatically.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      }
    } else {
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text('$studentName - Submitted Work', style: const TextStyle(color: Colors.white, fontSize: 15)),
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4.0,
                child: imageWidget,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _openFile(String? fileName, String? filePath, String? fileBytes, [String? storageUrl]) async {
    try {
      final cleanName = (fileName != null && fileName.isNotEmpty) ? fileName : 'student_submission.pdf';
      final isPdf = cleanName.toLowerCase().endsWith('.pdf');
      final mimeType = isPdf ? 'application/pdf' : 'application/octet-stream';

      // 1. If Cloud Storage URL is available, download / open via remote URL
      if (storageUrl != null && (storageUrl.startsWith('http://') || storageUrl.startsWith('https://'))) {
        if (kIsWeb) {
          triggerWebUrlDownload(storageUrl, cleanName);
          return;
        }
        final uri = Uri.parse(storageUrl);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }

      // 2. If Base64 bytes are present, download via Web Blob or save to temp file on native
      if (fileBytes != null && fileBytes.trim().isNotEmpty) {
        final cleanB64 = ImageCompressHelper.cleanBase64(fileBytes);
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

      // 3. Fallback to local file path on desktop/mobile if present
      if (!kIsWeb && filePath != null && filePath.isNotEmpty && File(filePath).existsSync()) {
        final uri = Uri.file(filePath);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: $e')));
      }
    }
  }

  void _showFullTextDialog(String studentName, String text) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Written Response: $studentName', style: TextStyle(color: AppTheme.text, fontSize: 16)),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: TextStyle(color: AppTheme.text, fontSize: 13, height: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _openGradingDialog(Map<String, dynamic> student) {
    final subId = student['submission_id'] as int?;
    if (subId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot grade: student has not submitted yet.')),
      );
      return;
    }

    final currentGrade = student['grade'] != null
        ? (student['grade'] is num
            ? (student['grade'] as num).toStringAsFixed(0)
            : student['grade'].toString())
        : '';
    final currentFeedback = student['feedback']?.toString() ?? '';

    final gradeController = TextEditingController(text: currentGrade);
    final feedbackController = TextEditingController(text: currentFeedback);
    final formId = 'teacher_grading_${widget.assignmentId}_${student['student_id']}';
    final disposer = SessionDraftDisposer();
    disposer.add(gradeController.bindSessionDraft(formId: formId, fieldKey: 'grade'));
    disposer.add(feedbackController.bindSessionDraft(formId: formId, fieldKey: 'feedback'));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.rate_review_outlined, color: AppTheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Grade: ${student['full_name'] ?? "Student"}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Score (out of ${widget.totalPoints} pts) *',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: gradeController,
                      maxLength: 4,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: AppTheme.text),
                      decoration: InputDecoration(
                        hintText: 'e.g. 95',
                        counterText: '',
                        hintStyle: TextStyle(color: AppTheme.textMuted),
                        filled: true,
                        fillColor: AppTheme.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Teacher Feedback / Evaluation',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: feedbackController,
                      maxLength: 500,
                      maxLines: 3,
                      style: TextStyle(color: AppTheme.text),
                      decoration: InputDecoration(
                        hintText: 'Great analysis, thorough responses and well-structured...',
                        hintStyle: TextStyle(color: AppTheme.textMuted),
                        filled: true,
                        fillColor: AppTheme.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final score = double.tryParse(gradeController.text.trim());
                    if (score == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid numeric grade.')),
                      );
                      return;
                    }

                    final user = ref.read(authProvider);
                    final teacherName = user?.fullName ?? 'Faculty Instructor';

                    final messenger = ScaffoldMessenger.of(context);

                    try {
                      await DatabaseHelper().gradeSubmission(
                        submissionId: subId,
                        grade: score,
                        feedback: feedbackController.text.trim().isNotEmpty ? feedbackController.text.trim() : null,
                        gradedBy: teacherName,
                      );

                      ref.invalidate(studentSubmissionProvider((
                        assignmentId: widget.assignmentId,
                        studentId: student['student_id'].toString(),
                      )));
                      ref.invalidate(activityRosterProvider(widget.assignmentId));
                      ref.invalidate(assignmentSubmissionsProvider(widget.assignmentId));

                      SessionDraftService.instance.clearForm(formId);

                      if (ctx.mounted) {
                        disposer.dispose();
                        Navigator.pop(ctx);
                      }
                      if (mounted) {
                        await _loadRoster();
                        messenger.showSnackBar(
                          SnackBar(
                            content: const Text('Grade & feedback recorded! Student notified.'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Failed to save grade: ${e.toString().replaceFirst("Exception: ", "")}'),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Save Grade', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatusBadge(String status, dynamic grade) {
    Color bg;
    Color text;
    String label;
    IconData icon;

    switch (status) {
      case 'graded':
        bg = AppTheme.success.withValues(alpha: 0.15);
        text = AppTheme.success;
        label = grade != null
            ? '${grade is num ? grade.toStringAsFixed(0) : grade}/${widget.totalPoints} pts'
            : 'Graded';
        icon = Icons.stars;
        break;
      case 'submitted':
        bg = AppTheme.primary.withValues(alpha: 0.15);
        text = AppTheme.primary;
        label = 'Submitted On-Time';
        icon = Icons.check_circle_outline;
        break;
      case 'late':
        bg = Colors.amber.shade900.withValues(alpha: 0.2);
        text = Colors.amber.shade400;
        label = 'Late Submission';
        icon = Icons.access_time_filled;
        break;
      case 'not submitted':
      default:
        bg = AppTheme.border.withValues(alpha: 0.3);
        text = AppTheme.textMuted;
        label = 'Not Submitted';
        icon = Icons.radio_button_unchecked;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: text.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String key, String label, int count, Color activeColor) {
    final isSelected = _activeFilter == key;
    return InkWell(
      onTap: () => setState(() => _activeFilter = key),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.18) : AppTheme.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? activeColor : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : AppTheme.border.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.black : AppTheme.textSecondary,
                ),
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

    final totalCount = _roster.length;
    final notSubmittedCount = _roster.where((r) => r['computed_status'] == 'not submitted').length;
    final submittedCount = _roster.where((r) => r['computed_status'] == 'submitted').length;
    final lateCount = _roster.where((r) => r['computed_status'] == 'late').length;
    final gradedCount = _roster.where((r) => r['computed_status'] == 'graded').length;

    final filtered = _filteredRoster;

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 720,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.assignment_ind_outlined, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.assignmentTitle,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Student Activity Roster • ${widget.totalPoints} Total Points • Due: ${_formatDate(widget.dueDate)}',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                if (widget.gdriveFolderUrl != null && widget.gdriveFolderUrl!.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.folder_shared_outlined, color: Colors.green),
                    tooltip: 'Open Submissions in Google Drive',
                    onPressed: () => _openLink(widget.gdriveFolderUrl!),
                  ),
                ],
                IconButton(
                  icon: Icon(Icons.close, color: AppTheme.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Search Bar & Filter Tabs
            TextField(
              controller: _searchController,
              maxLength: 60,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: TextStyle(color: AppTheme.text, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search student name, section, or email...',
                counterText: '',
                hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.primary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppTheme.border),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 4-state lifecycle filter tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterTab('all', 'All Students', totalCount, AppTheme.primary),
                  const SizedBox(width: 8),
                  _buildFilterTab('not submitted', 'Not Submitted', notSubmittedCount, Colors.grey.shade400),
                  const SizedBox(width: 8),
                  _buildFilterTab('submitted', 'Submitted', submittedCount, AppTheme.primary),
                  const SizedBox(width: 8),
                  _buildFilterTab('late', 'Late', lateCount, Colors.amber.shade400),
                  const SizedBox(width: 8),
                  _buildFilterTab('graded', 'Graded', gradedCount, AppTheme.success),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Roster Content
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_search_outlined, size: 52, color: AppTheme.textMuted),
                              const SizedBox(height: 10),
                              Text(
                                'No students match current filter',
                                style: TextStyle(color: AppTheme.text, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Try adjusting your search keywords.'
                                    : 'No students currently in the "$_activeFilter" category.',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final student = filtered[index];
                            final studentName = student['full_name'] ?? 'Unknown Student';
                            final section = student['section'] ?? '';
                            final gradeLevel = student['student_grade_level'] ?? '';
                            final status = student['computed_status'] as String? ?? 'not submitted';
                            final hasSubmission = student['submission_id'] != null;
                            final submittedAt = student['submitted_at'];
                            final link = student['content_link'];
                            final fileName = student['file_name'];
                            final fileSize = student['file_size'];
                            final textResponse = student['text_response'];
                            final imagePath = student['image_path'];
                            final imageBytes = student['image_bytes'] as String?;
                            final filePath = student['file_path'] as String?;
                            final fileBytes = student['file_bytes'] as String?;
                            final storageUrl = student['storage_url'] as String?;
                            final notes = student['notes'];
                            final grade = student['grade'];
                            final feedback = student['feedback'];
                            final isGraded = status == 'graded';

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isGraded
                                      ? AppTheme.success.withValues(alpha: 0.3)
                                      : (status == 'late'
                                          ? Colors.amber.withValues(alpha: 0.3)
                                          : AppTheme.border),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top row: Student Avatar + Name + Section + Status Badge
                                  Row(
                                    children: [
                                      UserAvatarWidget(
                                        imageSource: (student['profile_image'] ?? student['profileImage']) as String?,
                                        fallbackInitial: studentName,
                                        size: 36,
                                        fontSize: 14,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              studentName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: AppTheme.text,
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                if (section.isNotEmpty)
                                                  Text('Sec: $section', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                                if (section.isNotEmpty && gradeLevel.isNotEmpty)
                                                  Text(' • ', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                                if (gradeLevel.isNotEmpty)
                                                  Text('Grade $gradeLevel', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      _buildStatusBadge(status, grade),
                                    ],
                                  ),

                                  // Submission Artifacts section if student submitted
                                  if (hasSubmission) ...[
                                    const SizedBox(height: 12),
                                    const Divider(height: 1),
                                    const SizedBox(height: 10),

                                    // Submission timestamp
                                    Row(
                                      children: [
                                        Icon(Icons.schedule, size: 13, color: AppTheme.textMuted),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Submitted: ${_formatDate(submittedAt)}',
                                          style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // 1. Text response
                                    if (textResponse != null && textResponse.isNotEmpty) ...[
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Written Response:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                                          if (textResponse.length > 150)
                                            InkWell(
                                              onTap: () => _showFullTextDialog(studentName, textResponse),
                                              child: Text('Read Full Response', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surface,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppTheme.border),
                                        ),
                                        child: Text(
                                          textResponse,
                                          style: TextStyle(color: AppTheme.text, fontSize: 12, height: 1.4),
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],

                                    // 2. Image attachment
                                    if ((imagePath != null && imagePath.isNotEmpty) || (imageBytes != null && imageBytes.isNotEmpty)) ...[
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surface,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppTheme.border),
                                        ),
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: Container(
                                                width: 44,
                                                height: 44,
                                                color: AppTheme.background,
                                                child: Builder(
                                                  builder: (context) {
                                                    final decoded = ImageCompressHelper.safeDecodeBase64(imageBytes);
                                                    if (decoded != null && decoded.isNotEmpty) {
                                                      return Image.memory(
                                                        decoded,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, _, _) => Icon(Icons.image, color: AppTheme.primary),
                                                      );
                                                    }
                                                    if (imagePath != null && !kIsWeb && File(imagePath).existsSync()) {
                                                      return Image.file(
                                                        File(imagePath),
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, _, _) => Icon(Icons.image, color: AppTheme.primary),
                                                      );
                                                    }
                                                    if (imagePath != null && (imagePath.startsWith('http://') || imagePath.startsWith('https://'))) {
                                                      return Image.network(
                                                        imagePath,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, _, _) => Icon(Icons.image, color: AppTheme.primary),
                                                      );
                                                    }
                                                    return Icon(Icons.image, color: AppTheme.primary);
                                                  },
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Photo / Image Submission', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.text)),
                                                  Text('Tap button to inspect in full resolution', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                                ],
                                              ),
                                            ),
                                            ElevatedButton.icon(
                                              onPressed: () => _openImagePreview(imagePath, imageBytes, storageUrl, studentName),
                                              icon: const Icon(Icons.zoom_in, size: 14),
                                              label: const Text('View Image', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.primary,
                                                foregroundColor: Colors.black,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    // 3. File attachment
                                    if (fileName != null && fileName.isNotEmpty) ...[
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surface,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppTheme.border),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.insert_drive_file_outlined, size: 24, color: AppTheme.primary),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    fileName,
                                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.text),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    fileSize != null ? _formatFileSize(fileSize) : 'Attached document',
                                                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton.icon(
                                              onPressed: () => _openFile(fileName, filePath, fileBytes, storageUrl),
                                              icon: const Icon(Icons.open_in_new, size: 14),
                                              label: const Text('Open File', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                                                foregroundColor: AppTheme.primary,
                                                side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                visualDensity: VisualDensity.compact,
                                                elevation: 0,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    // 4. Link
                                    if (link != null && link.isNotEmpty) ...[
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surface,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppTheme.border),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.link, size: 20, color: AppTheme.primary),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                link,
                                                style: TextStyle(color: AppTheme.primary, fontSize: 12, decoration: TextDecoration.underline),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            IconButton(
                                              icon: const Icon(Icons.copy, size: 16),
                                              tooltip: 'Copy Link',
                                              color: AppTheme.textMuted,
                                              onPressed: () {
                                                Clipboard.setData(ClipboardData(text: link));
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied!')));
                                              },
                                            ),
                                            ElevatedButton.icon(
                                              onPressed: () => _openLink(link),
                                              icon: const Icon(Icons.open_in_browser, size: 14),
                                              label: const Text('Open Link', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.primary,
                                                foregroundColor: Colors.black,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    // 5. Notes
                                    if (notes != null && notes.isNotEmpty) ...[
                                      Text(
                                        'Note: "$notes"',
                                        style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                                      ),
                                      const SizedBox(height: 6),
                                    ],

                                    // 6. Feedback if graded
                                    if (feedback != null && feedback.isNotEmpty) ...[
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surface,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppTheme.border),
                                        ),
                                        child: Text(
                                          'Teacher feedback: $feedback',
                                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],

                                    // Action Button for Teacher
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _openGradingDialog(student),
                                        icon: Icon(isGraded ? Icons.edit : Icons.grade, size: 14),
                                        label: Text(
                                          isGraded ? 'Edit Grade' : 'Grade Submission',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isGraded ? AppTheme.surface : AppTheme.primary,
                                          foregroundColor: isGraded ? AppTheme.text : Colors.black,
                                          side: isGraded ? BorderSide(color: AppTheme.border) : null,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    // Student has not submitted yet
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.hourglass_empty, size: 13, color: AppTheme.textMuted),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Awaiting student submission',
                                          style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
