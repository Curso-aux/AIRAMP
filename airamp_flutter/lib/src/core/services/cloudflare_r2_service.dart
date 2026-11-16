import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Service for uploading files, images, and attachments to Cloudflare R2.
/// Eliminates Firebase Storage bandwidth/egress limits (10GB free, $0 egress).
class CloudflareR2Service {
  static final CloudflareR2Service _instance = CloudflareR2Service._internal();
  factory CloudflareR2Service() => _instance;
  static CloudflareR2Service get instance => _instance;
  CloudflareR2Service._internal();

  static const String accountId = '04f40ee82af58f1db27171ca2c8cd61e';
  static const String bucketName = 'aira-storage';
  static const String accessKeyId = '8ea943afd7c3f6ff3c6dde7ff99e8555';
  static const String secretAccessKey = '2e2f32b961564b47ddca2d6cfdacef87a690b6cb3d16b72d72a70334f4c31fed';
  static const String publicDevUrl = 'https://pub-4e41421375a34cc8b467d100681fa8e0.r2.dev';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  /// Uploads binary data to Cloudflare R2 bucket using AWS SigV4
  Future<String?> uploadBytes({
    required Uint8List bytes,
    required String path,
    String contentType = 'application/octet-stream',
    void Function(double progress)? onProgress,
  }) async {
    try {
      final cleanPath = path.startsWith('/') ? path.substring(1) : path;
      final host = '$accountId.r2.cloudflarestorage.com';
      final endpoint = 'https://$host/$bucketName/$cleanPath';

      // 1. Prepare timestamp strings
      final now = DateTime.now().toUtc();
      final amzDate = _formatAmzDate(now);
      final dateStamp = _formatDateStamp(now);

      // 2. Hash payload
      final payloadHash = sha256.convert(bytes).toString();

      // 3. Headers to sign (alphabetical order)
      final canonicalHeaders =
          'content-length:${bytes.length}\n'
          'content-type:$contentType\n'
          'host:$host\n'
          'x-amz-content-sha256:$payloadHash\n'
          'x-amz-date:$amzDate\n';

      const signedHeaders = 'content-length;content-type;host;x-amz-content-sha256;x-amz-date';

      // 4. Create Canonical Request
      final canonicalRequest = [
        'PUT',
        '/$bucketName/$cleanPath',
        '', // query string empty
        canonicalHeaders,
        signedHeaders,
        payloadHash,
      ].join('\n');

      final canonicalRequestHash = sha256.convert(utf8.encode(canonicalRequest)).toString();

      // 5. String to sign
      final credentialScope = '$dateStamp/auto/s3/aws4_request';
      final stringToSign = [
        'AWS4-HMAC-SHA256',
        amzDate,
        credentialScope,
        canonicalRequestHash,
      ].join('\n');

      // 6. Calculate signature
      final signingKey = _getSigningKey(secretAccessKey, dateStamp, 'auto', 's3');
      final signature = Hmac(sha256, signingKey)
          .convert(utf8.encode(stringToSign))
          .toString();

      // 7. Authorization header
      final authHeader =
          'AWS4-HMAC-SHA256 Credential=$accessKeyId/$credentialScope, '
          'SignedHeaders=$signedHeaders, Signature=$signature';

      // 8. Execute HTTP PUT request
      final response = await _dio.put(
        endpoint,
        data: bytes,
        options: Options(
          headers: {
            'Host': host,
            'Content-Type': contentType,
            'Content-Length': bytes.length.toString(),
            'x-amz-date': amzDate,
            'x-amz-content-sha256': payloadHash,
            'Authorization': authHeader,
          },
        ),
        onSendProgress: (sent, total) {
          if (total > 0 && onProgress != null) {
            onProgress(sent / total);
          }
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final finalUrl = generatePresignedGetUrl(cleanPath, expiresInSeconds: 604800);
        debugPrint('[CloudflareR2] Upload success: $finalUrl');
        return finalUrl;
      } else {
        debugPrint('[CloudflareR2] Upload failed: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('[CloudflareR2] Upload error: $e');
      return null;
    }
  }

  /// Generates an AWS SigV4 Presigned GET URL for an object in the R2 bucket.
  /// Bypasses DNS / public dev domain restrictions and works globally.
  String generatePresignedGetUrl(
    String path, {
    int expiresInSeconds = 86400, // 24 hours
  }) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final host = '$accountId.r2.cloudflarestorage.com';
    final now = DateTime.now().toUtc();

    String pad(int n) => n.toString().padLeft(2, '0');
    final amzDate =
        '${now.year}${pad(now.month)}${pad(now.day)}T${pad(now.hour)}${pad(now.minute)}${pad(now.second)}Z';
    final dateStamp = '${now.year}${pad(now.month)}${pad(now.day)}';

    final credentialScope = '$dateStamp/auto/s3/aws4_request';
    final credential = '$accessKeyId/$credentialScope';
    const signedHeaders = 'host';
    final expiresIn = expiresInSeconds.toString();

    // Query parameters sorted alphabetically
    final queryParams = [
      'X-Amz-Algorithm=AWS4-HMAC-SHA256',
      'X-Amz-Credential=${Uri.encodeComponent(credential)}',
      'X-Amz-Date=$amzDate',
      'X-Amz-Expires=$expiresIn',
      'X-Amz-SignedHeaders=$signedHeaders',
    ].join('&');

    final canonicalRequest = [
      'GET',
      '/$bucketName/$cleanPath',
      queryParams,
      'host:$host\n',
      signedHeaders,
      'UNSIGNED-PAYLOAD',
    ].join('\n');

    final canonicalHash = sha256.convert(utf8.encode(canonicalRequest)).toString();

    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      canonicalHash,
    ].join('\n');

    final signingKey = _getSigningKey(secretAccessKey, dateStamp, 'auto', 's3');
    final signature = Hmac(sha256, signingKey)
        .convert(utf8.encode(stringToSign))
        .toString();

    return 'https://$host/$bucketName/$cleanPath?$queryParams&X-Amz-Signature=$signature';
  }

  /// Converts any stored Cloudflare R2 URL or path into a signed, immediately accessible URL.
  /// If the URL is external (non-R2), returns it unmodified.
  String getAccessibleUrl(String? rawUrl, {int expiresInSeconds = 86400}) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return '';
    final trimmed = rawUrl.trim();

    try {
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        final uri = Uri.parse(trimmed);
        final host = uri.host.toLowerCase();
        // Check if this is an R2 dev URL or an R2 cloudflarestorage URL
        if (host.contains('r2.dev') || host.contains('r2.cloudflarestorage.com')) {
          var objectPath = uri.path;
          if (objectPath.startsWith('/$bucketName/')) {
            objectPath = objectPath.substring('/$bucketName/'.length);
          } else if (objectPath.startsWith('/')) {
            objectPath = objectPath.substring(1);
          }
          if (objectPath.isNotEmpty) {
            return generatePresignedGetUrl(objectPath, expiresInSeconds: expiresInSeconds);
          }
        }
        return trimmed;
      }

      // If it's a relative path in R2 (e.g. "submissions/...")
      if (!trimmed.startsWith('file://') &&
          !trimmed.startsWith('data:') &&
          !trimmed.startsWith('/data/')) {
        return generatePresignedGetUrl(trimmed, expiresInSeconds: expiresInSeconds);
      }
    } catch (e) {
      debugPrint('[CloudflareR2] getAccessibleUrl error: $e');
    }

    return trimmed;
  }

  // ── AWS SigV4 Helpers ─────────────────────────────────────

  static List<int> _getSigningKey(
    String key,
    String dateStamp,
    String regionName,
    String serviceName,
  ) {
    final kSecret = utf8.encode('AWS4$key');
    final kDate = Hmac(sha256, kSecret).convert(utf8.encode(dateStamp)).bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode(regionName)).bytes;
    final kService = Hmac(sha256, kRegion).convert(utf8.encode(serviceName)).bytes;
    final kSigning = Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;
    return kSigning;
  }

  static String _formatAmzDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}'
        '${dt.month.toString().padLeft(2, '0')}'
        '${dt.day.toString().padLeft(2, '0')}T'
        '${dt.hour.toString().padLeft(2, '0')}'
        '${dt.minute.toString().padLeft(2, '0')}'
        '${dt.second.toString().padLeft(2, '0')}Z';
  }

  static String _formatDateStamp(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}'
        '${dt.month.toString().padLeft(2, '0')}'
        '${dt.day.toString().padLeft(2, '0')}';
  }
}
