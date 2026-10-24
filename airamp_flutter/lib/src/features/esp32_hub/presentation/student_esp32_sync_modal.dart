import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/components/app_toast.dart';
import '../../../core/components/aira/aira_overlay_controller.dart';
import '../../../core/database/database_helper.dart';
import '../domain/esp32_hub_models.dart';
import '../data/saved_materials_service.dart';
import '../data/esp32_client_service.dart';
import 'saved_offline_materials_modal.dart';

/// Modal bottom sheet for students to discover learning materials from the offline
/// Classroom Hub and save them offline for zero-data studying.
class StudentEsp32SyncModal extends StatefulWidget {
  final String studentName;
  final String? studentSection;
  final VoidCallback? onSyncCompleted;

  const StudentEsp32SyncModal({
    super.key,
    required this.studentName,
    this.studentSection,
    this.onSyncCompleted,
  });

  static Future<void> show(
    BuildContext context, {
    required String studentName,
    String? studentSection,
    VoidCallback? onSyncCompleted,
  }) async {
    AiraOverlayController.hide();
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StudentEsp32SyncModal(
          studentName: studentName,
          studentSection: studentSection,
          onSyncCompleted: onSyncCompleted,
        ),
      );
    } finally {
      AiraOverlayController.show();
    }
  }

  @override
  State<StudentEsp32SyncModal> createState() => _StudentEsp32SyncModalState();
}

enum _SyncStep { manifest, downloading, done }

class _StudentEsp32SyncModalState extends State<StudentEsp32SyncModal> {
  _SyncStep _currentStep = _SyncStep.manifest;

  Esp32HubStatus _hubStatus = const Esp32HubStatus(
    isDevKitConnected: false,
    isSdCardDetected: false,
    ssid: 'AIRAMP-HUB-01',
    ipAddress: '192.168.4.1',
    password: 'aira1234',
  );

  Timer? _hubPollTimer;
  bool _isCheckingHub = false;
  bool _isDownloading = false;

  HubSyncManifest? _manifest;
  List<HubMaterialItem> _itemsToDownload = [];
  Set<String> _selectedItemIds = {};
  String _selectedTypeFilter = 'all';
  int _completedDownloads = 0;
  String _activeDownloadTitle = '';
  double _overallProgress = 0.0;

