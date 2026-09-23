import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/csv_helper.dart';
import '../../../../../core/utils/file_download_helper.dart';
import '../../../data/admin_repository.dart';

class TeacherBulkImportModal extends ConsumerStatefulWidget {
  const TeacherBulkImportModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const TeacherBulkImportModal(),
    );
  }

  @override
  ConsumerState<TeacherBulkImportModal> createState() => _TeacherBulkImportModalState();
}

class _TeacherRowValidation {
  final int rowNumber;
  final bool isValid;
  final String? issue;
  final Map<String, String> data;

  _TeacherRowValidation({
    required this.rowNumber,
    required this.isValid,
    this.issue,
    required this.data,
  });
}

class _TeacherBulkImportModalState extends ConsumerState<TeacherBulkImportModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _pasteController = TextEditingController();

  List<_TeacherRowValidation> _validationResults = [];
  bool _isProcessing = false;
  String? _uploadFileName;
  String? _errorMessage;
  String _previewFilter = 'All'; // 'All', 'Valid', 'Issues'
  bool _autoGeneratePasswords = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _pasteController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _pasteController.removeListener(_onTextChanged);
    _pasteController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _analyzeCsvContent(_pasteController.text);
  }

  void _analyzeCsvContent(String rawText) {
    if (rawText.trim().isEmpty) {
      setState(() {
        _validationResults = [];
        _errorMessage = null;
      });
      return;
    }

    try {
      final rows = CsvHelper.parse(rawText);
      final validations = <_TeacherRowValidation>[];
      final seenEmails = <String>{};

      for (int i = 0; i < rows.length; i++) {
        final row = rows[i];
        final name = (row['full_name'] ?? '').trim();
        final email = (row['email'] ?? '').trim().toLowerCase();

        String? issue;
        if (name.isEmpty) {
          issue = 'Missing faculty name';
        } else if (email.isEmpty) {
          issue = 'Missing email address';
        } else if (!email.contains('@') || !email.contains('.')) {
          issue = 'Invalid email syntax';
        } else if (seenEmails.contains(email)) {
          issue = 'Duplicate email in batch';
        } else {
          seenEmails.add(email);
        }

        validations.add(_TeacherRowValidation(
          rowNumber: i + 1,
          isValid: issue == null,
          issue: issue,
          data: row,
        ));
      }

      setState(() {
        _validationResults = validations;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to parse CSV: $e';
        _validationResults = [];
      });
    }
  }

  Future<void> _handleFilePick() async {
    try {
      final content = await pickCsvFile();
      if (content != null && content.isNotEmpty) {
        setState(() {
          _uploadFileName = 'Uploaded file (${content.length} bytes)';
          _pasteController.text = content;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  void _downloadTemplate() {
    final csvData = CsvHelper.getTeacherTemplateCsv();
    downloadCsvFile(csvData, 'airamp_faculty_template.csv');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.download_done, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Template downloaded: airamp_faculty_template.csv'),
          ],
        ),
        backgroundColor: AppTheme.primary,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _commitImport() async {
    final validRows = _validationResults
        .where((v) => v.isValid)
        .map((v) => Map<String, dynamic>.from(v.data))
        .toList();

    if (validRows.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final result = await ref.read(adminTeachersProvider.notifier).bulkImportTeachers(
            validRows,
            defaultPassword: _autoGeneratePasswords ? null : 'Teacher@123',
          );
      final successCount = result['successCount'] as int? ?? 0;
      final failedCount = result['failedCount'] as int? ?? 0;
      final errors = (result['errors'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final insertedTeachers = (result['insertedTeachers'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (!mounted) return;
      Navigator.of(context).pop();

      _showImportSummaryDialog(
        successCount: successCount,
        failedCount: failedCount,
        errors: errors,
        insertedTeachers: insertedTeachers,
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  void _showImportSummaryDialog({
    required int successCount,
    required int failedCount,
    required List<Map<String, dynamic>> errors,
    required List<Map<String, dynamic>> insertedTeachers,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              failedCount == 0 ? Icons.check_circle : Icons.info_outline,
              color: failedCount == 0 ? AppTheme.success : AppTheme.warning,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text('Faculty Import Summary', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 420),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Metrics Overview
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Text('$successCount', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.success)),
                            Text('Imported Successfully', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: failedCount > 0 ? AppTheme.error.withValues(alpha: 0.12) : AppTheme.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: failedCount > 0 ? AppTheme.error.withValues(alpha: 0.3) : AppTheme.border),
                        ),
                        child: Column(
                          children: [
                            Text('$failedCount', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: failedCount > 0 ? AppTheme.error : AppTheme.textMuted)),
                            Text('Skipped / Errors', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Error details if any
                if (errors.isNotEmpty) ...[
                  Text('Skipped Rows & Issues:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.error)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: errors.map((e) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '• Row ${e['row']}: ${e['email']} (${e['reason']})',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Export Credentials Info
                if (insertedTeachers.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.key, size: 20, color: AppTheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Credentials Auto-Generated',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.text),
                              ),
                              Text(
                                'You can export the faculty credentials sheet (CSV) to send or distribute login details.',
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (insertedTeachers.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                _exportCredentialsCsv(insertedTeachers);
              },
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Export Credentials (CSV)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _exportCredentialsCsv(List<Map<String, dynamic>> teachers) {
    final nowStr = DateTime.now().toIso8601String().split('T').first;
    final headers = ['Full Name', 'Email', 'Username', 'Temporary Password', 'Handled Sections', 'Specialty / Notes'];
    final rows = teachers.map((t) {
      return [
        t['full_name'] ?? '',
        t['email'] ?? '',
        t['username'] ?? '',
        t['plain_password'] ?? '',
        t['handled_sections'] ?? '',
        t['special_notes'] ?? '',
      ];
    }).toList();

    final csvContent = CsvHelper.generate(headers: headers, rows: rows);
    downloadCsvFile(csvContent, 'faculty_credentials_$nowStr.csv');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Credentials exported: faculty_credentials.csv'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final validCount = _validationResults.where((v) => v.isValid).length;
    final issueCount = _validationResults.where((v) => !v.isValid).length;

    final displayedValidations = _previewFilter == 'Valid'
        ? _validationResults.where((v) => v.isValid).toList()
        : _previewFilter == 'Issues'
            ? _validationResults.where((v) => !v.isValid).toList()
            : _validationResults;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 860,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.group_add_outlined, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bulk Import Faculty & Instructors (CSV)',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                        ),
                        Text(
                          'Onboard multiple faculty accounts at once via CSV upload or text paste',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _downloadTemplate,
                    icon: const Icon(Icons.file_download_outlined, size: 16),
                    label: const Text('Template .CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.close, color: AppTheme.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tab Selector (Paste vs File Upload)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.background,
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textMuted,
                indicatorColor: AppTheme.primary,
                indicatorWeight: 2,
                tabs: const [
                  Tab(icon: Icon(Icons.content_paste, size: 18), text: 'Direct Paste CSV'),
                  Tab(icon: Icon(Icons.upload_file, size: 18), text: 'Upload .CSV File'),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Direct Paste
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _pasteController,
                            maxLines: null,
                            expands: true,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Paste CSV rows here...\n\nExample:\nfull_name,email,handled_sections,specialty,notes\nMr. Arthur Santos,arthur.santos@school.edu,"STEM 12-A, STEM 12-B",General Mathematics,Lead Instructor\nMs. Elena Rivera,elena.rivera@school.edu,STEM 12-A,Earth & Life Science,Coordinator',
                              hintStyle: TextStyle(color: AppTheme.textMuted, fontFamily: 'monospace', fontSize: 12),
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
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tab 2: Upload File
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_upload_outlined, size: 48, color: AppTheme.primary),
                            const SizedBox(height: 12),
                            Text(
                              _uploadFileName ?? 'Select a CSV file from your computer',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.text),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Columns: full_name, email, handled_sections, specialty, notes',
                              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _handleFilePick,
                              icon: const Icon(Icons.folder_open, size: 18),
                              label: const Text('Browse CSV File'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Password Generator Configuration Option
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              color: AppTheme.background,
              child: Row(
                children: [
                  Checkbox(
                    value: _autoGeneratePasswords,
                    activeColor: AppTheme.primary,
                    onChanged: (val) => setState(() => _autoGeneratePasswords = val ?? true),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Auto-generate randomized secure passwords for faculty (e.g. Teach_8392#) and include in downloadable credentials summary',
                      style: TextStyle(fontSize: 12, color: AppTheme.text),
                    ),
                  ),
                ],
              ),
            ),

            // Validation Summary & Table
            if (_validationResults.isNotEmpty) ...[
              Container(
                height: 180,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppTheme.border)),
                ),
                child: Column(
                  children: [
                    // Filter bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      color: AppTheme.surface,
                      child: Row(
                        children: [
                          Text('Validation Preview:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.text)),
                          const SizedBox(width: 12),
                          ChoiceChip(
                            label: Text('All (${_validationResults.length})'),
                            selected: _previewFilter == 'All',
                            onSelected: (_) => setState(() => _previewFilter = 'All'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text('Valid ($validCount)'),
                            selected: _previewFilter == 'Valid',
                            selectedColor: AppTheme.success.withValues(alpha: 0.2),
                            onSelected: (_) => setState(() => _previewFilter = 'Valid'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text('Issues ($issueCount)'),
                            selected: _previewFilter == 'Issues',
                            selectedColor: AppTheme.error.withValues(alpha: 0.2),
                            onSelected: (_) => setState(() => _previewFilter = 'Issues'),
                          ),
                        ],
                      ),
                    ),
                    // Table rows
                    Expanded(
                      child: ListView.separated(
                        itemCount: displayedValidations.length,
                        separatorBuilder: (_, _) => Divider(height: 1, color: AppTheme.border),
                        itemBuilder: (context, index) {
                          final v = displayedValidations[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            color: v.isValid ? Colors.transparent : AppTheme.error.withValues(alpha: 0.05),
                            child: Row(
                              children: [
                                Text('Row ${v.rowNumber}', style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontFamily: 'monospace')),
                                const SizedBox(width: 14),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    v.data['full_name'] ?? 'Missing Name',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.text),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    v.data['email'] ?? 'Missing Email',
                                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: v.isValid ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.error.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    v.isValid ? 'READY' : (v.issue ?? 'INVALID'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: v.isValid ? AppTheme.success : AppTheme.error,
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
            ],

            // Modal Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  if (_errorMessage != null)
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: AppTheme.error, fontSize: 12),
                      ),
                    )
                  else if (_validationResults.isNotEmpty)
                    Expanded(
                      child: Text(
                        '$validCount valid row(s) ready to import${issueCount > 0 ? ', $issueCount will be skipped' : ''}',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    )
                  else
                    const Spacer(),
                  TextButton(
                    onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                    child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: (_isProcessing || validCount == 0) ? null : _commitImport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text('Import $validCount Faculty'),
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
