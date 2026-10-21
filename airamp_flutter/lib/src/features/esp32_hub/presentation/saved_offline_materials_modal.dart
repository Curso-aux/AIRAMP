import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/components/app_toast.dart';
import '../data/saved_materials_service.dart';
import '../domain/esp32_hub_models.dart';
import 'student_esp32_sync_modal.dart';

/// Modal sheet for students to view, search, read, and manage all offline learning materials
/// downloaded and saved from the classroom ESP32 hub.
class SavedOfflineMaterialsModal extends StatefulWidget {
  final String? studentName;
  final String? studentSection;
  final bool showHeader;

  const SavedOfflineMaterialsModal({
    super.key,
    this.studentName,
    this.studentSection,
    this.showHeader = true,
  });

  static Future<void> show(
    BuildContext context, {
    String? studentName,
    String? studentSection,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SavedOfflineMaterialsModal(
        studentName: studentName,
        studentSection: studentSection,
      ),
    );
  }

  @override
  State<SavedOfflineMaterialsModal> createState() => _SavedOfflineMaterialsModalState();
}

class _SavedOfflineMaterialsModalState extends State<SavedOfflineMaterialsModal> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';
  List<HubMaterialItem> _materials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
    SavedMaterialsService.instance.savedMaterialsNotifier.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    SavedMaterialsService.instance.savedMaterialsNotifier.removeListener(_onServiceUpdate);
    _searchController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) {
      setState(() {
        _materials = SavedMaterialsService.instance.savedMaterialsNotifier.value;
      });
    }
  }

  Future<void> _loadMaterials() async {
    final list = await SavedMaterialsService.instance.getSavedMaterials();
    if (!mounted) return;
    setState(() {
      _materials = list;
      _isLoading = false;
    });
  }

  List<HubMaterialItem> get _filteredMaterials {
    final query = _searchController.text.trim().toLowerCase();
    return _materials.where((item) {
      final matchesQuery = query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.subjectName.toLowerCase().contains(query);

      if (!matchesQuery) return false;

      switch (_selectedFilter) {
        case 'modules':
          return item.fileType == HubFileType.module;
        case 'pdfs':
          return item.fileType == HubFileType.pdf;
        case 'quizzes':
          return item.fileType == HubFileType.quiz;
        default:
          return true;
      }
    }).toList();
  }

  Color _getFileTypeColor(HubFileType type) {
    switch (type) {
      case HubFileType.pdf:
        return const Color(0xFFEF4444); // Red/Coral
      case HubFileType.quiz:
        return const Color(0xFFF59E0B); // Amber
      case HubFileType.module:
        return AppTheme.primary; // Emerald/Mint
      case HubFileType.doc:
        return const Color(0xFF3B82F6); // Blue
    }
  }

  IconData _getFileTypeIcon(HubFileType type) {
    switch (type) {
      case HubFileType.pdf:
        return Icons.picture_as_pdf_rounded;
      case HubFileType.quiz:
        return Icons.assignment_turned_in_rounded;
      case HubFileType.module:
        return Icons.menu_book_rounded;
      case HubFileType.doc:
        return Icons.description_rounded;
    }
  }

  String _getFileTypeTag(HubFileType type) {
    switch (type) {
      case HubFileType.pdf:
        return 'PDF';
      case HubFileType.quiz:
        return 'QUIZ';
      case HubFileType.module:
        return 'MODULE';
      case HubFileType.doc:
        return 'DOC';
    }
  }

  void _openReader(HubMaterialItem item) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => OfflineMaterialReaderDialog(item: item),
    );
  }

  Future<void> _confirmDelete(HubMaterialItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: AppTheme.error, size: 24),
            const SizedBox(width: 10),
            Text('Remove Offline Material?', style: TextStyle(color: AppTheme.text, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "${item.title}" from your phone cache? You can re-download it anytime from the ESP32 station.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SavedMaterialsService.instance.removeMaterial(item.id);
      if (mounted) {
        AppToast.showSuccess(context, 'Removed "${item.title}" from offline storage.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Column(
      children: [
        if (widget.showHeader) ...[
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.folder_special_rounded, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Offline Learning Materials',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.text,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              '100% Offline',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Stored on device · Browse modules and take quizzes with zero data',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
          ),
          const Divider(height: 1),
        ],

        if (_isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_materials.isEmpty)
          Expanded(child: _buildEmptyState())
        else ...[
          // Search and Filters
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search by title or subject...',
                    hintStyle: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.04),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Category Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'All (${_materials.length})', Icons.dashboard_outlined),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'modules',
                        'Modules (${_materials.where((m) => m.fileType == HubFileType.module).length})',
                        Icons.menu_book_outlined,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'pdfs',
                        'PDFs (${_materials.where((m) => m.fileType == HubFileType.pdf).length})',
                        Icons.picture_as_pdf_outlined,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'quizzes',
                        'Quizzes (${_materials.where((m) => m.fileType == HubFileType.quiz).length})',
                        Icons.assignment_turned_in_outlined,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Storage Info Strip
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Icon(Icons.sd_storage_outlined, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_materials.length} Saved · ${SavedMaterialsService.instance.getFormattedStorageUsed(_materials)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.text),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () {
                    if (widget.showHeader) {
                      Navigator.pop(context);
                    }
                    StudentEsp32SyncModal.show(
                      context,
                      studentName: widget.studentName ?? 'Student',
                      studentSection: widget.studentSection,
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_scanner, size: 14, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Sync More',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Material List
          Expanded(
            child: _filteredMaterials.isEmpty
                ? _buildSearchEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _filteredMaterials.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _filteredMaterials[index];
                      return _buildMaterialCard(item);
                    },
                  ),
          ),
        ],
      ],
    );

    if (!widget.showHeader) {
      return content;
    }

    return Container(
      height: size.height * 0.90,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.border),
      ),
      child: content,
    );
  }

  Widget _buildFilterChip(String filterKey, String label, IconData icon) {
    final isSelected = _selectedFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = filterKey),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppTheme.primary : AppTheme.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialCard(HubMaterialItem item) {
    final typeColor = _getFileTypeColor(item.fileType);
    final typeIcon = _getFileTypeIcon(item.fileType);
    final typeTag = _getFileTypeTag(item.fileType);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openReader(item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type Badge Icon
                    Container(
                      width: 46,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: typeColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(typeIcon, color: typeColor, size: 20),
                          const SizedBox(height: 2),
                          Text(
                            typeTag,
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: typeColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title & Metadata
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.text,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primarySoft,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.subjectName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                              Text(
                                item.formattedSize,
                                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                              if (item.isCompressed)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.success.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppTheme.success.withValues(alpha: 0.25)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.compress, size: 10, color: AppTheme.success),
                                      const SizedBox(width: 3),
                                      Text(
                                        'GZ Compressed',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 12, color: AppTheme.success),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Cached Offline',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.success,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Delete / Options Menu
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 20, color: AppTheme.textMuted),
                      tooltip: 'Remove from device cache',
                      onPressed: () => _confirmDelete(item),
                    ),
                  ],
                ),

                if (item.description != null && item.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.description!,
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 10),

                // Card Bottom Action Row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.savedAt ?? 'Synced via Classroom Station',
                        style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _openReader(item),
                      icon: Icon(
                        item.fileType == HubFileType.quiz ? Icons.play_arrow_rounded : Icons.menu_book_rounded,
                        size: 15,
                      ),
                      label: Text(item.fileType == HubFileType.quiz ? 'Take Quiz Offline' : 'Read Offline'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: typeColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: const Size(0, 32),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Decorative Glowing Backpack Icon
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(Icons.school_outlined, size: 44, color: AppTheme.primary),
            ),
            const SizedBox(height: 18),

            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.offline_pin, size: 14, color: AppTheme.success),
                  const SizedBox(width: 5),
                  Text(
                    'ZERO DATA · 100% OFFLINE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.success,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Text(
              'Your Offline Backpack is Empty',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Take your lessons anywhere. Connect to your teacher\'s ESP32 station to download modules, worksheets, and interactive quizzes for zero-data study.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.45),
            ),
            const SizedBox(height: 22),

            // Big CTA: Scan Classroom Hub QR
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (widget.showHeader) {
                    Navigator.pop(context);
                  }
                  StudentEsp32SyncModal.show(
                    context,
                    studentName: widget.studentName ?? 'Student',
                    studentSection: widget.studentSection,
                  );
                },
                icon: const Icon(Icons.qr_code_scanner, size: 20),
                label: const Text(
                  'Scan Classroom Hub QR',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 3-Step Visual Guide
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  _buildStudentStepRow(
                    Icons.qr_code,
                    '1. Point Camera at Teacher\'s QR',
                    'Scans station credentials and section info instantly',
                  ),
                  const Divider(height: 16),
                  _buildStudentStepRow(
                    Icons.bolt,
                    '2. Ultra-Fast Offline Transfer',
                    'Compressed files download over Wi-Fi in seconds',
                  ),
                  const Divider(height: 16),
                  _buildStudentStepRow(
                    Icons.menu_book,
                    '3. Read & Take Quizzes Anywhere',
                    'Open saved materials without cell signal or data load',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off_rounded, size: 40, color: AppTheme.primary),
            ),
            const SizedBox(height: 14),
            Text(
              'No materials found',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.text),
            ),
            const SizedBox(height: 6),
            Text(
              'No offline files match your search "${_searchController.text}".',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _selectedFilter = 'all';
                });
              },
              icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
              label: const Text('Clear Search & Filters'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentStepRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppTheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.text),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Interactive Reader Dialog for reading modules, reviewing PDFs, or taking diagnostic quizzes offline.
