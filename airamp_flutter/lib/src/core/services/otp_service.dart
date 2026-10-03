import 'dart:math';
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../database/firestore_service.dart';
import 'email_service.dart';

class OtpResult {
  final bool success;
  final String message;
  final String? email;
  final String? userId;
  final String? fullName;
  final String? role;

  OtpResult({
    required this.success,
    required this.message,
    this.email,
    this.userId,
    this.fullName,
    this.role,
  });
}

class _OtpRecord {
  final String code;
  final String email;
  final String identifier;
  final DateTime expiresAt;
  int attempts = 0;

  _OtpRecord({
    required this.code,
    required this.email,
    required this.identifier,
    required this.expiresAt,
  });
}

/// Centralized service handling generation, dispatch via SMTP, and verification
/// of One-Time Passwords (OTPs) for password changes and resets.
class OtpService {
  static final OtpService _instance = OtpService._internal();
  factory OtpService() => _instance;
  OtpService._internal();

  final Map<String, _OtpRecord> _activeOtps = {};

  /// Masks an email for secure presentation (e.g. "luyahan007@gmail.com" -> "l***7@gmail.com")
  static String maskEmail(String email) {
    if (!email.contains('@')) return email;
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) {
      return '${name[0]}***@$domain';
    }
    return '${name[0]}***${name[name.length - 1]}@$domain';
  }

  /// Direct OTP generation and SMTP dispatch for logged-in users (Student/Teacher profile)
  Future<OtpResult> requestOtpDirect({
    required String userId,
    required String email,
    required String fullName,
    required String role,
  }) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return OtpResult(
        success: false,
        message: 'Invalid or missing email address on this account.',
      );
    }

    // 1. Generate cryptographically secure 6-digit OTP
    final random = Random.secure();
    final otpCode = (100000 + random.nextInt(900000)).toString();

    // 2. Cache in memory with 10-minute expiry
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(minutes: 10));
    final record = _OtpRecord(
      code: otpCode,
      email: cleanEmail.toLowerCase(),
      identifier: userId.toLowerCase().trim(),
      expiresAt: expiresAt,
    );

    _activeOtps[userId.toLowerCase().trim()] = record;
    _activeOtps[cleanEmail.toLowerCase()] = record;

    // 3. Backup to Cloud Firestore for cross-client reliability
    try {
      await FirestoreService().saveDocument('password_otps', userId.trim(), {
        'otp': otpCode,
        'email': cleanEmail,
        'user_id': userId,
        'role': role,
        'created_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'used': false,
        'attempts': 0,
      });
      // Also backup by email key
      final emailSafeKey = cleanEmail.replaceAll('.', '_').replaceAll('@', '_at_');
      await FirestoreService().saveDocument('password_otps', emailSafeKey, {
        'otp': otpCode,
        'email': cleanEmail,
        'user_id': userId,
        'role': role,
        'created_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'used': false,
        'attempts': 0,
      });
    } catch (e) {
      debugPrint('[OtpService] Firestore OTP backup note: $e');
    }

    // 4. Send via EmailService (Gmail SMTP)
    final sendResult = await EmailService().sendPasswordResetOtp(
      toEmail: cleanEmail,
      fullName: fullName,
      userId: userId,
      otpCode: otpCode,
      role: role,
    );

    if (sendResult.success) {
      return OtpResult(
        success: true,
        message: 'A 6-digit verification code was sent to ${maskEmail(cleanEmail)}.',
        email: cleanEmail,
        userId: userId,
        fullName: fullName,
        role: role,
      );
    } else {
      return OtpResult(
        success: false,
        message: sendResult.message,
      );
    }
  }

  /// Resolves an account by ID (e.g. 001-0001, 002-0001) or Email, generates OTP,
  /// and sends it via SMTP (used by Forgot Password screen).
  Future<OtpResult> requestOtpForUser({
    required String identifier,
  }) async {
    final cleanIdentifier = identifier.trim();
    if (cleanIdentifier.isEmpty) {
      return OtpResult(
        success: false,
        message: 'Please enter your Student ID, Teacher ID, or registered email.',
      );
    }

    // 1. Search in Cloud Firestore first
    Map<String, dynamic>? account;
    try {
      account = await FirestoreService().findUserByIdentifier(cleanIdentifier);
    } catch (e) {
      debugPrint('[OtpService] Cloud user lookup note: $e');
    }

    // 2. Fallback to local SQLite database
    if (account == null) {
      try {
        final db = await DatabaseHelper().database;
        final idLower = cleanIdentifier.toLowerCase();
        final rows = await db.rawQuery(
          '''SELECT * FROM users
             WHERE LOWER(id) = ?
                OR LOWER(email) = ?
                OR LOWER(COALESCE(username, '')) = ?
                OR LOWER(full_name) = ?
             LIMIT 1''',
          [idLower, idLower, idLower, idLower],
        );
        if (rows.isNotEmpty) {
          account = Map<String, dynamic>.from(rows.first);
        }
      } catch (e) {
        debugPrint('[OtpService] Local DB lookup note: $e');
      }
    }

    if (account == null) {
      return OtpResult(
        success: false,
        message: 'No account found matching "$cleanIdentifier". Please verify your ID or email.',
      );
    }

    final userId = account['id']?.toString() ?? cleanIdentifier;
    final email = account['email']?.toString() ?? '';
    final fullName = account['full_name']?.toString() ?? account['username']?.toString() ?? 'AIRA User';
    final role = account['role']?.toString() ?? 'student';

    if (email.isEmpty || !email.contains('@')) {
      return OtpResult(
        success: false,
        message: 'No valid email address is linked to this account. Please contact School Administration.',
      );
    }

    return await requestOtpDirect(
      userId: userId,
      email: email,
      fullName: fullName,
      role: role,
    );
  }

  /// Verifies an entered OTP code against the active cache or Firestore backup.
  /// If valid, the code is immediately invalidated to prevent replay attacks.
  Future<bool> verifyOtp({
    required String identifier,
    required String enteredCode,
  }) async {
    final cleanCode = enteredCode.replaceAll(' ', '').trim();
    if (cleanCode.length != 6) return false;

    final key = identifier.toLowerCase().trim();

    // 1. In-memory check
    final record = _activeOtps[key];
    if (record != null) {
      if (DateTime.now().isAfter(record.expiresAt)) {
        _activeOtps.remove(key);
        return false;
      }
      if (record.attempts >= 5) {
        _activeOtps.remove(key);
        return false;
      }
      record.attempts++;

      if (record.code == cleanCode) {
        // Success: invalidate code
        _activeOtps.remove(key);
        _activeOtps.remove(record.email);
        _activeOtps.remove(record.identifier);

        // Mark used in Firestore
        try {
          await FirestoreService().saveDocument('password_otps', record.identifier, {'used': true});
          final emailKey = record.email.replaceAll('.', '_').replaceAll('@', '_at_');
          await FirestoreService().saveDocument('password_otps', emailKey, {'used': true});
        } catch (_) {}

        return true;
      }
    }

    // 2. Cloud Firestore fallback check
    try {
      final emailSafeKey = key.replaceAll('.', '_').replaceAll('@', '_at_');
      final doc = await FirestoreService().getDocument('password_otps', key) ??
          await FirestoreService().getDocument('password_otps', emailSafeKey);

      if (doc != null) {
        final storedOtp = doc['otp']?.toString();
        final used = doc['used'] == true;
        final expiresAtStr = doc['expires_at']?.toString();

        if (!used && storedOtp == cleanCode) {
          if (expiresAtStr != null) {
            final exp = DateTime.tryParse(expiresAtStr);
            if (exp != null && DateTime.now().isAfter(exp)) {
              return false;
            }
          }

          // Mark used
          await FirestoreService().saveDocument('password_otps', key, {'used': true});
          await FirestoreService().saveDocument('password_otps', emailSafeKey, {'used': true});
          return true;
        }
      }
    } catch (e) {
      debugPrint('[OtpService] Firestore verify note: $e');
    }

    return false;
  }
}
