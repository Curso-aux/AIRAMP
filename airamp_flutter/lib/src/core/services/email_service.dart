import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/email_config.dart';
import '../database/firestore_service.dart';
import 'email/email_sender.dart';

class EmailResult {
  final bool success;
  final String message;
  final String channel;

  EmailResult({
    required this.success,
    required this.message,
    required this.channel,
  });
}

/// Centralized service handling SMTP delivery and cloud queuing for
/// account credentials, welcome emails, and notifications.
class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  /// Sends a welcome and account credentials email to a student or teacher.
  Future<EmailResult> sendAccountCredentials({
    required String toEmail,
    required String fullName,
    required String userId,
    required String username,
    required String plainPassword,
    required String role, // 'student' or 'teacher'
    String? grade,
    String? section,
    List<String>? assignedCourses,
    String? specialNotes,
  }) async {
    final roleTitle = role.toLowerCase() == 'teacher' ? 'Faculty / Teacher' : 'Student';
    final subject = 'Welcome to AIRA - Your $roleTitle Account Credentials';

    final textContent = '''
Hello $fullName,

Welcome to the AIRA Learning Platform! Your $roleTitle account has been created by the administration.

Here are your account credentials to log in:
- User ID: $userId
- Username: $username
- Email: $toEmail
- Temporary Password: $plainPassword
- Account Type: $roleTitle
${grade != null && grade.isNotEmpty ? '- Grade Level: $grade\n' : ''}${section != null && section.isNotEmpty ? '- Section: $section\n' : ''}${assignedCourses != null && assignedCourses.isNotEmpty ? '- Assigned Courses: ${assignedCourses.join(", ")}\n' : ''}
You can log in directly at:
https://aira-app-database.web.app

Important: Please change your password after logging in for the first time.

Best regards,
AIRA School Administration
''';

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; color: #1e293b; margin: 0; padding: 24px; }
    .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 14px rgba(0,0,0,0.06); border: 1px solid #e2e8f0; }
    .header { background: linear-gradient(135deg, #0d9488 0%, #0284c7 100%); padding: 32px 24px; text-align: center; color: #ffffff; }
    .header h1 { margin: 0; font-size: 24px; font-weight: 700; letter-spacing: -0.5px; }
    .header p { margin: 6px 0 0; font-size: 14px; opacity: 0.9; }
    .content { padding: 32px 28px; }
    .greeting { font-size: 16px; font-weight: 600; margin-bottom: 12px; }
    .card { background-color: #f1f5f9; border-radius: 12px; padding: 20px; margin: 20px 0; border: 1px solid #cbd5e1; }
    .credential-row { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px dashed #cbd5e1; font-size: 14px; }
    .credential-row:last-child { border-bottom: none; }
    .label { color: #64748b; font-weight: 500; }
    .value { font-weight: 700; color: #0f172a; font-family: 'Courier New', Courier, monospace; }
    .btn-container { text-align: center; margin: 28px 0 16px; }
    .btn { display: inline-block; background-color: #0d9488; color: #ffffff !important; font-weight: 600; text-decoration: none; padding: 12px 28px; border-radius: 10px; font-size: 15px; }
    .notice { font-size: 12px; color: #64748b; background-color: #fffbeb; border: 1px solid #fde68a; border-radius: 8px; padding: 12px; margin-top: 20px; }
    .footer { text-align: center; padding: 20px; font-size: 12px; color: #94a3b8; border-top: 1px solid #f1f5f9; background-color: #fafafa; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>AIRA Learning Platform</h1>
      <p>Official Account Activation</p>
    </div>
    <div class="content">
      <div class="greeting">Hello, $fullName!</div>
      <p style="font-size: 14px; line-height: 1.5; color: #475569;">
        Your official <strong>$roleTitle</strong> account on the AIRA platform has been created by school administration. You can now access your dashboard, curriculum, and interactive learning tools.
      </p>
      
      <div class="card">
        <div class="credential-row"><span class="label">User / Student ID:</span><span class="value">$userId</span></div>
        <div class="credential-row"><span class="label">Username:</span><span class="value">$username</span></div>
        <div class="credential-row"><span class="label">School Email:</span><span class="value">$toEmail</span></div>
        <div class="credential-row"><span class="label">Initial Password:</span><span class="value">$plainPassword</span></div>
        <div class="credential-row"><span class="label">Account Role:</span><span class="value" style="color:#0d9488;">$roleTitle</span></div>
        ${grade != null && grade.isNotEmpty ? '<div class="credential-row"><span class="label">Grade Level:</span><span class="value">$grade</span></div>' : ''}
        ${section != null && section.isNotEmpty ? '<div class="credential-row"><span class="label">Classroom Section:</span><span class="value">$section</span></div>' : ''}
        ${assignedCourses != null && assignedCourses.isNotEmpty ? '<div class="credential-row"><span class="label">Assigned Courses:</span><span class="value">${assignedCourses.join(", ")}</span></div>' : ''}
      </div>

      <div class="btn-container">
        <a href="https://aira-app-database.web.app" class="btn">Log In to AIRA</a>
      </div>

      <div class="notice">
        <strong>Security Notice:</strong> For your security, please log in and change your initial password in your Account Settings. Keep this email confidential.
      </div>
    </div>
    <div class="footer">
      Sent automatically by AIRA Platform &bull; Evangelista Christian School<br>
      For technical support, contact the School Administration.
    </div>
  </div>
</body>
</html>
''';

    return await _deliverEmail(
      toEmail: toEmail,
      subject: subject,
      textContent: textContent,
      htmlContent: htmlContent,
      userId: userId,
      username: username,
      role: role,
      mailType: 'account_credentials',
      successMessage: 'Credentials email sent to $toEmail via Gmail SMTP',
    );
  }

  /// Sends a one-time password (OTP) verification email for password reset or change.
  Future<EmailResult> sendPasswordResetOtp({
    required String toEmail,
    required String fullName,
    required String userId,
    required String otpCode,
    required String role,
  }) async {
    final roleTitle = role.toLowerCase() == 'teacher' ? 'Faculty / Teacher' : 'Student';
    final subject = 'AIRA Security Code: $otpCode - Password Reset Verification';

    final textContent = '''
Hello $fullName,

You recently requested to change or reset your password for your AIRA $roleTitle account.

Your One-Time Password (OTP) verification code is:
$otpCode

This code is valid for 10 minutes. Please enter this code into the AIRA application to proceed.

Account Information:
- User / Student ID: $userId
- Account Role: $roleTitle
- Associated Email: $toEmail

If you did not initiate this request, your account remains secure and you may safely ignore this email.

Best regards,
AIRA Security & Administration
''';

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; color: #1e293b; margin: 0; padding: 24px; }
    .container { max-width: 560px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 14px rgba(0,0,0,0.06); border: 1px solid #e2e8f0; }
    .header { background: linear-gradient(135deg, #0d9488 0%, #0284c7 100%); padding: 28px 24px; text-align: center; color: #ffffff; }
    .header h1 { margin: 0; font-size: 22px; font-weight: 700; letter-spacing: -0.5px; }
    .header p { margin: 6px 0 0; font-size: 13px; opacity: 0.9; }
    .content { padding: 32px 28px; }
    .greeting { font-size: 16px; font-weight: 600; margin-bottom: 12px; color: #0f172a; }
    .otp-card { background-color: #f8fafc; border-radius: 12px; padding: 24px; margin: 24px 0; border: 2px dashed #0d9488; text-align: center; }
    .otp-code { font-family: 'Courier New', Courier, monospace; font-size: 36px; font-weight: 800; letter-spacing: 8px; color: #0d9488; display: inline-block; padding: 4px 12px; }
    .otp-expiry { font-size: 12px; color: #64748b; margin-top: 10px; font-weight: 500; }
    .info-box { background-color: #f1f5f9; border-radius: 10px; padding: 14px 18px; margin: 18px 0; font-size: 13px; color: #334155; }
    .info-row { display: flex; justify-content: space-between; padding: 4px 0; }
    .warning { font-size: 12px; color: #b45309; background-color: #fffbeb; border: 1px solid #fde68a; border-radius: 8px; padding: 12px; margin-top: 20px; line-height: 1.4; }
    .footer { text-align: center; padding: 20px; font-size: 12px; color: #94a3b8; border-top: 1px solid #f1f5f9; background-color: #fafafa; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>AIRA Security Verification</h1>
      <p>One-Time Password (OTP) for Password Change</p>
    </div>
    <div class="content">
      <div class="greeting">Hello, $fullName!</div>
      <p style="font-size: 14px; line-height: 1.5; color: #475569;">
        A request has been made to change or reset the password for your <strong>$roleTitle</strong> account. Enter the verification code below in the app to complete this request:
      </p>
      
      <div class="otp-card">
        <div class="otp-code">$otpCode</div>
        <div class="otp-expiry">&#9201; Valid for 10 minutes &bull; Single-use only</div>
      </div>

      <div class="info-box">
        <div class="info-row"><span><strong>Account ID:</strong></span> <code>$userId</code></div>
        <div class="info-row"><span><strong>Role:</strong></span> $roleTitle</div>
        <div class="info-row"><span><strong>Email:</strong></span> $toEmail</div>
      </div>

      <div class="warning">
        <strong>Important Security Notice:</strong> Never share this verification code with anyone. AIRA staff or administrators will never ask for your code. If you did not make this request, you can safely ignore this email; your existing password remains unchanged.
      </div>
    </div>
    <div class="footer">
      Sent automatically by AIRA Platform &bull; Evangelista Christian School<br>
      Security & Authentication Service
    </div>
  </div>
</body>
</html>
''';

    return await _deliverEmail(
      toEmail: toEmail,
      subject: subject,
      textContent: textContent,
      htmlContent: htmlContent,
      userId: userId,
      role: role,
      mailType: 'password_reset_otp',
      successMessage: 'Security OTP verification email sent to $toEmail via Gmail SMTP',
    );
  }

  /// Core cross-platform email delivery pipeline supporting Native SMTP,
  /// Local/Emulator HTTP Bridge, and Cloud Firestore Logging.
  Future<EmailResult> _deliverEmail({
    required String toEmail,
    required String subject,
    required String textContent,
    required String htmlContent,
    required String userId,
    String? username,
    required String role,
    required String mailType,
    required String successMessage,
  }) async {
    bool sent = false;
    String channel = 'none';

    // 1. Native Direct SMTP delivery (Android device/emulator, Windows, iOS)
    if (!kIsWeb) {
      try {
        final nativeOk = await sendNativeSmtp(
          toEmail: toEmail,
          subject: subject,
          textContent: textContent,
          htmlContent: htmlContent,
        );
        if (nativeOk) {
          sent = true;
          channel = 'smtp_native';
          debugPrint('[EmailService] Email ($mailType) sent directly via Gmail SMTP to $toEmail');
        }
      } catch (e) {
        debugPrint('[EmailService] Native SMTP delivery note: $e');
      }
    }

    // 2. HTTP SMTP Bridge Delivery (For Web & fallback on emulator/desktop)
    if (!sent) {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 15),
      ));

      final bridgeCandidates = kIsWeb
          ? [EmailConfig.localBridgeUrl, 'http://localhost:8088/send-email']
          : [EmailConfig.emulatorBridgeUrl, EmailConfig.localBridgeUrl];

      for (final endpoint in bridgeCandidates) {
        try {
          debugPrint('[EmailService] Attempting delivery ($mailType) via SMTP bridge: $endpoint');
          final response = await dio.post(
            endpoint,
            data: {
              'to': toEmail,
              'subject': subject,
              'text': textContent,
              'html': htmlContent,
              'sender': EmailConfig.senderEmail,
              'password': EmailConfig.smtpAppPassword,
            },
          );

          if (response.statusCode == 200) {
            sent = true;
            channel = 'smtp_bridge';
            debugPrint('[EmailService] Email ($mailType) delivered via SMTP bridge to $toEmail');
            break;
          }
        } catch (bridgeErr) {
          debugPrint('[EmailService] Bridge endpoint ($endpoint) attempt: $bridgeErr');
        }
      }
    }

    // 3. Always log to Cloud Firestore `mail` collection for auditing & persistence
    bool cloudQueued = false;
    try {
      final docId = 'mail_${DateTime.now().millisecondsSinceEpoch}';
      final dio = Dio();
      final url = 'https://firestore.googleapis.com/v1/projects/${FirestoreService.projectId}/databases/(default)/documents/mail/$docId?key=${FirestoreService.apiKey}';

      final fields = <String, dynamic>{
        'to': {'stringValue': toEmail},
        'subject': {'stringValue': subject},
        'user_id': {'stringValue': userId},
        'role': {'stringValue': role},
        'mail_type': {'stringValue': mailType},
        'created_at': {'stringValue': DateTime.now().toIso8601String()},
        'status': {'stringValue': sent ? 'sent_via_$channel' : 'queued_for_delivery'},
      };
      if (username != null && username.isNotEmpty) {
        fields['username'] = {'stringValue': username};
      }
      await dio.patch(url, data: {'fields': fields});
      cloudQueued = true;
    } catch (e) {
      debugPrint('[EmailService] Cloud mail audit note: $e');
    }

    if (sent) {
      return EmailResult(
        success: true,
        message: successMessage,
        channel: channel,
      );
    } else if (cloudQueued) {
      return EmailResult(
        success: true,
        message: 'Notification recorded & queued in Cloud Database for $toEmail',
        channel: 'firestore_trigger',
      );
    } else {
      return EmailResult(
        success: false,
        message: 'Could not deliver email to $toEmail',
        channel: 'failed',
      );
    }
  }
}


