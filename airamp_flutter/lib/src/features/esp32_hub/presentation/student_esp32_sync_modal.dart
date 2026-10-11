import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/components/app_toast.dart';
import '../domain/esp32_hub_models.dart';
import '../data/saved_materials_service.dart';
import 'components/qr_viewfinder_widget.dart';
import 'saved_offline_materials_modal.dart';

/// Modal bottom sheet for students to scan the teacher's ESP32 QR code,
/// discover classroom learning materials, and save them offline.
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

enum _SyncStep { scan, connecting, manifest, downloading, done }

class _StudentEsp32SyncModalState extends State<StudentEsp32SyncModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  _SyncStep _currentStep = _SyncStep.scan;
  final TextEditingController _ipController = TextEditingController(text: '192.168.4.1');
  final TextEditingController _ssidController = TextEditingController(text: 'AIRAMP-HUB-01');

  late HubSyncManifest _manifest;
  late List<HubMaterialItem> _itemsToDownload;
  int _completedDownloads = 0;
  String _activeDownloadTitle = '';
  double _overallProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _manifest = HubSyncManifest.sample(
      sectionName: widget.studentSection ?? 'Grade 10 - Rizal',
    );
    _itemsToDownload = List.from(_manifest.items);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ipController.dispose();
    _ssidController.dispose();
    super.dispose();
  }

  Future<void> _processHubConnection(String sourceInfo) async {
    setState(() {
      _currentStep = _SyncStep.connecting;
    });

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    setState(() {
      _currentStep = _SyncStep.manifest;
    });

    AppToast.showSuccess(
      context,
      'Connected to ${_manifest.hubName}! ${_itemsToDownload.length} materials found.',
    );
  }

  Future<void> _startOfflineDownload() async {
    setState(() {
      _currentStep = _SyncStep.downloading;
      _completedDownloads = 0;
      _overallProgress = 0.0;
    });

    for (int i = 0; i < _itemsToDownload.length; i++) {
      final item = _itemsToDownload[i];
      if (!mounted) return;

      setState(() {
        _activeDownloadTitle = item.title;
        _itemsToDownload[i] = item.copyWith(downloadStatus: HubDownloadStatus.downloading);
      });

      // Simulate download chunks
      for (double p = 0.2; p <= 1.0; p += 0.3) {
        await Future.delayed(const Duration(milliseconds: 180));
        if (!mounted) return;
        setState(() {
          _itemsToDownload[i] = item.copyWith(
            downloadStatus: HubDownloadStatus.downloading,
            downloadProgress: p,
          );
          _overallProgress = ((i + p) / _itemsToDownload.length).clamp(0.0, 1.0);
        });
      }

      setState(() {
        _itemsToDownload[i] = item.copyWith(
          downloadStatus: HubDownloadStatus.downloaded,
          downloadProgress: 1.0,
        );
        _completedDownloads++;
      });
    }

    // Persist downloaded materials to local device storage
    await SavedMaterialsService.instance.saveMaterials(_itemsToDownload);

    if (!mounted) return;
    setState(() {
      _currentStep = _SyncStep.done;
      _overallProgress = 1.0;
    });

    AppToast.showSuccess(
      context,
      'All materials saved offline! You can browse and study without internet.',
    );
    widget.onSyncCompleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.88,
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
              // Tab 1: QR Viewfinder
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  children: [
                    QrViewfinderWidget(
                      statusText: 'Point camera at Teacher\'s ESP32 QR',
                      onSimulatedScan: () {
                        _processHubConnection('Simulated QR: ${_manifest.qrPayload}');
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No Wi-Fi or data required! Your device will communicate directly with the classroom ESP32 station.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<List<HubMaterialItem>>(
                      valueListenable: SavedMaterialsService.instance.savedMaterialsNotifier,
                      builder: (context, savedList, _) {
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
                      'Connect your phone to the ESP32 Wi-Fi hotspot in your phone settings, then tap Connect below:',
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
                          _processHubConnection('Manual: ${_ipController.text}');
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
              'Handshaking with ${_manifest.hubName} at ${_ipController.text} via local Wi-Fi SoftAP',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManifestView() {
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
                        _manifest.hubName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.text,
                        ),
                      ),
                      Text(
                        'Section: ${_manifest.sectionName} • Instructor: ${_manifest.teacherName}',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Text(
            'Available Classroom Materials (${_itemsToDownload.length})',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 8),

          ..._itemsToDownload.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Container(
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
                      size: 20,
                      color: item.fileType == HubFileType.pdf
                          ? AppTheme.error
                          : item.fileType == HubFileType.quiz
                              ? AppTheme.warning
                              : AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.text,
                          ),
                        ),
                        Text(
                          '${item.subjectName} • ${item.formattedSize}',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Ready to Sync',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 20),

          // Download CTA
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _startOfflineDownload,
              icon: const Icon(Icons.download, size: 20),
              label: const Text(
                'Download & Save All Offline',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
            'All ${_itemsToDownload.length} materials from your teacher have been safely stored on your device. You can browse, read PDFs, and take quizzes offline anytime.',
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
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Close'),
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
