// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

/// Web implementation of WebSessionHelper utilizing browser sessionStorage.
///
/// In modern browsers, sessionStorage is strictly scoped to the lifecycle of the browser tab.
/// When the user refreshes/reloads the page in the same tab, sessionStorage remains preserved!
/// When the user closes the browser tab or window, sessionStorage is automatically purged.
/// This guarantees:
/// 1. Refreshing/reloading keeps the user authenticated on their current screen.
/// 2. Closing the tab or browser window terminates the active session.
class WebSessionHelper {
  static const String _activeKey = 'aira_web_active_session';
  static const String _sessionKey = 'aira_web_auth_session';
  static const String _userKey = 'aira_web_user_profile';

  /// Returns true if this browser tab has an active session marker.
  static bool hasActiveSession() {
    try {
      final val = html.window.sessionStorage[_activeKey];
      return val != null && val.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Sets the active session flag in sessionStorage and sets a tab/session cookie.
  static void markSessionActive(String userId) {
    try {
      html.window.sessionStorage[_activeKey] = userId.isNotEmpty ? userId : 'active';
      // Session cookie without expiration date naturally clears on browser/tab exit
      html.document.cookie = 'aira_session_active=1; path=/; SameSite=Lax';
    } catch (_) {}
  }

  /// Stores full session credentials in sessionStorage.
  static void saveSession({
    required String userId,
    required String role,
    required String token,
    bool mustChangePassword = false,
  }) {
    try {
      final sessionMap = {
        'userId': userId,
        'role': role,
        'token': token,
        'mustChangePassword': mustChangePassword,
      };
      html.window.sessionStorage[_sessionKey] = jsonEncode(sessionMap);
      markSessionActive(userId);
    } catch (_) {}
  }

  /// Retrieves saved session credentials from sessionStorage (if any).
  static Map<String, dynamic>? getSavedSession() {
    try {
      final raw = html.window.sessionStorage[_sessionKey];
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Stores complete user profile JSON in sessionStorage for instant (0ms) state restore on reload.
  static void saveUserProfile(Map<String, dynamic> userJson) {
    try {
      html.window.sessionStorage[_userKey] = jsonEncode(userJson);
      final uid = (userJson['id'] ?? '').toString();
      markSessionActive(uid);
    } catch (_) {}
  }

  /// Retrieves cached user profile JSON from sessionStorage (if any).
  static Map<String, dynamic>? getSavedUserProfile() {
    try {
      final raw = html.window.sessionStorage[_userKey];
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Clears the active session and user credentials from sessionStorage and expires the cookie.
  static void clearSession() {
    try {
      html.window.sessionStorage.remove(_activeKey);
      html.window.sessionStorage.remove(_sessionKey);
      html.window.sessionStorage.remove(_userKey);
      html.document.cookie = 'aira_session_active=; path=/; max-age=0; SameSite=Lax';
    } catch (_) {}
  }
}
