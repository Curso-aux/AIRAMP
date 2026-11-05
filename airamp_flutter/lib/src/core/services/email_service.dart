import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../api/rate_limit_interceptor.dart';
import '../config/email_config.dart';
import '../database/firestore_service.dart';
import 'email/email_sender.dart';

String _esc(String? val) => htmlEscape.convert(val ?? '');

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

  /// Holds the outcome of the most recent email dispatch
  static EmailResult? lastResult;

  /// Sends a welcome and account credentials email to a student, teacher, or administrator.
  Future<EmailResult> sendAccountCredentials({
    required String toEmail,
    required String fullName,
    required String userId,
    required String username,
    required String plainPassword,
    required String role, // 'student', 'teacher', 'admin', or 'super_admin'
    String? grade,
    String? section,
    List<String>? assignedCourses,
    String? specialNotes,
    String? campusName,
    String? campusCode,
  }) async {
    final roleNorm = role.toLowerCase().trim();
    String roleTitle;
    if (roleNorm == 'super_admin') {
      roleTitle = 'Super Administrator';
    } else if (roleNorm == 'admin') {
      roleTitle = 'Campus Administrator';
    } else if (roleNorm == 'teacher') {
      roleTitle = 'Faculty / Teacher';
    } else {
      roleTitle = 'Student';
    }

    final isAdmin = roleNorm == 'admin' || roleNorm == 'super_admin';
    final platformTitle = isAdmin ? 'AIRAMP Governance Platform' : 'AIRA Learning Platform';
    final subject = 'Welcome to $platformTitle - Your $roleTitle Account Credentials';
    final loginUrl = isAdmin
        ? 'https://aira-app-database.web.app/#/login?role=admin'
        : 'https://aira-app-database.web.app';

    final textContent = '''
Hello $fullName,

Welcome to the $platformTitle! Your $roleTitle account has been provisioned by the administration.

Here are your account credentials to log in:
- User / Account ID: $userId
- Username: $username
- Email: $toEmail
- Temporary Password: $plainPassword
- Account Role: $roleTitle
${campusName != null && campusName.isNotEmpty ? '- Assigned Campus: $campusName ${campusCode != null ? "($campusCode)" : ""}\n' : ''}${grade != null && grade.isNotEmpty ? '- Grade Level: $grade\n' : ''}${section != null && section.isNotEmpty ? '- Section: $section\n' : ''}${assignedCourses != null && assignedCourses.isNotEmpty ? '- Assigned Courses: ${assignedCourses.join(", ")}\n' : ''}
You can log in directly at:
$loginUrl

Important: For your security, please log in and change your temporary password immediately upon your first session.

Best regards,
AIRAMP Master Administration
''';

    final campusDisplay = (campusName != null && campusName.isNotEmpty)
        ? '${_esc(campusName)} ${campusCode != null && campusCode.isNotEmpty ? "(${_esc(campusCode)})" : ""}'
        : null;
    final primaryColor = isAdmin ? '#0284c7' : '#0d9488';
    final accentGradient = isAdmin
        ? 'linear-gradient(135deg, #0284c7 0%, #3b82f6 100%)'
        : 'linear-gradient(135deg, #0d9488 0%, #0284c7 100%)';
    final loginButtonText = isAdmin ? 'Log In to Administrator Portal' : 'Log In to AIRA Platform';
    final portalDescription = isAdmin
        ? 'Your official <strong>${_esc(roleTitle)}</strong> account on the AIRA platform has been provisioned by the master administration. You can now access your administrative portal, manage assigned campus faculties, and monitor operational telemetry.'
        : 'Your official <strong>${_esc(roleTitle)}</strong> account on the AIRA platform has been provisioned. You can now log in to access your assigned courses, academic resources, and campus services.';

    final htmlContent = '''
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>Account Activation</title>
</head>
<body style="margin: 0; padding: 0; background-color: #f8fafc; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #1e293b; -webkit-font-smoothing: antialiased;">
  <!-- Preheader Preview Text -->
  <div style="display: none; font-size: 1px; color: #f8fafc; line-height: 1px; max-height: 0px; max-width: 0px; opacity: 0; overflow: hidden;">
    Your official ${_esc(roleTitle)} credentials for AIRAMP are ready. Log in to activate your account.
  </div>

  <table border="0" cellpadding="0" cellspacing="0" width="100%" style="table-layout: fixed; background-color: #f8fafc; padding: 24px 0;">
    <tr>
      <td align="center">
        <!-- Main Email Container (Max 600px) -->
        <table border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 600px; background-color: #ffffff; border-radius: 12px; overflow: hidden; border: 1px solid #e2e8f0; box-shadow: 0 4px 14px rgba(0,0,0,0.05);">
          
          <!-- Header Banner -->
          <tr>
            <td align="center" style="background: $accentGradient; background-color: $primaryColor; padding: 32px 24px; color: #ffffff;">
              <h1 style="margin: 0; font-size: 24px; font-weight: 800; color: #ffffff; letter-spacing: -0.5px;">
                ${_esc(platformTitle)}
              </h1>
              <p style="margin: 6px 0 0; font-size: 13px; color: #e0f2fe; letter-spacing: 0.5px; text-transform: uppercase; font-weight: 600;">
                Official Account Activation
              </p>
            </td>
          </tr>

          <!-- Content Body -->
          <tr>
            <td style="padding: 32px 28px;">
              <div style="font-size: 17px; font-weight: 700; color: #0f172a; margin-bottom: 12px;">
                Hello, ${_esc(fullName)}!
              </div>
              <p style="font-size: 14px; line-height: 1.6; color: #475569; margin: 0 0 24px;">
                $portalDescription
              </p>

              <!-- Dedicated Primary Credentials Card (Isolated, Copy-Safe) -->
              <table border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #f8fafc; border: 1px solid #cbd5e1; border-radius: 8px; margin-bottom: 22px;">
                <tr>
                  <td style="padding: 12px 18px; background-color: #f1f5f9; border-bottom: 1px solid #e2e8f0;">
                    <span style="font-size: 11px; font-weight: 700; color: #475569; text-transform: uppercase; letter-spacing: 0.8px;">
                      &#128273; Primary Login Credentials
                    </span>
                  </td>
                </tr>
                <tr>
                  <td style="padding: 16px 18px;">
                    <table border="0" cellpadding="0" cellspacing="0" width="100%">
                      <tr>
                        <td width="38%" valign="middle" style="padding: 6px 0; font-size: 13px; color: #64748b; font-weight: 500;">Username:</td>
                        <td width="62%" valign="middle" style="padding: 6px 0; font-size: 14px; font-weight: 700; color: #0f172a; word-break: break-all;">${_esc(username)}</td>
                      </tr>
                      <tr>
                        <td width="38%" valign="middle" style="padding: 6px 0; font-size: 13px; color: #64748b; font-weight: 500;">Temporary Password:</td>
                        <td width="62%" valign="middle" style="padding: 6px 0;">
                          <span style="display: inline-block; font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, monospace; font-size: 14px; font-weight: 700; color: #0369a1; background-color: #e0f2fe; padding: 5px 10px; border-radius: 4px; border: 1px solid #bae6fd; letter-spacing: 0.5px;">
                            ${_esc(plainPassword)}
                          </span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <!-- Institutional Details Table -->
              <table border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #ffffff; border: 1px solid #e2e8f0; border-radius: 8px; margin-bottom: 26px;">
                <tr>
                  <td style="padding: 12px 18px; background-color: #f8fafc; border-bottom: 1px solid #e2e8f0;">
                    <span style="font-size: 11px; font-weight: 700; color: #64748b; text-transform: uppercase; letter-spacing: 0.8px;">
                      &#128203; Account Profile & Assignments
                    </span>
                  </td>
                </tr>
                <tr>
                  <td style="padding: 8px 18px;">
                    <table border="0" cellpadding="0" cellspacing="0" width="100%">
                      <tr>
                        <td width="38%" valign="middle" style="padding: 8px 0; border-bottom: 1px solid #f1f5f9; font-size: 13px; color: #64748b;">User / Admin ID:</td>
                        <td width="62%" valign="middle" style="padding: 8px 0; border-bottom: 1px solid #f1f5f9; font-size: 13px; font-weight: 600; color: #0f172a; font-family: 'SFMono-Regular', Consolas, monospace;">${_esc(userId)}</td>
                      </tr>
                      <tr>
                        <td width="38%" valign="middle" style="padding: 8px 0; border-bottom: 1px solid #f1f5f9; font-size: 13px; color: #64748b;">Institutional Email:</td>
                        <td width="62%" valign="middle" style="padding: 8px 0; border-bottom: 1px solid #f1f5f9; font-size: 13px; font-weight: 600; color: #0f172a; word-break: break-all;">${_esc(toEmail)}</td>
                      </tr>
                      <tr>
                        <td width="38%" valign="middle" style="padding: 8px 0; ${campusDisplay != null || (grade != null && grade.isNotEmpty) || (section != null && section.isNotEmpty) || (assignedCourses != null && assignedCourses.isNotEmpty) ? 'border-bottom: 1px solid #f1f5f9;' : ''} font-size: 13px; color: #64748b;">Account Role:</td>
                        <td width="62%" valign="middle" style="padding: 8px 0; ${campusDisplay != null || (grade != null && grade.isNotEmpty) || (section != null && section.isNotEmpty) || (assignedCourses != null && assignedCourses.isNotEmpty) ? 'border-bottom: 1px solid #f1f5f9;' : ''} font-size: 13px; font-weight: 700;">
                          <span style="display: inline-block; background-color: ${isAdmin ? '#e0f2fe' : '#ccfbf1'}; color: $primaryColor; padding: 2px 8px; border-radius: 4px; font-size: 12px; font-weight: 700;">${_esc(roleTitle)}</span>
                        </td>
                      </tr>
                      ${campusDisplay != null ? '''
                      <tr>
                        <td width="38%" valign="middle" style="padding: 8px 0; ${(grade != null && grade.isNotEmpty) || (section != null && section.isNotEmpty) || (assignedCourses != null && assignedCourses.isNotEmpty) ? 'border-bottom: 1px solid #f1f5f9;' : ''} font-size: 13px; color: #64748b;">Assigned Campus:</td>
                        <td width="62%" valign="middle" style="padding: 8px 0; ${(grade != null && grade.isNotEmpty) || (section != null && section.isNotEmpty) || (assignedCourses != null && assignedCourses.isNotEmpty) ? 'border-bottom: 1px solid #f1f5f9;' : ''} font-size: 13px; font-weight: 600; color: #0f172a;">$campusDisplay</td>
                      </tr>
                      ''' : ''}
                      ${grade != null && grade.isNotEmpty ? '''
                      <tr>
                        <td width="38%" valign="middle" style="padding: 8px 0; ${(section != null && section.isNotEmpty) || (assignedCourses != null && assignedCourses.isNotEmpty) ? 'border-bottom: 1px solid #f1f5f9;' : ''} font-size: 13px; color: #64748b;">Grade Level:</td>
                        <td width="62%" valign="middle" style="padding: 8px 0; ${(section != null && section.isNotEmpty) || (assignedCourses != null && assignedCourses.isNotEmpty) ? 'border-bottom: 1px solid #f1f5f9;' : ''} font-size: 13px; font-weight: 600; color: #0f172a;">${_esc(grade)}</td>
                      </tr>
                      ''' : ''}
                      ${section != null && section.isNotEmpty ? '''
                      <tr>
                        <td width="38%" valign="middle" style="padding: 8px 0; ${(assignedCourses != null && assignedCourses.isNotEmpty) ? 'border-bottom: 1px solid #f1f5f9;' : ''} font-size: 13px; color: #64748b;">Classroom Section:</td>
                        <td width="62%" valign="middle" style="padding: 8px 0; ${(assignedCourses != null && assignedCourses.isNotEmpty) ? 'border-bottom: 1px solid #f1f5f9;' : ''} font-size: 13px; font-weight: 600; color: #0f172a;">${_esc(section)}</td>
                      </tr>
                      ''' : ''}
                      ${assignedCourses != null && assignedCourses.isNotEmpty ? '''
                      <tr>
                        <td width="38%" valign="middle" style="padding: 8px 0; font-size: 13px; color: #64748b;">Assigned Courses:</td>
                        <td width="62%" valign="middle" style="padding: 8px 0; font-size: 13px; font-weight: 600; color: #0f172a;">${assignedCourses.map(_esc).join(", ")}</td>
                      </tr>
                      ''' : ''}
                    </table>
                  </td>
                </tr>
              </table>

              <!-- Call to Action Button (Bulletproof Table-Cell Button) -->
              <table border="0" cellpadding="0" cellspacing="0" width="100%">
                <tr>
                  <td align="center" style="padding: 8px 0 24px;">
                    <table border="0" cellpadding="0" cellspacing="0">
                      <tr>
                        <td align="center" style="background-color: $primaryColor; border-radius: 8px;">
                          <a href="${_esc(loginUrl)}" target="_blank" style="display: inline-block; padding: 14px 32px; font-size: 14px; font-weight: 700; color: #ffffff !important; text-decoration: none; border-radius: 8px; letter-spacing: 0.2px;">
                            $loginButtonText &rarr;
                          </a>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <!-- Security Notice Banner -->
              <table border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #fffbeb; border: 1px solid #fde68a; border-radius: 8px;">
                <tr>
                  <td style="padding: 12px 16px; font-size: 12px; line-height: 1.5; color: #92400e;">
                    <strong>Security Notice:</strong> For your security, please log in and change your initial password immediately in your Account Settings. Keep this email confidential.
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td align="center" style="background-color: #fafafa; border-top: 1px solid #f1f5f9; padding: 20px 24px; font-size: 12px; color: #94a3b8; line-height: 1.5;">
              Sent automatically by AIRAMP Platform &bull; Institutional Master Scope<br />
              For technical support, contact the Super Administration.
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
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
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>Security Verification</title>
</head>
<body style="margin: 0; padding: 0; background-color: #f8fafc; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #1e293b; -webkit-font-smoothing: antialiased;">
  <!-- Preheader Preview Text -->
  <div style="display: none; font-size: 1px; color: #f8fafc; line-height: 1px; max-height: 0px; max-width: 0px; opacity: 0; overflow: hidden;">
    Your password reset verification code is ${_esc(otpCode)}. Valid for 10 minutes.
  </div>

  <table border="0" cellpadding="0" cellspacing="0" width="100%" style="table-layout: fixed; background-color: #f8fafc; padding: 24px 0;">
    <tr>
      <td align="center">
        <!-- Main Container (560px) -->
        <table border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 560px; background-color: #ffffff; border-radius: 12px; overflow: hidden; border: 1px solid #e2e8f0; box-shadow: 0 4px 14px rgba(0,0,0,0.05);">
          
          <!-- Header Banner -->
          <tr>
            <td align="center" style="background: linear-gradient(135deg, #0d9488 0%, #0284c7 100%); background-color: #0d9488; padding: 28px 24px; color: #ffffff;">
              <h1 style="margin: 0; font-size: 22px; font-weight: 800; color: #ffffff; letter-spacing: -0.5px;">
                AIRA Security Verification
              </h1>
              <p style="margin: 6px 0 0; font-size: 13px; color: #ccfbf1; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px;">
                Password Reset Verification Code
              </p>
            </td>
          </tr>

          <!-- Content Body -->
          <tr>
            <td style="padding: 32px 28px;">
              <div style="font-size: 17px; font-weight: 700; color: #0f172a; margin-bottom: 12px;">
                Hello, ${_esc(fullName)}!
              </div>
              <p style="font-size: 14px; line-height: 1.6; color: #475569; margin: 0 0 20px;">
                A request has been made to change or reset the password for your <strong>${_esc(roleTitle)}</strong> account. Enter the verification code below in the app to complete this request:
              </p>

              <!-- OTP Card -->
              <table border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #f0fdf4; border: 2px dashed #0d9488; border-radius: 10px; margin-bottom: 22px;">
                <tr>
                  <td align="center" style="padding: 22px 16px;">
                    <div style="font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, monospace; font-size: 34px; font-weight: 800; letter-spacing: 8px; color: #0d9488; margin-bottom: 6px;">
                      ${_esc(otpCode)}
                    </div>
                    <div style="font-size: 12px; color: #64748b; font-weight: 500;">
                      &#9201; Valid for 10 minutes &bull; Single-use only
                    </div>
                  </td>
                </tr>
              </table>

              <!-- Details Table -->
              <table border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; margin-bottom: 22px;">
                <tr>
                  <td style="padding: 12px 18px;">
                    <table border="0" cellpadding="0" cellspacing="0" width="100%">
                      <tr>
                        <td width="35%" valign="middle" style="padding: 6px 0; font-size: 13px; color: #64748b; font-weight: 500;">Account ID:</td>
                        <td width="65%" valign="middle" style="padding: 6px 0; font-size: 13px; font-weight: 600; color: #0f172a; font-family: 'SFMono-Regular', Consolas, monospace;">${_esc(userId)}</td>
                      </tr>
                      <tr>
                        <td width="35%" valign="middle" style="padding: 6px 0; font-size: 13px; color: #64748b; font-weight: 500;">Account Role:</td>
                        <td width="65%" valign="middle" style="padding: 6px 0; font-size: 13px; font-weight: 600; color: #0d9488;">${_esc(roleTitle)}</td>
                      </tr>
                      <tr>
                        <td width="35%" valign="middle" style="padding: 6px 0; font-size: 13px; color: #64748b; font-weight: 500;">Associated Email:</td>
                        <td width="65%" valign="middle" style="padding: 6px 0; font-size: 13px; font-weight: 600; color: #0f172a; word-break: break-all;">${_esc(toEmail)}</td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <!-- Security Notice -->
              <table border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #fffbeb; border: 1px solid #fde68a; border-radius: 8px;">
                <tr>
                  <td style="padding: 12px 16px; font-size: 12px; line-height: 1.5; color: #92400e;">
                    <strong>Important Security Notice:</strong> Never share this verification code with anyone. AIRA staff or administrators will never ask for your code. If you did not make this request, you can safely ignore this email; your existing password remains unchanged.
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td align="center" style="background-color: #fafafa; border-top: 1px solid #f1f5f9; padding: 20px 24px; font-size: 12px; color: #94a3b8; line-height: 1.5;">
              Sent automatically by AIRA Platform &bull; Evangelista Christian School<br />
              Security & Authentication Service
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
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

  /// Sends an OTP verification email for specific security operations
  /// (e.g. Email Address Update, Student Account Registration, Administrator 2FA).
  Future<EmailResult> sendVerificationOtp({
    required String toEmail,
    required String fullName,
    required String otpCode,
    required String purpose,
    String? userId,
    String role = 'student',
  }) async {
    final roleTitle = role.toLowerCase() == 'teacher'
        ? 'Faculty / Teacher'
        : (role.toLowerCase() == 'admin' || role.toLowerCase() == 'super_admin' ? 'Administrator' : 'Student');
    final subject = 'AIRA Verification Code: $otpCode - $purpose';

    final textContent = '''
Hello $fullName,

Your 6-digit verification code for $purpose on the AIRA platform is:
$otpCode

This code is valid for 10 minutes. Please enter this code into the AIRA application to proceed.
${userId != null ? '- Account ID: $userId\n' : ''}- Target Email: $toEmail
- Verification Purpose: $purpose

If you did not initiate this request, please disregard this email.

Best regards,
AIRA Security & Identity Management
''';

    final htmlContent = '''
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>Identity Verification</title>
</head>
<body style="margin: 0; padding: 0; background-color: #f8fafc; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #1e293b; -webkit-font-smoothing: antialiased;">
  <!-- Preheader Preview Text -->
  <div style="display: none; font-size: 1px; color: #f8fafc; line-height: 1px; max-height: 0px; max-width: 0px; opacity: 0; overflow: hidden;">
    Your verification code for ${_esc(purpose)} is ${_esc(otpCode)}.
  </div>

  <table border="0" cellpadding="0" cellspacing="0" width="100%" style="table-layout: fixed; background-color: #f8fafc; padding: 24px 0;">
    <tr>
      <td align="center">
        <!-- Main Container (560px) -->
        <table border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 560px; background-color: #ffffff; border-radius: 12px; overflow: hidden; border: 1px solid #e2e8f0; box-shadow: 0 4px 14px rgba(0,0,0,0.05);">
          
          <!-- Header Banner -->
          <tr>
            <td align="center" style="background: linear-gradient(135deg, #0d9488 0%, #0284c7 100%); background-color: #0d9488; padding: 28px 24px; color: #ffffff;">
              <h1 style="margin: 0; font-size: 22px; font-weight: 800; color: #ffffff; letter-spacing: -0.5px;">
                AIRA Identity Verification
              </h1>
              <p style="margin: 6px 0 0; font-size: 13px; color: #ccfbf1; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px;">
                ${_esc(purpose)}
              </p>
            </td>
          </tr>

          <!-- Content Body -->
          <tr>
            <td style="padding: 32px 28px;">
              <div style="font-size: 17px; font-weight: 700; color: #0f172a; margin-bottom: 12px;">
                Hello, ${_esc(fullName)}!
              </div>
              <p style="font-size: 14px; line-height: 1.6; color: #475569; margin: 0 0 20px;">
                Please use the following single-use verification code to complete your <strong>${_esc(purpose)}</strong>:
              </p>

              <!-- OTP Card -->
              <table border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #f0fdf4; border: 2px dashed #0d9488; border-radius: 10px; margin-bottom: 22px;">
                <tr>
                  <td align="center" style="padding: 22px 16px;">
                    <div style="font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, monospace; font-size: 34px; font-weight: 800; letter-spacing: 8px; color: #0d9488; margin-bottom: 6px;">
                      ${_esc(otpCode)}
                    </div>
                    <div style="font-size: 12px; color: #64748b; font-weight: 500;">
                      &#9201; Valid for 10 minutes &bull; Single-use only
                    </div>
                  </td>
                </tr>
              </table>

              <!-- Details Table -->
              <table border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; margin-bottom: 22px;">
                <tr>
                  <td style="padding: 12px 18px;">
                    <table border="0" cellpadding="0" cellspacing="0" width="100%">
                      <tr>
                        <td width="35%" valign="middle" style="padding: 6px 0; font-size: 13px; color: #64748b; font-weight: 500;">Action / Purpose:</td>
                        <td width="65%" valign="middle" style="padding: 6px 0; font-size: 13px; font-weight: 600; color: #0f172a;">${_esc(purpose)}</td>
                      </tr>
                      ${userId != null ? '''
                      <tr>
                        <td width="35%" valign="middle" style="padding: 6px 0; font-size: 13px; color: #64748b; font-weight: 500;">Account ID:</td>
                        <td width="65%" valign="middle" style="padding: 6px 0; font-size: 13px; font-weight: 600; color: #0f172a; font-family: 'SFMono-Regular', Consolas, monospace;">${_esc(userId)}</td>
                      </tr>
                      ''' : ''}
                      <tr>
                        <td width="35%" valign="middle" style="padding: 6px 0; font-size: 13px; color: #64748b; font-weight: 500;">Account Role:</td>
                        <td width="65%" valign="middle" style="padding: 6px 0; font-size: 13px; font-weight: 600; color: #0d9488;">${_esc(roleTitle)}</td>
                      </tr>
                      <tr>
                        <td width="35%" valign="middle" style="padding: 6px 0; font-size: 13px; color: #64748b; font-weight: 500;">Recipient:</td>
                        <td width="65%" valign="middle" style="padding: 6px 0; font-size: 13px; font-weight: 600; color: #0f172a; word-break: break-all;">${_esc(toEmail)}</td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <!-- Security Notice -->
              <table border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #fffbeb; border: 1px solid #fde68a; border-radius: 8px;">
                <tr>
                  <td style="padding: 12px 16px; font-size: 12px; line-height: 1.5; color: #92400e;">
                    <strong>Security Notice:</strong> Never share this verification code with anyone. AIRA staff or administrators will never ask for your code. If you did not initiate this request, please ignore this email.
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td align="center" style="background-color: #fafafa; border-top: 1px solid #f1f5f9; padding: 20px 24px; font-size: 12px; color: #94a3b8; line-height: 1.5;">
              Sent automatically by AIRA Platform &bull; Evangelista Christian School<br />
              Security & Authentication Service
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';

    return await _deliverEmail(
      toEmail: toEmail,
      subject: subject,
      textContent: textContent,
      htmlContent: htmlContent,
      userId: userId ?? toEmail,
      role: role,
      mailType: 'action_verification_otp',
      successMessage: 'Verification code sent to $toEmail via Gmail SMTP',
    );
  }

  /// Sends an official response email from school administration to an inquiry.
  Future<EmailResult> sendInquiryReply({
    required String toEmail,
    required String fullName,
    required String userId,
    required String role,
    required String inquiryQuestion,
    required String adminReply,
    required String adminName,
  }) async {
    final roleTitle = role.toLowerCase() == 'teacher'
        ? 'Faculty Member'
        : (role.toLowerCase() == 'admin' || role.toLowerCase() == 'super_admin'
            ? 'Administrator'
            : 'Student');
    final subject = 'AIRA School Administration - Response to Your Inquiry';

    final textContent = '''
Hello $fullName,

This is an official response from AIRA School Administration regarding your inquiry.

Account Details:
- Recipient: $fullName ($userId)
- Role: $roleTitle
- Destination Email: $toEmail

Your Inquiry:
"$inquiryQuestion"

Administrative Response:
$adminReply

Answered by: $adminName (School Administration)
Date: ${DateTime.now().toLocal().toString().split('.')[0]}

This response has also been posted to your in-app AIRA notification center. You can access your account and records at:
https://aira-app-database.web.app

Best regards,
AIRA School Administration
Evangelista Christian School & Institutional Assessment Platform
''';

    final htmlContent = '''
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>Inquiry Response</title>
</head>
<body style="margin: 0; padding: 0; background-color: #f8fafc; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #1e293b; -webkit-font-smoothing: antialiased;">
  <!-- Preheader Preview Text -->
  <div style="display: none; font-size: 1px; color: #f8fafc; line-height: 1px; max-height: 0px; max-width: 0px; opacity: 0; overflow: hidden;">
    School administration has replied to your inquiry: "${_esc(inquiryQuestion.length > 60 ? '${inquiryQuestion.substring(0, 60)}...' : inquiryQuestion)}"
  </div>

  <table border="0" cellpadding="0" cellspacing="0" width="100%" style="table-layout: fixed; background-color: #f8fafc; padding: 24px 0;">
    <tr>
      <td align="center">
        <!-- Main Container (600px) -->
        <table border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 600px; background-color: #ffffff; border-radius: 12px; overflow: hidden; border: 1px solid #e2e8f0; box-shadow: 0 4px 14px rgba(0,0,0,0.05);">
          
          <!-- Header Banner -->
          <tr>
            <td align="center" style="background: linear-gradient(135deg, #0d9488 0%, #0284c7 100%); background-color: #0d9488; padding: 28px 24px; color: #ffffff;">
              <h1 style="margin: 0; font-size: 22px; font-weight: 800; color: #ffffff; letter-spacing: -0.5px;">
                AIRA School Administration
              </h1>
              <p style="margin: 6px 0 0; font-size: 13px; color: #ccfbf1; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px;">
                Official Inquiry Response
              </p>
            </td>
          </tr>

          <!-- Content Body -->
          <tr>
            <td style="padding: 32px 28px;">
              <div style="font-size: 17px; font-weight: 700; color: #0f172a; margin-bottom: 8px;">
                Hello, ${_esc(fullName)}!
              </div>
              <div style="margin-bottom: 20px;">
                <span style="display: inline-block; background-color: #ccfbf1; color: #0f766e; padding: 3px 10px; border-radius: 4px; font-size: 12px; font-weight: 700;">
                  ${_esc(roleTitle)} &bull; ID: ${_esc(userId)}
                </span>
              </div>
              <p style="font-size: 14px; line-height: 1.6; color: #334155; margin: 0 0 18px;">
                School administration has reviewed your inquiry and submitted the following official response:
              </p>

              <!-- Inquiry Box -->
              <table border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #f8fafc; border-left: 4px solid #94a3b8; border-radius: 0 8px 8px 0; margin-bottom: 20px;">
                <tr>
                  <td style="padding: 14px 16px;">
                    <div style="font-size: 11px; font-weight: 700; color: #64748b; text-transform: uppercase; letter-spacing: 0.8px; margin-bottom: 6px;">
                      Your Submitted Inquiry:
                    </div>
                    <div style="font-size: 14px; color: #475569; font-style: italic; line-height: 1.5;">
                      "${_esc(inquiryQuestion)}"
                    </div>
                  </td>
                </tr>
              </table>

              <!-- Reply Card -->
              <table border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 10px; margin-bottom: 24px;">
                <tr>
                  <td style="padding: 18px 20px;">
                    <div style="font-size: 13px; font-weight: 700; color: #166534; margin-bottom: 10px;">
                      &#9989; Administrative Response from ${_esc(adminName)}:
                    </div>
                    <div style="font-size: 14px; color: #14532d; line-height: 1.6; white-space: pre-wrap; font-weight: 500;">
                      ${_esc(adminReply)}
                    </div>
                  </td>
                </tr>
              </table>

              <!-- Audit Details -->
              <table border="0" cellpadding="0" cellspacing="0" width="100%" style="border-top: 1px dashed #cbd5e1; margin-bottom: 24px;">
                <tr>
                  <td style="padding-top: 12px; font-size: 12px; color: #64748b; line-height: 1.6;">
                    &bull; <strong>System Sync:</strong> A copy of this reply has been placed in your in-app notification inbox.<br />
                    &bull; <strong>Delivered to:</strong> ${_esc(toEmail)}
                  </td>
                </tr>
              </table>

              <!-- Action Button -->
              <table border="0" cellpadding="0" cellspacing="0" width="100%">
                <tr>
                  <td align="center" style="padding-bottom: 8px;">
                    <table border="0" cellpadding="0" cellspacing="0">
                      <tr>
                        <td align="center" style="background-color: #0d9488; border-radius: 8px;">
                          <a href="https://aira-app-database.web.app" target="_blank" style="display: inline-block; padding: 13px 28px; font-size: 14px; font-weight: 700; color: #ffffff !important; text-decoration: none; border-radius: 8px; letter-spacing: 0.2px;">
                            Open AIRA Portal &rarr;
                          </a>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td align="center" style="background-color: #fafafa; border-top: 1px solid #f1f5f9; padding: 20px 24px; font-size: 12px; color: #94a3b8; line-height: 1.5;">
              Sent automatically by AIRA Academic Management &bull; School Administration
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
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
      mailType: 'inquiry_response',
      successMessage: 'Inquiry reply sent to $toEmail via Gmail SMTP',
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

    // 2. HTTP SMTP Bridge Delivery (For Local Web & fallback on emulator/desktop)
    final isHttpsWeb = kIsWeb && Uri.base.scheme == 'https';
    if (!sent && (!isHttpsWeb || EmailConfig.cloudBridgeUrl.startsWith('https://'))) {
      final isCloudBridge = EmailConfig.cloudBridgeUrl.startsWith('https://');
      final dio = Dio(BaseOptions(
        connectTimeout: Duration(seconds: isCloudBridge ? 40 : 3),
        receiveTimeout: const Duration(seconds: 25),
      ))..interceptors.add(RateLimitInterceptor());

      final List<String> bridgeCandidates = [];
      if (EmailConfig.cloudBridgeUrl.isNotEmpty) {
        bridgeCandidates.add(EmailConfig.cloudBridgeUrl);
      }

      if (kIsWeb) {
        if (!isHttpsWeb) {
          final host = Uri.base.host;
          if (host == 'localhost') {
            bridgeCandidates.addAll([
              'http://localhost:8088/send-email',
              'http://127.0.0.1:8088/send-email',
            ]);
          } else if (host == '127.0.0.1') {
            bridgeCandidates.addAll([
              'http://127.0.0.1:8088/send-email',
              'http://localhost:8088/send-email',
            ]);
          } else if (host.isNotEmpty) {
            bridgeCandidates.addAll([
              'http://$host:8088/send-email',
              'http://localhost:8088/send-email',
              'http://127.0.0.1:8088/send-email',
            ]);
          } else {
            bridgeCandidates.addAll([
              'http://localhost:8088/send-email',
              'http://127.0.0.1:8088/send-email',
            ]);
          }
        }
      } else {
        bridgeCandidates.addAll([
          EmailConfig.emulatorBridgeUrl,
          EmailConfig.localBridgeUrl,
          'http://localhost:8088/send-email',
        ]);
      }

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
          debugPrint('[EmailService] Bridge endpoint ($endpoint) attempt note: $bridgeErr');
        }
      }
    }

    // 3. Cloud Firestore Queue Delivery & Audit
    // Enables Deployed Web (Firebase Hosting) to dispatch emails reliably
    // without Mixed Content blocks or needing a local open port on client devices.
    final docId = 'mail_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
    final firestoreDio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 8),
    ))..interceptors.add(RateLimitInterceptor());

    final docUrl = 'https://firestore.googleapis.com/v1/projects/${FirestoreService.projectId}/databases/(default)/documents/mail/$docId?key=${FirestoreService.apiKey}';

    if (!sent) {
      try {
        debugPrint('[EmailService] Enqueuing email into Cloud Firestore queue: $docId');
        final fields = <String, dynamic>{
          'to': {'stringValue': toEmail},
          'subject': {'stringValue': subject},
          'text': {'stringValue': textContent},
          'html': {'stringValue': htmlContent},
          'user_id': {'stringValue': userId},
          'role': {'stringValue': role},
          'mail_type': {'stringValue': mailType},
          'created_at': {'stringValue': DateTime.now().toIso8601String()},
          'status': {'stringValue': 'pending'},
        };
        if (username != null && username.isNotEmpty) {
          fields['username'] = {'stringValue': username};
        }

        final putResp = await firestoreDio.patch(docUrl, data: {'fields': fields});

        if (putResp.statusCode == 200 || putResp.statusCode == 201) {
          // Poll Firestore up to 6 seconds to see if our daemon dispatched it immediately
          bool pickedUp = false;
          for (int attempt = 0; attempt < 6; attempt++) {
            await Future.delayed(const Duration(milliseconds: 1000));
            try {
              final checkResp = await firestoreDio.get(docUrl);
              if (checkResp.statusCode == 200) {
                final checkData = checkResp.data as Map<String, dynamic>?;
                final checkFields = checkData?['fields'] as Map<String, dynamic>?;
                final checkStatus = checkFields?['status']?['stringValue'] as String?;
                if (checkStatus == 'sent_via_smtp') {
                  sent = true;
                  channel = 'smtp_cloud_bridge';
                  pickedUp = true;
                  debugPrint('[EmailService] Cloud Queue confirmed dispatch via SMTP for $docId');
                  break;
                } else if (checkStatus == 'failed') {
                  final err = checkFields?['error']?['stringValue'] as String? ?? 'Delivery failed in cloud bridge';
                  debugPrint('[EmailService] Cloud Queue dispatch failed: $err');
                  break;
                }
              }
            } catch (_) {}
          }

          if (!pickedUp) {
            // Still in queue - daemon will deliver it as soon as ready!
            sent = true;
            channel = 'cloud_queue_pending';
            debugPrint('[EmailService] Email safely enqueued in Cloud Firestore (awaiting daemon sync)');
          }
        }
      } catch (queueErr) {
        debugPrint('[EmailService] Cloud Firestore queue error: $queueErr');
      }
    } else {
      // Record audit record in Firestore if sent natively or via local bridge
      try {
        final fields = <String, dynamic>{
          'to': {'stringValue': toEmail},
          'subject': {'stringValue': subject},
          'user_id': {'stringValue': userId},
          'role': {'stringValue': role},
          'mail_type': {'stringValue': mailType},
          'created_at': {'stringValue': DateTime.now().toIso8601String()},
          'status': {'stringValue': 'sent_via_$channel'},
        };
        if (username != null && username.isNotEmpty) {
          fields['username'] = {'stringValue': username};
        }
        await firestoreDio.patch(docUrl, data: {'fields': fields});
      } catch (e) {
        debugPrint('[EmailService] Cloud mail audit note: $e');
      }
    }

    final String finalMessage;
    if (sent) {
      if (channel == 'cloud_queue_pending') {
        finalMessage = 'Credentials email enqueued for delivery to $toEmail. It will be dispatched automatically via Gmail SMTP.';
      } else {
        finalMessage = successMessage;
      }
    } else {
      finalMessage = 'Could not deliver email to $toEmail. Please ensure the SMTP bridge daemon (start_smtp_bridge.bat) is running or internet connectivity is active.';
    }

    final result = EmailResult(
      success: sent,
      message: finalMessage,
      channel: channel,
    );

    lastResult = result;
    return result;
  }
}


