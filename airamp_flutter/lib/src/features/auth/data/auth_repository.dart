import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/firestore_service.dart';
import '../../../core/services/otp_service.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/institutional_id_helper.dart';
import '../../../core/utils/web_session_helper.dart';

class AuthSession {
  final String session;
  final String userId;
  final String role;
  final String? schoolId;
  final bool mustChangePassword;

  AuthSession({
    required this.session,
    required this.userId,
    required this.role,
    this.schoolId = 'sch_main',
    this.mustChangePassword = false,
  });
}

class AuthRepository {
  final Dio _dio;
  AuthRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final db = await DatabaseHelper().database;
    final identifierLower = identifier.toLowerCase().trim();

    try {
      await db.execute('ALTER TABLE users ADD COLUMN username TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE users ADD COLUMN password_salt TEXT');
    } catch (_) {}

    // Find candidate accounts by ID (e.g. 001-0001, SA-000-0001), email, username, full name, or prefix
    List<Map<String, Object?>> candidateRows = [];
    try {
      candidateRows = await db.rawQuery(
        '''SELECT * FROM users
           WHERE LOWER(id) = ?
              OR LOWER(email) = ? 
              OR LOWER(COALESCE(username, '')) = ?
              OR LOWER(full_name) = ?
              OR LOWER(REPLACE(REPLACE(COALESCE(username, ''), '.', ' '), '_', ' ')) = ?
              OR LOWER(full_name) LIKE ?
              OR LOWER(COALESCE(username, '')) LIKE ?
              OR (? = 'sa-000-0001' AND (LOWER(id) = 'super_admin_christian' OR LOWER(id) = 'sa-000-0001' OR LOWER(email) = 'evangelistachristian88@gmail.com'))''',
        [identifierLower, identifierLower, identifierLower, identifierLower, identifierLower, '$identifierLower%', '$identifierLower%', identifierLower],
      );
    } catch (_) {
      candidateRows = await db.rawQuery(
        '''SELECT * FROM users
           WHERE LOWER(id) = ?
              OR LOWER(email) = ? 
              OR LOWER(full_name) = ?
              OR LOWER(full_name) LIKE ?
              OR (? = 'sa-000-0001' AND (LOWER(id) = 'super_admin_christian' OR LOWER(id) = 'sa-000-0001' OR LOWER(email) = 'evangelistachristian88@gmail.com'))''',
        [identifierLower, identifierLower, identifierLower, '$identifierLower%', identifierLower],
      );
    }

    // 2. First verify credentials against local SQLite candidates (instant 0ms execution)
    final List<Map<String, Object?>> verifiedUsers = [];
    for (final candidate in candidateRows) {
      final storedHash = candidate['password'] as String? ?? '';
      final storedSalt = candidate['password_salt'] as String?;

      if (DatabaseHelper.verifyPassword(password, storedHash, storedSalt)) {
        final candidateMap = Map<String, Object?>.from(candidate);
        // Auto-upgrade legacy plaintext accounts to salted SHA-256 on successful login
        if (storedSalt == null || storedSalt.isEmpty) {
          final newSalt = DatabaseHelper.generateSalt();
          final newHash = DatabaseHelper.hashPassword(password, newSalt);
          await db.update('users', {
            'password': newHash,
            'password_salt': newSalt,
          }, where: 'id = ?', whereArgs: [candidate['id']]);
          candidateMap['password'] = newHash;
          candidateMap['password_salt'] = newSalt;
        }
        verifiedUsers.add(candidateMap);
      }
    }

