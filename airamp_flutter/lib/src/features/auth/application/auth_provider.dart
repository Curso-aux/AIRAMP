import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/api/api_client.dart';
import '../../../core/components/auth/required_change_password_dialog.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/firestore_service.dart';
import '../../../core/utils/web_session_helper.dart';
import '../data/auth_repository.dart';

class User {
  final String id;
  final String email;
  final String role;
  final String fullName;
  final String username;
  final String? profileImage;
  final String? section;
  final String? grade;
  final String? schoolId;
  final List<String> availableRoles;
  final bool mustChangePassword;

  User({
    required this.id,
    required this.email,
    required this.role,
    required this.fullName,
    this.username = '',
    this.profileImage,
    this.section,
    this.grade,
    this.schoolId = 'sch_main',
    this.availableRoles = const ['student', 'teacher'],
    this.mustChangePassword = false,
  });

  bool get isSuperAdmin => role == 'super_admin';
  bool get isSchoolAdmin => role == 'admin';
  bool get isAdmin => role == 'admin' || role == 'super_admin';
  bool get isTeacher => role == 'teacher';
  bool get isStudent => role == 'student';

  /// Permission Matrix evaluator for Role-Based Access Control (RBAC)
  bool hasPermission(String permission) {
    if (isSuperAdmin) return true;
    switch (permission) {
      case 'manage_schools':
      case 'manage_admins':
      case 'system_audit':
        return false;
      case 'manage_teachers':
      case 'manage_students':
      case 'manage_subjects':
      case 'manage_sections':
      case 'bulk_import':
      case 'school_announcements':
        return isSchoolAdmin;
      case 'manage_schedules':
      case 'grade_submissions':
      case 'create_quizzes':
      case 'section_announcements':
        return isSchoolAdmin || isTeacher;
      case 'view_courses':
      case 'view_schedules':
      case 'take_quizzes':
      case 'submit_assignments':
        return true;
      default:
        return false;
    }
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final mustChange = json['mustChangePassword'] == true ||
        json['must_change_password'] == 1 ||
        json['must_change_password'] == true ||
        json['must_change_password'] == '1';

    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'student',
      fullName: json['fullName'] ?? json['full_name'] ?? '',
      username: json['username'] ?? json['fullName'] ?? json['full_name'] ?? '',
      profileImage: json['profileImage'] ?? json['profile_image'],
      section: json['section'],
      grade: json['grade'],
      schoolId: json['schoolId'] ?? json['school_id'] ?? 'sch_main',
      availableRoles: (json['availableRoles'] as List?)?.cast<String>() ?? const ['student', 'teacher'],
      mustChangePassword: mustChange,
    );
  }

  /// Create a copy with updated fields.
  User copyWith({
    String? fullName,
    String? username,
    String? email,
    String? profileImage,
    String? role,
    String? section,
    String? grade,
    String? schoolId,
    List<String>? availableRoles,
    bool? mustChangePassword,
  }) {
    return User(
      id: id,
      email: email ?? this.email,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      profileImage: profileImage ?? this.profileImage,
      section: section ?? this.section,
      grade: grade ?? this.grade,
      schoolId: schoolId ?? this.schoolId,
      availableRoles: availableRoles ?? this.availableRoles,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AuthNotifier extends Notifier<User?> {
  bool isLoading = false;

  Map<String, dynamic> _userToMap(User user) {
    return {
      'id': user.id,
      'email': user.email,
      'role': user.role,
      'fullName': user.fullName,
      'username': user.username,
      'profileImage': user.profileImage,
      'section': user.section,
      'grade': user.grade,
      'schoolId': user.schoolId,
      'availableRoles': user.availableRoles,
      'mustChangePassword': user.mustChangePassword,
    };
  }

  @override
  User? build() {
    if (kIsWeb && WebSessionHelper.hasActiveSession()) {
      try {
        final cached = WebSessionHelper.getSavedUserProfile();
        if (cached != null && cached.isNotEmpty) {
          final user = User.fromJson(cached);
          final savedSession = WebSessionHelper.getSavedSession();
          final token = savedSession?['token'] as String? ?? '';
          if (token.isNotEmpty) {
            ApiClient.setSession(session: token, userId: user.id);
          }
          return user;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> login(String identifier, String password) async {
    final repository = ref.read(authRepositoryProvider);
    isLoading = true;

    try {
      final data = await repository.login(identifier, password);
      final user = User.fromJson(data['user']);
      state = user;
      WebSessionHelper.markSessionActive(user.id);
      if (kIsWeb) {
        WebSessionHelper.saveUserProfile(_userToMap(user));
      }
      final prefs = await SharedPreferences.getInstance();
      if (user.mustChangePassword) {
        try {
          await prefs.setBool('must_change_password_${user.id}', true);
        } catch (_) {}
      } else {
        try {
          await prefs.remove('must_change_password_${user.id}');
        } catch (_) {}
      }
    } finally {
      isLoading = false;
    }
  }

  /// Switch the active role between student and teacher (Multi-Role support)
  Future<void> switchRole(String newRole) async {
    if (state == null) return;
    state = state!.copyWith(role: newRole);
    if (kIsWeb) {
      WebSessionHelper.saveUserProfile(_userToMap(state!));
      final savedSession = WebSessionHelper.getSavedSession();
      if (savedSession != null) {
        WebSessionHelper.saveSession(
          userId: savedSession['userId'] ?? state!.id,
          role: newRole,
          token: savedSession['token'] ?? '',
          mustChangePassword: savedSession['mustChangePassword'] == true,
        );
      }
    }

    // Update active session role in local database if a session exists
    try {
      final repository = ref.read(authRepositoryProvider);
      final session = await repository.currentSession();
      if (session != null) {
        final db = await DatabaseHelper().database;
        await db.update(
          'sessions',
          {'role': newRole},
          where: 'token = ?',
          whereArgs: [session.session],
        );
      }
    } catch (e) {
      debugPrint('[AuthProvider] Failed to persist role switch in session: $e');
    }
  }

  /// Restore user from persisted session on app start.
  Future<void> bootstrap() async {
    final repository = ref.read(authRepositoryProvider);
    final session = await repository.currentSession();
    if (session == null) return;

    // Web Session-Only Guard (Option B):
    // In web browsers, sessionStorage is purged automatically when the tab or window is closed.
    // If no active session marker exists in sessionStorage, terminate the dormant session so
    // that opening a new browser window returns the user cleanly to the public landing page.
    if (kIsWeb && !WebSessionHelper.hasActiveSession()) {
      await repository.logout();
      return;
    }

    // Strict platform separation:
    // On Mobile / Desktop (!kIsWeb): Admin sessions are NOT permitted. Mobile is exclusively for Students and Teachers!
    if (!kIsWeb && (session.role == 'admin' || session.role == 'super_admin')) {
      await repository.logout();
      return;
    }

    // On Web (kIsWeb): Fast restore from cached user profile in sessionStorage immediately if state is not set yet
    if (kIsWeb && state == null) {
      final cached = WebSessionHelper.getSavedUserProfile();
      if (cached != null && cached.isNotEmpty) {
        state = User.fromJson(cached);
        ApiClient.setSession(session: session.session, userId: session.userId);
      }
    }

    // On Web: Ensure in-memory SQLite contains current authenticated user row
    if (kIsWeb && state != null) {
      try {
        final db = await DatabaseHelper().database;
        await db.insert('users', {
          'id': state!.id,
          'email': state!.email,
          'username': state!.username,
          'role': state!.role,
          'full_name': state!.fullName,
          'profile_image': state!.profileImage,
          'section': state!.section,
          'grade': state!.grade,
          'school_id': state!.schoolId,
          'must_change_password': state!.mustChangePassword ? 1 : 0,
          'created_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (_) {}
    }

    // On Web (kIsWeb): Web portal is accessible to Students, Teachers, and Administrators.

    // 1. Check persistent safety guard from SharedPreferences
    bool persistentMustChange = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      persistentMustChange = prefs.getBool('must_change_password_${session.userId}') == true;
    } catch (_) {}

    // 2. Restore complete user profile from local database
    final db = await DatabaseHelper().database;
    List<Map<String, dynamic>> userRows = await db.query('users', where: 'id = ?', whereArgs: [session.userId]);
    if (userRows.isEmpty) {
      userRows = await db.query('users', where: 'LOWER(email) = ?', whereArgs: [session.userId.toLowerCase().trim()]);
    }
    if (userRows.isEmpty) {
      userRows = await db.query('users', where: 'LOWER(username) = ?', whereArgs: [session.userId.toLowerCase().trim()]);
    }

    final localAvatar = userRows.isNotEmpty
        ? (userRows.first['profile_image'] ?? userRows.first['profileImage']) as String?
        : null;

    final localMustChange = session.mustChangePassword ||
        persistentMustChange ||
        (userRows.isNotEmpty &&
            (userRows.first['must_change_password'] == 1 ||
             userRows.first['must_change_password'] == true ||
             userRows.first['must_change_password'] == '1'));

    Map<String, dynamic>? cloudUser;
    // Always query Cloud Firestore if the local session suspects a password change,
    // ensuring password changes made on another machine (e.g. Laptop A) reflect immediately on Laptop B.
    final needsCloudLookup = userRows.isEmpty ||
        localAvatar == null ||
        localAvatar.trim().isEmpty ||
        localMustChange;
    if (needsCloudLookup) {
      try {
        cloudUser = await FirestoreService()
            .findUserByIdentifier(session.userId)
            .timeout(const Duration(seconds: 4), onTimeout: () => null);
        if (cloudUser == null && userRows.isNotEmpty) {
          final uEmail = (userRows.first['email'] as String? ?? '').trim();
          if (uEmail.isNotEmpty && uEmail != session.userId) {
            cloudUser = await FirestoreService()
                .findUserByIdentifier(uEmail)
                .timeout(const Duration(seconds: 4), onTimeout: () => null);
          }
        }
      } catch (_) {}
    }

    bool mustChange = localMustChange;
    if (cloudUser != null) {
      final hasCloudMust = cloudUser.containsKey('must_change_password') ||
          cloudUser.containsKey('mustChangePassword');
      if (hasCloudMust) {
        final cm = cloudUser['must_change_password'];
        final cmCamel = cloudUser['mustChangePassword'];
        final cloudMust = cm == 1 || cm == true || cm == '1' || cmCamel == true;
        mustChange = cloudMust;
      }
    }

    if (mustChange) {
      try {
        if (userRows.isNotEmpty) {
          await db.update('users', {'must_change_password': 1},
              where: 'id = ?', whereArgs: [userRows.first['id']]);
        }
        await db.update('sessions', {'must_change_password': 1});
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('must_change_password_${session.userId}', true);
      } catch (_) {}
    } else {
      try {
        final cleanEmail = (userRows.isNotEmpty ? (userRows.first['email'] as String? ?? '') : '').toLowerCase().trim();
        if (userRows.isNotEmpty) {
          await db.update('users', {'must_change_password': 0},
              where: 'id = ?' + (cleanEmail.isNotEmpty ? ' OR LOWER(email) = ?' : ''),
              whereArgs: [userRows.first['id'], if (cleanEmail.isNotEmpty) cleanEmail]);
        }
        await db.update('sessions', {'must_change_password': 0});
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('must_change_password_${session.userId}');
        if (cleanEmail.isNotEmpty) {
          await prefs.remove('must_change_password_$cleanEmail');
        }
      } catch (_) {}
    }

    if (userRows.isNotEmpty) {
      final u = Map<String, dynamic>.from(userRows.first);
      final actualRole = u['role'] as String? ?? session.role;

      var profileImage = (u['profile_image'] ?? u['profileImage']) as String?;
      if ((profileImage == null || profileImage.trim().isEmpty) && cloudUser != null) {
        final cloudPhoto = (cloudUser['profileImage'] ?? cloudUser['profile_image']) as String?;
        if (cloudPhoto != null && cloudPhoto.trim().isNotEmpty) {
          profileImage = cloudPhoto;
          try {
            await db.update('users', {'profile_image': cloudPhoto}, where: 'id = ?', whereArgs: [session.userId]);
          } catch (_) {}
        }
      }

      state = User(
        id: session.userId,
        email: u['email'] as String? ?? '',
        role: actualRole,
        fullName: u['full_name'] as String? ?? session.userId,
        username: u['username'] as String? ?? '',
        profileImage: profileImage,
        section: u['section'] as String?,
        grade: u['grade'] as String?,
        schoolId: u['school_id'] as String? ?? 'sch_main',
        mustChangePassword: mustChange,
      );
    } else {
      state = User(
        id: session.userId,
        email: cloudUser?['email'] as String? ?? '',
        role: cloudUser?['role'] as String? ?? session.role,
        fullName: cloudUser?['full_name'] as String? ?? session.userId,
        username: cloudUser?['username'] as String? ?? '',
        profileImage: (cloudUser?['profileImage'] ?? cloudUser?['profile_image']) as String?,
        section: cloudUser?['section'] as String?,
        grade: cloudUser?['grade'] as String?,
        schoolId: cloudUser?['school_id'] as String? ?? 'sch_main',
        mustChangePassword: mustChange,
      );
    }
    if (kIsWeb && state != null) {
      WebSessionHelper.saveUserProfile(_userToMap(state!));
    }
    ApiClient.setSession(session: session.session, userId: session.userId);

    // Register real-time sync hook to refresh active user state when background cloud sync updates store
    FirestoreService.addSyncListener(() {
      refreshProfile();
    });
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String? username,
    String? sectionCode,
  }) async {
    final repository = ref.read(authRepositoryProvider);
    isLoading = true;

    try {
      final data = await repository.register(
        fullName: fullName,
        email: email,
        password: password,
        role: role,
        username: username,
        sectionCode: sectionCode,
      );
      final user = User.fromJson(data['user']);
      state = user;
      WebSessionHelper.markSessionActive(user.id);
      if (kIsWeb) {
        WebSessionHelper.saveUserProfile(_userToMap(user));
      }
    } finally {
      isLoading = false;
    }
  }

  /// Reloads current user's profile from local database and cloud to ensure the latest avatar and metadata are active.
  Future<void> refreshProfile() async {
    if (state == null) return;
    try {
      final db = await DatabaseHelper().database;
      final cleanEmail = state!.email.toLowerCase().trim();
      final rows = await db.query(
        'users',
        where: 'id = ?' + (cleanEmail.isNotEmpty ? ' OR LOWER(email) = ?' : ''),
        whereArgs: [state!.id, if (cleanEmail.isNotEmpty) cleanEmail],
      );
      if (rows.isNotEmpty) {
        final r = rows.first;
        final photo = (r['profile_image'] ?? r['profileImage']) as String?;
        final mustChange = r['must_change_password'] == 1 ||
            r['must_change_password'] == true ||
            r['must_change_password'] == '1';
        // If state already has mustChangePassword == false in this active session,
        // do not allow a stale SQLite row to revert it back to true.
        final resolvedMustChange = state!.mustChangePassword ? mustChange : false;
        state = state!.copyWith(
          profileImage: (photo != null && photo.isNotEmpty) ? photo : state!.profileImage,
          mustChangePassword: resolvedMustChange,
        );
        if (kIsWeb) {
          WebSessionHelper.saveUserProfile(_userToMap(state!));
        }
      }
    } catch (_) {}
  }

  /// Update the current user's profile fields locally.
  /// When backend is available, this will also call the API.
  Future<void> updateProfile({
    String? fullName,
    String? username,
    String? email,
    String? profileImage,
    String? password,
  }) async {
    if (state == null) return;

    final isPasswordChanged = password != null && password.trim().isNotEmpty;

    if (isPasswordChanged) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('must_change_password_${state!.id}');
        if (state!.email.isNotEmpty) {
          await prefs.remove('must_change_password_${state!.email}');
          await prefs.remove('must_change_password_${state!.email.toLowerCase().trim()}');
        }
      } catch (_) {}

      // Persist security notification for user without circular provider dependency
      DatabaseHelper().createNotification(
        userId: state!.id,
        type: 'security',
        title: 'Security Alert 🔐',
        message: 'Your account password was updated successfully.',
        targetRoute: state!.role == 'teacher'
            ? '/teacher/profile'
            : (state!.role == 'student' ? '/student/profile' : '/admin/profile'),
      ).catchError((_) => '');
    }

    // Update local state immediately
    state = state!.copyWith(
      fullName: fullName,
      username: username,
      email: email,
      profileImage: profileImage,
      mustChangePassword: isPasswordChanged ? false : state!.mustChangePassword,
    );
    if (kIsWeb) {
      WebSessionHelper.saveUserProfile(_userToMap(state!));
    }

    // Persist changes to local SQLite and cloud backend
    final repository = ref.read(authRepositoryProvider);
    try {
      await repository.updateProfile(
        userId: state!.id,
        fullName: fullName,
        email: email ?? state!.email,
        username: username ?? state!.username,
        profileImage: profileImage,
        password: password,
      );
    } catch (_) {
      // Silently continue
    }
  }

  /// Resets password for a user using verified OTP (for forgot password)
  Future<void> resetPasswordWithOtp({
    required String identifier,
    required String otpCode,
    required String newPassword,
  }) async {
    final repository = ref.read(authRepositoryProvider);
    await repository.resetPasswordWithOtp(
      identifier: identifier,
      otpCode: otpCode,
      newPassword: newPassword,
    );
  }

  /// Completes password reset using verified ephemeral reset ticket
  Future<void> completePasswordResetWithTicket({
    required String identifier,
    required String resetTicket,
    required String newPassword,
  }) async {
    final repository = ref.read(authRepositoryProvider);
    await repository.completePasswordResetWithTicket(
      identifier: identifier,
      resetTicket: resetTicket,
      newPassword: newPassword,
    );
  }

  /// Update the current student's section and grade upon key enrollment
  void updateUserSection({required String section, required String grade}) {
    if (state == null) return;
    state = state!.copyWith(
      section: section,
      grade: grade,
    );
    if (kIsWeb) {
      WebSessionHelper.saveUserProfile(_userToMap(state!));
    }
  }

  /// Clear student's current section and grade
  void clearUserSection() {
    if (state == null) return;
    state = User(
      id: state!.id,
      email: state!.email,
      role: state!.role,
      fullName: state!.fullName,
      username: state!.username,
      profileImage: state!.profileImage,
      section: null,
      grade: null,
    );
    if (kIsWeb) {
      WebSessionHelper.saveUserProfile(_userToMap(state!));
    }
  }

  Future<void> logout() async {
    final repository = ref.read(authRepositoryProvider);
    final userId = state?.id;
    isLoading = true;
    try {
      if (userId != null && state?.mustChangePassword != true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('must_change_password_$userId');
      }
    } catch (_) {}
    try {
      WebSessionHelper.clearSession();
      await repository.logout();
    } finally {
      isLoading = false;
      state = null;
      RequiredChangePasswordDialog.resetSession();
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, User?>(() {
  return AuthNotifier();
});
