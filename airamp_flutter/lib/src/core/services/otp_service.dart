import 'dart:math';
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../database/firestore_service.dart';
import '../utils/rate_limiter.dart';
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

/// Centralized service handling generation, dispatch via SMTP, rate-limiting,
/// and verification of One-Time Passwords (OTPs) for password changes and resets.
class OtpService {
  static final OtpService _instance = OtpService._internal();
  factory OtpService() => _instance;
  OtpService._internal();

  final Map<String, _OtpRecord> _activeOtps = {};
  final RateLimiter _limiter = RateLimiter();

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

  /// Returns a friendly lockout message if [identifier] is locked out, or null.
  String? getLockoutMessage(String identifier) {
    final key = identifier.toLowerCase().trim();
    if (_limiter.isLockedOut('otp_verify_$key')) {
      final rem = _limiter.getRemainingLockout('otp_verify_$key');
      final waitMins = max(1, (rem.inSeconds / 60).ceil());
      return 'Account temporarily locked out due to multiple failed verification attempts. Please wait $waitMins minute(s).';
    }
    return null;
  }

  /// Direct OTP generation and SMTP dispatch for logged-in users (Student/Teacher profile)
  /// Enforces cooldown (60s), rolling window (5 requests / 15m), and global limits.
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

    final normUserId = userId.toLowerCase().trim();
    final normEmail = cleanEmail.toLowerCase();

    // 1. Check if the user ID or email is currently locked out
    if (_limiter.isLockedOut('otp_verify_$normUserId') || _limiter.isLockedOut('otp_verify_$normEmail')) {
      final rem = _limiter.getRemainingLockout('otp_verify_$normUserId');
      final waitSecs = rem.inSeconds > 0 ? rem.inSeconds : _limiter.getRemainingLockout('otp_verify_$normEmail').inSeconds;
      final waitMins = max(1, (waitSecs / 60).ceil());
      return OtpResult(
        success: false,
        message: 'Account temporarily locked out due to multiple failed attempts. Please wait $waitMins minute(s).',
      );
    }

    // 2. Cooldown check: enforce minimum 60s between OTP requests
    final cooldownCheck = _limiter.checkAndRecord(
      'otp_req_cooldown_$normUserId',
      maxRequests: 1,
      window: const Duration(seconds: 60),
      cooldown: const Duration(seconds: 60),
    );
    if (!cooldownCheck.isAllowed) {
      return OtpResult(
        success: false,
        message: 'Please wait ${cooldownCheck.retryAfterSeconds}s before requesting a new verification code.',
      );
    }

    // 3. User & email sliding window check (max 5 requests per 15 minutes)
    final userWindowCheck = _limiter.checkAndRecord(
      'otp_req_window_$normUserId',
      maxRequests: 5,
      window: const Duration(minutes: 15),
    );
    if (!userWindowCheck.isAllowed) {
      return OtpResult(
        success: false,
        message: userWindowCheck.message,
      );
    }

    final emailWindowCheck = _limiter.checkAndRecord(
      'otp_req_window_$normEmail',
      maxRequests: 5,
      window: const Duration(minutes: 15),
    );
    if (!emailWindowCheck.isAllowed) {
      return OtpResult(
        success: false,
        message: emailWindowCheck.message,
      );
    }

    // 4. Global dispatch cap (max 25 requests per minute across all users)
    final globalCheck = _limiter.checkAndRecord(
      'otp_req_global',
      maxRequests: 25,
      window: const Duration(minutes: 1),
    );
    if (!globalCheck.isAllowed) {
      return OtpResult(
        success: false,
        message: 'High verification volume detected. Please wait ${globalCheck.retryAfterSeconds}s before trying again.',
      );
    }

    // 5. Generate cryptographically secure 6-digit OTP
    final random = Random.secure();
    final otpCode = (100000 + random.nextInt(900000)).toString();

    // 6. Cache in memory with 10-minute expiry
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

    // 7. Backup to Cloud Firestore for cross-client reliability
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

    // 8. Send via EmailService (Gmail SMTP)
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