    // 3. If local verification failed (e.g. newly created on Web Admin, or password was updated),
    // query Cloud Firestore via ultra-fast direct REST lookup to authenticate against latest cloud credentials
    Map<String, dynamic>? cloudUser;
    if (verifiedUsers.isEmpty) {
      try {
        cloudUser = await FirestoreService()
            .findUserByIdentifier(identifier)
            .timeout(const Duration(seconds: 4), onTimeout: () => null);
      } catch (e) {
        debugPrint('[AuthRepository] Cloud lookup note: $e');
      }

      if (cloudUser != null) {
        final cloudHash = cloudUser['password'] as String? ?? '';
        final cloudSalt = cloudUser['password_salt'] as String?;

        if (DatabaseHelper.verifyPassword(password, cloudHash, cloudSalt)) {
          final cloudId = cloudUser['id']?.toString() ?? 'usr_${DateTime.now().millisecondsSinceEpoch}';
          final cloudMust = cloudUser['must_change_password'] == 1 ||
              cloudUser['must_change_password'] == true ||
              cloudUser['must_change_password'] == '1';

          final cloudDbRow = <String, Object?>{
            'id': cloudId,
            'email': cloudUser['email'] ?? '',
            'username': cloudUser['username'] ?? '',
            'password': cloudHash,
            'password_salt': cloudSalt,
            'role': cloudUser['role'] ?? 'student',
            'full_name': cloudUser['full_name'] ?? '',
            'section': cloudUser['section'],
            'grade': cloudUser['grade'],
            'student_type': cloudUser['student_type'] ?? 'regular',
            'special_notes': cloudUser['special_notes'],
            'school_id': cloudUser['school_id'] ?? 'sch_main',
            'profile_image': cloudUser['profile_image'] ?? cloudUser['profileImage'],
            'must_change_password': cloudMust ? 1 : 0,
            'created_at': cloudUser['created_at'] ?? DateTime.now().toIso8601String(),
          };

          // Synchronize verified credentials to local SQLite cache so future logins are instant
          try {
            await db.insert('users', cloudDbRow, conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (_) {}

          verifiedUsers.add(cloudDbRow);
        }
      }
    }

    if (verifiedUsers.isEmpty) {
      throw Exception('Invalid email/username or password.');
    }

    // If multiple accounts match, prioritize exact email/username and faculty roles over student
    final sorted = List<Map<String, Object?>>.from(verifiedUsers);
    if (sorted.length > 1) {
      sorted.sort((a, b) {
        final aEmail = (a['email'] as String? ?? '').toLowerCase();
        final bEmail = (b['email'] as String? ?? '').toLowerCase();
        final aUser = (a['username'] as String? ?? '').toLowerCase();
        final bUser = (b['username'] as String? ?? '').toLowerCase();
        final aExact = aEmail == identifierLower || aUser == identifierLower;
        final bExact = bEmail == identifierLower || bUser == identifierLower;
        if (aExact && !bExact) return -1;
        if (!aExact && bExact) return 1;
        final aRole = a['role'] as String? ?? '';
        final bRole = b['role'] as String? ?? '';
        if (aRole != 'student' && bRole == 'student') return -1;
        if (aRole == 'student' && bRole != 'student') return 1;
        return 0;
      });
    }

    final user = Map<String, dynamic>.from(sorted.first);
    final userId = user['id'] as String;
    if (userId == 'super_admin_christian' ||
        userId == 'SA-000-0001' ||
        (user['email'] as String? ?? '').toLowerCase() == 'evangelistachristian88@gmail.com') {
      user['role'] = 'super_admin';
    } else {
      final detectedRole = InstitutionalIdHelper.detectRole(userId);
      if (detectedRole != null && user['role'] != detectedRole) {
        user['role'] = detectedRole;
        user['category'] = detectedRole;
        try {
          await db.update(
            'users',
            {'role': detectedRole, 'category': detectedRole},
            where: 'id = ?',
            whereArgs: [userId],
          );
        } catch (_) {}
      }
    }
    final role = user['role'] as String;

    final isArchived = user['is_archived'] == 1 ||
        user['is_archived'] == true ||
        user['is_archived'] == '1';
    if (isArchived) {
      throw Exception('This account has been deactivated. Please contact your institution administrator to restore access.');
    }

    // Check Cloud Firestore for this user to restore any cloud avatar or updated profile:
    if (cloudUser != null) {
      // Data already in memory from credential verification — apply instantly in 0ms!
      await _applyCloudProfile(cloudUser, user, userId, db);
    } else {
      // If local SQLite suspects must_change_password, check Cloud Firestore synchronously
      // to ensure we never force password change if the user already updated their password on another device!
      final localMust = user['must_change_password'] == 1 ||
          user['must_change_password'] == true ||
          user['must_change_password'] == '1';
      if (localMust) {
        try {
          final cu = await FirestoreService()
              .findUserByIdentifier(user['email']?.toString() ?? user['username']?.toString() ?? userId)
              .timeout(const Duration(seconds: 2), onTimeout: () => null);
          if (cu != null) {
            cloudUser = cu;
            await _applyCloudProfile(cu, user, userId, db);
          }
        } catch (_) {}
      } else {
        // Local SQLite credentials already verified and no password change needed — sync avatar in background
        unawaited(() async {
          try {
            final cu = await FirestoreService()
                .findUserByIdentifier(user['email']?.toString() ?? user['username']?.toString() ?? userId)
                .timeout(const Duration(seconds: 3), onTimeout: () => null);
            if (cu != null) {
              final appDb = await DatabaseHelper().database;
              await _applyCloudProfile(cu, null, userId, appDb);
            }
          } catch (_) {}
        }());
      }
    }

    final mustChange = user['must_change_password'] == 1 ||
        user['must_change_password'] == true ||
        user['must_change_password'] == '1';

    // Ensure local SQLite cache is updated with the verified user
    try {
      final dbUser = Map<String, dynamic>.from(user);
      dbUser.remove('profileImage');
      dbUser.remove('mustChangePassword');
      if (dbUser['must_change_password'] is bool) {
        dbUser['must_change_password'] = (dbUser['must_change_password'] == true) ? 1 : 0;
      }
      if (dbUser['is_archived'] is bool) {
        dbUser['is_archived'] = (dbUser['is_archived'] == true) ? 1 : 0;
      }

      final existing = await db.query('users', where: 'id = ?', whereArgs: [userId]);
      if (existing.isEmpty) {
        await db.insert('users', dbUser);
      } else {
        await db.update('users', dbUser, where: 'id = ?', whereArgs: [userId]);
      }
    } catch (_) {
      try {
        final dbUser = Map<String, dynamic>.from(user);
        dbUser.remove('profileImage');
        dbUser.remove('mustChangePassword');
        if (dbUser['must_change_password'] is bool) {
          dbUser['must_change_password'] = (dbUser['must_change_password'] == true) ? 1 : 0;
        }
        await db.update('users', dbUser, where: 'LOWER(email) = ?', whereArgs: [(user['email'] as String? ?? '').toLowerCase()]);
      } catch (_) {}
    }

    // Synchronize authenticated user with Cloud Firestore safely (never overwrite cloud avatar with null,
    // and never revert cloud must_change_password to 1 if cloud already has 0!)
    try {
      final syncData = Map<String, dynamic>.from(user);
      if (syncData['profile_image'] == null ||
          (syncData['profile_image'] is String && (syncData['profile_image'] as String).isEmpty)) {
        syncData.remove('profile_image');
        syncData.remove('profileImage');
      }
      if (cloudUser != null) {
        final hasCloudMust = cloudUser.containsKey('must_change_password') ||
            cloudUser.containsKey('mustChangePassword');
        if (hasCloudMust) {
          final cm = cloudUser['must_change_password'];
          final cmCamel = cloudUser['mustChangePassword'];
          final cloudMust = cm == 1 || cm == true || cm == '1' || cmCamel == true;
          syncData['must_change_password'] = cloudMust ? 1 : 0;
          syncData['mustChangePassword'] = cloudMust;
        }
      }
      unawaited(FirestoreService().saveUser(syncData));
    } catch (_) {}

    String token = _localToken(userId);

    if (ApiClient.isCloudAvailable) {
      try {
        final resp = await _dio.post(
          '/v1/auth/session',
          options: Options(
            headers: {
              'X-School-Session': token,
              'X-School-User-Id': userId,
            },
          ),
        );
        final data = resp.data;
        if (data is Map && data['token'] is String) {
          token = data['token'] as String;
        }
      } on DioException {
        // Fall through with local token
      }
    }

    await _persistSession(userId: userId, role: role, token: token, mustChangePassword: mustChange);
    ApiClient.setSession(session: token, userId: userId);

    // Pre-warm local cache with all users for instant display across directories and analytics
    unawaited(FirestoreService().syncCloudUsersToLocal(force: true));
    unawaited(FirestoreService().syncCloudSubjectsToLocal(force: true));
    unawaited(FirestoreService().syncCloudSectionsToLocal(force: true));
    if (role == 'student' && user['section'] != null && user['section'].toString().isNotEmpty) {
      unawaited(DatabaseHelper().ensureStudentEnrolledInSectionSubjects(userId, user['section'].toString()));
    }

    return {
      'user': {
        'id': userId,
        'email': user['email'],
        'role': role,
        'fullName': user['full_name'],
        'username': user['username'] ?? user['full_name'] ?? '',
        'section': user['section'],
        'grade': user['grade'],
        'schoolId': user['school_id'] ?? 'sch_main',
        'profileImage': user['profile_image'] ?? user['profileImage'],
        'must_change_password': user['must_change_password'] == 1 || user['must_change_password'] == true || user['must_change_password'] == '1',
        'mustChangePassword': user['must_change_password'] == 1 || user['must_change_password'] == true || user['must_change_password'] == '1',
      },
      'session': token,
    };
  }

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String? username,
    String? sectionCode,
  }) async {
    final db = await DatabaseHelper().database;

    try {
      await db.execute('ALTER TABLE users ADD COLUMN username TEXT');
    } catch (_) {}

    final existingEmail = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [email.toLowerCase().trim()],
    );

    if (existingEmail.isNotEmpty) {
      throw Exception('An account with this email already exists.');
    }

    final cloudExists = await FirestoreService().isEmailRegistered(email);
    if (cloudExists) {
      throw Exception('An account with this email already exists.');
    }

    if (username != null && username.trim().isNotEmpty) {
      final existingUser = await db.query(
        'users',
        where: "LOWER(COALESCE(username, '')) = ?",
        whereArgs: [username.toLowerCase().trim()],
      );
      if (existingUser.isNotEmpty) {
        throw Exception('An account with this username already exists.');
      }
    }

    final id = '${role}_${DateTime.now().millisecondsSinceEpoch}';
    final resolvedUsername = username?.trim().isNotEmpty == true
        ? username!.trim()
        : (email.contains('@') ? email.split('@').first : fullName.trim());

    final salt = DatabaseHelper.generateSalt();
    final hashedPassword = DatabaseHelper.hashPassword(password, salt);

    final userData = {
      'id': id,
      'email': email.trim(),
      'username': resolvedUsername,
      'password': hashedPassword,
      'password_salt': salt,
      'role': role,
      'full_name': fullName.trim(),
      'created_at': DateTime.now().toIso8601String(),
    };

    // If student and section code provided, validate and bind
    String? assignedSection;
    String? assignedGrade;
    if (role == 'student' && sectionCode != null && sectionCode.trim().isNotEmpty) {
      final codeTrimmed = sectionCode.trim();

      // 1. Check sections table by enrollment_key or section name
      final verified = await DatabaseHelper().verifySectionKey(codeTrimmed);
      if (verified != null) {
        final sec = verified['section'] as Map<String, dynamic>;
        assignedSection = sec['name']?.toString();
        assignedGrade = sec['grade']?.toString();
      } else {
        // 2. Fallback to reg_links table
        final linkRow = await db.query('reg_links', where: 'code = ?', whereArgs: [codeTrimmed]);
        if (linkRow.isNotEmpty) {
          assignedSection = linkRow.first['section'] as String?;
          if (assignedSection != null && assignedSection.isNotEmpty) {
            final secRow = await db.query('sections', where: 'name = ?', whereArgs: [assignedSection]);
            if (secRow.isNotEmpty) {
              assignedGrade = secRow.first['grade'] as String?;
            }
          }
        }
      }
    }

    if (assignedSection != null) {
      userData['section'] = assignedSection;
    }
    if (assignedGrade != null) {
      userData['grade'] = assignedGrade;
    }

    await db.insert('users', userData);

    // Save to Cloud Firestore so the user can log in on any device or browser
    try {
      await FirestoreService().saveUser(userData);
    } catch (_) {}

    if (role == 'student' && sectionCode != null && sectionCode.trim().isNotEmpty) {
      // First attempt section-key enrollment (binds section + subjects atomically)
      final enrolled = await DatabaseHelper().enrollStudentBySectionKey(id, sectionCode.trim());
      if (!enrolled) {
        // Fallback to legacy registration key validation
        await DatabaseHelper().validateAndConsumeRegistrationKey(sectionCode.trim(), id);
        if (assignedSection != null && assignedSection.isNotEmpty) {
          await DatabaseHelper().autoEnrollStudentBySection(id, assignedSection, assignedGrade ?? '');
        }
      }
    }

    final token = _localToken(id);
    await _persistSession(userId: id, role: role, token: token);
    ApiClient.setSession(session: token, userId: id);

    return {
      'user': {
        'id': id,
        'email': email.trim(),
        'username': resolvedUsername,
        'role': role,
        'fullName': fullName.trim(),
        'section': assignedSection,
        'grade': assignedGrade,
        'schoolId': 'sch_main',
      },
      'session': token,
    };
  }

  Future<AuthSession?> currentSession() async {
    final db = await DatabaseHelper().database;

    // Fast-path for Web: check sessionStorage first
    if (kIsWeb) {
      if (!WebSessionHelper.hasActiveSession()) {
        return null;
      }
      final webSession = WebSessionHelper.getSavedSession();
      if (webSession != null) {
        final savedUserId = webSession['userId'] as String? ?? '';
        final savedRole = webSession['role'] as String? ?? '';
        final savedToken = webSession['token'] as String? ?? '';
        final savedMust = webSession['mustChangePassword'] == true ||
            webSession['must_change_password'] == 1 ||
            webSession['must_change_password'] == true;

        if (savedUserId.isNotEmpty && savedRole.isNotEmpty && savedToken.isNotEmpty) {
          try {
            await db.delete('sessions');
            await db.insert('sessions', {
              'user_id': savedUserId,
              'token': savedToken,
              'role': savedRole,
              'must_change_password': savedMust ? 1 : 0,
              'created_at': DateTime.now().toIso8601String(),
            });
          } catch (_) {}
          // Pre-warm local cache on Web refresh so in-memory SQLite is populated with all users, subjects, and sections
          unawaited(FirestoreService().syncCloudUsersToLocal(force: true));
          unawaited(FirestoreService().syncCloudSubjectsToLocal(force: true));
          unawaited(FirestoreService().syncCloudSectionsToLocal(force: true));
          return AuthSession(
            session: savedToken,
            userId: savedUserId,
            role: savedRole,
            mustChangePassword: savedMust,
          );
        }
      }
    }

    final rows = await db.query('sessions', orderBy: 'id DESC', limit: 1);
    if (rows.isNotEmpty) {
      final r = rows.first;
      final mustChange = r['must_change_password'] == 1 ||
          r['must_change_password'] == true ||
          r['must_change_password'] == '1';
      return AuthSession(
        session: r['token'] as String,
        userId: r['user_id'] as String,
        role: r['role'] as String,
        mustChangePassword: mustChange,
      );
    }

    // Fallback: restore active session from SharedPreferences
    if (!kIsWeb || WebSessionHelper.hasActiveSession()) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedUserId = prefs.getString('auth_session_user_id');
        final savedRole = prefs.getString('auth_session_role');
        final savedToken = prefs.getString('auth_session_token');
        final savedMust = prefs.getBool('auth_session_must_change_password') ?? false;

        if (savedUserId != null && savedRole != null && savedToken != null) {
          try {
            await db.insert('sessions', {
              'user_id': savedUserId,
              'token': savedToken,
              'role': savedRole,
              'must_change_password': savedMust ? 1 : 0,
              'created_at': DateTime.now().toIso8601String(),
            });
          } catch (_) {}
          return AuthSession(
            session: savedToken,
            userId: savedUserId,
            role: savedRole,
            mustChangePassword: savedMust,
          );
        }
      } catch (_) {}
    }

    return null;
  }

  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? username,
    String? email,
    String? profileImage,
    String? password,
  }) async {
    final db = await DatabaseHelper().database;
    final updates = <String, Object?>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (username != null) updates['username'] = username;
    if (email != null) updates['email'] = email;
    if (profileImage != null) updates['profile_image'] = profileImage;
    final cleanEmail = (email ?? '').toLowerCase().trim();
    if (password != null && password.isNotEmpty) {
      final salt = DatabaseHelper.generateSalt();
      updates['password'] = DatabaseHelper.hashPassword(password, salt);
      updates['password_salt'] = salt;
      updates['must_change_password'] = 0;
      try {
        await db.update(
          'sessions',
          {'must_change_password': 0},
          where: 'user_id = ?' + (cleanEmail.isNotEmpty ? ' OR LOWER(user_id) = ?' : ''),
          whereArgs: [userId, if (cleanEmail.isNotEmpty) cleanEmail],
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('must_change_password_$userId');
        if (cleanEmail.isNotEmpty) {
          await prefs.remove('must_change_password_$cleanEmail');
        }
      } catch (_) {}
    }
    if (updates.isNotEmpty) {
      try {
        final updatedRows = await db.update('users', updates, where: 'id = ?', whereArgs: [userId]);
        if (updatedRows == 0 && cleanEmail.isNotEmpty) {
          await db.update('users', updates, where: 'LOWER(email) = ?', whereArgs: [cleanEmail]);
        }
      } catch (_) {}
      try {
        final cloudUpdates = Map<String, dynamic>.from(updates);
        if (fullName != null) cloudUpdates['fullName'] = fullName;
        if (profileImage != null) cloudUpdates['profileImage'] = profileImage;
        if (password != null && password.isNotEmpty) {
          cloudUpdates['must_change_password'] = 0;
          cloudUpdates['mustChangePassword'] = false;
        }
        await FirestoreService().saveUser({'id': userId, if (cleanEmail.isNotEmpty) 'email': cleanEmail, ...cloudUpdates});
        if (cleanEmail.isNotEmpty && cleanEmail != userId.toLowerCase()) {
          try {
            await FirestoreService().saveUser({'id': cleanEmail, ...cloudUpdates});
          } catch (_) {}
        }
      } catch (_) {}
    }

    if (ApiClient.isCloudAvailable) {
      try {
        await _dio.put('/v1/api/users/$userId', data: {
          'fullName': ?fullName,
          'username': ?username,
          'email': ?email,
          'profileImage': ?profileImage,
          'password': ?password,
        });
      } on DioException {
        // Fall through; local SQLite is already updated
      }
    }
  }

  /// Resets a user's password using a verified OTP code.
  /// Updates password as salted SHA-256 in both local SQLite and Cloud Firestore.
  Future<void> resetPasswordWithOtp({
    required String identifier,
    required String otpCode,
    required String newPassword,
  }) async {
    final cleanIdentifier = identifier.trim();
    final cleanPass = newPassword.trim();
    if (cleanPass.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    final lockoutMsg = OtpService().getLockoutMessage(cleanIdentifier);
    if (lockoutMsg != null) {
      throw Exception(lockoutMsg);
    }

    final isValid = await OtpService().verifyOtp(
      identifier: cleanIdentifier,
      enteredCode: otpCode,
    );
    if (!isValid) {
      final postLockout = OtpService().getLockoutMessage(cleanIdentifier);
      if (postLockout != null) {
        throw Exception(postLockout);
      }
      throw Exception('Invalid or expired OTP verification code.');
    }

    // Locate the user
    Map<String, dynamic>? user = await FirestoreService().findUserByIdentifier(cleanIdentifier);
    String? resolvedUserId = user?['id']?.toString();

    final db = await DatabaseHelper().database;
    if (resolvedUserId == null) {
      final idLower = cleanIdentifier.toLowerCase();
      final rows = await db.rawQuery(
        '''SELECT * FROM users
           WHERE LOWER(id) = ?
              OR LOWER(email) = ?
              OR LOWER(COALESCE(username, '')) = ?
           LIMIT 1''',
        [idLower, idLower, idLower],
      );
      if (rows.isNotEmpty) {
        resolvedUserId = rows.first['id'] as String?;
      }
    }

    if (resolvedUserId == null) {
      throw Exception('Account could not be identified for password update.');
    }

    // Salt and hash the new password
    final salt = DatabaseHelper.generateSalt();
    final hashedPassword = DatabaseHelper.hashPassword(cleanPass, salt);

    // Update SQLite
    try {
      await db.update(
        'users',
        {
          'password': hashedPassword,
          'password_salt': salt,
          'must_change_password': 0,
        },
        where: 'id = ?',
        whereArgs: [resolvedUserId],
      );
      await db.update('sessions', {'must_change_password': 0},
          where: 'user_id = ?', whereArgs: [resolvedUserId]);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('must_change_password_$resolvedUserId');
    } catch (e) {
      debugPrint('[AuthRepository] Local DB reset update error: $e');
    }

    // Update Cloud Firestore
    try {
      await FirestoreService().saveUser({
        'id': resolvedUserId,
        'password': hashedPassword,
        'password_salt': salt,
        'must_change_password': 0,
        'mustChangePassword': false,
      });
    } catch (e) {
      debugPrint('[AuthRepository] Firestore reset update error: $e');
    }
  }

  /// Completes password reset using a verified ephemeral Reset Ticket
  Future<void> completePasswordResetWithTicket({
    required String identifier,
    required String resetTicket,
    required String newPassword,
  }) async {
    final cleanIdentifier = identifier.trim();
    final cleanPass = newPassword.trim();
    if (cleanPass.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    final isValidTicket = await OtpService().validateAndConsumeResetTicket(
      identifier: cleanIdentifier,
      resetTicket: resetTicket,
    );
    if (!isValidTicket) {
      throw Exception('Verification session expired or invalid. Please verify your code again.');
    }

    // Locate the user
    Map<String, dynamic>? user = await FirestoreService().findUserByIdentifier(cleanIdentifier);
    String? resolvedUserId = user?['id']?.toString();

    final db = await DatabaseHelper().database;
    if (resolvedUserId == null) {
      final idLower = cleanIdentifier.toLowerCase();
      final rows = await db.rawQuery(
        '''SELECT * FROM users
           WHERE LOWER(id) = ?
              OR LOWER(email) = ?
              OR LOWER(COALESCE(username, '')) = ?
           LIMIT 1''',
        [idLower, idLower, idLower],
      );
      if (rows.isNotEmpty) {
        resolvedUserId = rows.first['id'] as String?;
      }
    }

    if (resolvedUserId == null) {
      throw Exception('Account could not be identified for password update.');
    }

    // Salt and hash the new password
    final salt = DatabaseHelper.generateSalt();
    final hashedPassword = DatabaseHelper.hashPassword(cleanPass, salt);

    // Update SQLite
    try {
      await db.update(
        'users',
        {
          'password': hashedPassword,
          'password_salt': salt,
          'must_change_password': 0,
        },
        where: 'id = ?',
        whereArgs: [resolvedUserId],
      );
      await db.update('sessions', {'must_change_password': 0},
          where: 'user_id = ?', whereArgs: [resolvedUserId]);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('must_change_password_$resolvedUserId');
    } catch (e) {
      debugPrint('[AuthRepository] Local DB reset update error: $e');
    }

    // Update Cloud Firestore
    try {
      await FirestoreService().saveUser({
        'id': resolvedUserId,
        'password': hashedPassword,
        'password_salt': salt,
        'must_change_password': 0,
        'mustChangePassword': false,
      });
    } catch (e) {
      debugPrint('[AuthRepository] Firestore reset update error: $e');
    }
  }

  Future<void> logout() async {
    final db = await DatabaseHelper().database;
    final session = await currentSession();
    if (session != null && ApiClient.isCloudAvailable) {
      try {
        await _dio.post(
          '/v1/auth/revoke',
          options: Options(
            headers: {
              'X-School-Session': session.session,
              'X-School-User-Id': session.userId,
            },
          ),
        );
      } on DioException {
        // ignore network errors during logout
      }
    }
    await db.delete('sessions');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_session_user_id');
      await prefs.remove('auth_session_role');
      await prefs.remove('auth_session_token');
      await prefs.remove('auth_session_must_change_password');
    } catch (_) {}
    ApiClient.clearSession();
    WebSessionHelper.clearSession();
  }

  Future<void> _persistSession({
    required String userId,
    required String role,
    required String token,
    bool mustChangePassword = false,
  }) async {
    final db = await DatabaseHelper().database;
    try {
      await db.execute('ALTER TABLE sessions ADD COLUMN must_change_password INTEGER DEFAULT 0');
    } catch (_) {}
    await db.delete('sessions');
    await db.insert('sessions', {
      'user_id': userId,
      'token': token,
      'role': role,
      'must_change_password': mustChangePassword ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    });

    if (kIsWeb) {
      WebSessionHelper.saveSession(
        userId: userId,
        role: role,
        token: token,
        mustChangePassword: mustChangePassword,
      );
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_session_user_id', userId);
      await prefs.setString('auth_session_role', role);
      await prefs.setString('auth_session_token', token);
      await prefs.setBool('auth_session_must_change_password', mustChangePassword);
    } catch (_) {}
  }

  static Future<void> _applyCloudProfile(
    Map<String, dynamic> cloudUser,
    Map<String, dynamic>? user,
    String userId,
    Database db,
  ) async {
    final cloudPhoto = (cloudUser['profileImage'] ?? cloudUser['profile_image']) as String?;
    if (cloudPhoto != null && cloudPhoto.trim().isNotEmpty) {
      if (user != null) {
        user['profile_image'] = cloudPhoto;
        user['profileImage'] = cloudPhoto;
      }
      try {
        await db.update('users', {'profile_image': cloudPhoto}, where: 'id = ?', whereArgs: [userId]);
      } catch (_) {}
    }
    final hasCloudMust = cloudUser.containsKey('must_change_password') ||
        cloudUser.containsKey('mustChangePassword');
    if (hasCloudMust) {
      final cm = cloudUser['must_change_password'];
      final cmCamel = cloudUser['mustChangePassword'];
      final cloudMust = cm == 1 || cm == true || cm == '1' || cmCamel == true;
      if (user != null) {
        user['must_change_password'] = cloudMust ? 1 : 0;
      }
      final cleanEmail = (cloudUser['email']?.toString() ?? '').toLowerCase().trim();
      try {
        await db.update(
          'users',
          {'must_change_password': cloudMust ? 1 : 0},
          where: 'id = ?' + (cleanEmail.isNotEmpty ? ' OR LOWER(email) = ?' : ''),
          whereArgs: [userId, if (cleanEmail.isNotEmpty) cleanEmail],
        );
        await db.update(
          'sessions',
          {'must_change_password': cloudMust ? 1 : 0},
          where: 'user_id = ?' + (cleanEmail.isNotEmpty ? ' OR LOWER(user_id) = ?' : ''),
          whereArgs: [userId, if (cleanEmail.isNotEmpty) cleanEmail],
        );
        final prefs = await SharedPreferences.getInstance();
        if (!cloudMust) {
          await prefs.remove('must_change_password_$userId');
          if (cleanEmail.isNotEmpty) {
            await prefs.remove('must_change_password_$cleanEmail');
          }
        } else {
          await prefs.setBool('must_change_password_$userId', true);
        }
      } catch (_) {}
    }
  }

  String _localToken(String userId) {
    final rand = Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    final tokenHex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'aira_sec_${userId}_$tokenHex';
  }
}
