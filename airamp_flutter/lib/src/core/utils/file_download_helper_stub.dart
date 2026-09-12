import 'dart:async';
import 'package:flutter/foundation.dart';

/// Stub implementation for non-web environments (tests, desktop, mobile)
void downloadCsvFile(String content, String filename) {
  debugPrint('CSV Download (Stub): $filename (${content.length} bytes)');
}

Future<String?> pickCsvFile() async {
  debugPrint('CSV File Picker (Stub): file picking is handled natively or via paste');
  return null;
}
