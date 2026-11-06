// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Web implementation of WebSessionHelper utilizing browser sessionStorage.
///
/// In modern browsers, sessionStorage is strictly scoped to the lifecycle of the browser tab.
/// When the user closes the tab or the browser window, sessionStorage is automatically purged.
/// This enforces Option B: closing the browser terminates the active web session so subsequent
/// visits immediately show the public landing page.
class WebSessionHelper {
  static const String _key = 'aira_web_active_session';

  /// Returns true if this browser tab has an active session.
  static bool hasActiveSession() {
    try {
      final val = html.window.sessionStorage[_key];
      return val != null && val.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Sets the active session flag in sessionStorage.
  static void markSessionActive(String userId) {
    try {
      html.window.sessionStorage[_key] = userId.isNotEmpty ? userId : 'active';
    } catch (_) {}
  }

  /// Clears the active session flag from sessionStorage.
  static void clearSession() {
    try {
      html.window.sessionStorage.remove(_key);
    } catch (_) {}
  }
}

