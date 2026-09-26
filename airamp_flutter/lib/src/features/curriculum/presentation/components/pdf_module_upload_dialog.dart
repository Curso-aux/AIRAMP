import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../admin/data/admin_repository.dart';
import '../../domain/pdf_module_parser_service.dart';

/// Modal dialog wrapper for [PdfModuleUploadCard].
class PdfModuleUploadDialog extends StatelessWidget {
  final int? subjectId;
  final String? subjectName;
  final int? initialTopicId;
  final String? initialTopicTitle;

  const PdfModuleUploadDialog({
    super.key,
    this.subjectId,
    this.subjectName,
    this.initialTopicId,
    this.initialTopicTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 680,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: PdfModuleUploadCard(
          subjectId: subjectId,
          subjectName: subjectName,
          initialTopicId: initialTopicId,
          initialTopicTitle: initialTopicTitle,
          isDialog: true,
          onCancel: () => Navigator.of(context).pop(false),
          onCompleted: (result) {
            // Note: If creating a new subject, handled in Card's Done button
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop(result.success);
            }
          },
        ),
      ),
    );
  }
}

/// Reusable Card component for uploading and scanning PDF modules.
/// Can be rendered directly in-page (e.g. in empty SubjectDetailScreen)
/// or inside a Dialog modal.
class PdfModuleUploadCard extends ConsumerStatefulWidget {
  final int? subjectId;
  final String? subjectName;
  final int? initialTopicId;
  final String? initialTopicTitle;
  final bool isDialog;
  final VoidCallback? onCancel;
  final void Function(PdfModuleParseResult result)? onCompleted;

  const PdfModuleUploadCard({
    super.key,
    this.subjectId,
    this.subjectName,
    this.initialTopicId,
    this.initialTopicTitle,
    this.isDialog = false,
    this.onCancel,
    this.onCompleted,
  });

  @override
  ConsumerState<PdfModuleUploadCard> createState() => _PdfModuleUploadCardState();
}

class _PdfModuleUploadCardState extends ConsumerState<PdfModuleUploadCard> {
  // Mode: 'topic' or 'whole_module'
  late String _uploadType;
  late String _selectedTerm;

  // New Subject creation fields (if widget.subjectId == null)
  final TextEditingController _subjectNameController = TextEditingController();
  String _selectedSemester = '1st Semester';

  // Single Topic target
  int? _selectedTopicId;
  final TextEditingController _customTopicController = TextEditingController();

  // Picked file
  String? _pickedFileName;
  int _pickedFileSize = 0;
  Uint8List? _pickedFileBytes;
  bool _isDragging = false;

  // Processing state
  bool _isProcessing = false;
  String _statusMessage = '';
  double _progress = 0.0;
  PdfModuleParseResult? _parseResult;

  @override
  void initState() {
    super.initState();
    _uploadType = (widget.initialTopicId != null) ? 'topic' : 'whole_module';
    _selectedTerm = 'Prelim';
    _selectedTopicId = widget.initialTopicId;
    if (widget.initialTopicTitle != null) {
      _customTopicController.text = widget.initialTopicTitle!;
    }
    if (widget.subjectName != null && widget.subjectName!.isNotEmpty) {
      _subjectNameController.text = widget.subjectName!;
    }
  }