    // Rate-limit account lookup attempts to prevent brute-forcing student IDs
    final normLookup = cleanIdentifier.toLowerCase();
    final lookupCheck = _limiter.checkAndRecord(
      'user_lookup_$normLookup',
      maxRequests: 8,
      window: const Duration(minutes: 1),
    );
    if (!lookupCheck.isAllowed) {
      return OtpResult(
        success: false,
        message: 'Too many lookup requests for this ID. Please wait ${lookupCheck.retryAfterSeconds}s.',
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

  /// Generates and sends an OTP for verifying an email address during registration,
  /// sensitive profile changes (e.g. updating email), or 2FA authentication.
  Future<OtpResult> requestEmailVerificationOtp({
    required String targetEmail,
    required String fullName,
    String? userId,
    String role = 'student',
    String purpose = 'Security Verification',
  }) async {
    final cleanEmail = targetEmail.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return OtpResult(
        success: false,
        message: 'Invalid or missing email address.',
      );
    }

    final normEmail = cleanEmail.toLowerCase();
    final rateKey = userId != null ? userId.toLowerCase().trim() : normEmail;

    // 1. Lockout check
    if (_limiter.isLockedOut('otp_verify_$rateKey') || _limiter.isLockedOut('otp_verify_$normEmail')) {
      final rem = _limiter.getRemainingLockout('otp_verify_$rateKey');
      final waitSecs = rem.inSeconds > 0 ? rem.inSeconds : _limiter.getRemainingLockout('otp_verify_$normEmail').inSeconds;
      final waitMins = max(1, (waitSecs / 60).ceil());
      return OtpResult(
        success: false,
        message: 'Account temporarily locked out due to multiple failed attempts. Please wait $waitMins minute(s).',
      );
    }

    // 2. Cooldown check (60s minimum)
    final cooldownCheck = _limiter.checkAndRecord(
      'otp_req_cooldown_$rateKey',
      maxRequests: 1,
      window: const Duration(seconds: 60),
      cooldown: const Duration(seconds: 60),
    );
    if (!cooldownCheck.isAllowed) {
      return OtpResult(
        success: false,
        message: 'Please wait ${cooldownCheck.retryAfterSeconds}s before requesting a new code.',
      );
    }

    // 3. User & email sliding window check (max 5 requests per 15 minutes)
    final windowCheck = _limiter.checkAndRecord(
      'otp_req_window_$normEmail',
      maxRequests: 5,
      window: const Duration(minutes: 15),
    );
    if (!windowCheck.isAllowed) {
      return OtpResult(
        success: false,
        message: windowCheck.message,
      );
    }

    // 4. Global dispatch cap
    final globalCheck = _limiter.checkAndRecord(
      'otp_req_global',
      maxRequests: 25,
      window: const Duration(minutes: 1),
    );
    if (!globalCheck.isAllowed) {
      return OtpResult(
        success: false,
        message: 'High verification volume detected. Please wait ${globalCheck.retryAfterSeconds}s.',
      );
    }

    // 5. Generate secure 6-digit OTP
    final random = Random.secure();
    final otpCode = (100000 + random.nextInt(900000)).toString();

    // 6. Cache in memory with 10-minute expiry
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(minutes: 10));
    final record = _OtpRecord(
      code: otpCode,
      email: normEmail,
      identifier: rateKey,
      expiresAt: expiresAt,
    );

    _activeOtps[rateKey] = record;
    _activeOtps[normEmail] = record;

    // 7. Backup to Cloud Firestore
    try {
      final emailSafeKey = normEmail.replaceAll('.', '_').replaceAll('@', '_at_');
      await FirestoreService().saveDocument('security_otps', emailSafeKey, {
        'otp': otpCode,
        'email': cleanEmail,
        'identifier': rateKey,
        'purpose': purpose,
        'role': role,
        'created_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'used': false,
        'attempts': 0,
      });
      if (userId != null) {
        await FirestoreService().saveDocument('security_otps', userId.trim(), {
          'otp': otpCode,
          'email': cleanEmail,
          'identifier': rateKey,
          'purpose': purpose,
          'role': role,
          'created_at': now.toIso8601String(),
          'expires_at': expiresAt.toIso8601String(),
          'used': false,
          'attempts': 0,
        });
      }
    } catch (e) {
      debugPrint('[OtpService] Security OTP backup note: $e');
    }

    // 8. Deliver email
    final sendResult = await EmailService().sendVerificationOtp(
      toEmail: cleanEmail,
      fullName: fullName,
      userId: userId,
      otpCode: otpCode,
      purpose: purpose,
      role: role,
    );

    if (sendResult.success) {
      return OtpResult(
        success: true,
        message: 'A 6-digit verification code was sent to ${maskEmail(cleanEmail)}.',
        email: cleanEmail,
        userId: userId ?? rateKey,
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

  /// Verifies an entered OTP code against the active cache or Firestore backup.
  /// If valid, the code is immediately invalidated to prevent replay attacks.
  /// Tracks failed attempts and locks out the account on 5 consecutive failures.
  Future<bool> verifyOtp({
    required String identifier,
    required String enteredCode,
  }) async {
    final cleanCode = enteredCode.replaceAll(' ', '').trim();
    if (cleanCode.length != 6) return false;

    final key = identifier.toLowerCase().trim();

    // 1. Check if user is locked out
    if (_limiter.isLockedOut('otp_verify_$key')) {
      final rem = _limiter.getRemainingLockout('otp_verify_$key');
      final waitMins = max(1, (rem.inSeconds / 60).ceil());
      debugPrint('[OtpService] Verification blocked for $key: locked out for $waitMins min(s)');
      return false;
    }

    // 2. In-memory check
    final record = _activeOtps[key];
    if (record != null) {
      if (DateTime.now().isAfter(record.expiresAt)) {
        _activeOtps.remove(key);
        _recordVerificationFailure(key, record.email);
        return false;
      }
      if (record.attempts >= 5) {
        _activeOtps.remove(key);
        _recordVerificationFailure(key, record.email);
        return false;
      }
      record.attempts++;

      if (record.code == cleanCode) {
        // Success: invalidate code & clear failure counters
        _activeOtps.remove(key);
        _activeOtps.remove(record.email);
        _activeOtps.remove(record.identifier);

        _limiter.reset('otp_verify_$key');
        _limiter.reset('otp_verify_${record.email.toLowerCase()}');
        _limiter.reset('otp_verify_${record.identifier.toLowerCase()}');

        // Mark used in Firestore
        try {
          await FirestoreService().saveDocument('password_otps', record.identifier, {'used': true});
          final emailKey = record.email.replaceAll('.', '_').replaceAll('@', '_at_');
          await FirestoreService().saveDocument('password_otps', emailKey, {'used': true});
          await FirestoreService().saveDocument('security_otps', record.identifier, {'used': true});
          await FirestoreService().saveDocument('security_otps', emailKey, {'used': true});
        } catch (_) {}

        return true;
      }
    }

    // 3. Cloud Firestore fallback check
    try {
      final emailSafeKey = key.replaceAll('.', '_').replaceAll('@', '_at_');
      final doc = await FirestoreService().getDocument('security_otps', key) ??
          await FirestoreService().getDocument('security_otps', emailSafeKey) ??
          await FirestoreService().getDocument('password_otps', key) ??
          await FirestoreService().getDocument('password_otps', emailSafeKey);

      if (doc != null) {
        final storedOtp = doc['otp']?.toString();
        final used = doc['used'] == true;
        final expiresAtStr = doc['expires_at']?.toString();

        if (!used && storedOtp == cleanCode) {
          if (expiresAtStr != null) {
            final exp = DateTime.tryParse(expiresAtStr);
            if (exp != null && DateTime.now().isAfter(exp)) {
              _recordVerificationFailure(key);
              return false;
            }
          }

          // Mark used
          await FirestoreService().saveDocument('security_otps', key, {'used': true});
          await FirestoreService().saveDocument('security_otps', emailSafeKey, {'used': true});
          await FirestoreService().saveDocument('password_otps', key, {'used': true});
          await FirestoreService().saveDocument('password_otps', emailSafeKey, {'used': true});

          _limiter.reset('otp_verify_$key');
          _limiter.reset('otp_verify_$emailSafeKey');
          return true;
        }
      }
    } catch (e) {
      debugPrint('[OtpService] Firestore verify note: $e');
    }

    // Failed attempt: record failure and potentially lock out
    _recordVerificationFailure(key, record?.email);
    return false;
  }

  void _recordVerificationFailure(String identifier, [String? email]) {
    final normId = identifier.toLowerCase().trim();
    _limiter.recordFailure(
      'otp_verify_$normId',
      maxFailures: 5,
      lockoutDuration: const Duration(minutes: 15),
      reason: 'Too many incorrect verification attempts.',
    );
    if (email != null && email.isNotEmpty) {
      final normEmail = email.toLowerCase().trim();
      _limiter.recordFailure(
        'otp_verify_$normEmail',
        maxFailures: 5,
        lockoutDuration: const Duration(minutes: 15),
        reason: 'Too many incorrect verification attempts.',
      );
    }
  }
}
