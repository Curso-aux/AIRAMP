import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/components/app_toast.dart';
import '../domain/esp32_hub_models.dart';
import '../data/saved_materials_service.dart';
import '../data/esp32_client_service.dart';
import 'components/qr_viewfinder_widget.dart';
import 'saved_offline_materials_modal.dart';

/// Modal bottom sheet for students to scan the teacher's ESP32 QR code with the real camera,
/// discover classroom learning materials from the ESP32 Hub, and save them offline.
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
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StudentEsp32SyncModal(
        studentName: studentName,
        studentSection: studentSection,
        onSyncCompleted: onSyncCompleted,
      ),
    );
  }

  @override
  State<StudentEsp32SyncModal> createState() => _StudentEsp32SyncModalState();
}

enum _SyncStep { scan, connecting, wifiPrompt, manifest, downloading, done }

class _StudentEsp32SyncModalState extends State<StudentEsp32SyncModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  _SyncStep _currentStep = _SyncStep.scan;
  final TextEditingController _ipController = TextEditingController(text: '192.168.4.1');
  final TextEditingController _ssidController = TextEditingController(text: 'AIRAMP-HUB-01');

  HubQrPayload? _scannedPayload;
  HubSyncManifest? _manifest;
  List<HubMaterialItem> _itemsToDownload = [];
  Set<String> _selectedItemIds = {};
  String _selectedTypeFilter = 'all';
  int _completedDownloads = 0;
  String _activeDownloadTitle = '';
  double _overallProgress = 0.0;
  bool _isReconnecting = false;

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
        return Icons.picture_as_pdf_rounded;
      case 'html':
        return Icons.language_rounded;
      case 'quiz':
        return Icons.assignment_turned_in_rounded;
      case 'doc':
        return Icons.description_rounded;
      case 'module':
      default:
        return Icons.menu_book_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'pdf':
        return const Color(0xFFEF4444);
      case 'html':
        return const Color(0xFF3B82F6);
      case 'quiz':
        return const Color(0xFFF59E0B);
      case 'doc':
        return const Color(0xFF6366F1);
      case 'module':
      default:
        return AppTheme.primary;
    }
  }

  Color _getFileColor(HubMaterialItem item) {
    return _getCategoryColor(_getItemCategory(item));
  }

  IconData _getFileIcon(HubMaterialItem item) {
    return _getCategoryIcon(_getItemCategory(item));
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ipController.dispose();
    _ssidController.dispose();
    super.dispose();
  }

  /// Handles real connection attempt with the ESP32 Hub
  Future<void> _processHubConnection(String sourceInfo) async {
    final payload = HubQrPayload.parse(sourceInfo);
    _scannedPayload = payload;
    _ipController.text = payload.ipAddress;
    _ssidController.text = payload.ssid;

    setState(() {
      _currentStep = _SyncStep.connecting;
      _isReconnecting = false;
    });

    // Step 1: Ping the ESP32 Hub (Triggers buzzer chime on hardware)
    final pingResult = await Esp32ClientService.instance.ping(payload.ipAddress);

    if (!mounted) return;

    if (pingResult == null) {
      // Could not connect to ESP32 (Phone is likely not connected to the ESP32's Wi-Fi hotspot)
      setState(() {
        _currentStep = _SyncStep.wifiPrompt;
      });
      return;
    }

    // Step 2: Fetch the real curriculum manifest from the ESP32
    final manifest = await Esp32ClientService.instance.fetchManifest(
      payload.ipAddress,
      qrPayload: payload.raw,
    );

    if (!mounted) return;

    if (manifest != null && manifest.items.isNotEmpty) {
      setState(() {
        _manifest = manifest;
        _itemsToDownload = List.from(manifest.items);
        _selectedItemIds = manifest.items.map((e) => e.id).toSet();
        _selectedTypeFilter = 'all';
        _currentStep = _SyncStep.manifest;
      });

      AppToast.showSuccess(
        context,
        'Connected to ${manifest.hubName}! ${manifest.items.length} materials ready.',
      );
    } else {
      // Manifest returned empty or SD card had no files
      final fallbackManifest = HubSyncManifest(
        hubId: 'AIRAMP-HUB-01',
        hubName: 'AIRA Offline Classroom Hub',
        teacherName: 'Classroom Instructor',
        sectionName: payload.sectionName,
        generatedAt: DateTime.now().toIso8601String(),
        items: [],
        qrPayload: payload.raw,
      );

      setState(() {
        _manifest = fallbackManifest;
        _itemsToDownload = [];
        _selectedItemIds = {};
        _selectedTypeFilter = 'all';
        _currentStep = _SyncStep.manifest;
      });

      AppToast.showInfo(
        context,
        'Connected to ESP32 Hub! No files currently in manifest.',
      );
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

    final ip = _scannedPayload?.ipAddress ?? _ipController.text;

    setState(() {
      _itemsToDownload = List.from(targets);
      _currentStep = _SyncStep.downloading;
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

    if (!mounted) return;
    setState(() {
      _currentStep = _SyncStep.done;
      _overallProgress = 1.0;
    });

    AppToast.showSuccess(
      context,
      '${savedResults.length} ${savedResults.length == 1 ? 'material' : 'materials'} saved offline! Ready to study without internet.',
    );
    widget.onSyncCompleted?.call();
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
                  child: Icon(Icons.qr_code_scanner, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Classroom Hub Sync',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Download modules offline with no internet or data',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'View Saved Offline Materials',
                  icon: Icon(Icons.folder_special_outlined, color: AppTheme.primary),
                  onPressed: () {
                    Navigator.pop(context);
                    SavedOfflineMaterialsModal.show(
                      context,
                      studentName: widget.studentName,
                      studentSection: widget.studentSection,
                    );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppTheme.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content based on step
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentStep) {
      case _SyncStep.scan:
        return _buildScanView();
      case _SyncStep.connecting:
        return _buildConnectingView();
      case _SyncStep.wifiPrompt:
        return _buildWifiPromptView();
      case _SyncStep.manifest:
        return _buildManifestView();
      case _SyncStep.downloading:
        return _buildDownloadingView();
      case _SyncStep.done:
        return _buildDoneView();
    }
  }

  Widget _buildScanView() {
    return Column(
      children: [
        ValueListenableBuilder<List<HubMaterialItem>>(
          valueListenable: SavedMaterialsService.instance.savedMaterialsNotifier,
          builder: (context, savedList, _) {
            final count = savedList.length;
            return TabBar(
              controller: _tabController,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textMuted,
              indicatorColor: AppTheme.primary,
              indicatorWeight: 3,
              tabs: [
                const Tab(icon: Icon(Icons.camera_alt_outlined, size: 20), text: 'Scan Hub QR'),
                Tab(
                  icon: const Icon(Icons.folder_special_rounded, size: 20),
                  text: count > 0 ? 'Saved ($count)' : 'Saved Files',
                ),
                const Tab(icon: Icon(Icons.wifi, size: 20), text: 'Manual Connect'),
              ],
            );
          },
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Real Camera QR Viewfinder
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  children: [
                    QrViewfinderWidget(
                      statusText: 'Point camera at Teacher\'s ESP32 screen',
                      onScanned: (qrCode) {
                        _processHubConnection(qrCode);
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Scan the QR code displayed on the ESP32 OLED screen or classroom projector.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<List<HubMaterialItem>>(
                      valueListenable: SavedMaterialsService.instance.savedMaterialsNotifier,
                      builder: (context, savedList, _) {
                        if (savedList.isEmpty) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.folder_special_rounded, color: AppTheme.primary, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Saved Materials (${savedList.length})',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.text,
                                      ),
                                    ),
                                    Text(
                                      'Review offline modules & quizzes',
                                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  _tabController.animateTo(1);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  minimumSize: const Size(0, 32),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                                child: const Text('View Files', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Tab 2: Saved Learning Materials Embedded View
              SavedOfflineMaterialsModal(
                studentName: widget.studentName,
                studentSection: widget.studentSection,
                showHeader: false,
              ),

              // Tab 3: Manual Wi-Fi Connect
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connect Directly to ESP32 DevKit',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'If camera is unavailable, connect your phone to the ESP32 Wi-Fi hotspot in your phone settings, then tap Connect below:',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _ssidController,
                      decoration: InputDecoration(
                        labelText: 'ESP32 Wi-Fi SSID',
                        prefixIcon: const Icon(Icons.wifi),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _ipController,
                      decoration: InputDecoration(
                        labelText: 'ESP32 Hub IP Gateway',
                        prefixIcon: const Icon(Icons.language),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _processHubConnection(
                            'WIFI:S:${_ssidController.text};P:aira1234;;AIRAMP:SEC=Class;IP=${_ipController.text}',
                          );
                        },
                        icon: const Icon(Icons.link),
                        label: const Text('Connect & Discover Materials'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectingView() {
    final ip = _scannedPayload?.ipAddress ?? _ipController.text;
    final ssid = _scannedPayload?.ssid ?? _ssidController.text;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(strokeWidth: 3),
            const SizedBox(height: 24),
            Text(
              'Connecting to ESP32 Station...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Handshaking with $ssid at http://$ip/api/ping',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  /// Displays clear Wi-Fi instructions when phone cannot reach the ESP32 IP
  Widget _buildWifiPromptView() {
    final payload = _scannedPayload ?? HubQrPayload.parse('');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.wifi_off_rounded, color: AppTheme.warning, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            'Connect Phone to ESP32 Wi-Fi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'QR code was recognized successfully! However, your phone is not currently connected to the ESP32\'s local Wi-Fi station.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),

          // Wi-Fi Credentials Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                _buildWifiCredentialRow(Icons.wifi, 'Wi-Fi Name (SSID)', payload.ssid),
                const Divider(height: 16),
                _buildWifiCredentialRow(Icons.lock_outline, 'Password', payload.password),
                const Divider(height: 16),
                _buildWifiCredentialRow(Icons.language, 'Gateway IP', payload.ipAddress),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            '👉 Open your phone Wi-Fi settings, connect to "${payload.ssid}" using password "${payload.password}", then tap Retry below.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 24),

          // Retry Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isReconnecting
                  ? null
                  : () async {
                      setState(() => _isReconnecting = true);
                      await _processHubConnection(payload.raw);
                    },
              icon: _isReconnecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 20),
              label: Text(_isReconnecting ? 'Connecting...' : 'I\'m Connected · Retry Handshake'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          TextButton.icon(
            onPressed: () {
              setState(() {
                _currentStep = _SyncStep.scan;
              });
            },
            icon: const Icon(Icons.qr_code_scanner, size: 18),
            label: const Text('Back to Camera Scanner'),
          ),
        ],
      ),
    );
  }

  Widget _buildWifiCredentialRow(IconData icon, String label, String value) {
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

  Widget _buildTypeFilterChip(String key, String label, IconData icon, Color color) {
    final isSelected = _selectedTypeFilter == key;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTypeFilter = key;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : AppTheme.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? color : AppTheme.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySectionHeader(String category, List<HubMaterialItem> items) {
    final color = _getCategoryColor(category);
    final icon = _getCategoryIcon(category);
    final title = _getCategoryTitle(category);
    final allCategorySelected = items.isNotEmpty && items.every((i) => _selectedItemIds.contains(i.id));

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${items.length}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
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
                fontWeight: FontWeight.bold,
                color: color,
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
    final fileColor = _getFileColor(item);
    final fileIcon = _getFileIcon(item);

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
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primarySoft.withValues(alpha: 0.3)
              : AppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.7)
                : AppTheme.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Selection Checkbox
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: isSelected,
                activeColor: AppTheme.primary,
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
            const SizedBox(width: 10),

            // File Type Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: fileColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                fileIcon,
                size: 20,
                color: fileColor,
              ),
            ),
            const SizedBox(width: 12),

            // Title & Subject/Size
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
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
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      if (isSaved) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 10, color: AppTheme.success),
                              const SizedBox(width: 2),
                              Text(
                                'Saved',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
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

            // Quick Download Button for this specific file
            Tooltip(
              message: isSaved ? 'Re-download this file' : 'Download this file only',
              child: InkWell(
                onTap: () => _startOfflineDownload(targetItems: [item]),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSaved
                        ? AppTheme.surfaceLight
                        : AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSaved
                          ? AppTheme.border
                          : AppTheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSaved ? Icons.check : Icons.download_rounded,
                        size: 14,
                        color: isSaved ? AppTheme.success : AppTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isSaved ? 'Sync' : 'Get',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSaved ? AppTheme.success : AppTheme.primary,
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
    );
  }

  Widget _buildManifestView() {
    final manifest = _manifest!;
    final savedItemIds = SavedMaterialsService.instance.savedMaterialsNotifier.value
        .map((e) => e.id)
        .toSet();

    // Group items by category to segregate them cleanly
    final grouped = <String, List<HubMaterialItem>>{};
    for (final item in manifest.items) {
      final cat = _getItemCategory(item);
      grouped.putIfAbsent(cat, () => []).add(item);
    }

    // Determine filtered groups
    final filteredGroups = _selectedTypeFilter == 'all'
        ? grouped
        : {
            if (grouped.containsKey(_selectedTypeFilter))
              _selectedTypeFilter: grouped[_selectedTypeFilter]!,
          };

    final visibleItems = filteredGroups.values.expand((list) => list).toList();
    final allVisibleSelected = visibleItems.isNotEmpty &&
        visibleItems.every((item) => _selectedItemIds.contains(item.id));

    final pdfCount = grouped['pdf']?.length ?? 0;
    final htmlCount = grouped['html']?.length ?? 0;
    final quizCount = grouped['quiz']?.length ?? 0;
    final moduleCount = grouped['module']?.length ?? 0;
    final docCount = grouped['doc']?.length ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Station Info Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        manifest.hubName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.text,
                        ),
                      ),
                      Text(
                        'Section: ${manifest.sectionName} • Teacher: ${manifest.teacherName}',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Header with Select All / Deselect All
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Classroom Materials (${manifest.items.length})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedItemIds.isEmpty
                          ? 'Tap materials or categories to select'
                          : '${_selectedItemIds.length} of ${manifest.items.length} selected (${_formatSize(_selectedTotalBytes)})',
                      style: TextStyle(
                        fontSize: 11,
                        color: _selectedItemIds.isEmpty ? AppTheme.textMuted : AppTheme.primary,
                        fontWeight: FontWeight.w600,
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
                    allVisibleSelected
                        ? Icons.remove_done_rounded
                        : Icons.done_all_rounded,
                    size: 16,
                    color: AppTheme.primary,
                  ),
                  label: Text(
                    allVisibleSelected
                        ? (_selectedTypeFilter == 'all' ? 'Deselect All' : 'Deselect Category')
                        : (_selectedTypeFilter == 'all' ? 'Select All' : 'Select Category'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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
          const SizedBox(height: 12),

          // Filter of specific type of files
          if (manifest.items.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTypeFilterChip(
                    'all',
                    'All (${manifest.items.length})',
                    Icons.grid_view_rounded,
                    AppTheme.primary,
                  ),
                  if (pdfCount > 0) ...[
                    const SizedBox(width: 8),
                    _buildTypeFilterChip(
                      'pdf',
                      'PDFs ($pdfCount)',
                      Icons.picture_as_pdf_rounded,
                      const Color(0xFFEF4444),
                    ),
                  ],
                  if (htmlCount > 0) ...[
                    const SizedBox(width: 8),
                    _buildTypeFilterChip(
                      'html',
                      'HTML / Web ($htmlCount)',
                      Icons.language_rounded,
                      const Color(0xFF3B82F6),
                    ),
                  ],
                  if (quizCount > 0) ...[
                    const SizedBox(width: 8),
                    _buildTypeFilterChip(
                      'quiz',
                      'Quizzes ($quizCount)',
                      Icons.assignment_turned_in_rounded,
                      const Color(0xFFF59E0B),
                    ),
                  ],
                  if (moduleCount > 0) ...[
                    const SizedBox(width: 8),
                    _buildTypeFilterChip(
                      'module',
                      'Modules ($moduleCount)',
                      Icons.menu_book_rounded,
                      AppTheme.primary,
                    ),
                  ],
                  if (docCount > 0) ...[
                    const SizedBox(width: 8),
                    _buildTypeFilterChip(
                      'doc',
                      'Docs ($docCount)',
                      Icons.description_rounded,
                      const Color(0xFF6366F1),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          if (manifest.items.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Text(
                'No curriculum files found on this hub yet.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            )
          else if (filteredGroups.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  Icon(Icons.filter_list_off_rounded, size: 36, color: AppTheme.textMuted),
                  const SizedBox(height: 8),
                  Text(
                    'No files found for this filter.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
                const SizedBox(height: 8),
              ];
            }),

          const SizedBox(height: 12),

          // Download CTA
          if (manifest.items.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _selectedItemIds.isEmpty ? null : () => _startOfflineDownload(),
                icon: Icon(
                  _selectedItemIds.isEmpty
                      ? Icons.file_download_off_outlined
                      : Icons.download_rounded,
                  size: 20,
                ),
                label: Text(
                  _selectedItemIds.isEmpty
                      ? 'Select Files to Download'
                      : _selectedItemIds.length == manifest.items.length
                          ? 'Download All Offline (${manifest.items.length})'
                          : 'Download Selected (${_selectedItemIds.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.border,
                  disabledForegroundColor: AppTheme.textMuted,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            if (_selectedItemIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '${_selectedItemIds.length} of ${manifest.items.length} files selected (${_formatSize(_selectedTotalBytes)}) · Zero mobile data needed',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ),
            ],
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDownloadingView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.downloading, size: 48, color: AppTheme.primary),
          const SizedBox(height: 16),
          Text(
            'Downloading Classroom Materials...',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Saving: $_activeDownloadTitle',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _overallProgress,
              minHeight: 8,
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
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check, size: 48, color: AppTheme.success),
          ),
          const SizedBox(height: 18),
          Text(
            'Offline Sync Complete!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_itemsToDownload.length} ${_itemsToDownload.length == 1 ? 'material' : 'materials'} from your teacher ${(_itemsToDownload.length == 1 ? 'has' : 'have')} been safely stored on your device. You can browse, read, and take quizzes offline anytime.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 24),

          // Saved Summary Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                _buildDoneSummaryRow(Icons.offline_pin, 'Storage Status', 'Cached on Device'),
                const Divider(height: 16),
                _buildDoneSummaryRow(Icons.data_usage, 'Data Used', '0 MB (Free Local AP)'),
                const Divider(height: 16),
                _buildDoneSummaryRow(Icons.assignment_turned_in, 'Offline Quizzes', 'Ready to take'),
              ],
            ),
          ),

          const SizedBox(height: 24),

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
                  icon: Icon(
                    _manifest != null && _manifest!.items.isNotEmpty
                        ? Icons.arrow_back_rounded
                        : Icons.close,
                    size: 16,
                  ),
                  label: Text(
                    _manifest != null && _manifest!.items.isNotEmpty
                        ? 'Download More'
                        : 'Close',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: BorderSide(color: AppTheme.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                  icon: const Icon(Icons.folder_special_rounded, size: 18),
                  label: const Text('View Saved Materials'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        Icon(icon, size: 18, color: AppTheme.success),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.text,
          ),
        ),
      ],
    );
  }
}
