import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/esp32_hub_models.dart';

/// Manages persistent offline storage of learning materials saved from the classroom ESP32 hub,
/// including reading, external system hand-off, and redirection/export to device internal storage.
class SavedMaterialsService {
  static final SavedMaterialsService instance = SavedMaterialsService._internal();
  SavedMaterialsService._internal();

  static const String _storageKey = 'airamp_saved_esp32_materials_v1';
  final ValueNotifier<List<HubMaterialItem>> savedMaterialsNotifier = ValueNotifier<List<HubMaterialItem>>([]);
  bool _initialized = false;

  Future<void> init({bool force = false}) async {
    if (_initialized && !force) return;
    _initialized = true;
    final list = await getSavedMaterials();
    savedMaterialsNotifier.value = list;
  }

  /// Retrieves all offline saved learning materials, seeding with default classroom materials if none exist.
  Future<List<HubMaterialItem>> getSavedMaterials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        final items = decoded
            .map((item) => HubMaterialItem.fromJson(item as Map<String, dynamic>))
            .toList();
        if (items.isNotEmpty) {
          savedMaterialsNotifier.value = items;
          return items;
        }
      }
    } catch (e) {
      debugPrint('[SavedMaterialsService] Error loading saved materials: $e');
    }

    // Return empty list if nothing saved yet (no fake data)
    final initialList = <HubMaterialItem>[];
    savedMaterialsNotifier.value = initialList;
    return initialList;
  }

  /// Saves a batch of downloaded materials into offline persistent storage.
  Future<void> saveMaterials(List<HubMaterialItem> newItems) async {
    try {
      final existing = await getSavedMaterials();
      final map = {for (var item in existing) item.id: item};

      for (var item in newItems) {
        map[item.id] = item.copyWith(
          downloadStatus: HubDownloadStatus.downloaded,
          downloadProgress: 1.0,
          savedAt: 'Synced ${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}',
        );
      }

      final merged = map.values.toList();
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(merged.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, encoded);

      savedMaterialsNotifier.value = merged;
    } catch (e) {
      debugPrint('[SavedMaterialsService] Error saving materials: $e');
    }
  }

  /// Opens the material with the device's default reader app (PDF viewer, Word, text reader, browser).
  Future<OpenResult> openMaterial(HubMaterialItem item) async {
    try {
      String? targetPath = item.localPath;

      if (!kIsWeb && targetPath != null) {
        final file = File(targetPath);
        if (await file.exists()) {
          return await OpenFilex.open(targetPath);
        }
      }

      // If localPath doesn't exist on disk but we have in-memory content, write it to a temp file
      if (!kIsWeb && item.content != null && item.content!.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final ext = _extensionFor(item.fileType);
        final tempFileName = item.fileName ?? '${item.id}.$ext';
        final tempFile = File('${tempDir.path}/$tempFileName');
        await tempFile.writeAsString(item.content!);
        return await OpenFilex.open(tempFile.path);
      }

      return OpenResult(
        type: ResultType.fileNotFound,
        message: 'Material file not found in device cache.',
      );
    } catch (e) {
      debugPrint('[SavedMaterialsService] Error opening material: $e');
      return OpenResult(
        type: ResultType.error,
        message: e.toString(),
      );
    }
  }

  /// Exports the material from the private app sandbox into the device's public storage.
  /// Uses the native system Storage Access Framework / file picker so the student can
  /// select their desired destination folder (e.g. Downloads, Documents, SD card).
  Future<String?> exportToInternalStorage(HubMaterialItem item) async {
    try {
      final fileName = item.fileName ?? '${item.id}.${_extensionFor(item.fileType)}';
      Uint8List? bytes;

      if (!kIsWeb && item.localPath != null) {
        final file = File(item.localPath!);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        }
      }

      if (bytes == null && item.content != null && item.content!.isNotEmpty) {
        bytes = Uint8List.fromList(utf8.encode(item.content!));
      }

      if (bytes == null || bytes.isEmpty) {
        // Fallback placeholder content so the user still gets a readable export of the material
        final placeholder = '# ${item.title}\nSubject: ${item.subjectName}\n\n${item.description ?? 'Curriculum material provided by your teacher.'}';
        bytes = Uint8List.fromList(utf8.encode(placeholder));
      }

      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'Save "${item.title}" to Device Storage',
        fileName: fileName,
        bytes: bytes,
      );

      if (savedUri != null) {
        if (savedUri.isScheme('file')) {
          return savedUri.toFilePath();
        }
        return savedUri.toString();
      }

      return null;
    } catch (e) {
      debugPrint('[SavedMaterialsService] Error exporting material via file picker: $e');
      return null;
    }
  }

  /// Automatically copies the material to the device's public Downloads directory under /AIRAMP/
  /// without requiring manual folder selection.
  Future<String?> exportDirectlyToDownloads(HubMaterialItem item, {Directory? targetDirectory}) async {
    try {
      if (kIsWeb) return null;

      final fileName = item.fileName ?? '${item.id}.${_extensionFor(item.fileType)}';
      Uint8List? bytes;

      if (item.localPath != null) {
        final file = File(item.localPath!);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        }
      }

      if (bytes == null && item.content != null && item.content!.isNotEmpty) {
        bytes = Uint8List.fromList(utf8.encode(item.content!));
      }

      if (bytes == null || bytes.isEmpty) {
        final placeholder = '# ${item.title}\nSubject: ${item.subjectName}\n\n${item.description ?? 'Curriculum material provided by your teacher.'}';
        bytes = Uint8List.fromList(utf8.encode(placeholder));
      }

      Directory? targetDir = targetDirectory;
      if (targetDir == null) {
        try {
          targetDir = await getDownloadsDirectory();
        } catch (_) {}

        if (targetDir == null && Platform.isAndroid) {
          targetDir = Directory('/storage/emulated/0/Download');
        }

        if (targetDir == null || !await targetDir.exists()) {
          try {
            targetDir = await getApplicationDocumentsDirectory();
          } catch (_) {
            targetDir = Directory.systemTemp;
          }
        }
      }

      final airampFolder = Directory('${targetDir.path}/AIRAMP');
      if (!await airampFolder.exists()) {
        await airampFolder.create(recursive: true);
      }

      final targetFile = File('${airampFolder.path}/$fileName');
      await targetFile.writeAsBytes(bytes);
      return targetFile.path;
    } catch (e) {
      debugPrint('[SavedMaterialsService] Error exporting to downloads directory: $e');
      return null;
    }
  }

  /// Removes a single material item from offline cache and cleans up its physical file on disk.
  Future<void> removeMaterial(String id) async {
    try {
      final current = await getSavedMaterials();
      final target = current.where((item) => item.id == id).firstOrNull;

      // Delete physical file from sandbox storage to prevent storage leaks
      if (target?.localPath != null && !kIsWeb) {
        try {
          final file = File(target!.localPath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('[SavedMaterialsService] Error deleting physical file: $e');
        }
      }

      final updated = current.where((item) => item.id != id).toList();
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(updated.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, encoded);

      savedMaterialsNotifier.value = updated;
    } catch (e) {
      debugPrint('[SavedMaterialsService] Error removing material: $e');
    }
  }

  /// Clears all offline materials from the device and cleans up cached files.
  Future<void> clearAll() async {
    try {
      final current = await getSavedMaterials();
      if (!kIsWeb) {
        for (final item in current) {
          if (item.localPath != null) {
            try {
              final file = File(item.localPath!);
              if (await file.exists()) {
                await file.delete();
              }
            } catch (_) {}
          }
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      savedMaterialsNotifier.value = [];
    } catch (e) {
      debugPrint('[SavedMaterialsService] Error clearing materials: $e');
    }
  }

  /// Returns total cached file size formatted in MB.
  String getFormattedStorageUsed(List<HubMaterialItem> items) {
    final totalBytes = items.fold<int>(0, (sum, item) => sum + item.sizeBytes);
    if (totalBytes < 1024) return '$totalBytes B';
    if (totalBytes < 1024 * 1024) return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _extensionFor(HubFileType type) {
    switch (type) {
      case HubFileType.quiz:
        return 'json';
      case HubFileType.pdf:
        return 'pdf';
      case HubFileType.doc:
        return 'docx';
      case HubFileType.module:
        return 'pdf';
    }
  }
}
