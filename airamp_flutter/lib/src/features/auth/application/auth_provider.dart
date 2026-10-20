import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../../../core/components/auth/required_change_password_dialog.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/firestore_service.dart';
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
      profileImage: json['profileImage'],
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

  @override
  User? build() {
    return null;
  }

  Future<void> login(String identifier, String password) async {
    final repository = ref.read(authRepositoryProvider);
    isLoading = true;

    try {
      final data = await repository.login(identifier, password);
      final user = User.fromJson(data['user']);
      state = user;
      if (user.mustChangePassword) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('must_change_password_${user.id}', true);
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

    // Strict platform separation:
    // On Mobile / Desktop (!kIsWeb): Admin sessions are NOT permitted. Mobile is exclusively for Students and Teachers!
    if (!kIsWeb && (session.role == 'admin' || session.role == 'super_admin')) {
      await repository.logout();
      return;
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

    Map<String, dynamic>? cloudUser;
    final needsCloudLookup = userRows.isEmpty;
    if (needsCloudLookup) {
      try {
        cloudUser = await FirestoreService()
            .findUserByIdentifier(session.userId)
            .timeout(const Duration(seconds: 3), onTimeout: () => null);
      } catch (_) {}
    }

    if (userRows.isNotEmpty) {
      final u = userRows.first;
      final actualRole = u['role'] as String? ?? session.role;
      var mustChange = session.mustChangePassword ||
          persistentMustChange ||
          u['must_change_password'] == 1 ||
          u['must_change_password'] == true ||
          u['must_change_password'] == '1';

      if (!mustChange && cloudUser != null) {
        final cm = cloudUser['must_change_password'];
        if (cm == 1 || cm == true || cm == '1') {
          mustChange = true;
        }
      }

      if (mustChange) {
        try {
          await db.update('users', {'must_change_password': 1},
              where: 'id = ?', whereArgs: [u['id']]);
          await db.update('sessions', {'must_change_password': 1});
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('must_change_password_${session.userId}', true);
        } catch (_) {}
      }

      state = User(
        id: session.userId,
        email: u['email'] as String? ?? '',
        role: actualRole,
        fullName: u['full_name'] as String? ?? session.userId,
        username: u['username'] as String? ?? '',
        section: u['section'] as String?,
        grade: u['grade'] as String?,
        schoolId: u['school_id'] as String? ?? 'sch_main',
        mustChangePassword: mustChange,
      );
    } else {
      final cloudMustChange = cloudUser != null &&
          (cloudUser['must_change_password'] == 1 ||
           cloudUser['must_change_password'] == true ||
           cloudUser['must_change_password'] == '1');

      final mustChange = session.mustChangePassword || persistentMustChange || cloudMustChange;

      if (mustChange) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('must_change_password_${session.userId}', true);
        } catch (_) {}
      }

      state = User(
        id: session.userId,
        email: cloudUser?['email'] as String? ?? '',
        role: cloudUser?['role'] as String? ?? session.role,
        fullName: cloudUser?['full_name'] as String? ?? session.userId,
        username: cloudUser?['username'] as String? ?? '',
        section: cloudUser?['section'] as String?,
        grade: cloudUser?['grade'] as String?,
        schoolId: cloudUser?['school_id'] as String? ?? 'sch_main',
        mustChangePassword: mustChange,
      );
    }
    ApiClient.setSession(session: session.session, userId: session.userId);
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
    } finally {
      isLoading = false;
    }
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
      } catch (_) {}
    }

    // Update local state immediately
    state = state!.copyWith(
      fullName: fullName,
      username: username,
      email: email,
      profileImage: profileImage,
      mustChangePassword: isPasswordChanged ? false : state!.mustChangePassword,
    );

    // Persist changes to local SQLite and cloud backend
    final repository = ref.read(authRepositoryProvider);
    try {
      await repository.updateProfile(
        userId: state!.id,
        fullName: fullName,
        email: email,
        username: username,
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

  /// Update the current student's section and grade upon key enrollment
  void updateUserSection({required String section, required String grade}) {
    if (state == null) return;
    state = state!.copyWith(
      section: section,
      grade: grade,
    );
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
  }

  Future<void> logout() async {
    final repository = ref.read(authRepositoryProvider);
    final userId = state?.id;
    isLoading = true;
    try {
      if (userId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('must_change_password_$userId');
      }
    } catch (_) {}
    try {
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
