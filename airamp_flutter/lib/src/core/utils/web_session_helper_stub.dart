/// Stub implementation of WebSessionHelper for non-web platforms (mobile & desktop).
///
/// On mobile/desktop, sessions persist across app restarts as expected on native OSes.
class WebSessionHelper {
  static bool hasActiveSession() => true;

  static void markSessionActive(String userId) {}

  static void saveSession({
    required String userId,
    required String role,
    required String token,
    bool mustChangePassword = false,
  }) {}

  static Map<String, dynamic>? getSavedSession() => null;

  static void saveUserProfile(Map<String, dynamic> userJson) {}

  static Map<String, dynamic>? getSavedUserProfile() => null;

  static void clearSession() {}
}
