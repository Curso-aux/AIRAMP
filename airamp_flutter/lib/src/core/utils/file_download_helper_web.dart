// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

/// Browser-native CSV file download via Blob and AnchorElement
void downloadCsvFile(String content, String filename) {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  html.document.body?.children.remove(anchor);
  html.Url.revokeObjectUrl(url);
}

/// Browser-native file picker returning text content of the selected CSV file
Future<String?> pickCsvFile() {
  final completer = Completer<String?>();
  final input = html.FileUploadInputElement()
    ..accept = '.csv,text/csv,text/plain';

  input.onChange.listen((e) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }
    final file = files[0];
    final reader = html.FileReader();
    reader.readAsText(file);
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result is String) {
        completer.complete(result);
      } else {
        completer.complete(null);
      }
    });
    reader.onError.listen((_) {
      completer.complete(null);
    });
  });

  input.click();
  return completer.future;
}
