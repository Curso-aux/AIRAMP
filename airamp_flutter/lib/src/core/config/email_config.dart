/// Configuration for AIRA SMTP email delivery service.
/// Credentials saved for password reset, OTP verification, and notifications.
class EmailConfig {
  static const String smtpHost = 'smtp.gmail.com';
  static const int smtpPort = 587;
  static const String senderEmail = 'evangelistachristian88@gmail.com';
  static const String senderName = 'AIRA Platform';
  static const String smtpAppPassword = 'xzvg jnxx dqtx mqag';
  static const bool isConfigured = true;

  /// Local SMTP Bridge HTTP endpoints
  static const String localBridgeUrl = 'http://127.0.0.1:8088/send-email';
  static const String emulatorBridgeUrl = 'http://10.0.2.2:8088/send-email';
}