  int get _selectedTotalBytes {
    if (_manifest == null) return 0;
    return _manifest!.items
        .where((item) => _selectedItemIds.contains(item.id))
        .fold(0, (sum, item) => sum + item.sizeBytes);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _getItemCategory(HubMaterialItem item) {
    final name = (item.fileName ?? item.title).toLowerCase();
    if (name.endsWith('.pdf') || item.fileType == HubFileType.pdf) {
      return 'pdf';
    }
    if (name.endsWith('.html') || name.endsWith('.htm')) {
      return 'html';
    }
    if (name.endsWith('.json') || item.fileType == HubFileType.quiz) {
      return 'quiz';
    }
    if (name.endsWith('.doc') || name.endsWith('.docx') || item.fileType == HubFileType.doc) {
      return 'doc';
    }
    return 'module';
  }

  String _getCategoryTitle(String category) {
    switch (category) {
      case 'pdf':
        return 'PDF Documents';
      case 'html':
        return 'HTML & Web Pages';
      case 'quiz':
        return 'Interactive Quizzes';
      case 'doc':
        return 'Word & Text Docs';
      case 'module':
      default:
        return 'Curriculum Modules';
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'html':
        return Icons.language_outlined;
      case 'quiz':
        return Icons.assignment_outlined;
      case 'doc':
        return Icons.description_outlined;
      case 'module':
      default:
        return Icons.menu_book_outlined;
    }
  }

  @override
  void initState() {
    super.initState();
    _refreshHubStatus();

    // Auto-detect connection to ESP32 Wi-Fi every 3 seconds so the student
    // automatically syncs with the hub as soon as their phone joins the hub Wi-Fi
    _hubPollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && !_isCheckingHub && !_isDownloading) {
        _refreshHubStatus(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _hubPollTimer?.cancel();
    super.dispose();
  }

  /// Pings the ESP32 to check connection and load available classroom materials from MicroSD
  Future<void> _refreshHubStatus({bool silent = false}) async {
    if (!silent) {
      setState(() => _isCheckingHub = true);
    }

    try {
      final wasConnected = _hubStatus.isDevKitConnected;
      final status = await Esp32ClientService.instance.checkHubStatus('192.168.4.1');

      if (!mounted) return;

      setState(() {
        _hubStatus = status;
        if (!silent) _isCheckingHub = false;
      });

      if (status.isDevKitConnected) {
        final manifest = await Esp32ClientService.instance.fetchManifest(status.ipAddress);
        if (!mounted) return;
        if (manifest != null) {
          setState(() {
            _manifest = manifest;
            if (_selectedItemIds.isEmpty && manifest.items.isNotEmpty) {
              _selectedItemIds = manifest.items.map((e) => e.id).toSet();
            }
          });
        }

        if (!wasConnected && mounted) {
          AppToast.showSuccess(
            context,
            'Connected to Classroom Hub! ${manifest?.items.length ?? 0} materials ready.',
          );
        }
      }
    } catch (e) {
      debugPrint('[StudentEsp32SyncModal] _refreshHubStatus error: $e');
    } finally {
      if (mounted && !silent && _isCheckingHub) {
        setState(() => _isCheckingHub = false);
      }
    }
  }

  /// Downloads selected curriculum files from the ESP32 SD card into local phone storage
  Future<void> _startOfflineDownload({List<HubMaterialItem>? targetItems}) async {
    final targets = targetItems ??
        (_manifest?.items
            .where((item) => _selectedItemIds.contains(item.id))
            .toList() ??
            []);

    if (targets.isEmpty) {
      AppToast.showInfo(context, 'Please select at least one material to download.');
      return;
    }

    final ip = _hubStatus.ipAddress;

    setState(() {
      _itemsToDownload = List.from(targets);
      _currentStep = _SyncStep.downloading;
      _isDownloading = true;
      _completedDownloads = 0;
      _overallProgress = 0.0;
    });

    final List<HubMaterialItem> savedResults = [];

    for (int i = 0; i < _itemsToDownload.length; i++) {
      final item = _itemsToDownload[i];
      if (!mounted) return;

      setState(() {
        _activeDownloadTitle = item.title;
        _itemsToDownload[i] = item.copyWith(downloadStatus: HubDownloadStatus.downloading);
      });

      // Real HTTP download from ESP32 /download?file=...
      final downloadedItem = await Esp32ClientService.instance.downloadFile(
        ipAddress: ip,
        item: item,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _itemsToDownload[i] = item.copyWith(
              downloadStatus: HubDownloadStatus.downloading,
              downloadProgress: p,
            );
            _overallProgress = ((i + p) / _itemsToDownload.length).clamp(0.0, 1.0);
          });
        },
      );

      savedResults.add(downloadedItem);

      if (!mounted) return;
      setState(() {
        _itemsToDownload[i] = downloadedItem;
        _completedDownloads++;
        _overallProgress = (_completedDownloads / _itemsToDownload.length).clamp(0.0, 1.0);
      });
    }

    // Persist real downloaded materials to local phone storage
    await SavedMaterialsService.instance.saveMaterials(savedResults);