class OfflineMaterialReaderDialog extends StatefulWidget {
  final HubMaterialItem item;

  const OfflineMaterialReaderDialog({super.key, required this.item});

  @override
  State<OfflineMaterialReaderDialog> createState() => _OfflineMaterialReaderDialogState();
}

class _OfflineMaterialReaderDialogState extends State<OfflineMaterialReaderDialog> {
  final Map<int, String> _quizAnswers = {};
  bool _quizSubmitted = false;
  int _score = 0;
  double _fontSize = 14.0;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isQuiz = widget.item.fileType == HubFileType.quiz;

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: size.height * 0.85,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Reader Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isQuiz ? Icons.assignment_turned_in : Icons.menu_book,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${widget.item.subjectName} · 100% Offline Mode',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (!isQuiz) ...[
                    IconButton(
                      icon: const Icon(Icons.text_decrease, size: 18),
                      tooltip: 'Decrease font size',
                      onPressed: () {
                        if (_fontSize > 12) setState(() => _fontSize -= 1.5);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.text_increase, size: 18),
                      tooltip: 'Increase font size',
                      onPressed: () {
                        if (_fontSize < 20) setState(() => _fontSize += 1.5);
                      },
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: isQuiz ? _buildQuizBody() : _buildDocumentBody(),
              ),
            ),

            // Bottom Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.offline_pin, size: 14, color: AppTheme.success),
                      const SizedBox(width: 5),
                      Text(
                        'Stored on device · No internet needed',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentBody() {
    final content = widget.item.content ?? 'No content preview available offline.';
    final sections = content.split('\n\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Topic Overview Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Offline Learning Module Guide',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.item.description ?? 'Curriculum material provided by your teacher.',
                style: TextStyle(fontSize: _fontSize * 0.9, color: AppTheme.textSecondary, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Text Sections
        for (final sec in sections) ...[
          if (sec.startsWith('## ') || sec.startsWith('### '))
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Text(
                sec.replaceAll('### ', '').replaceAll('## ', ''),
                style: TextStyle(
                  fontSize: _fontSize * 1.2,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                sec.replaceAll('**', ''),
                style: TextStyle(
                  fontSize: _fontSize,
                  height: 1.5,
                  color: AppTheme.text,
                ),
              ),
            ),
        ],

        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: AppTheme.success, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'End of offline lesson module. Review concepts at your own pace.',
                  style: TextStyle(fontSize: 12, color: AppTheme.success, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuizBody() {
    // 5 sample diagnostic multiple choice questions
    final questions = [
      {
        'q': '1. In which phase of mitosis do chromosomes align in the center of the cell?',
        'options': ['A) Anaphase', 'B) Metaphase', 'C) Telophase', 'D) Prophase'],
        'correct': 'B',
        'explanation': 'During metaphase, spindle fibers pull chromosomes to the equatorial metaphase plate.',
      },
      {
        'q': '2. What is the powerhouse of the cell responsible for ATP production?',
        'options': ['A) Nucleus', 'B) Ribosome', 'C) Mitochondria', 'D) Endoplasmic Reticulum'],
        'correct': 'C',
        'explanation': 'Mitochondria generate ATP chemical energy needed for metabolic processes.',
      },
      {
        'q': '3. What molecule carries hereditary genetic instructions in living organisms?',
        'options': ['A) RNA', 'B) Hemoglobin', 'C) DNA', 'D) Glucose'],
        'correct': 'C',
        'explanation': 'Deoxyribonucleic acid (DNA) stores hereditary genetic codes.',
      },
      {
        'q': '4. During which stage do sister chromatids separate and move to opposite poles?',
        'options': ['A) Anaphase', 'B) Metaphase', 'C) Prophase', 'D) Interphase'],
        'correct': 'A',
        'explanation': 'Centromeres divide and sister chromatids separate during anaphase.',
      },
      {
        'q': '5. Which cellular division process produces haploid gametes (sex cells)?',
        'options': ['A) Mitosis', 'B) Binary Fission', 'C) Meiosis', 'D) Budding'],
        'correct': 'C',
        'explanation': 'Meiosis reduces chromosome count by half to produce sperm and egg cells.',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_quizSubmitted) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _score >= 3 ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _score >= 3 ? AppTheme.success : AppTheme.warning),
            ),
            child: Row(
              children: [
                Icon(
                  _score >= 3 ? Icons.emoji_events_rounded : Icons.info_outline,
                  color: _score >= 3 ? AppTheme.success : AppTheme.warning,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Offline Score: $_score / ${questions.length} (${((_score / questions.length) * 100).toInt()}%)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _score >= 3 ? 'Great job! Mastery criteria met.' : 'Keep practicing! Review lesson modules offline.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Questions List
        for (int i = 0; i < questions.length; i++) ...[
          _buildQuizQuestionCard(i, questions[i]),
          const SizedBox(height: 16),
        ],

        if (!_quizSubmitted) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () {
                if (_quizAnswers.length < questions.length) {
                  AppToast.showWarning(context, 'Please answer all ${questions.length} questions before submitting.');
                  return;
                }
                int calculated = 0;
                for (int i = 0; i < questions.length; i++) {
                  if (_quizAnswers[i] == questions[i]['correct']) {
                    calculated++;
                  }
                }
                setState(() {
                  _score = calculated;
                  _quizSubmitted = true;
                });
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Submit Quiz & Check Score Offline'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _quizAnswers.clear();
                  _quizSubmitted = false;
                  _score = 0;
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retake Quiz Offline'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: BorderSide(color: AppTheme.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuizQuestionCard(int index, Map<String, dynamic> qData) {
    final selectedOption = _quizAnswers[index];
    final isCorrectAnswer = qData['correct'] as String;
    final options = qData['options'] as List<String>;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _quizSubmitted
              ? (selectedOption == isCorrectAnswer ? AppTheme.success : AppTheme.error.withValues(alpha: 0.6))
              : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            qData['q'] as String,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.text),
          ),
          const SizedBox(height: 10),
          for (final opt in options) ...[
            InkWell(
              onTap: _quizSubmitted
                  ? null
                  : () {
                      setState(() {
                        _quizAnswers[index] = opt.substring(0, 1);
                      });
                    },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: selectedOption == opt.substring(0, 1)
                      ? AppTheme.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selectedOption == opt.substring(0, 1)
                        ? AppTheme.primary
                        : AppTheme.border.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selectedOption == opt.substring(0, 1)
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: selectedOption == opt.substring(0, 1) ? AppTheme.primary : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        opt,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selectedOption == opt.substring(0, 1) ? FontWeight.bold : FontWeight.normal,
                          color: AppTheme.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_quizSubmitted) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, size: 14, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Explanation: ${qData['explanation']}',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
