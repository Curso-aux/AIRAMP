import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../data/auth_repository.dart';

class User {
  final String id;
  final String email;
  final String role;
  final String fullName;

  User({
    required this.id,
    required this.email,
    required this.role,
    required this.fullName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'student',
      fullName: json['fullName'] ?? '',
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRepository(dio);
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
