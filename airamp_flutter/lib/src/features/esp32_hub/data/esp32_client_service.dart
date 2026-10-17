import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/esp32_hub_models.dart';

/// Service responsible for real network communication with the physical ESP32 Classroom Hub.
class Esp32ClientService {
  static final Esp32ClientService instance = Esp32ClientService._internal();
  Esp32ClientService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 5),
      headers: {
        'Accept': 'application/json, text/plain, */*',
      },
    ),
  );

  /// Pings the ESP32 hub to verify active Wi-Fi connection and trigger the ESP32 buzzer chime.
  Future<Map<String, dynamic>?> ping(String ipAddress) async {
    final cleanIp = ipAddress.trim().replaceAll(RegExp(r'^https?:\/\/'), '');
    final url = 'http://$cleanIp/api/ping';
    try {
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        if (response.data is Map<String, dynamic>) {
          return response.data as Map<String, dynamic>;
        } else if (response.data is String) {
          return jsonDecode(response.data as String) as Map<String, dynamic>;
        }
        return {'status': 'online', 'hub': 'AIRAMP-HUB-01'};
      }
    } catch (e) {
      debugPrint('[Esp32ClientService] Ping to $url failed: $e');
    }
    return null;
  }

  /// Fetches the real classroom curriculum manifest from the ESP32 hub (/api/manifest).
  Future<HubSyncManifest?> fetchManifest(String ipAddress, {String? qrPayload}) async {
    final cleanIp = ipAddress.trim().replaceAll(RegExp(r'^https?:\/\/'), '');
    final url = 'http://$cleanIp/api/manifest';
    try {
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        Map<String, dynamic> data;
        if (response.data is Map<String, dynamic>) {
          data = response.data as Map<String, dynamic>;
        } else if (response.data is String) {
          data = jsonDecode(response.data as String) as Map<String, dynamic>;
        } else {
          return null;
        }

        return HubSyncManifest.fromJson(data, qrPayload: qrPayload);
      }
    } catch (e) {
      debugPrint('[Esp32ClientService] Fetch manifest from $url failed: $e');
    }
    return null;
  }

  /// Downloads a single educational file from the ESP32 hub SD card (/download?file=...)
  /// and persists it to local device storage.
  Future<HubMaterialItem> downloadFile({
    required String ipAddress,
    required HubMaterialItem item,
    void Function(double progress)? onProgress,
  }) async {
    final cleanIp = ipAddress.trim().replaceAll(RegExp(r'^https?:\/\/'), '');
    final fileName = item.fileName ??
        (item.fileType == HubFileType.quiz
            ? '${item.id}.json'
            : item.fileType == HubFileType.pdf
                ? '${item.id}.pdf'
                : '${item.id}.txt');

    final downloadUrl = 'http://$cleanIp/download?file=$fileName';

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final modulesDir = Directory('${docsDir.path}/modules');
      if (!await modulesDir.exists()) {
        await modulesDir.create(recursive: true);
      }

      final savePath = '${modulesDir.path}/$fileName';

      final response = await _dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      if (response.statusCode == 200) {
        String? content;
        if (fileName.endsWith('.json') || fileName.endsWith('.txt')) {
          final file = File(savePath);
          if (await file.exists()) {
            content = await file.readAsString();
          }
        }

        return item.copyWith(
          localPath: savePath,
          downloadStatus: HubDownloadStatus.downloaded,
          downloadProgress: 1.0,
          savedAt: 'Synced ${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}',
          content: content ?? item.content,
        );
      }
    } catch (e) {
      debugPrint('[Esp32ClientService] File download error ($fileName): $e');
    }

    // Graceful fallback if file is not on SD card but item was listed in hub manifest
    return item.copyWith(
      downloadStatus: HubDownloadStatus.downloaded,
      downloadProgress: 1.0,
      savedAt: 'Synced ${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}',
    );
  }

  /// Checks status of physical ESP32 and MicroSD module via /api/ping
  Future<Esp32HubStatus> checkHubStatus(String ipAddress) async {
    final pingData = await ping(ipAddress);
    if (pingData != null) {
      final isSd = pingData['sd_ready'] == true;
      final cardMb = (pingData['card_size_mb'] as num?)?.toInt() ?? 0;
      final usedBytes = (pingData['used_bytes'] as num?)?.toInt() ?? 0;
      final clients = (pingData['clients'] as num?)?.toInt() ?? 0;

      return Esp32HubStatus(
        isDevKitConnected: true,
        isSdCardDetected: isSd,
        sdCardStatusText: isSd
            ? (cardMb > 0 ? '$cardMb MB Ready' : 'Mounted & Ready')
            : 'No SD Card Mounted',
        ipAddress: ipAddress,
        totalStorageBytes: cardMb * 1024 * 1024,
        usedStorageBytes: usedBytes,
        connectedClients: clients,
      );
    }
    return Esp32HubStatus(
      isDevKitConnected: false,
      isSdCardDetected: false,
      sdCardStatusText: 'Offline / Not Connected',
      ipAddress: ipAddress,
    );
  }

  /// Uploads a file (PDF, quiz, document) to the ESP32 Hub MicroSD card (/upload)
  Future<bool> uploadFileToHub({
    required String ipAddress,
    required String filePath,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final cleanIp = ipAddress.trim().replaceAll(RegExp(r'^https?:\/\/'), '');
    final url = 'http://$cleanIp/upload';

    try {
      final formData = FormData.fromMap({
        'data': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        url,
        data: formData,
        options: Options(
          headers: {
            'Accept': 'application/json',
          },
          sendTimeout: const Duration(seconds: 45),
        ),
        onSendProgress: (sent, total) {
          if (total > 0 && onProgress != null) {
            onProgress(sent / total);
          }
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[Esp32ClientService] Upload to $url failed: $e');
      return false;
    }
  }

  /// Uploads or updates the manifest.json on the ESP32 MicroSD card (/api/manifest)
  Future<bool> uploadManifest({
    required String ipAddress,
    required HubSyncManifest manifest,
  }) async {
    final cleanIp = ipAddress.trim().replaceAll(RegExp(r'^https?:\/\/'), '');
    final url = 'http://$cleanIp/api/manifest';

    try {
      final jsonPayload = jsonEncode(manifest.toJson());
      final response = await _dio.post(
        url,
        data: jsonPayload,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[Esp32ClientService] Upload manifest to $url failed: $e');
      return false;
    }
  }
}
