import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/database/database_helper.dart';
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

  User({
    required this.id,
    required this.email,
    required this.role,
    required this.fullName,
    this.username = '',
    this.profileImage,
    this.section,
    this.grade,
  });

  bool get isTeacher => role == 'teacher';
  bool get isStudent => role == 'student';
  bool get isAdmin => role == 'admin' || role == 'super_admin';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'student',
      fullName: json['fullName'] ?? '',
      username: json['username'] ?? json['fullName'] ?? '',
      profileImage: json['profileImage'],
      section: json['section'],
      grade: json['grade'],
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
    } finally {
      isLoading = false;
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

    // On Web (kIsWeb): Non-admin sessions are NOT permitted. Web is exclusively for School Administrators!
    if (kIsWeb && (session.role != 'admin' && session.role != 'super_admin')) {
      await repository.logout();
      return;
    }

    // Restore complete user profile from local database
    final db = await DatabaseHelper().database;
    final userRows = await db.query('users', where: 'id = ?', whereArgs: [session.userId]);
    if (userRows.isNotEmpty) {
      final u = userRows.first;
      final actualRole = u['role'] as String? ?? session.role;
      state = User(
        id: session.userId,
        email: u['email'] as String? ?? '',
        role: actualRole,
        fullName: u['full_name'] as String? ?? session.userId,
        username: u['username'] as String? ?? '',
        section: u['section'] as String?,
        grade: u['grade'] as String?,
      );
    } else {
      state = User(
        id: session.userId,
        email: '',
        role: session.role,
        fullName: session.userId,
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

    // Update local state immediately
    state = state!.copyWith(
      fullName: fullName,
      username: username,
      email: email,
      profileImage: profileImage,
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
    isLoading = true;
    try {
      await repository.logout();
    } finally {
      isLoading = false;
      state = null;
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, User?>(() {
  return AuthNotifier();
});
