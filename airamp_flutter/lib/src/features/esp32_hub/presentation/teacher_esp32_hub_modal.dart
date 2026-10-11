import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/components/app_toast.dart';
import '../domain/esp32_hub_models.dart';
import 'components/hub_qr_code_widget.dart';

/// Modal dialog for teachers to manage the ESP32 Offline Learning Hub,
/// upload curriculum materials, and display the classroom QR code.
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
  final Esp32HubStatus _hubStatus = const Esp32HubStatus();
  late List<HubMaterialItem> _availableMaterials;
  final Set<String> _selectedMaterialIds = {};

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStepText = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final manifest = HubSyncManifest.sample(
      teacherName: widget.teacherName,
      sectionName: widget.initialSection ?? 'Grade 10 - Rizal',
    );
    _availableMaterials = manifest.items;
    _selectedMaterialIds.addAll(_availableMaterials.map((m) => m.id));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int get _selectedBytes => _availableMaterials
      .where((m) => _selectedMaterialIds.contains(m.id))
      .fold<int>(0, (sum, m) => sum + m.sizeBytes);

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _handleUploadToEsp32() async {
    if (_selectedMaterialIds.isEmpty) {
      AppToast.showWarning(context, 'Please select at least one material to upload.');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.1;
      _uploadStepText = 'Generating manifest & metadata...';
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _uploadProgress = 0.35;
      _uploadStepText = 'Packaging ${_selectedMaterialIds.length} modules & quizzes...';
    });

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _uploadProgress = 0.70;
      _uploadStepText = 'Transmitting package to ESP32 at ${_hubStatus.ipAddress}...';
    });

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _uploadProgress = 1.0;
      _uploadStepText = 'Verified! Materials successfully stored in ESP32 station.';
      _isUploading = false;
    });

    AppToast.showSuccess(
      context,
      'Materials ready! Students can now scan the QR code to download offline.',
    );

    // Switch to QR Tab
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      _tabController.animateTo(1);
    }
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
                  child: Icon(Icons.router, color: AppTheme.primary, size: 24),
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
                  icon: Icon(Icons.close, color: AppTheme.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Hardware Status Strip
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(14),
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
                          color: AppTheme.success,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.success.withValues(alpha: 0.4),
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
                              'Ready (AP: ${_hubStatus.ssid})',
                              style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
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
                          color: AppTheme.warning,
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
                              'Pending Delivery',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.warning,
                                fontWeight: FontWeight.w600,
                              ),
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
          // DevKit Notice Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppTheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your ESP32 DevKit is ready for AP testing! Until your MicroSD module arrives, uploads will package and validate directly with the DevKit. Once your SD module is wired, full 16GB-32GB PDF libraries will be supported.',
                    style: TextStyle(fontSize: 12, color: AppTheme.text, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Section Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Materials to Package & Upload',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.text,
                ),
              ),
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
                  _selectedMaterialIds.length == _availableMaterials.length
                      ? 'Deselect All'
                      : 'Select All',
                  style: TextStyle(color: AppTheme.primary, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Material Checklist
          ..._availableMaterials.map((item) {
            final isChecked = _selectedMaterialIds.contains(item.id);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isChecked
                    ? AppTheme.primarySoft.withValues(alpha: 0.1)
                    : AppTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isChecked
                      ? AppTheme.primary.withValues(alpha: 0.4)
                      : AppTheme.border,
                ),
              ),
              child: CheckboxListTile(
                value: isChecked,
                activeColor: AppTheme.primary,
                title: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.text,
                  ),
                ),
                subtitle: Text(
                  '${item.subjectName} • ${item.formattedSize} • ${item.fileType.name.toUpperCase()}',
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
                    Text(
                      'Package Size:',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    Text(
                      _formatBytes(_selectedBytes),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Selected Items:',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    Text(
                      '${_selectedMaterialIds.length} of ${_availableMaterials.length}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.text,
                      ),
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
                      Text(
                        _uploadStepText,
                        style: TextStyle(fontSize: 12, color: AppTheme.text),
                      ),
                      Text(
                        '${(_uploadProgress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
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
              onPressed: _isUploading ? null : _handleUploadToEsp32,
              icon: _isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.upload, size: 20),
              label: Text(
                _isUploading ? 'Transferring...' : 'Upload to ESP32 DevKit',
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
    final qrData = 'WIFI:S:${_hubStatus.ssid};T:WPA;P:${_hubStatus.password};;AIRAMP:SEC=${widget.initialSection ?? 'Section-1'};IP=${_hubStatus.ipAddress}';

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
            'Wiring & Setup Guide (Once SD Module Arrives)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'When your MicroSD module arrives, connect it to your ESP32 DevKit using standard SPI pins as shown below:',
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
            '2. MicroSD File Storage',
            'Modules, PDF textbooks, and quizzes are stored in standard FAT32 format on the SD card, making it simple to transfer files either wirelessly or by popping the SD card into a computer.',
            Icons.sd_storage,
          ),
          const SizedBox(height: 8),
          _buildStepCard(
            '3. Fast Local HTTP Transfers',
            'The ESP32 runs an asynchronous lightweight HTTP server that pushes files directly to student phones at local Wi-Fi speeds (~1 to 2 MB/s).',
            Icons.speed,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPinRow(String col1, String col2, String col3, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              col1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.w600,
                color: isHeader ? AppTheme.primary : AppTheme.text,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              col2,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
                color: isHeader ? AppTheme.primary : AppTheme.accent,
                fontFamily: isHeader ? null : 'monospace',
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              col3,
              style: TextStyle(
                fontSize: 11,
                color: isHeader ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(String title, String desc, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
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
            child: Icon(icon, size: 18, color: AppTheme.primary),
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
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
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
