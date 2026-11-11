import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/firestore_service.dart';

class GoogleDriveUploadResult {
  final bool success;
  final String? fileId;
  final String? viewUrl;
  final String? downloadUrl;
  final String? fileName;
  final String? folderName;
  final String? errorMessage;

  const GoogleDriveUploadResult({
    required this.success,
    this.fileId,
    this.viewUrl,
    this.downloadUrl,
    this.fileName,
    this.folderName,
    this.errorMessage,
  });
}

/// Production-ready Google Drive Routing Service for AIRAMP.
/// Automatically routes student assignment files directly into
/// a teacher's Google Drive folder without requiring student Google accounts.
class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  static GoogleDriveService get instance => _instance;

  static const String _prefKeyBridgeUrl = 'aira_gdrive_bridge_url';
  static const String _envBridgeUrl = String.fromEnvironment('GDRIVE_BRIDGE_URL');
  static const String defaultBridgeUrl =
      'https://script.google.com/macros/s/AKfycbzkTRg-EENR5qyt1MQYiFY1789w-qii3aHpoXXkY34cjTNPalFnaqVzEUg63ZdwNr8a/exec';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(seconds: 45),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );

  /// Retrieves the active Google Apps Script Web App URL.
  /// Checks environment variable -> local cache -> Cloud Firestore system configuration.
  Future<String?> getBridgeUrl() async {
    // 1. Environment variable override
    if (_envBridgeUrl.isNotEmpty) return _envBridgeUrl;

    // 2. Local SharedPreferences cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final localUrl = prefs.getString(_prefKeyBridgeUrl);
      if (localUrl != null && localUrl.trim().isNotEmpty) {
        return localUrl.trim();
      }
    } catch (_) {}

    // 3. Cloud Firestore central configuration
    try {
      final doc = await FirestoreService().getDocument('system_config', 'gdrive_bridge');
      if (doc != null && doc['bridge_url'] != null) {
        final url = doc['bridge_url'].toString().trim();
        if (url.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefKeyBridgeUrl, url);
          return url;
        }
      }
    } catch (_) {}

    // 4. Default built-in verified production bridge URL
    return defaultBridgeUrl;
  }

  /// Sets or updates the custom bridge URL across both local cache and Cloud Firestore.
  Future<void> setBridgeUrl(String url) async {
    final cleanUrl = url.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyBridgeUrl, cleanUrl);

      // Persist to Cloud Firestore so all students and faculty inherit it immediately
      await FirestoreService().saveDocument('system_config', 'gdrive_bridge', {
        'bridge_url': cleanUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[GoogleDriveService] Error saving bridge URL: $e');
    }
  }

  /// Extracts the clean Google Drive folder ID from a variety of link formats.
  static String? extractFolderId(String? input) {
    if (input == null) return null;
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // Direct folder ID with no slashes
    if (!trimmed.contains('/') && trimmed.length >= 15) {
      return trimmed;
    }

    // Pattern 1: /folders/([a-zA-Z0-9_-]+)
    final folderPattern = RegExp(r'/folders/([a-zA-Z0-9_-]+)');
    final match = folderPattern.firstMatch(trimmed);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }

    // Pattern 2: id=([a-zA-Z0-9_-]+)
    final idPattern = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)');
    final idMatch = idPattern.firstMatch(trimmed);
    if (idMatch != null && idMatch.groupCount >= 1) {
      return idMatch.group(1);
    }

    return trimmed;
  }

  /// Determines if a given string contains a Google Drive folder link or ID.
  static bool isGoogleDriveFolder(String? input) {
    if (input == null || input.trim().isEmpty) return false;
    final trimmed = input.trim();
    return (trimmed.contains('drive.google.com') && trimmed.contains('folder')) ||
           trimmed.contains('drive.google.com/drive/folders');
  }

  /// Uploads a student file directly to the teacher's Google Drive folder.
  Future<GoogleDriveUploadResult> uploadToTeacherDriveFolder({
    required String folderUrlOrId,
    required String fileName,
    required Uint8List bytes,
    required String studentName,
    required String studentId,
    String? section,
    String? mimeType,
    void Function(double progress)? onProgress,
  }) async {
    final bridgeUrl = await getBridgeUrl();
    if (bridgeUrl == null || bridgeUrl.isEmpty) {
      return const GoogleDriveUploadResult(
        success: false,
        errorMessage: 'Google Drive submission bridge is not configured. Please contact administrator.',
      );
    }

    try {
      final cleanFolderId = extractFolderId(folderUrlOrId);
      final base64Content = base64Encode(bytes);
      final detectedMime = mimeType ?? _detectMimeType(fileName);

      final payload = {
        'folderId': cleanFolderId,
        'fileName': fileName,
        'mimeType': detectedMime,
        'bytes': base64Content,
        'studentName': studentName,
        'studentId': studentId,
        'section': section ?? '',
      };

      if (onProgress != null) onProgress(0.2);

      Response response = await _dio.post(
        bridgeUrl,
        data: jsonEncode(payload),
        options: Options(
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
        onSendProgress: (sent, total) {
          if (total > 0 && onProgress != null) {
            final p = 0.2 + (sent / total) * 0.7;
            onProgress(p.clamp(0.2, 0.9));
          }
        },
      );

      // Explicitly follow 302/301 redirect if header is provided
      if (response.statusCode == 302 || response.statusCode == 301) {
        final redirectUrl = response.headers.value('location');
        if (redirectUrl != null && redirectUrl.isNotEmpty) {
          response = await _dio.get(redirectUrl);
        }
      }

      if (onProgress != null) onProgress(1.0);

      final rawData = response.data;
      Map<String, dynamic> data;
      if (rawData is Map<String, dynamic>) {
        data = rawData;
      } else if (rawData is String) {
        data = jsonDecode(rawData) as Map<String, dynamic>;
      } else {
        throw 'Unexpected response format from Google Drive bridge';
      }

      if (data['status'] == 'success') {
        return GoogleDriveUploadResult(
          success: true,
          fileId: data['fileId'] as String?,
          viewUrl: data['viewUrl'] as String?,
          downloadUrl: data['downloadUrl'] as String?,
          fileName: data['fileName'] as String?,
          folderName: data['folderName'] as String?,
        );
      } else {
        return GoogleDriveUploadResult(
          success: false,
          errorMessage: data['message'] as String? ?? 'Failed to upload to Google Drive.',
        );
      }
    } catch (e) {
      debugPrint('[GoogleDriveService] Upload failed: $e');
      return GoogleDriveUploadResult(
        success: false,
        errorMessage: 'Google Drive Upload Error: $e',
      );
    }
  }

  static String _detectMimeType(String fileName) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'zip':
        return 'application/zip';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
}
