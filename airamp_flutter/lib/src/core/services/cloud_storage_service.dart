import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

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
/// Handles binary file uploads, progress tracking, and secure direct-to-cloud file links
/// preventing bloated SQLite base64 text columns and 1MB Firestore document limits.
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

  bool get isAvailable => _storage != null;

  /// Uploads a student submission document or image directly to Cloud Storage.
  Future<CloudStorageUploadResult> uploadSubmissionFile({
    required int assignmentId,
    required String studentId,
    required String fileName,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) async {
    final storage = _storage;
    if (storage == null) {
      return const CloudStorageUploadResult(
        success: false,
        errorMessage: 'Cloud Storage is currently unavailable. Saving locally.',
      );
    }

    try {
      final sanitizedName = _sanitizeFileName(fileName);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'submissions/assign_$assignmentId/${studentId}_${timestamp}_$sanitizedName';
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

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

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
    final storage = _storage;
    if (storage == null) {
      return const CloudStorageUploadResult(
        success: false,
        errorMessage: 'Cloud Storage is currently unavailable. Saving locally.',
      );
    }

    try {
      final sanitizedName = _sanitizeFileName(fileName);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'assignments/handouts/${teacherId}_${timestamp}_$sanitizedName';
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

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

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
    final storage = _storage;
    if (storage == null) {
      return const CloudStorageUploadResult(
        success: false,
        errorMessage: 'Cloud Storage is currently unavailable.',
      );
    }

    try {
      final sanitizedName = _sanitizeFileName(fileName);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'curriculum/lo_$loId/${timestamp}_$sanitizedName';
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

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

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

  /// Attempts to find and download a curriculum material from Cloud Storage
  Future<Uint8List?> downloadCurriculumMaterial({
    required String fileName,
    int? loId,
  }) async {
    final storage = _storage;
    if (storage == null) return null;
    try {
      final sanitized = _sanitizeFileName(fileName).toLowerCase();
      // Try loId folder first if provided
      if (loId != null) {
        try {
          final listRes = await storage.ref('curriculum/lo_$loId').listAll();
          for (final item in listRes.items) {
            final itemName = item.name.toLowerCase();
            if (itemName.contains(sanitized) || sanitized.contains(itemName.replaceAll(RegExp(r'^\d+_'), ''))) {
              return await item.getData(35 * 1024 * 1024); // max 35MB
            }
          }
        } catch (_) {}
      }

      // Try global curriculum folders
      try {
        final rootRes = await storage.ref('curriculum').listAll();
        for (final prefix in rootRes.prefixes) {
          final subList = await prefix.listAll();
          for (final item in subList.items) {
            final itemName = item.name.toLowerCase();
            if (itemName.contains(sanitized) || sanitized.contains(itemName.replaceAll(RegExp(r'^\d+_'), ''))) {
              return await item.getData(35 * 1024 * 1024);
            }
          }
        }
      } catch (_) {}
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
