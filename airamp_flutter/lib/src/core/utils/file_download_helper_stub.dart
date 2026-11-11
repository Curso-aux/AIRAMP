import 'dart:async';
import 'package:flutter/foundation.dart';

/// Stub implementation for non-web environments (tests, desktop, mobile)
void downloadCsvFile(String content, String filename) {
  debugPrint('CSV Download (Stub): $filename (${content.length} bytes)');
}

/// Stub implementation for non-web binary download
void downloadBinaryFileWeb(List<int> bytes, String filename, String mimeType) {
  debugPrint('Binary Download (Stub): $filename (${bytes.length} bytes)');
}

/// Stub implementation for opening PDF in new tab on web
void openPdfBlobInNewTabWeb(List<int> bytes, String filename) {
  debugPrint('openPdfBlobInNewTabWeb (Stub): $filename (${bytes.length} bytes)');
}

/// Stub implementation for non-web URL trigger
void triggerWebUrlDownload(String url, String filename) {
  debugPrint('Trigger URL Download (Stub): $filename from $url');
}

Future<String?> pickCsvFile() async {
  debugPrint('CSV File Picker (Stub): file picking is handled natively or via paste');
  return null;
}
