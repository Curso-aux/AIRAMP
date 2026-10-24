import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/components/app_toast.dart';
import '../domain/esp32_hub_models.dart';
import '../data/esp32_client_service.dart';
import '../data/saved_materials_service.dart';
import 'saved_offline_materials_modal.dart';

/// Modal dialog for teachers to manage the ESP32 Offline Learning Hub,
/// pick and upload real curriculum files to the ESP32 MicroSD card, and display the classroom QR code.
class TeacherEsp32HubModal extends StatefulWidget {
  final String teacherName;
  final String? initialSection;
  final bool startWithScanner;

  const TeacherEsp32HubModal({
    super.key,
    required this.teacherName,
    this.initialSection,
    this.startWithScanner = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String teacherName,
    String? initialSection,
    bool startWithScanner = false,
    bool useRootNavigator = true,
  }) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: useRootNavigator,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TeacherEsp32HubModal(
        teacherName: teacherName,
        initialSection: initialSection,
        startWithScanner: startWithScanner,
      ),
    );
  }

  @override
  State<TeacherEsp32HubModal> createState() => _TeacherEsp32HubModalState();
}

class _TeacherEsp32HubModalState extends State<TeacherEsp32HubModal> {
  Esp32HubStatus _hubStatus = const Esp32HubStatus();
  HubSyncManifest? _hubManifest;
  final List<HubMaterialItem> _availableMaterials = [];
  final Set<String> _selectedMaterialIds = {};

  Timer? _hubPollTimer;
  bool _isCheckingHub = false;
  bool _isUploading = false;
  bool _compressBeforeUpload = true;
  double _uploadProgress = 0.0;
  String _uploadStepText = '';