    try {
      await DatabaseHelper().createNotification(
        userId: widget.studentName,
        type: 'offline_sync',
        title: 'Offline Sync Complete',
        message: '${savedResults.length} learning materials saved offline. Ready to study without internet.',
        targetRoute: '/student/home',
      );
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _currentStep = _SyncStep.done;
      _isDownloading = false;
      _overallProgress = 1.0;
    });

    AppToast.showSuccess(
      context,
      '${savedResults.length} ${savedResults.length == 1 ? 'material' : 'materials'} saved offline! Ready to study without internet.',
    );
    widget.onSyncCompleted?.call();
  }

  /// Opens the offline material reader dialog for quick viewing
  void _openReader(HubMaterialItem item) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => OfflineMaterialReaderDialog(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.90,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.dns_outlined, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Classroom Hub Sync',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Download class lessons & quizzes offline',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Saved Files Shortcut Pill
                ValueListenableBuilder<List<HubMaterialItem>>(
                  valueListenable: SavedMaterialsService.instance.savedMaterialsNotifier,
                  builder: (context, savedList, _) {
                    return InkWell(
                      onTap: () {
                        SavedOfflineMaterialsModal.show(
                          context,
                          studentName: widget.studentName,
                          studentSection: widget.studentSection,
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_outlined, size: 14, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              'Saved (${savedList.length})',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Refresh',
                  icon: _isCheckingHub
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.refresh, color: AppTheme.textMuted, size: 20),
                  onPressed: _isCheckingHub ? null : () => _refreshHubStatus(silent: false),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: Icon(Icons.close, color: AppTheme.textMuted, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Live Hardware Ledger Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                // Station Node
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _hubStatus.isDevKitConnected ? AppTheme.success : AppTheme.textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STATION NODE',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _hubStatus.isDevKitConnected
                            ? 'Online'
                            : 'Standby',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _hubStatus.isDevKitConnected ? AppTheme.success : AppTheme.text,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(height: 22, width: 1, color: AppTheme.border),
                const SizedBox(width: 12),
                // Storage Media
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _hubStatus.isSdCardDetected
                        ? AppTheme.success
                        : (_hubStatus.isDevKitConnected ? AppTheme.warning : AppTheme.textMuted),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STORAGE MEDIA',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _hubStatus.isSdCardDetected
                            ? (_hubStatus.totalStorageBytes > 0 ? _hubStatus.formattedTotalStorage : 'Mounted & Ready')
                            : (_hubStatus.isDevKitConnected ? 'Card Standby' : 'Standby'),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _hubStatus.isSdCardDetected ? AppTheme.text : AppTheme.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (_hubStatus.isDevKitConnected) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () async {
                      AppToast.showInfo(context, 'Pinging hub...');
                      final ping = await Esp32ClientService.instance.ping(_hubStatus.ipAddress);
                      if (!context.mounted) return;
                      if (ping != null) {
                        AppToast.showSuccess(context, '192.168.4.1 online');
                      } else {
                        AppToast.showError(context, 'No response from ${_hubStatus.ipAddress}');
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flash_on, size: 12, color: AppTheme.primary),
                          const SizedBox(width: 2),
                          Text(
                            'Ping',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Content body based on current step
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentStep) {
      case _SyncStep.manifest:
        return _buildManifestView();
      case _SyncStep.downloading:
        return _buildDownloadingView();
      case _SyncStep.done:
        return _buildDoneView();
    }
  }

  /// Live connection reminder card shown at the top of the material view
  Widget _buildLiveConnectionReminder() {
    if (_hubStatus.isDevKitConnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_outline, size: 16, color: AppTheme.success),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Hub Connected',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${_hubStatus.ipAddress})',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Station reachable. Select materials below to download directly to your device.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: AppTheme.warning,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Classroom Hub Not Connected',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Scan the QR code displayed on the physical ESP32 Hub screen with your phone\'s camera to connect, then tap Verify Connection Link below.',
            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: OutlinedButton.icon(
              onPressed: _isCheckingHub ? null : () => _refreshHubStatus(silent: false),
              icon: _isCheckingHub
                  ? const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 15),
              label: Text(
                _isCheckingHub ? 'Verifying Link...' : 'Verify Connection Link',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.text,
                side: BorderSide(color: AppTheme.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilterChip(String key, String label, IconData icon) {
    final isSelected = _selectedTypeFilter == key;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTypeFilter = key;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.12) : AppTheme.surfaceLight,
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
              size: 13,
              color: isSelected ? AppTheme.primary : AppTheme.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySectionHeader(String category, List<HubMaterialItem> items) {
    final icon = _getCategoryIcon(category);
    final title = _getCategoryTitle(category);
    final allCategorySelected = items.isNotEmpty && items.every((i) => _selectedItemIds.contains(i.id));

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              '${items.length}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                if (allCategorySelected) {
                  for (final item in items) {
                    _selectedItemIds.remove(item.id);
                  }
                } else {
                  for (final item in items) {
                    _selectedItemIds.add(item.id);
                  }
                }
              });
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              allCategorySelected ? 'Deselect Category' : 'Select Category',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialItemCard(HubMaterialItem item, Set<String> savedItemIds) {
    final isSelected = _selectedItemIds.contains(item.id);
    final isSaved = savedItemIds.contains(item.id);
    final fileCategory = _getItemCategory(item);
    final fileIcon = _getCategoryIcon(fileCategory);

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedItemIds.remove(item.id);
          } else {
            _selectedItemIds.add(item.id);
          }
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: isSelected,
                activeColor: AppTheme.primary,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedItemIds.add(item.id);
                    } else {
                      _selectedItemIds.remove(item.id);
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 8),

            // File Icon
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.border),
              ),
              child: Icon(fileIcon, size: 16, color: AppTheme.textSecondary),
            ),
            const SizedBox(width: 10),

            // Title & Meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: AppTheme.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${item.subjectName} • ${item.formattedSize}',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      if (isSaved) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline, size: 10, color: AppTheme.success),
                              const SizedBox(width: 2),
                              Text(
                                'Saved',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Quick actions
            if (isSaved) ...[
              IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 16),
                tooltip: 'Read Offline',
                visualDensity: VisualDensity.compact,
                color: AppTheme.textMuted,
                onPressed: () => _openReader(item),
              ),
            ],
            // Quick Download button
            InkWell(
              onTap: () => _startOfflineDownload(targetItems: [item]),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSaved ? Icons.sync : Icons.download_outlined,
                      size: 13,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isSaved ? 'Sync' : 'Get',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManifestView() {
    final manifest = _manifest;
    final savedItemIds = SavedMaterialsService.instance.savedMaterialsNotifier.value
        .map((e) => e.id)
        .toSet();

    // Group items by category
    final grouped = <String, List<HubMaterialItem>>{};
    if (manifest != null) {
      for (final item in manifest.items) {
        final cat = _getItemCategory(item);
        grouped.putIfAbsent(cat, () => []).add(item);
      }
    }

    final filteredGroups = _selectedTypeFilter == 'all'
        ? grouped
        : {
            if (grouped.containsKey(_selectedTypeFilter))
              _selectedTypeFilter: grouped[_selectedTypeFilter]!,
          };

    final visibleItems = filteredGroups.values.expand((list) => list).toList();
    final allVisibleSelected = visibleItems.isNotEmpty &&
        visibleItems.every((item) => _selectedItemIds.contains(item.id));

    final totalItemsCount = manifest?.items.length ?? 0;
    final pdfCount = grouped['pdf']?.length ?? 0;
    final htmlCount = grouped['html']?.length ?? 0;
    final quizCount = grouped['quiz']?.length ?? 0;
    final moduleCount = grouped['module']?.length ?? 0;
    final docCount = grouped['doc']?.length ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live Connection Reminder
          _buildLiveConnectionReminder(),
          const SizedBox(height: 14),

          // If disconnected and no manifest, show calm instructions
          if (manifest == null && !_hubStatus.isDevKitConnected) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  Icon(Icons.wifi_tethering_outlined, size: 36, color: AppTheme.textMuted),
                  const SizedBox(height: 12),
                  Text(
                    'Offline Classroom Hub Distribution',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Scan the QR code on the physical ESP32 screen to connect this device and download learning modules, quizzes, and lesson PDFs without internet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isCheckingHub ? null : () => _refreshHubStatus(silent: false),
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('Check Connection Link', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Header with Selection summary & Select All
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Classroom Materials ($totalItemsCount)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _selectedItemIds.isEmpty
                            ? 'Tap materials to select for offline download'
                            : '${_selectedItemIds.length} of $totalItemsCount selected (${_formatSize(_selectedTotalBytes)})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _selectedItemIds.isEmpty ? AppTheme.textMuted : AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (visibleItems.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        if (allVisibleSelected) {
                          for (final item in visibleItems) {
                            _selectedItemIds.remove(item.id);
                          }
                        } else {
                          for (final item in visibleItems) {
                            _selectedItemIds.add(item.id);
                          }
                        }
                      });
                    },
                    icon: Icon(
                      allVisibleSelected ? Icons.remove_done : Icons.done_all,
                      size: 15,
                      color: AppTheme.primary,
                    ),
                    label: Text(
                      allVisibleSelected ? 'Deselect All' : 'Select All',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Category filter chips
            if (totalItemsCount > 0) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTypeFilterChip('all', 'All ($totalItemsCount)', Icons.grid_view_outlined),
                    if (pdfCount > 0) ...[
                      const SizedBox(width: 6),
                      _buildTypeFilterChip('pdf', 'PDFs ($pdfCount)', Icons.picture_as_pdf_outlined),
                    ],
                    if (quizCount > 0) ...[
                      const SizedBox(width: 6),
                      _buildTypeFilterChip('quiz', 'Quizzes ($quizCount)', Icons.assignment_outlined),
                    ],
                    if (moduleCount > 0) ...[
                      const SizedBox(width: 6),
                      _buildTypeFilterChip('module', 'Modules ($moduleCount)', Icons.menu_book_outlined),
                    ],
                    if (htmlCount > 0) ...[
                      const SizedBox(width: 6),
                      _buildTypeFilterChip('html', 'HTML / Web ($htmlCount)', Icons.language_outlined),
                    ],
                    if (docCount > 0) ...[
                      const SizedBox(width: 6),
                      _buildTypeFilterChip('doc', 'Docs ($docCount)', Icons.description_outlined),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (manifest != null && manifest.items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                alignment: Alignment.center,
                child: Text(
                  'No materials currently published to this hub.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              )
            else if (filteredGroups.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    Icon(Icons.filter_list_off, size: 28, color: AppTheme.textMuted),
                    const SizedBox(height: 6),
                    Text(
                      'No files found for this category filter.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              ...filteredGroups.entries.expand((entry) {
                final cat = entry.key;
                final catItems = entry.value;

                return [
                  _buildCategorySectionHeader(cat, catItems),
                  ...catItems.map((item) => _buildMaterialItemCard(item, savedItemIds)),
                  const SizedBox(height: 4),
                ];
              }),

            const SizedBox(height: 12),

            // Download Action CTA
            if (totalItemsCount > 0) ...[
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _selectedItemIds.isEmpty ? null : () => _startOfflineDownload(),
                  icon: Icon(
                    _selectedItemIds.isEmpty
                        ? Icons.file_download_off_outlined
                        : Icons.download_outlined,
                    size: 18,
                  ),
                  label: Text(
                    _selectedItemIds.isEmpty
                        ? 'Select Files to Download'
                        : _selectedItemIds.length == totalItemsCount
                            ? 'Download All Offline ($totalItemsCount)'
                            : 'Download Selected (${_selectedItemIds.length})',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.surfaceLight,
                    disabledForegroundColor: AppTheme.textMuted,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              if (_selectedItemIds.isNotEmpty) ...[
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    '${_selectedItemIds.length} files (${_formatSize(_selectedTotalBytes)}) · Zero mobile data needed',
                    style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                  ),
                ),
              ],
            ],
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDownloadingView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.downloading, size: 36, color: AppTheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Downloading Classroom Materials...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Transferring: $_activeDownloadTitle',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _overallProgress,
              minHeight: 6,
              backgroundColor: AppTheme.border,
              valueColor: AlwaysStoppedAnimation(AppTheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_completedDownloads of ${_itemsToDownload.length} files saved',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              Text(
                '${(_overallProgress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoneView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_outline, size: 40, color: AppTheme.success),
          ),
          const SizedBox(height: 16),
          Text(
            'Offline Sync Complete',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_itemsToDownload.length} ${_itemsToDownload.length == 1 ? 'material' : 'materials'} successfully saved to your device. Ready to read and take quizzes offline anytime.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),

          // Summary Ledger Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                _buildDoneSummaryRow(Icons.offline_pin_outlined, 'Storage Status', 'Cached on Device'),
                const Divider(height: 14),
                _buildDoneSummaryRow(Icons.data_usage_outlined, 'Mobile Data Used', '0 MB (Direct Wi-Fi Hub)'),
                const Divider(height: 14),
                _buildDoneSummaryRow(Icons.assignment_outlined, 'Offline Access', 'Ready to study'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (_manifest != null && _manifest!.items.isNotEmpty) {
                      setState(() {
                        _currentStep = _SyncStep.manifest;
                      });
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.arrow_back, size: 15),
                  label: const Text('Download More', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.text,
                    side: BorderSide(color: AppTheme.border),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    SavedOfflineMaterialsModal.show(
                      context,
                      studentName: widget.studentName,
                      studentSection: widget.studentSection,
                    );
                  },
                  icon: const Icon(Icons.folder_outlined, size: 16),
                  label: const Text('View Saved Materials', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoneSummaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.text,
          ),
        ),
      ],
    );
  }
}
