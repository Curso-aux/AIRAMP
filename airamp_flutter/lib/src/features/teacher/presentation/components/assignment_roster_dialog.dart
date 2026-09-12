import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/application/auth_provider.dart';
import '../../../submissions/data/submissions_repository.dart';

class AssignmentRosterDialog extends ConsumerStatefulWidget {
  final int assignmentId;
  final String assignmentTitle;
  final int totalPoints;
  final String? dueDate;

  const AssignmentRosterDialog({
    super.key,
    required this.assignmentId,
    required this.assignmentTitle,
    required this.totalPoints,
    this.dueDate,
  });

  @override
  ConsumerState<AssignmentRosterDialog> createState() => _AssignmentRosterDialogState();
}

class _AssignmentRosterDialogState extends ConsumerState<AssignmentRosterDialog> {
  List<Map<String, dynamic>> _submissions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() => _loading = true);
    final subs = await DatabaseHelper().getSubmissionsForAssignment(widget.assignmentId);
    if (mounted) {
      setState(() {
        _submissions = subs;
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

  void _openGradingDialog(Map<String, dynamic> sub) {
    final subId = sub['id'] as int;
    final currentGrade = sub['grade']?.toString() ?? '';
    final currentFeedback = sub['feedback']?.toString() ?? '';

    final gradeController = TextEditingController(text: currentGrade);
    final feedbackController = TextEditingController(text: currentFeedback);

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
                      'Grade: ${sub['full_name'] ?? sub['student_name'] ?? "Student"}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Score (out of ${widget.totalPoints} pts) *', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: gradeController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: AppTheme.text),
                      decoration: InputDecoration(
                        hintText: 'e.g. 95',
                        hintStyle: TextStyle(color: AppTheme.textMuted),
                        filled: true,
                        fillColor: AppTheme.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Teacher Feedback / Remarks', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: feedbackController,
                      maxLines: 3,
                      style: TextStyle(color: AppTheme.text),
                      decoration: InputDecoration(
                        hintText: 'Great code architecture, well-documented API...',
                        hintStyle: TextStyle(color: AppTheme.textMuted),
                        filled: true,
                        fillColor: AppTheme.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
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
                    final teacherName = user?.fullName ?? 'Teacher';

                    final messenger = ScaffoldMessenger.of(context);

                    await DatabaseHelper().gradeSubmission(
                      submissionId: subId,
                      grade: score,
                      feedback: feedbackController.text.trim().isNotEmpty ? feedbackController.text.trim() : null,
                      gradedBy: teacherName,
                    );

                    // Invalidate provider so student side updates
                    ref.invalidate(studentSubmissionProvider((
                      assignmentId: widget.assignmentId,
                      studentId: sub['student_id'].toString(),
                    )));
                    ref.invalidate(assignmentSubmissionsProvider(widget.assignmentId));

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                    if (mounted) {
                      _loadSubmissions();
                      messenger.showSnackBar(
                        SnackBar(
                          content: const Text('Submission graded successfully!'),
                          backgroundColor: AppTheme.success,
                        ),
                      );
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

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
                        'Student Submissions • ${widget.totalPoints} Points',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppTheme.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : _submissions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox_outlined, size: 56, color: AppTheme.textMuted),
                              const SizedBox(height: 12),
                              Text(
                                'No submissions yet',
                                style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'When students submit links or attachments for this assignment, they will appear here.',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _submissions.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final sub = _submissions[index];
                            final studentName = sub['full_name'] ?? sub['student_name'] ?? 'Unknown Student';
                            final section = sub['section'] ?? '';
                            final submittedAt = sub['submitted_at'];
                            final link = sub['content_link'];
                            final fileName = sub['file_name'];
                            final fileSize = sub['file_size'];
                            final notes = sub['notes'];
                            final grade = sub['grade'];
                            final feedback = sub['feedback'];
                            final isGraded = sub['status'] == 'graded' && grade != null;

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isGraded ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.border,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top row: Student name & Grade Badge
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                                        child: Text(
                                          studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                                          style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              studentName,
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.text),
                                            ),
                                            if (section.isNotEmpty)
                                              Text(section, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isGraded ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.primary.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isGraded ? '${grade is num ? grade.toStringAsFixed(0) : grade} / ${widget.totalPoints} pts' : 'Needs Grading',
                                          style: TextStyle(
                                            color: isGraded ? AppTheme.success : AppTheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Submission date
                                  Row(
                                    children: [
                                      Icon(Icons.schedule, size: 13, color: AppTheme.textMuted),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Submitted: ${_formatDate(submittedAt)}',
                                        style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Link attachment if present
                                  if (link != null && link.isNotEmpty) ...[
                                    Row(
                                      children: [
                                        Icon(Icons.link, size: 14, color: AppTheme.primary),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            link,
                                            style: TextStyle(color: AppTheme.primary, fontSize: 12, decoration: TextDecoration.underline),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy, size: 14),
                                          color: AppTheme.textMuted,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: link));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Link copied to clipboard!')),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                  ],

                                  // File attachment if present
                                  if (fileName != null && fileName.isNotEmpty) ...[
                                    Row(
                                      children: [
                                        Icon(Icons.insert_drive_file_outlined, size: 14, color: AppTheme.primary),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '$fileName (${fileSize != null ? _formatFileSize(fileSize) : ""})',
                                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                  ],

                                  // Student notes if present
                                  if (notes != null && notes.isNotEmpty) ...[
                                    Text(
                                      'Note: "$notes"',
                                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
                                    ),
                                    const SizedBox(height: 6),
                                  ],

                                  // Feedback if already graded
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

                                  // Grade button
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _openGradingDialog(sub),
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
