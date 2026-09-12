import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/csv_helper.dart';
import '../../../../../core/utils/file_download_helper.dart';
import '../../../data/admin_repository.dart';

class BulkImportModal extends ConsumerStatefulWidget {
  const BulkImportModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const BulkImportModal(),
    );
  }

  @override
  ConsumerState<BulkImportModal> createState() => _BulkImportModalState();
}

class _BulkImportModalState extends ConsumerState<BulkImportModal> with SingleTickerProviderStateMixin {
  final TextEditingController _pasteController = TextEditingController();
  late TabController _tabController;

  List<Map<String, String>> _parsedRows = [];
  List<_RowValidation> _validationResults = [];
  bool _isProcessing = false;
  String? _uploadFileName;
  String? _errorMessage;

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
        _parsedRows = [];
        _validationResults = [];
        _errorMessage = null;
      });
      return;
    }

    try {
      final rows = CsvHelper.parse(rawText);
      final validations = <_RowValidation>[];
      final seenEmails = <String>{};

      for (int i = 0; i < rows.length; i++) {
        final row = rows[i];
        final name = (row['full_name'] ?? '').trim();
        final email = (row['email'] ?? '').trim().toLowerCase();

        String? issue;
        if (name.isEmpty) {
          issue = 'Missing full name';
        } else if (email.isEmpty) {
          issue = 'Missing email address';
        } else if (!email.contains('@') || !email.contains('.')) {
          issue = 'Invalid email syntax';
        } else if (seenEmails.contains(email)) {
          issue = 'Duplicate email in batch';
        } else {
          seenEmails.add(email);
        }

        validations.add(_RowValidation(
          rowNumber: i + 1,
          isValid: issue == null,
          issue: issue,
          data: row,
        ));
      }

      setState(() {
        _parsedRows = rows;
        _validationResults = validations;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to parse CSV: $e';
        _parsedRows = [];
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
    final csvData = CsvHelper.getStudentTemplateCsv();
    downloadCsvFile(csvData, 'airamp_student_template.csv');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.download_done, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Template downloaded: airamp_student_template.csv'),
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
      final result = await ref.read(adminStudentsProvider.notifier).bulkImportUsers(validRows);
      final successCount = result['successCount'] as int? ?? 0;
      final failedCount = result['failedCount'] as int? ?? 0;

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bulk import complete! $successCount user(s) imported.'
                  '${failedCount > 0 ? ' ($failedCount skipped)' : ''}',
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final validCount = _validationResults.where((v) => v.isValid).length;
    final issueCount = _validationResults.where((v) => !v.isValid).length;

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
            _buildHeader(),

            // Tabs / Method selection
            _buildTabSelector(),

            // Content Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Input View (Paste Text or File Pick)
                    SizedBox(
                      height: 165,
                      child: TabBarView(
                        controller: _tabController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          // Tab 1: Paste Text
                          _buildPasteArea(),
                          // Tab 2: Upload File
                          _buildUploadArea(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Pre-flight validation summary bar
                    _buildValidationStatusBar(validCount, issueCount),

                    const SizedBox(height: 10),

                    // Live Table Preview
                    Expanded(
                      child: _buildPreviewTable(),
                    ),
                  ],
                ),
              ),
            ),

            // Modal Footer Actions
            _buildFooter(validCount),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
      decoration: BoxDecoration(
        color: AppTheme.background.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
            child: Icon(Icons.group_add_rounded, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bulk Import Students & Faculty',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Onboard multiple student accounts at once via CSV file upload or text paste',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Download Template Button
          OutlinedButton.icon(
            onPressed: _downloadTemplate,
            icon: const Icon(Icons.file_download_outlined, size: 16),
            label: const Text('Template .CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 8),
          // Close button
          IconButton(
            icon: Icon(Icons.close, color: AppTheme.textMuted, size: 20),
            tooltip: 'Close dialog',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        labelColor: AppTheme.primary,
        unselectedLabelColor: AppTheme.textMuted,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(
            icon: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.content_paste_rounded, size: 16),
                SizedBox(width: 8),
                Text('Direct Paste CSV'),
              ],
            ),
          ),
          Tab(
            icon: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_file_rounded, size: 16),
                SizedBox(width: 8),
                Text('Upload .CSV File'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasteArea() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: TextField(
        controller: _pasteController,
        maxLines: null,
        expands: true,
        style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppTheme.text),
        decoration: InputDecoration(
          hintText: 'Paste comma-separated rows with header (e.g. full_name,email,role,grade,section)...',
          hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(12),
          suffixIcon: _pasteController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () => _pasteController.clear(),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildUploadArea() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border, style: BorderStyle.solid),
      ),
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_upload_outlined, size: 32, color: AppTheme.primary),
              const SizedBox(height: 6),
              Text(
                _uploadFileName ?? 'Select standard CSV file from your computer',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.text,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _handleFilePick,
                icon: const Icon(Icons.folder_open, size: 15),
                label: const Text('Browse CSV File', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValidationStatusBar(int validCount, int issueCount) {
    if (_parsedRows.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: AppTheme.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Paste CSV content or load a file above to inspect validation preview.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          // Total Rows Badge
          _buildBadge(
            label: '${_parsedRows.length} Rows',
            color: AppTheme.textSecondary,
            icon: Icons.list_alt,
          ),
          const SizedBox(width: 10),
          // Valid Records Badge
          _buildBadge(
            label: '$validCount Valid',
            color: AppTheme.success,
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(width: 10),
          // Issues Badge
          if (issueCount > 0)
            _buildBadge(
              label: '$issueCount Issues',
              color: AppTheme.error,
              icon: Icons.error_outline,
            ),
          if (_errorMessage != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(fontSize: 12, color: AppTheme.error, fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTable() {
    if (_validationResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.table_chart_outlined, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text(
              'No CSV data loaded yet',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppTheme.surface),
            headingTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.text),
            dataTextStyle: TextStyle(fontSize: 12, color: AppTheme.text),
            columnSpacing: 16,
            horizontalMargin: 16,
            columns: const [
              DataColumn(label: Text('#')),
              DataColumn(label: Text('Full Name')),
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Role')),
              DataColumn(label: Text('Grade & Section')),
              DataColumn(label: Text('Classification')),
              DataColumn(label: Text('Validation')),
            ],
            rows: _validationResults.map((val) {
              final d = val.data;
              return DataRow(
                color: WidgetStateProperty.resolveWith<Color?>((states) {
                  if (!val.isValid) return AppTheme.error.withValues(alpha: 0.08);
                  return null;
                }),
                cells: [
                  DataCell(Text('${val.rowNumber}')),
                  DataCell(
                    Text(
                      d['full_name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  DataCell(Text(d['email'] ?? '')),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (d['role'] == 'teacher' ? AppTheme.warning : AppTheme.primary).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        (d['role'] ?? 'student').toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: d['role'] == 'teacher' ? AppTheme.warning : AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
                  DataCell(Text('${d['grade'] ?? '-'} / ${d['section'] ?? 'Unassigned'}')),
                  DataCell(Text(d['student_type'] ?? 'regular')),
                  DataCell(
                    val.isValid
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 16, color: AppTheme.success),
                              const SizedBox(width: 4),
                              Text('Ready', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error, size: 16, color: AppTheme.error),
                              const SizedBox(width: 4),
                              Text(
                                val.issue ?? 'Error',
                                style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ],
                          ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(int validCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.background.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          const SizedBox(width: 14),
          ElevatedButton(
            onPressed: (_isProcessing || validCount == 0) ? null : _commitImport,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_upload_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        validCount > 0 ? 'Commit Import ($validCount Records)' : 'No Records Ready',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RowValidation {
  final int rowNumber;
  final bool isValid;
  final String? issue;
  final Map<String, String> data;

  _RowValidation({
    required this.rowNumber,
    required this.isValid,
    this.issue,
    required this.data,
  });
}
