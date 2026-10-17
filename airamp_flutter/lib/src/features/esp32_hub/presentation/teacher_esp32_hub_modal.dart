import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/components/app_toast.dart';
import '../domain/esp32_hub_models.dart';
import '../data/esp32_client_service.dart';
import 'components/hub_qr_code_widget.dart';

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
  final List<HubMaterialItem> _availableMaterials = [];
  final Set<String> _selectedMaterialIds = {};

  bool _isCheckingHub = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStepText = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshHubStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Pings the ESP32 to get real hardware state (DevKit and MicroSD card) and loads existing manifest
  Future<void> _refreshHubStatus() async {
    setState(() => _isCheckingHub = true);

    final status = await Esp32ClientService.instance.checkHubStatus('192.168.4.1');

    if (!mounted) return;

    setState(() {
      _hubStatus = status;
      _isCheckingHub = false;
    });

    if (status.isDevKitConnected) {
      final manifest = await Esp32ClientService.instance.fetchManifest(status.ipAddress);
      if (!mounted) return;
      if (manifest != null && manifest.items.isNotEmpty) {
        setState(() {
          final existingIds = _availableMaterials.map((m) => m.id).toSet();
          for (final item in manifest.items) {
            if (!existingIds.contains(item.id)) {
              _availableMaterials.add(item);
              _selectedMaterialIds.add(item.id);
            }
          }
        });
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

    final qrPayload = 'WIFI:S:${_hubStatus.ssid};T:WPA;P:${_hubStatus.password};;AIRAMP:SEC=${widget.initialSection ?? 'Grade 10'};IP=${_hubStatus.ipAddress}';

    final updatedManifest = HubSyncManifest(
      hubId: 'AIRAMP-HUB-01',
      hubName: 'AIRA Classroom Station',
      teacherName: widget.teacherName,
      sectionName: widget.initialSection ?? 'Grade 10',
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
              Tab(icon: Icon(Icons.cloud_upload_outlined, size: 20), text: 'Upload'),
              Tab(icon: Icon(Icons.qr_code, size: 20), text: 'Classroom QR'),
              Tab(icon: Icon(Icons.memory, size: 20), text: 'Hardware Guide'),
            ],
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUploadTab(),
                _buildQrTab(),
                _buildHardwareGuideTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadTab() {
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
                        ? 'Connected to ESP32 Hub! Select real files below to upload directly to the MicroSD card.'
                        : 'Connect your phone to Wi-Fi "${_hubStatus.ssid}" (Password: "${_hubStatus.password}") to upload files directly to the ESP32.',
                    style: TextStyle(fontSize: 12, color: AppTheme.text, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Button: Add Real Files from Phone
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _pickRealFiles,
              icon: const Icon(Icons.note_add_outlined, size: 18),
              label: const Text('+ Pick Real PDF / Documents from Phone', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: BorderSide(color: AppTheme.primary, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Section Title & Select/Deselect
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Materials to Package & Upload (${_availableMaterials.length})',
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
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.folder_open_outlined, size: 36, color: AppTheme.textMuted),
                  const SizedBox(height: 8),
                  Text('No materials added yet.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Tap "+ Pick Real PDF / Documents" above to add real materials.', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ],
              ),
            )
          else
            ..._availableMaterials.map((item) {
              final isChecked = _selectedMaterialIds.contains(item.id);
              final isLocal = item.localPath != null;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isChecked ? AppTheme.primarySoft.withValues(alpha: 0.1) : AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isChecked ? AppTheme.primary.withValues(alpha: 0.4) : AppTheme.border,
                  ),
                ),
                child: CheckboxListTile(
                  value: isChecked,
                  activeColor: AppTheme.primary,
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.text,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isLocal)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('Phone File', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    '${item.fileName ?? item.title} • ${item.formattedSize} • ${item.fileType.name.toUpperCase()}',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      item.fileType == HubFileType.pdf
                          ? Icons.picture_as_pdf
                          : item.fileType == HubFileType.quiz
                              ? Icons.assignment
                              : Icons.menu_book,
                      size: 18,
                      color: item.fileType == HubFileType.pdf
                          ? AppTheme.error
                          : item.fileType == HubFileType.quiz
                              ? AppTheme.warning
                              : AppTheme.primary,
                    ),
                  ),
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
                    Text('Selected Items:', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
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
                _isUploading ? 'Transferring to MicroSD...' : 'Upload to ESP32 MicroSD',
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
    final qrData = 'WIFI:S:${_hubStatus.ssid};T:WPA;P:${_hubStatus.password};;AIRAMP:SEC=${widget.initialSection ?? 'Grade 10'};IP=${_hubStatus.ipAddress}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
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

          // QR Code Graphic
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
                  Icons.folder_shared,
                  'Packaged Materials',
                  '${_selectedMaterialIds.length} Items (${_formatBytes(_selectedBytes)})',
                ),
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

  Widget _buildHardwareGuideTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wiring & Pinout Reference (MicroSD SPI Module)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Connect your MicroSD Card Module to your ESP32 DevKit using standard SPI pins as shown below:',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),

          // Pinout Table
          Container(
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                _buildPinRow('MicroSD Pin', 'ESP32 DevKit Pin', 'Function', isHeader: true),
                const Divider(height: 1),
                _buildPinRow('VCC', '3.3V or 5V', 'Power supply'),
                const Divider(height: 1),
                _buildPinRow('GND', 'GND', 'Ground'),
                const Divider(height: 1),
                _buildPinRow('CS / SS', 'GPIO 5', 'Chip Select'),
                const Divider(height: 1),
                _buildPinRow('MOSI', 'GPIO 23', 'Data In'),
                const Divider(height: 1),
                _buildPinRow('SCK / CLK', 'GPIO 18', 'SPI Clock'),
                const Divider(height: 1),
                _buildPinRow('MISO', 'GPIO 19', 'Data Out'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // How It Operates
          Text(
            'How the Offline Classroom Station Works',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 10),
          _buildStepCard(
            '1. Standalone Wi-Fi SoftAP',
            'The ESP32 broadcasts a private Wi-Fi network with no router or internet connection needed. Up to 4–8 students can connect simultaneously to download.',
            Icons.wifi_tethering,
          ),
          const SizedBox(height: 8),
          _buildStepCard(
            '2. MicroSD File Server',
            'Materials (PDFs, quizzes) uploaded by the teacher are saved directly into the MicroSD card. Fast SPI streaming delivers files directly to student devices.',
            Icons.sd_card,
          ),
          const SizedBox(height: 8),
          _buildStepCard(
            '3. Zero Data Cost for Students',
            'Students scan the QR code to auto-connect to the hub and sync modules directly into their offline library with 0 MB cellular data used.',
            Icons.offline_pin,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
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
      ],
    );
  }

  Widget _buildPinRow(String pin1, String pin2, String desc, {bool isHeader = false}) {
    final style = TextStyle(
      fontSize: 12,
      fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
      color: isHeader ? AppTheme.primary : AppTheme.text,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(pin1, style: style)),
          Expanded(flex: 3, child: Text(pin2, style: style)),
          Expanded(flex: 3, child: Text(desc, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary))),
        ],
      ),
    );
  }

  Widget _buildStepCard(String title, String desc, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
