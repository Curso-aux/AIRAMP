/// Stub implementation of WebSessionHelper for non-web platforms (mobile & desktop).
///
/// On mobile/desktop, sessions persist across app restarts as expected on native OSes.
class WebSessionHelper {
  static bool hasActiveSession() => true;

  static void markSessionActive(String userId) {}

  static void clearSession() {}
}

