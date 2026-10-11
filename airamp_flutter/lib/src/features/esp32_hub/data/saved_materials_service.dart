import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/esp32_hub_models.dart';

/// Manages persistent offline storage of learning materials saved from the classroom ESP32 hub.
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

    // Default seeded materials from the classroom hub manifest
    final initialList = List<HubMaterialItem>.from(HubSyncManifest.sample().items);
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

  /// Removes a single material item from offline cache.
  Future<void> removeMaterial(String id) async {
    try {
      final current = await getSavedMaterials();
      final updated = current.where((item) => item.id != id).toList();
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(updated.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, encoded);

      savedMaterialsNotifier.value = updated;
    } catch (e) {
      debugPrint('[SavedMaterialsService] Error removing material: $e');
    }
  }

  /// Clears all offline materials from the device.
  Future<void> clearAll() async {
    try {
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
}
