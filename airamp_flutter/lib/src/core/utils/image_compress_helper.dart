import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

/// Universal image downscaling and compression helper for AIRAMP.
/// Uses Flutter's native UI codec (available on Web and Mobile)
/// to downscale large camera/gallery photos down to ~60-150 KB,
/// ensuring snappy offline SQLite storage and reliable Cloud Firestore synchronization.
class ImageCompressHelper {
  /// Downscales [bytes] so the maximum dimension (width or height) does not exceed [maxDimension].
  /// Returns PNG compressed bytes. If processing fails or image is already smaller, returns [bytes].
  static Future<Uint8List> compressImage(
    Uint8List bytes, {
    int maxDimension = 1200,
  }) async {
    if (bytes.isEmpty) return bytes;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final width = image.width;
      final height = image.height;

      if (width <= maxDimension &&
          height <= maxDimension &&
          bytes.lengthInBytes < 400000) {
        return bytes;
      }

      int targetWidth = width;
      int targetHeight = height;

      if (width > maxDimension || height > maxDimension) {
        if (width >= height) {
          targetHeight = (height * maxDimension / width).round();
          targetWidth = maxDimension;
        } else {
          targetWidth = (width * maxDimension / height).round();
          targetHeight = maxDimension;
        }
      }

      final scaledCodec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final scaledFrame = await scaledCodec.getNextFrame();
      final byteData = await scaledFrame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData != null) {
        final result = byteData.buffer.asUint8List();
        debugPrint(
          '[ImageCompressHelper] Compressed image: ${bytes.lengthInBytes ~/ 1024} KB -> ${result.lengthInBytes ~/ 1024} KB (${targetWidth}x$targetHeight)',
        );
        return result;
      }
    } catch (e) {
      debugPrint('[ImageCompressHelper] Downscale note: $e');
    }
    return bytes;
  }

  /// Cleans base64 strings by removing data URI prefixes (e.g. data:image/png;base64,) and whitespace.
  static String cleanBase64(String raw) {
    if (raw.contains(',')) {
      return raw.split(',').last.trim();
    }
    return raw.trim();
  }

  /// Safely decodes base64 image bytes, stripping headers if needed.
  static Uint8List? safeDecodeBase64(String? base64Str) {
    if (base64Str == null || base64Str.trim().isEmpty) return null;
    try {
      return base64Decode(cleanBase64(base64Str));
    } catch (_) {
      return null;
    }
  }
}
