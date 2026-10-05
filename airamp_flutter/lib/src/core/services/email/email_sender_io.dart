import 'dart:io' show Platform, File;
import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../../config/email_config.dart';

String _resolvePassword() {
  if (EmailConfig.smtpAppPassword.isNotEmpty) {
    return EmailConfig.smtpAppPassword.replaceAll(' ', '');
  }
  final env = Platform.environment['SMTP_APP_PASSWORD'];
  if (env != null && env.isNotEmpty) {
    return env.replaceAll(' ', '');
  }
  for (final path in ['.env', '../.env', 'airamp_flutter/.env']) {
    try {
      final f = File(path);
      if (f.existsSync()) {
        for (final line in f.readAsLinesSync()) {
          final trimmed = line.trim();
          if (trimmed.startsWith('SMTP_APP_PASSWORD=')) {
            final val = trimmed.substring('SMTP_APP_PASSWORD='.length).replaceAll('"', '').replaceAll("'", '').trim();
            if (val.isNotEmpty) {
              return val.replaceAll(' ', '');
            }
          }
        }
      }
    } catch (_) {}
  }
  return '';
}

/// Native (Android, iOS, Desktop) SMTP delivery via direct socket connection to Gmail SMTP.
Future<bool> sendNativeSmtp({
  required String toEmail,
  required String subject,
  required String textContent,
  required String htmlContent,
}) async {
  try {
    final cleanPassword = _resolvePassword();
    if (cleanPassword.isEmpty) {
      debugPrint('[EmailSenderIO] No SMTP password configured.');
      return false;
    }

    final smtpServer = SmtpServer(
      EmailConfig.smtpHost,
      port: EmailConfig.smtpPort,
      username: EmailConfig.senderEmail,
      password: cleanPassword,
      allowInsecure: true,
      ssl: false,
    );

    final message = Message()
      ..from = Address(EmailConfig.senderEmail, EmailConfig.senderName)
      ..recipients.add(toEmail)
      ..subject = subject
      ..text = textContent
      ..html = htmlContent;

    final sendReport = await send(message, smtpServer, timeout: const Duration(seconds: 12));
    debugPrint('[EmailSenderIO] SMTP Delivery Report: $sendReport');
    return true;
  } catch (e) {
    debugPrint('[EmailSenderIO] Error sending SMTP email: $e');
    return false;
  }
}
