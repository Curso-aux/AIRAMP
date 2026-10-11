/// Status of the physical ESP32 device and attached peripherals
class Esp32HubStatus {
  final String boardModel;
  final bool isDevKitConnected;
  final bool isSdCardDetected;
  final String sdCardStatusText;
  final String ipAddress;
  final String ssid;
  final String password;
  final int totalStorageBytes;
  final int usedStorageBytes;

  const Esp32HubStatus({
    this.boardModel = 'ESP32 DevKit V1 (30-pin / 38-pin)',
    this.isDevKitConnected = true,
    this.isSdCardDetected = false,
    this.sdCardStatusText = 'Module Pending (Awaiting delivery)',
    this.ipAddress = '192.168.4.1',
    this.ssid = 'AIRAMP-HUB-01',
    this.password = 'aira1234',
    this.totalStorageBytes = 4194304, // 4MB internal SPI flash fallback
    this.usedStorageBytes = 1048576,
  });

  String get formattedTotalStorage {
    if (isSdCardDetected) {
      return '${(totalStorageBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB (MicroSD)';
    }
    return '${(totalStorageBytes / (1024 * 1024)).toStringAsFixed(0)} MB (DevKit Flash)';
  }
}

enum HubFileType { pdf, quiz, module, doc }

enum HubDownloadStatus { notDownloaded, downloading, downloaded }

/// Represents an educational material item stored on or targeted for the ESP32
class HubMaterialItem {
  final String id;
  final String title;
  final String subjectName;
  final HubFileType fileType;
  final int sizeBytes;
  final String? localPath;
  final HubDownloadStatus downloadStatus;
  final double downloadProgress;

  const HubMaterialItem({
    required this.id,
    required this.title,
    required this.subjectName,
    required this.fileType,
    required this.sizeBytes,
    this.localPath,
    this.downloadStatus = HubDownloadStatus.notDownloaded,
    this.downloadProgress = 0.0,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  HubMaterialItem copyWith({
    HubDownloadStatus? downloadStatus,
    double? downloadProgress,
    String? localPath,
  }) {
    return HubMaterialItem(
      id: id,
      title: title,
      subjectName: subjectName,
      fileType: fileType,
      sizeBytes: sizeBytes,
      localPath: localPath ?? this.localPath,
      downloadStatus: downloadStatus ?? this.downloadStatus,
      downloadProgress: downloadProgress ?? this.downloadProgress,
    );
  }
}

/// Manifest structure transmitted between ESP32 and AIRAMP clients
class HubSyncManifest {
  final String hubId;
  final String hubName;
  final String teacherName;
  final String sectionName;
  final String generatedAt;
  final List<HubMaterialItem> items;
  final String qrPayload;

  const HubSyncManifest({
    required this.hubId,
    required this.hubName,
    required this.teacherName,
    required this.sectionName,
    required this.generatedAt,
    required this.items,
    required this.qrPayload,
  });

  /// Default mock manifest representing materials uploaded by the teacher
  factory HubSyncManifest.sample({
    String teacherName = 'Faculty Instructor',
    String sectionName = 'Grade 10 - Rizal',
  }) {
    return HubSyncManifest(
      hubId: 'AIRAMP-HUB-DEVKIT-01',
      hubName: 'AIRA Classroom Station #1',
      teacherName: teacherName,
      sectionName: sectionName,
      generatedAt: DateTime.now().toIso8601String(),
      qrPayload: 'WIFI:S:AIRAMP-HUB-01;T:WPA;P:aira1234;;AIRAMP:SEC=$sectionName;IP=192.168.4.1',
      items: const [
        HubMaterialItem(
          id: 'mat_01',
          title: 'Module 1: Cellular Biology & Mitosis',
          subjectName: 'General Science',
          fileType: HubFileType.pdf,
          sizeBytes: 1450000,
        ),
        HubMaterialItem(
          id: 'mat_02',
          title: 'Unit 2: Quadratic Functions & Parabolas',
          subjectName: 'Mathematics',
          fileType: HubFileType.pdf,
          sizeBytes: 980000,
        ),
        HubMaterialItem(
          id: 'mat_03',
          title: 'Quarter 1 Diagnostic Assessment (20 Items)',
          subjectName: 'General Science',
          fileType: HubFileType.quiz,
          sizeBytes: 320000,
        ),
        HubMaterialItem(
          id: 'mat_04',
          title: 'Reading Comprehension & Critical Analysis',
          subjectName: 'English',
          fileType: HubFileType.module,
          sizeBytes: 650000,
        ),
      ],
    );
  }
}
