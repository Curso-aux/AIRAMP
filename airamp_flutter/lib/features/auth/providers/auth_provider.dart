import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginPendingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void setState(bool value) => state = value;
}

final loginPendingProvider = NotifierProvider<LoginPendingNotifier, bool>(() {
  return LoginPendingNotifier();
});

class AuthNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> login(String identifier, String password) async {
    await Future.delayed(const Duration(seconds: 2));
    state = true;
  }
}

final authProvider = NotifierProvider<AuthNotifier, bool>(() {
  return AuthNotifier();
});
