/// Web / Non-IO stub for SMTP email sending.
Future<bool> sendNativeSmtp({
  required String toEmail,
  required String subject,
  required String textContent,
  required String htmlContent,
}) async {
  // Direct raw TCP sockets are restricted by web browsers.
  return false;
}
