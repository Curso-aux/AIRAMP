/// Configuration for AIRA SMTP email delivery service.
/// Credentials saved for password reset, OTP verification, and notifications.
class EmailConfig {
  static const String smtpHost = 'smtp.gmail.com';
  static const int smtpPort = 587;
  static const String senderEmail = String.fromEnvironment(
    'SMTP_SENDER_EMAIL',
    defaultValue: 'evangelistachristian88@gmail.com',
  );
  static const String senderName = 'AIRA Platform';

  static const String defaultAppPassword = 'ljvh jvre qasx serr';

  static const String _envPassword = String.fromEnvironment(
    'SMTP_APP_PASSWORD',
    defaultValue: defaultAppPassword,
  );
  static String _runtimePassword = '';

  static void setRuntimePassword(String pwd) => _runtimePassword = pwd;

  static String get smtpAppPassword {
    if (_envPassword.isNotEmpty) return _envPassword;
    if (_runtimePassword.isNotEmpty) return _runtimePassword;
    return defaultAppPassword;
  }

  static bool get isConfigured => smtpAppPassword.isNotEmpty;

  /// Local SMTP Bridge HTTP endpoints
  static const String localBridgeUrl = 'http://127.0.0.1:8088/send-email';
  static const String emulatorBridgeUrl = 'http://10.0.2.2:8088/send-email';
  static const String cloudBridgeUrl = String.fromEnvironment('SMTP_BRIDGE_URL', defaultValue: '');
}

