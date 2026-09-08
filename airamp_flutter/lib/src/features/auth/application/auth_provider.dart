import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../data/auth_repository.dart';

class User {
  final String id;
  final String email;
  final String role;
  final String fullName;
  final String username;
  final String? profileImage;

  User({
    required this.id,
    required this.email,
    required this.role,
    required this.fullName,
    this.username = '',
    this.profileImage,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'student',
      fullName: json['fullName'] ?? '',
      username: json['username'] ?? json['fullName'] ?? '',
      profileImage: json['profileImage'],
    );
  }

  /// Create a copy with updated fields.
  User copyWith({
    String? fullName,
    String? username,
    String? email,
    String? profileImage,
    String? role,
  }) {
    return User(
      id: id,
      email: email ?? this.email,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      profileImage: profileImage ?? this.profileImage,
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

    state = User(
      id: session.userId,
      email: '',
      role: session.role,
      fullName: session.userId,
    );
    ApiClient.setSession(session: session.session, userId: session.userId);
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    final repository = ref.read(authRepositoryProvider);
    isLoading = true;

    try {
      final data = await repository.register(
        fullName: fullName,
        email: email,
        password: password,
        role: role,
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

    // Persist changes to backend when available
    if (ApiClient.isCloudAvailable) {
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
        // Silently continue; SQLite state already updated locally
      }
    }
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
