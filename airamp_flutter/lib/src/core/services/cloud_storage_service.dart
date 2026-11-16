import 'dart:async';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'cloudflare_r2_service.dart';

class CloudStorageUploadResult {
  final bool success;
  final String? downloadUrl;
  final String? storagePath;
  final String? errorMessage;

  const CloudStorageUploadResult({
    required this.success,
    this.downloadUrl,
    this.storagePath,
    this.errorMessage,
  });
}

/// Production-ready Cloud Storage Service for AIRAMP.
/// Implements a hybrid architecture:
/// - Primary: Cloudflare R2 (10 GB free, $0 egress/bandwidth fees forever)
/// - Fallback: Firebase Storage (if R2 is temporarily unreachable)
class CloudStorageService {
  static final CloudStorageService _instance = CloudStorageService._internal();
  factory CloudStorageService() => _instance;
  CloudStorageService._internal();

  FirebaseStorage? get _storage {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseStorage.instance;
      }
    } catch (e) {
      debugPrint('[CloudStorageService] FirebaseStorage not initialized: $e');
    }
    return null;
  }

  /// Cloud storage is always available via Cloudflare R2, with Firebase fallback
  bool get isAvailable => true;

  /// Uploads a student submission document or image directly to Cloud Storage.
  Future<CloudStorageUploadResult> uploadSubmissionFile({
    required int assignmentId,
    required String studentId,
    required String fileName,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) async {
    final sanitizedName = _sanitizeFileName(fileName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'submissions/assign_$assignmentId/${studentId}_${timestamp}_$sanitizedName';

    // 1. Primary: Cloudflare R2 (Zero bandwidth fees)
    try {
      final r2Url = await CloudflareR2Service.instance.uploadBytes(
        bytes: bytes,
        path: path,
        contentType: getMimeType(fileName),
        onProgress: onProgress,
      );
      if (r2Url != null) {
        return CloudStorageUploadResult(
          success: true,
          downloadUrl: r2Url,
          storagePath: path,
        );
      }
    } catch (e) {
      debugPrint('[CloudStorageService] Cloudflare R2 submission fallback: $e');
    }

    // 2. Fallback: Firebase Storage
    final storage = _storage;
    if (storage == null) {
      return const CloudStorageUploadResult(
        success: false,
        errorMessage: 'Cloud Storage is currently unavailable. Saving locally.',
      );
    }

    try {
      final ref = storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: getMimeType(fileName),
        customMetadata: {
          'assignmentId': assignmentId.toString(),
          'studentId': studentId,
          'originalFileName': fileName,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = ref.putData(bytes, metadata);
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          if (snapshot.totalBytes > 0) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            onProgress(progress.clamp(0.0, 1.0));
          }
        });
      }

      final snapshot = await uploadTask.timeout(const Duration(seconds: 15));
      final downloadUrl = await snapshot.ref.getDownloadURL().timeout(const Duration(seconds: 8));

      return CloudStorageUploadResult(
        success: true,
        downloadUrl: downloadUrl,
        storagePath: path,
      );
    } catch (e) {
      debugPrint('[CloudStorageService] uploadSubmissionFile error: $e');
      return CloudStorageUploadResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Uploads a teacher assignment handout/brief directly to Cloud Storage.
  Future<CloudStorageUploadResult> uploadAssignmentAttachment({
    required String teacherId,
    required String fileName,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) async {
    final sanitizedName = _sanitizeFileName(fileName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'assignments/handouts/${teacherId}_${timestamp}_$sanitizedName';

    // 1. Primary: Cloudflare R2
    try {
      final r2Url = await CloudflareR2Service.instance.uploadBytes(
        bytes: bytes,
        path: path,
        contentType: getMimeType(fileName),
        onProgress: onProgress,
      );
      if (r2Url != null) {
        return CloudStorageUploadResult(
          success: true,
          downloadUrl: r2Url,
          storagePath: path,
        );
      }
    } catch (e) {
      debugPrint('[CloudStorageService] Cloudflare R2 assignment fallback: $e');
    }

    // 2. Fallback: Firebase Storage
    final storage = _storage;
    if (storage == null) {
      return const CloudStorageUploadResult(
        success: false,
        errorMessage: 'Cloud Storage is currently unavailable. Saving locally.',
      );
    }

    try {
      final ref = storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: getMimeType(fileName),
        customMetadata: {
          'teacherId': teacherId,
          'originalFileName': fileName,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = ref.putData(bytes, metadata);
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          if (snapshot.totalBytes > 0) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            onProgress(progress.clamp(0.0, 1.0));
          }
        });
      }

      final snapshot = await uploadTask.timeout(const Duration(seconds: 15));
      final downloadUrl = await snapshot.ref.getDownloadURL().timeout(const Duration(seconds: 8));

      return CloudStorageUploadResult(
        success: true,
        downloadUrl: downloadUrl,
        storagePath: path,
      );
    } catch (e) {
      debugPrint('[CloudStorageService] uploadAssignmentAttachment error: $e');
      return CloudStorageUploadResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Uploads a curriculum material (PDF, slide, doc, image) directly to Cloud Storage.
  Future<CloudStorageUploadResult> uploadCurriculumMaterial({
    required int loId,
    required String fileName,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) async {
    final sanitizedName = _sanitizeFileName(fileName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'curriculum/lo_$loId/${timestamp}_$sanitizedName';

    // 1. Primary: Cloudflare R2
    try {
      final r2Url = await CloudflareR2Service.instance.uploadBytes(
        bytes: bytes,
        path: path,
        contentType: getMimeType(fileName),
        onProgress: onProgress,
      );
      if (r2Url != null) {
        return CloudStorageUploadResult(
          success: true,
          downloadUrl: r2Url,
          storagePath: path,
        );
      }
    } catch (e) {
      debugPrint('[CloudStorageService] Cloudflare R2 curriculum fallback: $e');
    }

    // 2. Fallback: Firebase Storage
    final storage = _storage;
    if (storage == null) {
      return const CloudStorageUploadResult(
        success: false,
        errorMessage: 'Cloud Storage is currently unavailable.',
      );
    }

    try {
      final ref = storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: getMimeType(fileName),
        customMetadata: {
          'loId': loId.toString(),
          'originalFileName': fileName,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = ref.putData(bytes, metadata);
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          if (snapshot.totalBytes > 0) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            onProgress(progress.clamp(0.0, 1.0));
          }
        });
      }

      final snapshot = await uploadTask.timeout(const Duration(seconds: 15));
      final downloadUrl = await snapshot.ref.getDownloadURL().timeout(const Duration(seconds: 8));

      return CloudStorageUploadResult(
        success: true,
        downloadUrl: downloadUrl,
        storagePath: path,
      );
    } catch (e) {
      debugPrint('[CloudStorageService] uploadCurriculumMaterial error: $e');
      return CloudStorageUploadResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Uploads a chat image or attachment to Cloudflare R2
  Future<CloudStorageUploadResult> uploadChatAttachment({
    required String conversationId,
    required String senderId,
    required String fileName,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) async {
    final sanitizedName = _sanitizeFileName(fileName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'chat/$conversationId/${senderId}_${timestamp}_$sanitizedName';

    // 1. Primary: Cloudflare R2
    try {
      final r2Url = await CloudflareR2Service.instance.uploadBytes(
        bytes: bytes,
        path: path,
        contentType: getMimeType(fileName),
        onProgress: onProgress,
      );
      if (r2Url != null) {
        return CloudStorageUploadResult(
          success: true,
          downloadUrl: r2Url,
          storagePath: path,
        );
      }
    } catch (e) {
      debugPrint('[CloudStorageService] Cloudflare R2 chat attachment fallback: $e');
    }

    // 2. Fallback: Firebase Storage
    final storage = _storage;
    if (storage == null) {
      return const CloudStorageUploadResult(
        success: false,
        errorMessage: 'Storage unavailable',
      );
    }

    try {
      final ref = storage.ref().child(path);
      final metadata = SettableMetadata(contentType: getMimeType(fileName));
      final uploadTask = ref.putData(bytes, metadata);
      final snapshot = await uploadTask.timeout(const Duration(seconds: 15));
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return CloudStorageUploadResult(
        success: true,
        downloadUrl: downloadUrl,
        storagePath: path,
      );
    } catch (e) {
      return CloudStorageUploadResult(success: false, errorMessage: e.toString());
    }
  }

  /// Attempts to find and download a curriculum material from Cloud Storage
  Future<Uint8List?> downloadCurriculumMaterial({
    required String fileName,
    String? storagePath,
    int? loId,
  }) async {
    // 1. If storagePath is a direct HTTP URL (e.g. from Cloudflare R2)
    if (storagePath != null && storagePath.startsWith('http')) {
      try {
        final res = await Dio().get<List<int>>(
          storagePath,
          options: Options(responseType: ResponseType.bytes),
        );
        if (res.data != null) return Uint8List.fromList(res.data!);
      } catch (_) {}
    }

    // 2. Direct R2 lookup
    if (storagePath != null && storagePath.isNotEmpty) {
      final r2Url = '${CloudflareR2Service.publicDevUrl}/${storagePath.startsWith('/') ? storagePath.substring(1) : storagePath}';
      try {
        final res = await Dio().get<List<int>>(
          r2Url,
          options: Options(responseType: ResponseType.bytes),
        );
        if (res.data != null && res.statusCode == 200) {
          return Uint8List.fromList(res.data!);
        }
      } catch (_) {}
    }

    // 3. Fallback to Firebase Storage
    final storage = _storage;
    if (storage == null) return null;
    try {
      if (storagePath != null && storagePath.isNotEmpty) {
        try {
          return await storage.ref(storagePath).getData(10 * 1024 * 1024);
        } catch (_) {}
      }

      final sanitized = _sanitizeFileName(fileName);
      if (loId != null) {
        try {
          return await storage.ref('curriculum/lo_$loId/$sanitized').getData(10 * 1024 * 1024);
        } catch (_) {}
        try {
          final listRes = await storage.ref('curriculum/lo_$loId').list(const ListOptions(maxResults: 20));
          for (final item in listRes.items) {
            final itemName = item.name.toLowerCase();
            if (itemName.contains(sanitized.toLowerCase()) ||
                sanitized.toLowerCase().contains(itemName.replaceAll(RegExp(r'^\d+_'), ''))) {
              return await item.getData(10 * 1024 * 1024);
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[CloudStorageService] downloadCurriculumMaterial error: $e');
    }
    return null;
  }

  static String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  static String getMimeType(String fileName) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
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
      case 'zip':
        return 'application/zip';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      default:
        return 'application/octet-stream';
    }
  }
}
