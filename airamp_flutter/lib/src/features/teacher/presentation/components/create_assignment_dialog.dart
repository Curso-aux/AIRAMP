import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/animations/app_transitions.dart';
import '../../../../core/components/app_toast.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/services/session_draft_service.dart';
import '../../../auth/application/auth_provider.dart';
import '../../../submissions/data/submissions_repository.dart';
import '../../data/teacher_repository.dart';

class CreateAssignmentDialog extends ConsumerStatefulWidget {
  final int? subjectId;
  final String? subjectName;
  final String? initialSection;

  const CreateAssignmentDialog({
    super.key,
    this.subjectId,
    this.subjectName,
    this.initialSection,
  });

  @override
  ConsumerState<CreateAssignmentDialog> createState() => _CreateAssignmentDialogState();
}

class _CreateAssignmentDialogState extends ConsumerState<CreateAssignmentDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _pointsController = TextEditingController(text: '100');
  DateTime? _dueDate;
  String _submissionType = 'both'; // 'link', 'file', 'both'
  bool _isSaving = false;
  final SessionDraftDisposer _draftDisposer = SessionDraftDisposer();

  int? _selectedSubjectId;
  String? _selectedSubjectName;
  String _selectedSection = 'All Handled Sections';
  String? _attachmentName;
  int? _attachmentSize;
  String? _attachmentPath;
  String? _attachmentBase64;

  String get _formId => 'teacher_create_assignment_${_selectedSubjectId ?? widget.subjectId ?? 0}';

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.subjectId != null && widget.subjectId! > 0 ? widget.subjectId : null;
    _selectedSubjectName = widget.subjectName;
    if (widget.initialSection != null && widget.initialSection!.trim().isNotEmpty) {
      _selectedSection = widget.initialSection!.trim();
    }

    _draftDisposer.add(_titleController.bindSessionDraft(formId: _formId, fieldKey: 'title'));
    _draftDisposer.add(_descController.bindSessionDraft(formId: _formId, fieldKey: 'desc'));
    _draftDisposer.add(_pointsController.bindSessionDraft(formId: _formId, fieldKey: 'points'));
    // Default due date: 7 days from now
    _dueDate = DateTime.now().add(const Duration(days: 7, hours: 4));
  }

  Future<void> _pickAttachment() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'png', 'jpg', 'jpeg', 'zip'],
      );
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        final size = await file.length();
        String? b64;
        if (bytes.isNotEmpty) {
          b64 = base64Encode(bytes);
        }
        setState(() {
          _attachmentName = file.name;
          _attachmentSize = size > 0 ? size : bytes.length;
          _attachmentPath = file.path;
          _attachmentBase64 = b64;
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to pick file: $e');
      }
    }
  }

  @override
  void dispose() {
    _draftDisposer.dispose();
    _titleController.dispose();
    _descController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primary,
              surface: AppTheme.surface,
              onSurface: AppTheme.text,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_dueDate ?? DateTime.now()),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.dark(
                primary: AppTheme.primary,
                surface: AppTheme.surface,
                onSurface: AppTheme.text,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          _dueDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      } else {
        setState(() {
          _dueDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, 23, 59);
        });
      }
    }
  }

  String _formatDueDate(DateTime? dt) {
    if (dt == null) return 'No due date';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} $hour:$min $amPm';
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      AppToast.showWarning(context, 'Please enter an assignment title.');
      return;
    }

    final effectiveSubjectId = _selectedSubjectId ?? widget.subjectId;
    if (effectiveSubjectId == null || effectiveSubjectId <= 0) {
      AppToast.showWarning(context, 'Please select a subject for this assignment.');
      return;
    }

    final points = int.tryParse(_pointsController.text.trim()) ?? 100;
    final user = ref.read(authProvider);
    final teacherId = user?.id ?? 'teacher_1';
    final teacherName = user?.fullName ?? 'Sir John Reyes';

    setState(() => _isSaving = true);

    try {
      await DatabaseHelper().createAssignment(
        title: title,
        description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
        subjectId: effectiveSubjectId,
        teacherId: teacherId,
        teacherName: teacherName,
        targetSections: _selectedSection,
        dueDate: _dueDate?.toIso8601String(),
        totalPoints: points,
        submissionType: _submissionType,
        attachmentName: _attachmentName,
        attachmentPath: _attachmentPath,
        attachmentSize: _attachmentSize,
        attachmentBytes: _attachmentBase64,
      );

      // Invalidate relevant providers
      ref.invalidate(subjectAssignmentsProvider(effectiveSubjectId));
      ref.invalidate(teacherSubjectsProvider);

      SessionDraftService.instance.clearForm(_formId);

      if (mounted) {
        AppToast.showSuccess(context, 'Assignment "$title" created successfully!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Error creating assignment: ${e.toString().replaceFirst("Exception: ", "")}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  bool get _hasUnsavedChanges =>
      _titleController.text.trim().isNotEmpty || _descController.text.trim().isNotEmpty;

  Future<void> _handleCancel() async {
    if (_isSaving) return;
    if (!_hasUnsavedChanges) {
      Navigator.pop(context);
      return;
    }
    final shouldDiscard = await AppModalTransitions.confirmDiscardChanges(
      context: context,
      title: 'Discard Assignment Draft?',
      message: 'You have unsaved changes to this assignment. Are you sure you want to discard them?',
    );
    if (shouldDiscard && mounted) {
      SessionDraftService.instance.clearForm(_formId);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldDiscard = await AppModalTransitions.confirmDiscardChanges(
          context: context,
          title: 'Discard Assignment Draft?',
          message: 'You have unsaved changes to this assignment. Are you sure you want to discard them?',
        );
        if (shouldDiscard && context.mounted) {
          SessionDraftService.instance.clearForm(_formId);
          Navigator.pop(context);
        }
      },
      child: Dialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 500,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Bar
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.assignment_add, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Assignment',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                        ),
                        Text(
                          _selectedSubjectName ?? widget.subjectName ?? 'New Activity / Project',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppTheme.textMuted),
                    onPressed: _handleCancel,
                  ),
                ],
              ),
            const SizedBox(height: 18),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subject Context or Selection Dropdown
                    if (widget.subjectId != null && widget.subjectId! > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.menu_book, color: AppTheme.primary, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Subject / Class Context',
                                    style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    _selectedSubjectName ?? widget.subjectName ?? 'Subject',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ] else ...[
                      Text('Assigned Subject *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                      const SizedBox(height: 6),
                      Consumer(
                        builder: (context, ref, _) {
                          final teacherSubjects = ref.watch(teacherSubjectsProvider);
                          return DropdownButtonFormField<int>(
                            initialValue: _selectedSubjectId,
                            decoration: InputDecoration(
                              hintText: 'Select which subject to assign to',
                              hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                              filled: true,
                              fillColor: AppTheme.background,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.primary)),
                            ),
                            items: teacherSubjects.map((s) {
                              final sId = s['id'] as int;
                              final sName = s['name']?.toString() ?? 'Subject';
                              final sCode = s['subject_code']?.toString() ?? '';
                              return DropdownMenuItem<int>(
                                value: sId,
                                child: Text(
                                  sCode.isNotEmpty ? '$sName ($sCode)' : sName,
                                  style: TextStyle(color: AppTheme.text, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedSubjectId = val;
                                final match = teacherSubjects.firstWhere((s) => s['id'] == val, orElse: () => {});
                                _selectedSubjectName = match['name']?.toString();
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Target Handled Section(s)
                    Text('Target Handled Section *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    Consumer(
                      builder: (context, ref, _) {
                        final sectionsAsync = ref.watch(teacherHandledSectionsProvider);
                        final handledSections = sectionsAsync.value ?? [];
                        final allOptions = ['All Handled Sections', ...handledSections.where((s) => s != 'All Handled Sections' && s != 'All Sections')];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: allOptions.contains(_selectedSection) ? _selectedSection : 'All Handled Sections',
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.groups_outlined, size: 18, color: AppTheme.primary),
                                hintText: 'Specify which section will do this task',
                                hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                filled: true,
                                fillColor: AppTheme.background,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.primary)),
                              ),
                              items: allOptions.map((sec) {
                                return DropdownMenuItem<String>(
                                  value: sec,
                                  child: Text(
                                    sec == 'All Handled Sections' ? '👥 All Handled Sections (All Students)' : '📌 $sec',
                                    style: TextStyle(
                                      color: AppTheme.text,
                                      fontSize: 13,
                                      fontWeight: sec == 'All Handled Sections' ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedSection = val;
                                  });
                                }
                              },
                            ),
                            if (allOptions.length > 1) ...[
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: allOptions.map((sec) {
                                    final isSel = _selectedSection == sec;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ChoiceChip(
                                        label: Text(
                                          sec == 'All Handled Sections' ? 'All Sections' : sec,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                        selected: isSel,
                                        onSelected: (_) => setState(() => _selectedSection = sec),
                                        selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                                        backgroundColor: AppTheme.background,
                                        labelStyle: TextStyle(
                                          color: isSel ? AppTheme.primary : AppTheme.textMuted,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Assignment Title
                    Text('Title *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _titleController,
                      maxLength: 80,
                      style: TextStyle(color: AppTheme.text),
                      decoration: InputDecoration(
                        hintText: 'e.g. Unit 1 Project: Mobile Layout Design',
                        hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        filled: true,
                        fillColor: AppTheme.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.primary)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description / Instructions
                    Text('Instructions & Requirements', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _descController,
                      maxLength: 1500,
                      style: TextStyle(color: AppTheme.text),
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Explain the project expectations, deliverables, and submission guidelines...',
                        hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        filled: true,
                        fillColor: AppTheme.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.primary)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Due Date & Points Row
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Due Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: _pickDueDate,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.background,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _formatDueDate(_dueDate),
                                          style: TextStyle(color: AppTheme.text, fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Points', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _pointsController,
                                maxLength: 4,
                                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: AppTheme.text),
                                decoration: InputDecoration(
                                  counterText: '',
                                  suffixText: 'pts',
                                  suffixStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                  filled: true,
                                  fillColor: AppTheme.background,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.primary)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Allowed Submission Format
                    Text('Allowed Submission Format', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        children: [
                          _buildFormatOption(
                            value: 'both',
                            title: 'Both Link & File (Recommended)',
                            subtitle: 'Students can paste links or upload documents',
                          ),
                          Divider(height: 1, color: AppTheme.border),
                          _buildFormatOption(
                            value: 'file',
                            title: 'File Upload Only',
                            subtitle: 'Students must attach a file (PDF, ZIP, DOC, etc.)',
                          ),
                          Divider(height: 1, color: AppTheme.border),
                          _buildFormatOption(
                            value: 'link',
                            title: 'Web Link Only',
                            subtitle: 'GitHub, Figma, Google Drive or external URL',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Teacher Reference Attachment
                    Text('Attach Worksheet / Rubric / Handout (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    if (_attachmentName != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.attach_file, color: AppTheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$_attachmentName (${(_attachmentSize != null && _attachmentSize! > 0) ? (_attachmentSize! / 1024).toStringAsFixed(1) : ""} KB)',
                                style: TextStyle(color: AppTheme.text, fontSize: 12, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, size: 18, color: AppTheme.error),
                              tooltip: 'Remove Attachment',
                              onPressed: () {
                                setState(() {
                                  _attachmentName = null;
                                  _attachmentSize = null;
                                  _attachmentPath = null;
                                  _attachmentBase64 = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      OutlinedButton.icon(
                        onPressed: _pickAttachment,
                        icon: Icon(Icons.upload_file_outlined, size: 18, color: AppTheme.primary),
                        label: Text('Upload Assignment Handout / Brief', style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Dialog Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _handleCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textMuted,
                    side: BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Create Assignment', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildFormatOption({
    required String value,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _submissionType == value;
    return InkWell(
      onTap: () => setState(() => _submissionType = value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.text,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
