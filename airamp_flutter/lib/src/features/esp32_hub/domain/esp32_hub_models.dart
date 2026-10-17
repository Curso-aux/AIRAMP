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
  final int connectedClients;

  const Esp32HubStatus({
    this.boardModel = 'ESP32 DevKit V1 (30-pin / 38-pin)',
    this.isDevKitConnected = false,
    this.isSdCardDetected = false,
    this.sdCardStatusText = 'Checking MicroSD...',
    this.ipAddress = '192.168.4.1',
    this.ssid = 'AIRAMP-HUB-01',
    this.password = 'aira1234',
    this.totalStorageBytes = 0,
    this.usedStorageBytes = 0,
    this.connectedClients = 0,
  });

  Esp32HubStatus copyWith({
    bool? isDevKitConnected,
    bool? isSdCardDetected,
    String? sdCardStatusText,
    String? ipAddress,
    String? ssid,
    String? password,
    int? totalStorageBytes,
    int? usedStorageBytes,
    int? connectedClients,
  }) {
    return Esp32HubStatus(
      boardModel: boardModel,
      isDevKitConnected: isDevKitConnected ?? this.isDevKitConnected,
      isSdCardDetected: isSdCardDetected ?? this.isSdCardDetected,
      sdCardStatusText: sdCardStatusText ?? this.sdCardStatusText,
      ipAddress: ipAddress ?? this.ipAddress,
      ssid: ssid ?? this.ssid,
      password: password ?? this.password,
      totalStorageBytes: totalStorageBytes ?? this.totalStorageBytes,
      usedStorageBytes: usedStorageBytes ?? this.usedStorageBytes,
      connectedClients: connectedClients ?? this.connectedClients,
    );
  }

  String get formattedTotalStorage {
    if (isSdCardDetected && totalStorageBytes > 0) {
      if (totalStorageBytes >= 1024 * 1024 * 1024) {
        return '${(totalStorageBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB (MicroSD)';
      }
      return '${(totalStorageBytes / (1024 * 1024)).toStringAsFixed(0)} MB (MicroSD)';
    }
    return isSdCardDetected ? 'MicroSD Mounted' : 'No SD Card';
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
  final String? fileName;
  final String? localPath;
  final HubDownloadStatus downloadStatus;
  final double downloadProgress;
  final String? savedAt;
  final String? description;
  final String? content;

  const HubMaterialItem({
    required this.id,
    required this.title,
    required this.subjectName,
    required this.fileType,
    required this.sizeBytes,
    this.fileName,
    this.localPath,
    this.downloadStatus = HubDownloadStatus.notDownloaded,
    this.downloadProgress = 0.0,
    this.savedAt,
    this.description,
    this.content,
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
    String? fileName,
    String? localPath,
    String? savedAt,
    String? description,
    String? content,
  }) {
    return HubMaterialItem(
      id: id,
      title: title,
      subjectName: subjectName,
      fileType: fileType,
      sizeBytes: sizeBytes,
      fileName: fileName ?? this.fileName,
      localPath: localPath ?? this.localPath,
      downloadStatus: downloadStatus ?? this.downloadStatus,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      savedAt: savedAt ?? this.savedAt,
      description: description ?? this.description,
      content: content ?? this.content,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subjectName': subjectName,
    'fileType': fileType.name,
    'sizeBytes': sizeBytes,
    'fileName': fileName,
    'localPath': localPath,
    'downloadStatus': downloadStatus.name,
    'downloadProgress': downloadProgress,
    'savedAt': savedAt,
    'description': description,
    'content': content,
  };

  factory HubMaterialItem.fromJson(Map<String, dynamic> json) {
    return HubMaterialItem(
      id: json['id'] as String? ?? 'item_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? 'Classroom Material',
      subjectName: json['subjectName'] as String? ?? 'General Subject',
      fileName: json['fileName'] as String?,
      fileType: HubFileType.values.firstWhere(
        (e) => e.name == json['fileType'],
        orElse: () => json['fileType'] == 'pdf'
            ? HubFileType.pdf
            : json['fileType'] == 'quiz'
                ? HubFileType.quiz
                : HubFileType.module,
      ),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      localPath: json['localPath'] as String?,
      downloadStatus: HubDownloadStatus.values.firstWhere(
        (e) => e.name == json['downloadStatus'],
        orElse: () => HubDownloadStatus.notDownloaded,
      ),
      downloadProgress: (json['downloadProgress'] as num?)?.toDouble() ?? 0.0,
      savedAt: json['savedAt'] as String?,
      description: json['description'] as String?,
      content: json['content'] as String?,
    );
  }
}

/// Parsed data from the classroom QR code payload
class HubQrPayload {
  final String ssid;
  final String password;
  final String sectionName;
  final String ipAddress;
  final String raw;

  const HubQrPayload({
    required this.ssid,
    required this.password,
    required this.sectionName,
    required this.ipAddress,
    required this.raw,
  });

  factory HubQrPayload.parse(String raw) {
    String ssid = 'AIRAMP-HUB-01';
    String pass = 'aira1234';
    String sec = 'Grade 10';
    String ip = '192.168.4.1';

    final ssidMatch = RegExp(r'WIFI:S:([^;]+);').firstMatch(raw);
    if (ssidMatch != null && ssidMatch.group(1) != null) {
      ssid = ssidMatch.group(1)!;
    }

    final passMatch = RegExp(r'P:([^;]*);').firstMatch(raw);
    if (passMatch != null && passMatch.group(1) != null) {
      pass = passMatch.group(1)!;
    }

    final secMatch = RegExp(r'SEC=([^;]+);?').firstMatch(raw);
    if (secMatch != null && secMatch.group(1) != null) {
      sec = secMatch.group(1)!;
    }

    final ipMatch = RegExp(r'IP=([^;]+)').firstMatch(raw);
    if (ipMatch != null && ipMatch.group(1) != null) {
      ip = ipMatch.group(1)!;
    } else {
      final urlMatch = RegExp(r'https?:\/\/([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)').firstMatch(raw);
      if (urlMatch != null && urlMatch.group(1) != null) {
        ip = urlMatch.group(1)!;
      } else {
        final rawIpMatch = RegExp(r'\b([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\b').firstMatch(raw);
        if (rawIpMatch != null && rawIpMatch.group(1) != null) {
          ip = rawIpMatch.group(1)!;
        }
      }
    }

    return HubQrPayload(
      ssid: ssid,
      password: pass,
      sectionName: sec,
      ipAddress: ip,
      raw: raw,
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

  factory HubSyncManifest.fromJson(Map<String, dynamic> json, {String? qrPayload}) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return HubSyncManifest(
      hubId: json['hubId'] as String? ?? 'AIRAMP-HUB-01',
      hubName: json['hubName'] as String? ?? 'AIRA Classroom Station',
      teacherName: json['teacherName'] as String? ?? 'Faculty Instructor',
      sectionName: json['sectionName'] as String? ?? 'General Section',
      generatedAt: json['generatedAt'] as String? ?? DateTime.now().toIso8601String(),
      qrPayload: qrPayload ?? '',
      items: rawItems
          .map((item) => HubMaterialItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  HubSyncManifest copyWith({
    String? hubId,
    String? hubName,
    String? teacherName,
    String? sectionName,
    String? generatedAt,
    List<HubMaterialItem>? items,
    String? qrPayload,
  }) {
    return HubSyncManifest(
      hubId: hubId ?? this.hubId,
      hubName: hubName ?? this.hubName,
      teacherName: teacherName ?? this.teacherName,
      sectionName: sectionName ?? this.sectionName,
      generatedAt: generatedAt ?? this.generatedAt,
      items: items ?? this.items,
      qrPayload: qrPayload ?? this.qrPayload,
    );
  }

  Map<String, dynamic> toJson() => {
    'hubId': hubId,
    'hubName': hubName,
    'teacherName': teacherName,
    'sectionName': sectionName,
    'generatedAt': generatedAt,
    'items': items.map((e) => e.toJson()).toList(),
  };

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
          fileType: HubFileType.module,
          sizeBytes: 1450000,
          savedAt: 'Synced via Classroom Station',
          description: 'Detailed study guide covering the stages of mitosis (Prophase, Metaphase, Anaphase, Telophase) and cellular reproduction in living organisms.',
          content: '## Overview\nCell division is the biological process by which a parent cell divides into two or more daughter cells. In eukaryotic cells, mitosis is the nuclear division cycle.\n\n### Phases of Mitosis:\n1. **Prophase**: Chromatin condenses into visible chromosomes. The nucleolus disappears and the mitotic spindle begins forming.\n2. **Metaphase**: Chromosomes line up along the equatorial metaphase plate attached to spindle fibers.\n3. **Anaphase**: Sister chromatids are pulled apart to opposite poles of the dividing cell.\n4. **Telophase & Cytokinesis**: Nuclear envelope reforms around daughter nuclei, and the cytoplasm divides into two identical diploid cells.\n\n### Key Takeaways:\n- Mitosis results in genetically identical daughter cells.\n- Crucial for tissue repair, biological growth, and organism maintenance.',
        ),
        HubMaterialItem(
          id: 'mat_02',
          title: 'Unit 2: Quadratic Functions & Parabolas',
          subjectName: 'Mathematics',
          fileType: HubFileType.pdf,
          sizeBytes: 980000,
          savedAt: 'Synced via Classroom Station',
          description: 'Standard quadratic form y = ax² + bx + c, vertex formula, axis of symmetry, discriminant rules, and projectile trajectory modeling.',
          content: '## Quadratic Functions\nA quadratic function is a polynomial function of degree 2:\nf(x) = ax² + bx + c\nwhere a, b, and c are real numbers and a ≠ 0.\n\n### Vertex Formula:\nThe vertex coordinates (h, k) are given by:\n- h = -b / (2a)\n- k = f(h)\n\n### Discriminant Analysis:\n- If b² - 4ac > 0: Two distinct real roots.\n- If b² - 4ac = 0: Exactly one real root (tangent to x-axis).\n- If b² - 4ac < 0: No real roots (complex roots).\n\n### Real-World Applications:\n- Basketball projectile paths\n- Architectural arches and suspension bridge cables\n- Satellite dish focal optimization',
        ),
        HubMaterialItem(
          id: 'mat_03',
          title: 'Quarter 1 Diagnostic Assessment (5 Items)',
          subjectName: 'General Science',
          fileType: HubFileType.quiz,
          sizeBytes: 320000,
          savedAt: 'Synced via Classroom Station',
          description: 'Interactive offline diagnostic practice test with immediate on-device scoring and answer explanations.',
          content: 'Q1: In which phase of mitosis do chromosomes align in the center of the cell?\nA) Anaphase\nB) Metaphase\nC) Telophase\nD) Prophase\nAnswer: B\nExplanation: During metaphase, spindle fibers pull chromosomes to the equatorial plane of the cell.\n\nQ2: What is the powerhouse of the cell responsible for ATP production?\nA) Nucleus\nB) Ribosome\nC) Mitochondria\nD) Endoplasmic Reticulum\nAnswer: C\nExplanation: Mitochondria generate most of the chemical energy needed by the cell.\n\nQ3: What molecule carries genetic instructions in living organisms?\nA) RNA\nB) Hemoglobin\nC) DNA\nD) Glucose\nAnswer: C\nExplanation: Deoxyribonucleic acid (DNA) contains the hereditary genetic code.\n\nQ4: During which stage do sister chromatids separate?\nA) Anaphase\nB) Metaphase\nC) Prophase\nD) Interphase\nAnswer: A\nExplanation: In anaphase, centromeres split and sister chromatids are pulled to opposite spindle poles.\n\nQ5: Which cellular division process produces sex cells (gametes)?\nA) Mitosis\nB) Binary Fission\nC) Meiosis\nD) Budding\nAnswer: C\nExplanation: Meiosis reduces the chromosome count by half to yield haploid gametes.',
        ),
        HubMaterialItem(
          id: 'mat_04',
          title: 'Reading Comprehension & Critical Analysis',
          subjectName: 'English',
          fileType: HubFileType.doc,
          sizeBytes: 650000,
          savedAt: 'Synced via Classroom Station',
          description: 'Guided textual analysis, thesis identification, context clues, tone recognition, and argumentative synthesis exercises.',
          content: '## Critical Analysis in Modern Reading\nCritical reading means evaluating an author\'s argument, assessing rhetorical devices, and verifying textual evidence rather than passively absorbing text.\n\n### Four Pillars of Reading Comprehension:\n1. **Identifying the Thesis**: Pinpoint the author\'s primary claim or central insight early in the text.\n2. **Using Context Clues**: Infer definitions of unfamiliar vocabulary using surrounding sentence structures and contrast clues.\n3. **Tone & Perspective**: Discern whether the narrative voice is objective, satirical, persuasive, or informational.\n4. **Synthesizing Evidence**: Connect key facts from the passage to support valid independent conclusions.',
        ),
      ],
    );
  }
}