  @override
  void initState() {
    super.initState();
    _refreshHubStatus();

    // Auto-detect connection to ESP32 Wi-Fi every 3 seconds so the user
    // immediately sees live hardware details and MicroSD files
    _hubPollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && !_isCheckingHub && !_isUploading) {
        _refreshHubStatus(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _hubPollTimer?.cancel();
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
            'Connected to Classroom Hub! Hardware status loaded.',
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
        allowedExtensions: ['pdf', 'json', 'txt', 'doc', 'docx', 'zip', 'gz'],
      );

      if (files.isEmpty) return;

      int addedCount = 0;
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        final fileName = file.name;
        final size = await file.length();
        final isPdf = fileName.toLowerCase().endsWith('.pdf');
        final isQuiz = fileName.toLowerCase().endsWith('.json');
        final isArchive = fileName.toLowerCase().endsWith('.zip') || fileName.toLowerCase().endsWith('.gz');
        final fileType = isPdf
            ? HubFileType.pdf
            : (isQuiz
                ? HubFileType.quiz
                : (isArchive ? HubFileType.module : HubFileType.doc));

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
          isCompressed: fileName.toLowerCase().endsWith('.gz'),
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
        'Cannot reach ESP32 at 192.168.4.1. Please scan the QR code on the physical ESP32 screen to connect your phone.',
      );
      return;
    }

    // Step 1: Upload each local file to ESP32 MicroSD (/upload)
    for (int i = 0; i < selectedItems.length; i++) {
      final item = selectedItems[i];
      if (item.localPath != null) {
        File uploadTargetFile = File(item.localPath!);
        String targetFileName = item.fileName ?? '${item.id}.pdf';
        int targetSizeBytes = item.sizeBytes;
        bool itemIsCompressed = item.isCompressed;
        int? origSize = item.originalSizeBytes;

        // Perform compression if enabled and not already compressed
        if (_compressBeforeUpload &&
            !targetFileName.toLowerCase().endsWith('.gz') &&
            !targetFileName.toLowerCase().endsWith('.zip')) {
          setState(() {
            _uploadStepText = 'Compressing ${item.title} to save SD space...';
          });
          final compressedFile = await Esp32ClientService.instance.compressFileForUpload(uploadTargetFile);
          if (compressedFile != null && compressedFile.path != uploadTargetFile.path) {
            origSize = targetSizeBytes;
            uploadTargetFile = compressedFile;
            targetFileName = '$targetFileName.gz';
            targetSizeBytes = await compressedFile.length();
            itemIsCompressed = true;
          }
        }

        setState(() {
          _uploadStepText = 'Uploading ${item.title} to MicroSD...';
        });

        final success = await Esp32ClientService.instance.uploadFileToHub(
          ipAddress: _hubStatus.ipAddress,
          filePath: uploadTargetFile.path,
          fileName: targetFileName,
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

        // Clean up temporary compressed file if created
        if (itemIsCompressed && uploadTargetFile.path != item.localPath) {
          try {
            await uploadTargetFile.delete();
          } catch (_) {}
        }

        // Update selected items list entry with final uploaded metadata
        final updatedItem = item.copyWith(
          fileName: targetFileName,
          sizeBytes: targetSizeBytes,
          isCompressed: itemIsCompressed,
          originalSizeBytes: origSize,
        );
        selectedItems[i] = updatedItem;
        final availIdx = _availableMaterials.indexWhere((m) => m.id == item.id);
        if (availIdx >= 0) {
          _availableMaterials[availIdx] = updatedItem;
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
      'Materials uploaded to ESP32 MicroSD! Students can now access them directly from the hub.',
    );
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Icon(Icons.dns_outlined, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Classroom Offline Hub',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Local Storage Station • Offline File Distribution',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh Hub Status',
                  icon: _isCheckingHub
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.refresh, size: 20, color: AppTheme.textMuted),
                  onPressed: _isCheckingHub ? null : () => _refreshHubStatus(silent: false),
                ),
                IconButton(
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
                            : (_hubStatus.isDevKitConnected ? 'No Card Detected' : 'Standby'),
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

          // File Management View
          Expanded(
            child: _buildMaterialsTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsTab() {
    final estSavings = (_selectedBytes * 0.68).toInt();
    final estTransferBytes = (_selectedBytes * 0.32).toInt();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live Connection Reminder Card
          _buildLiveConnectionReminder(),
          const SizedBox(height: 16),

          if (_availableMaterials.isEmpty) ...[
            // Staging Hero Upload Card when empty (eliminates empty state clutter)
            _buildEmptyStagingHero(),
          ] else ...[
            // Header Bar with Title, Add Files, and Select All
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Classroom Materials (${_availableMaterials.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.text,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickRealFiles,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Files', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
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
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  child: Text(
                    _selectedMaterialIds.length == _availableMaterials.length ? 'Deselect All' : 'Select All',
                    style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Staged Material Cards
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
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Icon(
                              item.fileType == HubFileType.pdf
                                  ? Icons.picture_as_pdf
                                  : item.fileType == HubFileType.quiz
                                      ? Icons.assignment_outlined
                                      : Icons.folder_outlined,
                              size: 18,
                              color: item.fileType == HubFileType.pdf
                                  ? AppTheme.pdfColor
                                  : item.fileType == HubFileType.quiz
                                      ? AppTheme.accent
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
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
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
                                            ? AppTheme.surface
                                            : AppTheme.success.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isLocal ? AppTheme.border : AppTheme.success.withValues(alpha: 0.25),
                                        ),
                                      ),
                                      child: Text(
                                        isLocal ? 'Staged' : 'MicroSD',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: isLocal ? AppTheme.textMuted : AppTheme.success,
                                        ),
                                      ),
                                    ),
                                    if (item.isCompressed) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surface,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppTheme.border),
                                        ),
                                        child: Text(
                                          'GZ',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
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

            // Compression Option Toggle Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Icon(
                      Icons.compress,
                      size: 20,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Pre-Upload Compression',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.text,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Text(
                                'Saves ~68% SD Space',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _compressBeforeUpload
                              ? 'Est. transfer: ~${_formatBytes(estTransferBytes)} (saves ~${_formatBytes(estSavings)})'
                              : 'Uploads raw uncompressed files (${_formatBytes(_selectedBytes)})',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _compressBeforeUpload,
                    activeTrackColor: AppTheme.primary,
                    onChanged: (val) {
                      setState(() {
                        _compressBeforeUpload = val;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Package Stats Bar
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TRANSFER PAYLOAD', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Text(
                        _compressBeforeUpload ? '~${_formatBytes(estTransferBytes)}' : _formatBytes(_selectedBytes),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.text),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('STAGED ITEMS', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Text(
                        '${_selectedMaterialIds.length} of ${_availableMaterials.length}',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.text),
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
                  borderRadius: BorderRadius.circular(10),
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
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _isUploading || _selectedMaterialIds.isEmpty
                    ? null
                    : () {
                        if (!_hubStatus.isDevKitConnected) {
                          _showConnectToHubPrompt();
                        } else {
                          _handleUploadToEsp32();
                        }
                      },
                icon: _isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(
                        _hubStatus.isDevKitConnected ? Icons.cloud_upload_outlined : Icons.wifi_tethering,
                        size: 18,
                      ),
                label: Text(
                  _isUploading
                      ? 'Synchronizing with MicroSD...'
                      : (_hubStatus.isDevKitConnected
                          ? 'Transfer ${_selectedMaterialIds.length} Selected to MicroSD'
                          : 'Connect to Wi-Fi to Sync (${_selectedMaterialIds.length} Staged)'),
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  /// Live connection reminder banner displayed at top of materials view
  /// Live connection reminder banner displayed at top of materials view
  Widget _buildLiveConnectionReminder() {
    if (_hubStatus.isDevKitConnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    'MicroSD accessible. Local storage is ready for curriculum synchronization.',
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
            'Scan the QR code or view credentials on the physical ESP32 Hub screen with your camera to connect, then tap Verify Link below.',
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

  Widget _buildEmptyStagingHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          // Professional Appliance Icon
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 26,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 14),

          Text(
            'Classroom Material Repository',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.text,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Stage syllabus files, textbook chapters (.pdf), quizzes (.json), or zipped modules for distribution over the offline station.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),

          // Understated Technical Format Ledger
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              'Supported Formats: PDF Documents • JSON Quizzes • ZIP & GZ Archives',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMuted,
                letterSpacing: 0.1,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Primary Action: Choose Files from Device
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _pickRealFiles,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text(
                'Select Files from Device',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Secondary Action: Open Offline Library
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: () => SavedOfflineMaterialsModal.show(context),
              icon: Icon(Icons.folder_open_outlined, size: 17, color: AppTheme.text),
              label: Text('Open Offline Saved Library', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.text)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.text,
                side: BorderSide(color: AppTheme.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Quick Workflow Steps
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                _buildGuideStep('1', 'Select learning materials from your local phone storage'),
                const SizedBox(height: 7),
                _buildGuideStep('2', 'Connect to Classroom Hub Wi-Fi (scan physical screen)'),
                const SizedBox(height: 7),
                _buildGuideStep('3', 'Transfer package to MicroSD for instant student distribution'),
              ],
            ),
          ),
        ],
      ),
    );
  }



  /// Bottom sheet prompt displayed when user tries to upload to ESP32 while not connected to its Wi-Fi
  void _showConnectToHubPrompt() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Icon(Icons.wifi_tethering, color: AppTheme.primary, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              'Station Wi-Fi Link Required',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.text),
            ),
            const SizedBox(height: 6),
            Text(
              'Curriculum files are staged on this device. Connect to the hub Wi-Fi hotspot to transfer them to physical MicroSD storage:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.qr_code_scanner, size: 20, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Scan the Wi-Fi QR code or check credentials displayed on the physical ESP32 Hub screen.',
                      style: TextStyle(fontSize: 12, color: AppTheme.text, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Primary Action: Verify Wi-Fi Connection
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _refreshHubStatus(silent: false);
                },
                icon: const Icon(Icons.refresh, size: 17),
                label: const Text('Verify Link & Continue', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }



  Widget _buildGuideStep(String stepNumber, String instruction) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.border),
          ),
          child: Text(
            stepNumber,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            instruction,
            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }

}

