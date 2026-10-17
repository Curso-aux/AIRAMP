import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/components/app_toast.dart';
import '../domain/esp32_hub_models.dart';
import '../data/esp32_client_service.dart';
import '../data/saved_materials_service.dart';
import 'components/hub_qr_code_widget.dart';
import 'saved_offline_materials_modal.dart';

/// Modal dialog for teachers to manage the ESP32 Offline Learning Hub,
/// pick and upload real curriculum files to the ESP32 MicroSD card, and display the classroom QR code.
class TeacherEsp32HubModal extends StatefulWidget {
  final String teacherName;
  final String? initialSection;

  const TeacherEsp32HubModal({
    super.key,
    required this.teacherName,
    this.initialSection,
  });

  static Future<void> show(
    BuildContext context, {
    required String teacherName,
    String? initialSection,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TeacherEsp32HubModal(
        teacherName: teacherName,
        initialSection: initialSection,
      ),
    );
  }

  @override
  State<TeacherEsp32HubModal> createState() => _TeacherEsp32HubModalState();
}

class _TeacherEsp32HubModalState extends State<TeacherEsp32HubModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Esp32HubStatus _hubStatus = const Esp32HubStatus();
  HubSyncManifest? _hubManifest;
  final List<HubMaterialItem> _availableMaterials = [];
  final Set<String> _selectedMaterialIds = {};

  Timer? _hubPollTimer;
  bool _isCheckingHub = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStepText = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshHubStatus();

    // Auto-detect connection to ESP32 Wi-Fi every 3 seconds so the user
    // immediately sees live hardware details, MicroSD files, and the matching QR code
    _hubPollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && !_isCheckingHub && !_isUploading) {
        _refreshHubStatus(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _hubPollTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  /// Pings the ESP32 to get real hardware state (DevKit and MicroSD card) and loads existing manifest
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
            _hubManifest = manifest;
            if (manifest.items.isNotEmpty) {
              final existingIds = _availableMaterials.map((m) => m.id).toSet();
              for (final item in manifest.items) {
                if (!existingIds.contains(item.id)) {
                  _availableMaterials.add(item);
                  _selectedMaterialIds.add(item.id);
                }
              }
            }
          });
        }

        if (!wasConnected && mounted) {
          AppToast.showSuccess(
            context,
            'Connected to ${_hubStatus.ssid}! Hardware information & QR code loaded.',
          );
        }
      }
    } catch (e) {
      debugPrint('[TeacherEsp32HubModal] _refreshHubStatus error: $e');
    } finally {
      if (mounted && !silent && _isCheckingHub) {
        setState(() => _isCheckingHub = false);
      }
    }
  }

  /// Opens the material viewer for the teacher to view the material's offline contents, questions, or PDF
  Future<void> _openMaterialViewer(HubMaterialItem item) async {
    HubMaterialItem itemToView = item;

    // If content is empty and connected to hub, attempt quick fetch
    if ((itemToView.content == null || itemToView.content!.isEmpty) &&
        itemToView.localPath == null &&
        _hubStatus.isDevKitConnected) {
      AppToast.showInfo(context, 'Loading "${item.title}" from ESP32...');
      try {
        itemToView = await Esp32ClientService.instance.downloadFile(
          ipAddress: _hubStatus.ipAddress,
          item: item,
        );
      } catch (_) {}
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => OfflineMaterialReaderDialog(item: itemToView),
    );
  }

  /// Downloads the material from the ESP32 Hub and saves it to the teacher's phone offline library
  Future<void> _retrieveMaterialToPhone(HubMaterialItem item) async {
    try {
      AppToast.showInfo(context, 'Retrieving "${item.title}" to device...');
      HubMaterialItem itemToSave = item;

      // If content isn't downloaded yet and we are connected to the ESP32 hub
      if ((itemToSave.content == null || itemToSave.content!.isEmpty) &&
          itemToSave.localPath == null &&
          _hubStatus.isDevKitConnected) {
        itemToSave = await Esp32ClientService.instance.downloadFile(
          ipAddress: _hubStatus.ipAddress,
          item: item,
        );
      }

      await SavedMaterialsService.instance.saveMaterials([itemToSave]);

      if (!mounted) return;
      AppToast.showSuccess(
        context,
        'Retrieved "${item.title}"! Saved to your offline materials library.',
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, 'Failed to retrieve "${item.title}": $e');
    }
  }

  /// Prompts for confirmation and deletes the material from the ESP32 MicroSD card and manifest
  Future<void> _confirmAndDeleteMaterial(HubMaterialItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_forever, color: AppTheme.error, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Delete Material?',
                style: TextStyle(
                  color: AppTheme.text,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${item.title}" (${item.fileName ?? 'file'})?',
              style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _hubStatus.isDevKitConnected
                  ? 'This will remove the file from the ESP32 MicroSD card and update the manifest. Students will no longer be able to download this material.'
                  : 'This will remove the item from your upload staging list.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      AppToast.showInfo(context, 'Deleting "${item.title}"...');

      // If connected to ESP32 and fileName is set, call DELETE API on the ESP32
      if (_hubStatus.isDevKitConnected && item.fileName != null) {
        final success = await Esp32ClientService.instance.deleteFileFromHub(
          ipAddress: _hubStatus.ipAddress,
          fileName: item.fileName!,
        );
        debugPrint('[TeacherHub] File delete on ESP32 returned: $success');
      }

      if (!mounted) return;

      setState(() {
        _availableMaterials.removeWhere((m) => m.id == item.id);
        _selectedMaterialIds.remove(item.id);
      });

      // Update the manifest on the ESP32 MicroSD so students won't see it anymore
      if (_hubStatus.isDevKitConnected) {
        final remainingItems = List<HubMaterialItem>.from(_availableMaterials);
        final updatedManifest = HubSyncManifest(
          hubId: _hubManifest?.hubId ?? 'AIRAMP-HUB-01',
          hubName: _hubManifest?.hubName ?? 'AIRA Classroom Station',
          teacherName: widget.teacherName,
          sectionName: _hubManifest?.sectionName ?? widget.initialSection ?? 'Grade 10',
          generatedAt: DateTime.now().toIso8601String(),
          items: remainingItems,
          qrPayload: _hubManifest?.qrPayload ?? '',
        );

        await Esp32ClientService.instance.uploadManifest(
          ipAddress: _hubStatus.ipAddress,
          manifest: updatedManifest,
        );
        _hubManifest = updatedManifest;
      }

      if (mounted) {
        AppToast.showSuccess(context, 'Deleted "${item.title}" successfully.');
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to delete: $e');
      }
    }
  }

  /// Allows the teacher to pick real PDF files or quizzes from phone storage
  Future<void> _pickRealFiles() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'json', 'txt', 'doc', 'docx'],
      );

      if (files.isEmpty) return;

      int addedCount = 0;
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        final fileName = file.name;
        final size = await file.length();
        final isPdf = fileName.toLowerCase().endsWith('.pdf');
        final isQuiz = fileName.toLowerCase().endsWith('.json');
        final fileType = isPdf
            ? HubFileType.pdf
            : (isQuiz ? HubFileType.quiz : HubFileType.module);

        final uniqueId = 'mat_teacher_${DateTime.now().millisecondsSinceEpoch}_$i';

        final newItem = HubMaterialItem(
          id: uniqueId,
          title: fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
          subjectName: 'Classroom Material',
          fileType: fileType,
          sizeBytes: size,
          fileName: fileName,
          localPath: file.path,
          downloadStatus: HubDownloadStatus.downloaded,
          downloadProgress: 1.0,
          savedAt: 'Ready to Upload',
        );

        if (mounted) {
          setState(() {
            _availableMaterials.insert(0, newItem);
            _selectedMaterialIds.add(newItem.id);
          });
        }
        addedCount++;
      }

      if (mounted && addedCount > 0) {
        AppToast.showSuccess(
          context,
          'Added $addedCount real file(s)! Tap "Upload to ESP32" to transfer them over Wi-Fi.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to pick files: $e');
      }
    }
  }

  int get _selectedBytes => _availableMaterials
      .where((m) => _selectedMaterialIds.contains(m.id))
      .fold<int>(0, (sum, m) => sum + m.sizeBytes);

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  /// Real upload process: transfers selected files directly to the ESP32 MicroSD card via HTTP
  Future<void> _handleUploadToEsp32() async {
    if (_selectedMaterialIds.isEmpty) {
      AppToast.showWarning(context, 'Please select at least one material to upload.');
      return;
    }

    final selectedItems = _availableMaterials
        .where((m) => _selectedMaterialIds.contains(m.id))
        .toList();

    // Verify phone is connected to ESP32 Wi-Fi
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.05;
      _uploadStepText = 'Verifying connection to ESP32 at ${_hubStatus.ipAddress}...';
    });

    final isAlive = await Esp32ClientService.instance.ping(_hubStatus.ipAddress);
    if (!mounted) return;

    if (isAlive == null) {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
      AppToast.showError(
        context,
        'Cannot reach ESP32 at 192.168.4.1. Please connect your phone Wi-Fi to "${_hubStatus.ssid}" (Password: "${_hubStatus.password}").',
      );
      return;
    }

    // Step 1: Upload each local file to ESP32 MicroSD (/upload)
    for (int i = 0; i < selectedItems.length; i++) {
      final item = selectedItems[i];
      if (item.localPath != null) {
        setState(() {
          _uploadStepText = 'Uploading ${item.title} to MicroSD...';
        });

        final success = await Esp32ClientService.instance.uploadFileToHub(
          ipAddress: _hubStatus.ipAddress,
          filePath: item.localPath!,
          fileName: item.fileName ?? '${item.id}.pdf',
          onProgress: (p) {
            if (!mounted) return;
            setState(() {
              _uploadProgress = ((i + p) / (selectedItems.length + 1)).clamp(0.05, 0.95);
            });
          },
        );

        if (!success) {
          debugPrint('[TeacherUpload] Warning: file transfer returned non-200 for ${item.title}');
        }
      }
    }

    // Step 2: Upload updated manifest to ESP32 MicroSD (/api/manifest)
    setState(() {
      _uploadStepText = 'Saving curriculum manifest to MicroSD...';
      _uploadProgress = 0.95;
    });

    final qrPayload = (_hubManifest != null && _hubManifest!.qrPayload.isNotEmpty)
        ? _hubManifest!.qrPayload
        : 'WIFI:S:${_hubStatus.ssid};T:WPA;P:${_hubStatus.password};;AIRAMP:SEC=${_hubManifest?.sectionName ?? widget.initialSection ?? 'Grade 10'};IP=${_hubStatus.ipAddress}';

    final updatedManifest = HubSyncManifest(
      hubId: _hubManifest?.hubId ?? 'AIRAMP-HUB-01',
      hubName: _hubManifest?.hubName ?? 'AIRA Classroom Station',
      teacherName: widget.teacherName,
      sectionName: _hubManifest?.sectionName ?? widget.initialSection ?? 'Grade 10',
      generatedAt: DateTime.now().toIso8601String(),
      items: selectedItems,
      qrPayload: qrPayload,
    );

    await Esp32ClientService.instance.uploadManifest(
      ipAddress: _hubStatus.ipAddress,
      manifest: updatedManifest,
    );

    if (!mounted) return;

    setState(() {
      _hubManifest = updatedManifest;
      _uploadProgress = 1.0;
      _uploadStepText = 'Success! Materials are now stored in ESP32 MicroSD.';
      _isUploading = false;
    });

    AppToast.showSuccess(
      context,
      'Materials uploaded to ESP32 MicroSD! Students can now scan the QR code to download.',
    );

    // Switch to Classroom QR tab so students can scan
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      _tabController.animateTo(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.90,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
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

          // Header
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
                  child: Icon(Icons.hub_outlined, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ESP32 Offline Learning Hub',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Deliver classroom modules without internet or data',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh Hardware Status',
                  icon: _isCheckingHub
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 22),
                  onPressed: _isCheckingHub ? null : _refreshHubStatus,
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppTheme.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Live Hardware Status Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                // DevKit Badge
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _hubStatus.isDevKitConnected ? AppTheme.success : AppTheme.error,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_hubStatus.isDevKitConnected ? AppTheme.success : AppTheme.error).withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ESP32 DevKit',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.text,
                              ),
                            ),
                            Text(
                              _hubStatus.isDevKitConnected ? 'Ready (${_hubStatus.ssid})' : 'Offline (Check Wi-Fi)',
                              style: TextStyle(
                                fontSize: 10,
                                color: _hubStatus.isDevKitConnected ? AppTheme.success : AppTheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 24, width: 1, color: AppTheme.border),
                const SizedBox(width: 12),
                // MicroSD Status Badge
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
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
                              'MicroSD Module',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.text,
                              ),
                            ),
                            Text(
                              _hubStatus.isSdCardDetected
                                  ? (_hubStatus.totalStorageBytes > 0 ? _hubStatus.formattedTotalStorage : 'Mounted & Ready')
                                  : (_hubStatus.isDevKitConnected ? 'No Card Detected' : 'Connect Wi-Fi to check'),
                              style: TextStyle(
                                fontSize: 10,
                                color: _hubStatus.isSdCardDetected ? AppTheme.success : AppTheme.warning,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: AppTheme.primary,
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.folder_shared_outlined, size: 20), text: 'Materials'),
              Tab(icon: Icon(Icons.qr_code, size: 20), text: 'Classroom QR'),
            ],
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMaterialsTab(),
                _buildQrTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connection & Wi-Fi Helper Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _hubStatus.isDevKitConnected ? AppTheme.primarySoft : AppTheme.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hubStatus.isDevKitConnected ? AppTheme.primary.withValues(alpha: 0.3) : AppTheme.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _hubStatus.isDevKitConnected ? Icons.check_circle_outline : Icons.wifi_find,
                  color: _hubStatus.isDevKitConnected ? AppTheme.primary : AppTheme.warning,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _hubStatus.isDevKitConnected
                        ? 'Connected to ESP32 Hub! You can view materials stored on the MicroSD, retrieve them to phone storage, delete items, or upload new files.'
                        : 'Connect your phone to Wi-Fi "${_hubStatus.ssid}" (Password: "${_hubStatus.password}") to manage materials on the ESP32 Hub.',
                    style: TextStyle(fontSize: 12, color: AppTheme.text, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons: Pick Files & View Saved Offline Materials
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _pickRealFiles,
                    icon: const Icon(Icons.note_add_outlined, size: 18),
                    label: const Text(
                      'Upload Materials',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      SavedOfflineMaterialsModal.show(context);
                    },
                    icon: const Icon(Icons.folder_special_outlined, size: 18),
                    label: const Text(
                      'Saved',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.text,
                      side: BorderSide(color: AppTheme.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Section Title & Select/Deselect
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Classroom Materials (${_availableMaterials.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.text,
                ),
              ),
              if (_availableMaterials.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedMaterialIds.length == _availableMaterials.length) {
                        _selectedMaterialIds.clear();
                      } else {
                        _selectedMaterialIds.addAll(_availableMaterials.map((m) => m.id));
                      }
                    });
                  },
                  child: Text(
                    _selectedMaterialIds.length == _availableMaterials.length ? 'Deselect All' : 'Select All',
                    style: TextStyle(color: AppTheme.primary, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (_availableMaterials.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  Icon(Icons.folder_open_outlined, size: 40, color: AppTheme.textMuted),
                  const SizedBox(height: 10),
                  Text(
                    'No materials on ESP32 MicroSD yet',
                    style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap "+ Upload Materials" above to pick PDFs or files from your phone to transfer to the classroom hub.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            )
          else
            ..._availableMaterials.map((item) {
              final isChecked = _selectedMaterialIds.contains(item.id);
              final isLocal = item.localPath != null;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isChecked ? AppTheme.primary.withValues(alpha: 0.5) : AppTheme.border,
                    width: isChecked ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: isChecked,
                            activeColor: AppTheme.primary,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedMaterialIds.add(item.id);
                                } else {
                                  _selectedMaterialIds.remove(item.id);
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (item.fileType == HubFileType.pdf
                                      ? AppTheme.error
                                      : item.fileType == HubFileType.quiz
                                          ? AppTheme.warning
                                          : AppTheme.primary)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              item.fileType == HubFileType.pdf
                                  ? Icons.picture_as_pdf
                                  : item.fileType == HubFileType.quiz
                                      ? Icons.assignment
                                      : Icons.menu_book,
                              size: 20,
                              color: item.fileType == HubFileType.pdf
                                  ? AppTheme.error
                                  : item.fileType == HubFileType.quiz
                                      ? AppTheme.warning
                                      : AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.text,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isLocal
                                            ? AppTheme.warning.withValues(alpha: 0.15)
                                            : AppTheme.success.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isLocal ? 'Phone File' : 'On MicroSD',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isLocal ? AppTheme.warning : AppTheme.success,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${item.fileName ?? item.title} • ${item.formattedSize} • ${item.fileType.name.toUpperCase()}',
                                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Action Buttons: View, Retrieve (save to phone), Delete
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Row(
                        children: [
                          // View Button
                          TextButton.icon(
                            onPressed: () => _openMaterialViewer(item),
                            icon: Icon(Icons.visibility_outlined, size: 16, color: AppTheme.primary),
                            label: Text(
                              'View',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Retrieve Button
                          TextButton.icon(
                            onPressed: () => _retrieveMaterialToPhone(item),
                            icon: Icon(Icons.download_for_offline_outlined, size: 16, color: AppTheme.success),
                            label: Text(
                              'Retrieve',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.success),
                            ),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                          ),
                          const Spacer(),
                          // Delete Button
                          TextButton.icon(
                            onPressed: () => _confirmAndDeleteMaterial(item),
                            icon: Icon(Icons.delete_outline, size: 16, color: AppTheme.error),
                            label: Text(
                              'Delete',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.error),
                            ),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 16),

          // Package Stats Bar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Package Size:', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    Text(
                      _formatBytes(_selectedBytes),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Selected for Upload:', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    Text(
                      '${_selectedMaterialIds.length} of ${_availableMaterials.length}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Upload Progress indicator (when active)
          if (_isUploading || _uploadProgress > 0) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _uploadStepText,
                          style: TextStyle(fontSize: 12, color: AppTheme.text),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${(_uploadProgress * 100).toInt()}%',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: AppTheme.border,
                      valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Upload Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isUploading || _selectedMaterialIds.isEmpty ? null : _handleUploadToEsp32,
              icon: _isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_upload, size: 20),
              label: Text(
                _isUploading ? 'Transferring to MicroSD...' : 'Upload Selected to MicroSD',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildQrTab() {
    final qrData = (_hubManifest != null && _hubManifest!.qrPayload.isNotEmpty)
        ? _hubManifest!.qrPayload
        : 'WIFI:S:${_hubStatus.ssid};T:WPA;P:${_hubStatus.password};;AIRAMP:SEC=${_hubManifest?.sectionName ?? widget.initialSection ?? 'Grade 10'};IP=${_hubStatus.ipAddress}';

    // When NOT connected to the ESP32 Wi-Fi, hide the QR code and show the connection guide with refresh button
    if (!_hubStatus.isDevKitConnected) {
      return RefreshIndicator(
        onRefresh: () => _refreshHubStatus(silent: false),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Offline State Card (Guides user to connect)
              _buildOfflineDisconnectedCard(),
              const SizedBox(height: 16),
              // Required Station Credentials Card
              _buildDisconnectedCredentialsCard(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    }

    // When CONNECTED to the ESP32 Wi-Fi, show the authentic QR code and station details
    return RefreshIndicator(
      onRefresh: () => _refreshHubStatus(silent: false),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Connected Success Banner with Refresh Button
            _buildConnectedBanner(),
            const SizedBox(height: 12),

            Text(
              'Present this QR Code to Students',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Students scan this with their AIRAMP app to connect to your ESP32 station and download your uploaded modules offline.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),

            // Authentic QR Code Graphic matching ESP32 OLED
            HubQrCodeWidget(
              qrData: qrData,
              hubSsid: _hubStatus.ssid,
              hubIp: _hubStatus.ipAddress,
              size: 210,
            ),

            const SizedBox(height: 20),

            // Station Details Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  _buildInfoRow(Icons.wifi, 'Wi-Fi Network', _hubStatus.ssid),
                  const Divider(height: 16),
                  _buildInfoRow(Icons.lock_outline, 'Wi-Fi Password', _hubStatus.password),
                  const Divider(height: 16),
                  _buildInfoRow(Icons.language, 'Hub IP Gateway', _hubStatus.ipAddress),
                  const Divider(height: 16),
                  _buildInfoRow(
                    Icons.class_outlined,
                    'Class / Section',
                    _hubManifest?.sectionName ?? widget.initialSection ?? 'Grade 10',
                  ),
                  const Divider(height: 16),
                  _buildInfoRow(
                    Icons.folder_shared,
                    'Packaged Materials',
                    _availableMaterials.isNotEmpty
                        ? '${_availableMaterials.length} Items (${_formatBytes(_selectedBytes)})'
                        : (_hubManifest != null && _hubManifest!.items.isNotEmpty
                            ? '${_hubManifest!.items.length} Items'
                            : '0 Items (0 B)'),
                    trailing: _availableMaterials.isNotEmpty
                        ? InkWell(
                            onTap: () => _tabController.animateTo(0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('View List', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                                  const SizedBox(width: 2),
                                  Icon(Icons.arrow_forward_ios, size: 9, color: AppTheme.primary),
                                ],
                              ),
                            ),
                          )
                        : null,
                  ),
                  const Divider(height: 16),
                  _buildInfoRow(
                    Icons.sd_storage,
                    'MicroSD Storage',
                    _hubStatus.isSdCardDetected
                        ? _hubStatus.formattedTotalStorage
                        : (_hubStatus.isDevKitConnected ? 'No Card Detected' : 'Connect Wi-Fi to check'),
                  ),
                  if (_hubStatus.isDevKitConnected) ...[
                    const Divider(height: 16),
                    _buildInfoRow(
                      Icons.people_outline,
                      'Connected Students',
                      '${_hubStatus.connectedClients} Connected',
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Copy / Share Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                        text: 'Wi-Fi: ${_hubStatus.ssid} | Password: ${_hubStatus.password} | Hub IP: ${_hubStatus.ipAddress}',
                      ));
                      AppToast.showSuccess(context, 'Station credentials copied to clipboard!');
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy Info'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.text,
                      side: BorderSide(color: AppTheme.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showFullscreenQrDialog(context, qrData);
                    },
                    icon: const Icon(Icons.fullscreen, size: 18),
                    label: const Text('Projector Mode'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: AppTheme.success, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Connected to ${_hubStatus.ssid}! Hardware synchronized.',
              style: TextStyle(fontSize: 12, color: AppTheme.text, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: 'Refresh Status',
            icon: _isCheckingHub
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 18),
            onPressed: _isCheckingHub ? null : () => _refreshHubStatus(silent: false),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineDisconnectedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.wifi_off_rounded,
              size: 38,
              color: AppTheme.warning,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ESP32 Hub Not Connected',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect your phone to the ESP32 Wi-Fi station to load the real classroom materials and display the student QR code.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGuideStep('1', 'Open your phone\'s Wi-Fi Settings'),
                const SizedBox(height: 8),
                _buildGuideStep('2', 'Connect to "${_hubStatus.ssid}"'),
                const SizedBox(height: 8),
                _buildGuideStep('3', 'Password is "${_hubStatus.password}"'),
                const SizedBox(height: 8),
                _buildGuideStep('4', 'Return here — QR code will show automatically'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _isCheckingHub ? null : () => _refreshHubStatus(silent: false),
              icon: _isCheckingHub
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.refresh, size: 20),
              label: Text(
                _isCheckingHub ? 'Checking Connection...' : 'Refresh Connection',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep(String stepNumber, String instruction) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Text(
            stepNumber,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            instruction,
            style: TextStyle(fontSize: 12, color: AppTheme.text),
          ),
        ),
      ],
    );
  }

  Widget _buildDisconnectedCredentialsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.wifi, 'Required Wi-Fi SSID', _hubStatus.ssid),
          const Divider(height: 16),
          _buildInfoRow(Icons.lock_outline, 'Wi-Fi Password', _hubStatus.password),
          const Divider(height: 16),
          _buildInfoRow(Icons.language, 'Hub IP Gateway', _hubStatus.ipAddress),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(
                  text: 'SSID: ${_hubStatus.ssid} | Password: ${_hubStatus.password}',
                ));
                AppToast.showSuccess(context, 'Wi-Fi credentials copied to clipboard!');
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy Wi-Fi Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.text,
                side: BorderSide(color: AppTheme.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullscreenQrDialog(BuildContext context, String qrData) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black.withValues(alpha: 0.95),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
              const Spacer(),
              Text(
                'Scan to Download Classroom Modules',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Open AIRAMP > Tap "Scan Hub QR" • No Data or Internet Needed',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
              ),
              const SizedBox(height: 30),
              HubQrCodeWidget(
                qrData: qrData,
                hubSsid: _hubStatus.ssid,
                hubIp: _hubStatus.ipAddress,
                size: 300,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Station: ${_hubStatus.ssid}  •  Password: ${_hubStatus.password}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Widget? trailing}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const Spacer(),
        SelectableText(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.text,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing,
        ],
      ],
    );
  }
}
