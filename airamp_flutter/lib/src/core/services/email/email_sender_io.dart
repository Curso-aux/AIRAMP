import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../../config/email_config.dart';

/// Native (Android, iOS, Desktop) SMTP delivery via direct socket connection to Gmail SMTP.
Future<bool> sendNativeSmtp({
  required String toEmail,
  required String subject,
  required String textContent,
  required String htmlContent,
}) async {
  try {
    final cleanPassword = EmailConfig.smtpAppPassword.replaceAll(' ', '');
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

    final sendReport = await send(message, smtpServer);
    debugPrint('[EmailSenderIO] SMTP Delivery Report: $sendReport');
    return true;
  } catch (e) {
    debugPrint('[EmailSenderIO] Error sending SMTP email: $e');
    return false;
  }
}