  @override
  void dispose() {
    _customTopicController.dispose();
    _subjectNameController.dispose();
    super.dispose();
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _autoFillNames(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final clean = (dot != -1) ? fileName.substring(0, dot) : fileName;
    final humanTitle = clean
        .replaceAll(RegExp(r'[_+\-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (widget.subjectId == null && _subjectNameController.text.trim().isEmpty) {
      _subjectNameController.text = humanTitle;
    }
    if (_uploadType == 'topic' && _customTopicController.text.trim().isEmpty) {
      _customTopicController.text = humanTitle;
    }
  }

  Future<void> _pickPdfFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        final size = await file.length();
        setState(() {
          _pickedFileName = file.name;
          _pickedFileSize = size > 0 ? size : bytes.length;
          _pickedFileBytes = bytes;
          _autoFillNames(file.name);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read PDF file: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _onFileDropped(DropItem item) async {
    final lowerName = item.name.toLowerCase();
    if (!lowerName.endsWith('.pdf')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only PDF documents are supported for module scanning.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final bytes = await item.readAsBytes();
      final length = await item.length();
      setState(() {
        _pickedFileName = item.name;
        _pickedFileSize = length > 0 ? length : bytes.length;
        _pickedFileBytes = bytes;
        _autoFillNames(item.name);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not read dropped file: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _startParsingAndImport() async {
    if (_pickedFileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or drop a PDF module first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Reading PDF binary data...';
      _progress = 0.05;
      _parseResult = null;
    });

    final parser = PdfModuleParserService();
    PdfModuleParseResult result;

    if (widget.subjectId == null) {
      // ── Create Subject from PDF Module Mode ──
      result = await parser.createSubjectAndImportPdf(
        pdfBytes: _pickedFileBytes!,
        fileName: _pickedFileName ?? 'module.pdf',
        customSubjectName: _subjectNameController.text.trim().isNotEmpty
            ? _subjectNameController.text.trim()
            : null,
        semester: _selectedSemester,
        uploadType: _uploadType,
        term: _selectedTerm,
        onProgress: (status, prog) {
          if (mounted) {
            setState(() {
              _statusMessage = status;
              _progress = prog;
            });
          }
        },
      );

      if (result.success && mounted) {
        ref.read(subjectsProvider.notifier).reload();
        if (result.createdSubjectId != null) {
          ref.read(subjectDetailProvider.notifier).loadHierarchy(result.createdSubjectId!);
        }
      }
    } else {
      // ── Import into Existing Subject Mode ──
      result = await parser.parseAndImportPdf(
        pdfBytes: _pickedFileBytes!,
        fileName: _pickedFileName ?? 'module.pdf',
        subjectId: widget.subjectId!,
        uploadType: _uploadType,
        term: _selectedTerm,
        targetTopicId: _selectedTopicId,
        customTopicTitle: _customTopicController.text.trim().isNotEmpty
            ? _customTopicController.text.trim()
            : null,
        onProgress: (status, prog) {
          if (mounted) {
            setState(() {
              _statusMessage = status;
              _progress = prog;
            });
          }
        },
      );

      if (result.success && mounted) {
        ref.read(subjectDetailProvider.notifier).loadHierarchy(widget.subjectId!);
      }
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _parseResult = result;
      });

      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Error processing PDF module'),
            backgroundColor: AppTheme.error,
          ),
        );
      } else {
        if (widget.onCompleted != null) {
          widget.onCompleted!(result);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingTopics = ref.watch(subjectDetailProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDialog ? AppTheme.border : AppTheme.primary.withValues(alpha: 0.35),
          width: widget.isDialog ? 1.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDialog ? 0.25 : 0.08),
            blurRadius: widget.isDialog ? 28 : 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header Banner ──
            _buildHeader(context),

            // ── Body ──
            if (widget.isDialog)
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _parseResult != null && _parseResult!.success
                      ? _buildSuccessSummary(context)
                      : _buildForm(context, existingTopics, isDark),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(24),
                child: _parseResult != null && _parseResult!.success
                    ? _buildSuccessSummary(context)
                    : _buildForm(context, existingTopics, isDark),
              ),

            // ── Footer Actions ──
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isCreatingSubject = widget.subjectId == null;
    final title = isCreatingSubject
        ? 'Create Subject from PDF Module'
        : 'AI Module Scanner & Importer';
    final subtitle = isCreatingSubject
        ? 'Auto-scan PDF to generate subject, curriculum & Gizmo quizzes'
        : (widget.subjectName != null && widget.subjectName!.isNotEmpty
            ? widget.subjectName!
            : 'Auto-detect topics, LOs, and Gizmo review practice');

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.15),
            const Color(0xFF0D9488).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.picture_as_pdf, color: Colors.white, size: 26),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'AUTO-QUIZ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (widget.isDialog)
            IconButton(
              icon: Icon(Icons.close, color: AppTheme.textMuted),
              onPressed: widget.onCancel ?? () => Navigator.of(context).pop(false),
            ),
        ],
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    List<Map<String, dynamic>> existingTopics,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 0. Subject Info (if creating brand new subject from PDF) ──
        if (widget.subjectId == null) ...[
          Text(
            '1. Subject / Course Information',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _subjectNameController,
                  enabled: !_isProcessing,
                  decoration: InputDecoration(
                    labelText: 'Subject / Course Name',
                    hintText: 'e.g. Fundamentals of Business Analytics',
                    labelStyle: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    helperText: 'Auto-filled from PDF file name, or enter your custom name',
                    helperStyle: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Academic Semester',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: ['1st Semester', '2nd Semester', 'Summer'].map((sem) {
                    final isSel = _selectedSemester == sem;
                    return ChoiceChip(
                      label: Text(sem),
                      selected: isSel,
                      selectedColor: AppTheme.primary,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.black : Theme.of(context).colorScheme.onSurface,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: _isProcessing ? null : (_) => setState(() => _selectedSemester = sem),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── 1. Select Upload Mode / Scope ──
        Text(
          widget.subjectId == null ? '2. Choose PDF Module Scope' : '1. Choose PDF Module Scope',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Option A: Single Topic
            Expanded(
              child: _buildScopeCard(
                title: 'Single Topic PDF',
                subtitle: 'Upload material for a specific topic (e.g. Topic 1)',
                icon: Icons.bookmark_border,
                isSelected: _uploadType == 'topic',
                onTap: _isProcessing
                    ? null
                    : () => setState(() => _uploadType = 'topic'),
              ),
            ),
            const SizedBox(width: 12),
            // Option B: Whole Module
            Expanded(
              child: _buildScopeCard(
                title: 'Whole Module / Term',
                subtitle: 'Multi-topic syllabus for Prelim, Midterm, or Finals',
                icon: Icons.auto_stories_outlined,
                isSelected: _uploadType == 'whole_module',
                onTap: _isProcessing
                    ? null
                    : () => setState(() => _uploadType = 'whole_module'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Scope Details Configuration
        if (_uploadType == 'topic') ...[
          _buildTopicConfigSection(context, existingTopics),
        ] else ...[
          _buildTermConfigSection(context),
        ],

        const SizedBox(height: 24),

        // ── 2. PDF File Dropzone / Browser ──
        Text(
          widget.subjectId == null ? '3. Select or Drop PDF File' : '2. Select or Drop PDF File',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        _buildDropzone(context),

        // ── 3. Processing Indicator ──
        if (_isProcessing) ...[
          const SizedBox(height: 24),
          _buildProcessingCard(context),
        ],
      ],
    );
  }

  Widget _buildScopeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.12)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                ),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle, size: 18, color: AppTheme.primary)
                else
                  Icon(Icons.circle_outlined, size: 18, color: AppTheme.border),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicConfigSection(
    BuildContext context,
    List<Map<String, dynamic>> existingTopics,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category_outlined, size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                'Target Topic Destination',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.subjectId != null && existingTopics.isNotEmpty) ...[
            DropdownButtonFormField<int?>(
              initialValue: _selectedTopicId,
              isExpanded: true,
              dropdownColor: Theme.of(context).colorScheme.surface,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                hintText: 'Select existing topic or create new',
                hintStyle: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('➕ Create as New Topic (Auto-Detected from PDF)'),
                ),
                ...existingTopics.map((t) {
                  final tid = t['id'] as int;
                  final ttitle = t['title']?.toString() ?? 'Topic $tid';
                  return DropdownMenuItem<int?>(
                    value: tid,
                    child: Text(
                      ttitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
              onChanged: _isProcessing
                  ? null
                  : (val) {
                      setState(() {
                        _selectedTopicId = val;
                      });
                    },
            ),
            const SizedBox(height: 10),
          ],
          if (_selectedTopicId == null)
            TextField(
              controller: _customTopicController,
              enabled: !_isProcessing,
              decoration: InputDecoration(
                labelText: 'Topic Title / Number (Optional)',
                hintText: 'e.g., Topic 1: Introduction to Mobile Architecture',
                labelStyle: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                helperText: 'Auto-detected from PDF headers if left empty.',
                helperStyle: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTermConfigSection(BuildContext context) {
    final terms = ['Prelim', 'Midterm', 'Semi-Finals', 'Finals', 'Full Course'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_outlined, size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                'Academic Term Period (Coverage)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: terms.map((term) {
              final isSel = _selectedTerm == term;
              return ChoiceChip(
                label: Text(term),
                selected: isSel,
                selectedColor: AppTheme.primary,
                labelStyle: TextStyle(
                  color: isSel ? Colors.black : Theme.of(context).colorScheme.onSurface,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                onSelected: _isProcessing ? null : (_) => setState(() => _selectedTerm = term),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDropzone(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (detail) async {
        setState(() => _isDragging = false);
        if (detail.files.isNotEmpty) {
          await _onFileDropped(detail.files.first);
        }
      },
      child: InkWell(
        onTap: _isProcessing ? null : _pickPdfFile,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: _isDragging
                ? AppTheme.primary.withValues(alpha: 0.08)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isDragging
                  ? AppTheme.primary
                  : (_pickedFileName != null ? AppTheme.primary : AppTheme.border),
              width: _isDragging || _pickedFileName != null ? 1.8 : 1.2,
              style: BorderStyle.solid,
            ),
          ),
          child: _pickedFileName != null
              ? Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(Icons.picture_as_pdf, color: Color(0xFFE11D48), size: 24),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pickedFileName!,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _formatFileSize(_pickedFileSize),
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _isProcessing ? null : _pickPdfFile,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Change'),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 40,
                      color: _isDragging ? AppTheme.primary : AppTheme.textMuted,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Drag & Drop your Module PDF here',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'or click to browse your computer files (PDF up to 50MB)',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildProcessingCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '${(_progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: Theme.of(context).colorScheme.surface,
              color: AppTheme.primary,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessSummary(BuildContext context) {
    final res = _parseResult!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Success Header
        Center(
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_outline, color: AppTheme.success, size: 40),
              ),
              const SizedBox(height: 14),
              Text(
                res.createdSubjectName != null
                    ? 'Subject "${res.createdSubjectName}" Created!'
                    : 'Module Imported & Scanned!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Curriculum content and interactive practice flashcards are ready.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Metrics Grid
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              _buildMetricRow(
                icon: Icons.layers_outlined,
                label: 'Topics Created',
                value: '${res.totalTopicsCreated}',
                color: AppTheme.primary,
              ),
              const Divider(height: 20),
              _buildMetricRow(
                icon: Icons.flag_outlined,
                label: 'Learning Outcomes (LOs)',
                value: '${res.totalLosCreated}',
                color: const Color(0xFF0EA5E9),
              ),
              const Divider(height: 20),
              _buildMetricRow(
                icon: Icons.menu_book_outlined,
                label: 'Reading Content Sections',
                value: '${res.totalContentsCreated}',
                color: const Color(0xFF8B5CF6),
              ),
              const Divider(height: 20),
              _buildMetricRow(
                icon: Icons.help_outline,
                label: 'Quiz Practice Questions',
                value: '${res.totalQuestionsCreated}',
                color: const Color(0xFFF59E0B),
              ),
              const Divider(height: 20),
              _buildMetricRow(
                icon: Icons.psychology_outlined,
                label: 'Gizmo Flashcards Generated',
                value: '${res.totalFlashcardsGenerated}',
                color: AppTheme.success,
              ),
            ],
          ),
        ),

        if (res.topicTitles.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Created Topics:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          ...res.topicTitles.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.check, size: 14, color: AppTheme.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t,
                      style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetricRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    if (_parseResult != null && _parseResult!.success) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              if (widget.onCompleted != null) {
                widget.onCompleted!(_parseResult!);
              }
              if (widget.subjectId == null && _parseResult?.createdSubjectId != null) {
                context.push('/admin/subjects/${_parseResult!.createdSubjectId}');
              }
              if (widget.isDialog && Navigator.of(context).canPop()) {
                Navigator.of(context).pop(true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Done & View Subject Curriculum',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
      );
    }

    final submitLabel = widget.subjectId == null
        ? 'Create Subject & Scan Module'
        : 'Scan & Import Module';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (widget.isDialog || widget.onCancel != null) ...[
            TextButton(
              onPressed: _isProcessing
                  ? null
                  : (widget.onCancel ?? () => Navigator.of(context).pop(false)),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(width: 12),
          ],
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _startParsingAndImport,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text(
              submitLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
