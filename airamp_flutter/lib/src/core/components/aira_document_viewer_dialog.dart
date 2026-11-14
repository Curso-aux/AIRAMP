import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/cloud_storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/file_download_helper.dart';
import '../../features/curriculum/presentation/curriculum_content_sheet.dart';
import 'app_toast.dart';

/// Interactive in-app Document & PDF Viewer Dialog for AIRAMP.
/// Allows students and teachers to view, read, search, download, and open curriculum materials
/// directly within the app or in the phone's native system reader.
class AiraDocumentViewerDialog extends StatefulWidget {
  final Map<String, dynamic> content;
  final MaterialFileInfo? fileInfo;

  const AiraDocumentViewerDialog({
    super.key,
    required this.content,
    this.fileInfo,
  });

  /// Displays the in-app document viewer modal.
  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> content,
    MaterialFileInfo? fileInfo,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (ctx) => AiraDocumentViewerDialog(
        content: content,
        fileInfo: fileInfo,
      ),
    );
  }

  /// Opens a local file using the device's native viewer (e.g. Google Drive PDF Viewer, Adobe Acrobat).
  static Future<void> openFileWithSystem({
    required String filePath,
    String mimeType = 'application/pdf',
  }) async {
    if (Platform.isAndroid) {
      try {
        const channel = MethodChannel('com.aral.airamp/file_manager');
        final success = await channel.invokeMethod<bool>('openFile', {
          'filePath': filePath,
          'mimeType': mimeType,
        });
        if (success == true) return;
      } catch (e) {
        debugPrint('[AiraDocumentViewerDialog] MethodChannel openFile error: $e');
      }
    } else if (Platform.isWindows) {
      try {
        final res = await Process.run('cmd', ['/c', 'start', '""', filePath]);
        if (res.exitCode == 0) return;
      } catch (_) {}
    } else if (Platform.isMacOS) {
      try {
        final res = await Process.run('open', [filePath]);
        if (res.exitCode == 0) return;
      } catch (_) {}
    } else if (Platform.isLinux) {
      try {
        final res = await Process.run('xdg-open', [filePath]);
        if (res.exitCode == 0) return;
      } catch (_) {}
    }

    try {
      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  /// Synthesizes DepEd Senior High School curriculum PDF document on-the-fly.
  /// Intelligently parses contentData so raw JSON strings are NEVER displayed.
  static Uint8List generateDepEdPdfBytes({
    required String title,
    required String? description,
    required String? contentData,
  }) {
    final document = PdfDocument();
    final page = document.pages.add();
    final fontTitle = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final fontSubtitle = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
    final fontBody = PdfStandardFont(PdfFontFamily.helvetica, 11);
    final fontFooter = PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.italic);

    // Title banner
    page.graphics.drawString(
      title,
      fontTitle,
      brush: PdfSolidBrush(PdfColor(13, 148, 136)), // Teal
      bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, 26),
    );

    page.graphics.drawString(
      'AIRAMP CURRICULUM MODULE • DEPED SENIOR HIGH SCHOOL',
      fontSubtitle,
      brush: PdfSolidBrush(PdfColor(100, 116, 139)),
      bounds: Rect.fromLTWH(0, 28, page.getClientSize().width, 16),
    );

    page.graphics.drawLine(
      PdfPen(PdfColor(226, 232, 240), width: 1.5),
      const Offset(0, 48),
      Offset(page.getClientSize().width, 48),
    );

    // Parse human-readable body content (eliminating raw JSON metadata)
    String cleanBody = '';
    if (description != null && description.trim().isNotEmpty) {
      cleanBody = description.trim();
    }

    if (contentData != null && contentData.trim().isNotEmpty) {
      final raw = contentData.trim();
      final parsedInfo = MaterialFileInfo.tryParse(raw);
      if (parsedInfo != null) {
        if (parsedInfo.description != null && parsedInfo.description!.trim().isNotEmpty) {
          cleanBody = cleanBody.isNotEmpty ? '$cleanBody\n\n${parsedInfo.description}' : parsedInfo.description!;
        } else {
          final note = 'Course Material: ${parsedInfo.fileName}\nFormat: ${parsedInfo.fileExtension.toUpperCase()} (${formatFileSize(parsedInfo.fileSize)})\n\nOfficial learning module handout published by faculty.';
          cleanBody = cleanBody.isNotEmpty ? '$cleanBody\n\n$note' : note;
        }
      } else if (!raw.startsWith('{') || !raw.endsWith('}')) {
        cleanBody = cleanBody.isNotEmpty ? '$cleanBody\n\n$raw' : raw;
      }
    }

    if (cleanBody.isEmpty) {
      cleanBody = 'Comprehensive lecture reading material and lesson objectives for $title.';
    }

    final textElement = PdfTextElement(
      text: cleanBody,
      font: fontBody,
      brush: PdfSolidBrush(PdfColor(30, 41, 59)),
    );

    final layoutFormat = PdfLayoutFormat(
      layoutType: PdfLayoutType.paginate,
    );

    textElement.draw(
      page: page,
      bounds: Rect.fromLTWH(0, 60, page.getClientSize().width, page.getClientSize().height - 90),
      format: layoutFormat,
    );

    // Footer
    page.graphics.drawString(
      'AIRAMP Automated Offline-First Learning Platform',
      fontFooter,
      brush: PdfSolidBrush(PdfColor(148, 163, 184)),
      bounds: Rect.fromLTWH(0, page.getClientSize().height - 20, page.getClientSize().width, 16),
    );

    final List<int> savedBytes = document.saveSync();
    document.dispose();
    return Uint8List.fromList(savedBytes);
  }

  @override
  State<AiraDocumentViewerDialog> createState() =>
      _AiraDocumentViewerDialogState();
}

class _AiraDocumentViewerDialogState extends State<AiraDocumentViewerDialog> {
  bool _isLoading = true;
  String? _errorMessage;
  Uint8List? _documentBytes;
  List<String> _pages = [];
  int _currentPageIndex = 0;
  double _fontSizeScale = 1.0;
  late final ScrollController _pageScrollController;

  @override
  void initState() {
    super.initState();
    _pageScrollController = ScrollController();
    _loadDocumentContent();
  }

  @override
  void dispose() {
    _pageScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDocumentContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final info = widget.fileInfo;
      Uint8List? bytes;

      // 1. Direct Base64 bytes in MaterialFileInfo
      if (info?.fileBytes != null && info!.fileBytes!.trim().isNotEmpty) {
        try {
          bytes = base64Decode(info.fileBytes!.trim());
        } catch (_) {}
      }

      // 2. Check local file path if on Native desktop/mobile
      if (bytes == null && !kIsWeb && info?.filePath != null) {
        try {
          final f = File(info!.filePath!);
          if (f.existsSync()) {
            bytes = await f.readAsBytes();
          }
        } catch (_) {}
      }

      // 3. Check remote HTTP/HTTPS URL
      final rawPath = (info?.filePath ?? '').trim();
      final rawData = (widget.content['content_data']?.toString() ?? '').trim();
      final potentialUrl = rawPath.startsWith('http://') || rawPath.startsWith('https://')
          ? rawPath
          : (rawData.startsWith('http://') || rawData.startsWith('https://') ? rawData : null);

      if (bytes == null && potentialUrl != null) {
        try {
          final res = await Dio().get<List<int>>(
            potentialUrl,
            options: Options(responseType: ResponseType.bytes),
          );
          if (res.data != null) {
            bytes = Uint8List.fromList(res.data!);
          }
        } catch (e) {
          debugPrint('[AiraDocumentViewerDialog] Remote fetch error: $e');
        }
      }

      // 4. Check Cloud Storage
      if (bytes == null && CloudStorageService().isAvailable && info != null) {
        try {
          bytes = await CloudStorageService().downloadCurriculumMaterial(
            fileName: info.fileName,
            loId: widget.content['lo_id'] as int?,
          );
        } catch (_) {}
      }

      // 5. If raw bytes are still missing, synthesize a formatted DepEd PDF on-the-fly
      if (bytes == null || bytes.isEmpty) {
        bytes = AiraDocumentViewerDialog.generateDepEdPdfBytes(
          title: widget.content['title']?.toString() ?? info?.fileName ?? 'Curriculum Module',
          description: info?.description,
          contentData: widget.content['content_data']?.toString(),
        );
      }

      _documentBytes = bytes;

      // 6. Extract text pages using Syncfusion PDF
      final List<String> extractedPages = [];
      try {
        final PdfDocument doc = PdfDocument(inputBytes: bytes);
        final pageCount = doc.pages.count;
        if (pageCount > 0) {
          final extractor = PdfTextExtractor(doc);
          for (int i = 0; i < pageCount; i++) {
            final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
            extractedPages.add(pageText.trim().isEmpty ? '(Page ${i + 1} contains graphical or tabular content)' : pageText.trim());
          }
        }
        doc.dispose();
      } catch (e) {
        debugPrint('[AiraDocumentViewerDialog] Text extraction fallback: $e');
      }

      if (extractedPages.isEmpty) {
        final notes = info?.description ?? widget.content['content_data']?.toString() ?? 'Learning module reading material.';
        extractedPages.add(notes);
      }

      if (mounted) {
        setState(() {
          _pages = extractedPages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load document: $e';
        });
      }
    }
  }

  void _handleDownload() {
    final rawName = widget.fileInfo?.fileName ?? '${widget.content['title'] ?? 'Lecture_Notes'}.pdf';
    AiraDownloadProgressDialog.show(
      context,
      fileName: rawName,
      fileSize: widget.fileInfo?.fileSize ?? _documentBytes?.length ?? 0,
      bytes: _documentBytes,
      content: widget.content,
      fileInfo: widget.fileInfo,
    );
  }

  Future<void> _openInSystemViewer() async {
    if (_documentBytes == null || _documentBytes!.isEmpty) {
      AppToast.showWarning(context, 'Document is still preparing. Please wait.');
      return;
    }

    final rawName = widget.fileInfo?.fileName ?? '${widget.content['title'] ?? 'Lecture_Notes'}.pdf';
    final cleanName = rawName.replaceAll(RegExp(r'[^a-zA-Z0-9._\-]'), '_');
    final ext = cleanName.contains('.') ? cleanName.split('.').last.toLowerCase() : 'pdf';
    final mimeType = ext == 'pdf' ? 'application/pdf' : 'application/octet-stream';

    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$cleanName');
      await tempFile.writeAsBytes(_documentBytes!);
      await AiraDocumentViewerDialog.openFileWithSystem(
        filePath: tempFile.path,
        mimeType: mimeType,
      );
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Could not launch system viewer: $e');
      }
    }
  }

  void _copyCurrentPageText() {
    if (_pages.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _pages[_currentPageIndex]));
    AppToast.showSuccess(context, 'Page text copied to clipboard!');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primary;
    final surface = Theme.of(context).colorScheme.surface;
    final title = widget.content['title']?.toString() ?? widget.fileInfo?.fileName ?? 'Curriculum Material';
    final rawName = widget.fileInfo?.fileName ?? '$title.pdf';
    final fileSizeStr = widget.fileInfo != null ? formatFileSize(widget.fileInfo!.fileSize) : '';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 900),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
              blurRadius: 36,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header Bar ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Color(0xFFEF4444),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              rawName,
                              if (fileSizeStr.isNotEmpty) fileSizeStr,
                              if (_pages.isNotEmpty) '${_pages.length} Pages',
                            ].join(' • '),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Open in External / Native Reader Button
                    IconButton(
                      icon: const Icon(Icons.open_in_new_rounded, size: 19),
                      tooltip: 'Open in System PDF Viewer',
                      onPressed: _openInSystemViewer,
                    ),

                    // Font Zoom Control
                    IconButton(
                      icon: const Icon(Icons.text_fields_rounded, size: 20),
                      tooltip: 'Toggle Font Size',
                      onPressed: () {
                        setState(() {
                          _fontSizeScale = _fontSizeScale >= 1.3 ? 0.9 : _fontSizeScale + 0.15;
                        });
                      },
                    ),

                    // Copy Page Text
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copy text',
                      onPressed: _copyCurrentPageText,
                    ),

                    const SizedBox(width: 4),

                    // Download Action Button (Opens Modal Loading Screen)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _handleDownload,
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text(
                        'Download',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Close Modal Button
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // ── Reader Body ──
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: primary),
                            const SizedBox(height: 16),
                            Text(
                              'Loading & rendering curriculum material...',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.error),
                                  const SizedBox(height: 12),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppTheme.text, fontSize: 13),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadDocumentContent,
                                    child: const Text('Try Again'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Container(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 720),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: surface,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                                        blurRadius: 18,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Top Page Sub-Header
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'OFFICIAL STUDY HANDOUT',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.2,
                                              color: primary,
                                            ),
                                          ),
                                          Text(
                                            _pages.isNotEmpty
                                                ? 'Page ${_currentPageIndex + 1} of ${_pages.length}'
                                                : '',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textMuted,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 20),

                                      // Extracted Document Text View
                                      Expanded(
                                        child: Scrollbar(
                                          controller: _pageScrollController,
                                          thumbVisibility: true,
                                          child: SingleChildScrollView(
                                            controller: _pageScrollController,
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                            child: SelectableText(
                                              _pages.isNotEmpty ? _pages[_currentPageIndex] : '',
                                              style: TextStyle(
                                                fontSize: 14 * _fontSizeScale,
                                                height: 1.65,
                                                color: Theme.of(context).colorScheme.onSurface,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
              ),

              // ── Navigation Bottom Bar ──
              if (_pages.length > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    border: Border(
                      top: BorderSide(
                        color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.chevron_left_rounded, size: 18),
                        label: const Text('Previous'),
                        onPressed: _currentPageIndex > 0
                            ? () {
                                setState(() {
                                  _currentPageIndex--;
                                  _pageScrollController.jumpTo(0);
                                });
                              }
                            : null,
                      ),
                      Text(
                        'Page ${_currentPageIndex + 1} of ${_pages.length}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.chevron_right_rounded, size: 18),
                        label: const Text('Next'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.black,
                          elevation: 0,
                        ),
                        onPressed: _currentPageIndex < _pages.length - 1
                            ? () {
                                setState(() {
                                  _currentPageIndex++;
                                  _pageScrollController.jumpTo(0);
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal Download Progress Dialog that provides animated loading feedback,
/// progress status updates, and ensures files are saved visible to the device's Downloads directory.
class AiraDownloadProgressDialog extends StatefulWidget {
  final String fileName;
  final int fileSize;
  final Uint8List? bytes;
  final String? remoteUrl;
  final Map<String, dynamic>? content;
  final MaterialFileInfo? fileInfo;

  const AiraDownloadProgressDialog({
    super.key,
    required this.fileName,
    required this.fileSize,
    this.bytes,
    this.remoteUrl,
    this.content,
    this.fileInfo,
  });

  static Future<void> show(
    BuildContext context, {
    required String fileName,
    required int fileSize,
    Uint8List? bytes,
    String? remoteUrl,
    Map<String, dynamic>? content,
    MaterialFileInfo? fileInfo,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => AiraDownloadProgressDialog(
        fileName: fileName,
        fileSize: fileSize,
        bytes: bytes,
        remoteUrl: remoteUrl,
        content: content,
        fileInfo: fileInfo,
      ),
    );
  }

  @override
  State<AiraDownloadProgressDialog> createState() => _AiraDownloadProgressDialogState();
}

class _AiraDownloadProgressDialogState extends State<AiraDownloadProgressDialog> {
  double _progress = 0.15;
  String _statusText = 'Preparing download...';
  bool _isCompleted = false;
  bool _hasError = false;
  String? _errorMessage;
  String? _savedPath;
  File? _localFile;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    setState(() {
      _progress = 0.2;
      _statusText = 'Resolving document source...';
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final cleanName = widget.fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._\-]'), '_');
      final ext = cleanName.contains('.') ? cleanName.split('.').last.toLowerCase() : 'pdf';
      final mimeType = ext == 'pdf' ? 'application/pdf' : 'application/octet-stream';

      Uint8List? fileBytes = widget.bytes;

      // 1. Resolve bytes if null
      if (fileBytes == null || fileBytes.isEmpty) {
        if (widget.fileInfo?.fileBytes != null && widget.fileInfo!.fileBytes!.trim().isNotEmpty) {
          try {
            fileBytes = base64Decode(widget.fileInfo!.fileBytes!.trim());
          } catch (_) {}
        }

        if (fileBytes == null && !kIsWeb && widget.fileInfo?.filePath != null) {
          try {
            final f = File(widget.fileInfo!.filePath!);
            if (f.existsSync()) fileBytes = await f.readAsBytes();
          } catch (_) {}
        }

        final targetUrl = widget.remoteUrl ?? widget.fileInfo?.filePath;
        if (fileBytes == null && targetUrl != null && (targetUrl.startsWith('http://') || targetUrl.startsWith('https://'))) {
          setState(() {
            _progress = 0.45;
            _statusText = 'Streaming from Cloud Storage...';
          });
          try {
            final res = await Dio().get<List<int>>(
              targetUrl,
              options: Options(responseType: ResponseType.bytes),
              onReceiveProgress: (received, total) {
                if (total > 0 && mounted) {
                  setState(() {
                    _progress = 0.3 + (received / total * 0.45);
                    _statusText = 'Downloaded ${(received / 1024).toStringAsFixed(0)} KB of ${(total / 1024).toStringAsFixed(0)} KB...';
                  });
                }
              },
            );
            if (res.data != null) {
              fileBytes = Uint8List.fromList(res.data!);
            }
          } catch (_) {}
        }

        if (fileBytes == null && CloudStorageService().isAvailable && widget.fileInfo != null) {
          try {
            fileBytes = await CloudStorageService().downloadCurriculumMaterial(
              fileName: widget.fileInfo!.fileName,
              loId: widget.content?['lo_id'] as int?,
            );
          } catch (_) {}
        }

        if (fileBytes == null || fileBytes.isEmpty) {
          setState(() {
            _progress = 0.7;
            _statusText = 'Compiling official DepEd module document...';
          });
          fileBytes = AiraDocumentViewerDialog.generateDepEdPdfBytes(
            title: widget.content?['title']?.toString() ?? widget.fileInfo?.fileName ?? widget.fileName,
            description: widget.fileInfo?.description,
            contentData: widget.content?['content_data']?.toString(),
          );
        }
      }

      setState(() {
        _progress = 0.85;
        _statusText = 'Registering with device Downloads...';
      });

      // 2. Write to public storage
      String finalSavedPath = '';
      if (kIsWeb) {
        downloadBinaryFileWeb(fileBytes, cleanName, mimeType);
        finalSavedPath = 'Browser Downloads';
      } else if (Platform.isAndroid) {
        // Use native MethodChannel to insert into MediaStore.Downloads
        bool channelSaved = false;
        try {
          const channel = MethodChannel('com.aral.airamp/file_manager');
          final result = await channel.invokeMethod<String>('saveToDownloads', {
            'fileName': cleanName,
            'bytes': fileBytes,
            'mimeType': mimeType,
          });
          if (result != null && result.isNotEmpty) {
            finalSavedPath = result;
            channelSaved = true;
          }
        } catch (e) {
          debugPrint('[AiraDownloadProgressDialog] MethodChannel saveToDownloads note: $e');
        }

        // Cache file for quick opening
        try {
          final tempDir = await getTemporaryDirectory();
          final tempF = File('${tempDir.path}/$cleanName');
          await tempF.writeAsBytes(fileBytes);
          _localFile = tempF;
        } catch (_) {}

        if (!channelSaved) {
          // Fallback to POSIX write
          try {
            final pubDir = Directory('/storage/emulated/0/Download');
            if (pubDir.existsSync()) {
              final pf = File('${pubDir.path}/$cleanName');
              await pf.writeAsBytes(fileBytes);
              finalSavedPath = pf.path;
              _localFile = pf;
            }
          } catch (_) {}

          if (finalSavedPath.isEmpty) {
            final ext = await getExternalStorageDirectory();
            if (ext != null) {
              final ef = File('${ext.path}/$cleanName');
              await ef.writeAsBytes(fileBytes);
              finalSavedPath = ef.path;
              _localFile = ef;
            }
          }
        }
      } else {
        // Desktop
        final targetDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
        final df = File('${targetDir.path}/$cleanName');
        await df.writeAsBytes(fileBytes);
        finalSavedPath = df.path;
        _localFile = df;
      }

      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        setState(() {
          _progress = 1.0;
          _statusText = 'Download Complete!';
          _isCompleted = true;
          _savedPath = finalSavedPath.isNotEmpty ? finalSavedPath : 'Downloads folder';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _openFile() {
    if (_localFile != null && _localFile!.existsSync()) {
      final ext = widget.fileName.contains('.') ? widget.fileName.split('.').last.toLowerCase() : 'pdf';
      final mimeType = ext == 'pdf' ? 'application/pdf' : 'application/octet-stream';
      AiraDocumentViewerDialog.openFileWithSystem(
        filePath: _localFile!.path,
        mimeType: mimeType,
      );
    } else {
      AppToast.showInfo(context, 'File is saved in your device Downloads folder.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primary;
    final surface = Theme.of(context).colorScheme.surface;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status Icon
            if (_hasError)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline_rounded, size: 40, color: AppTheme.error),
              )
            else if (_isCompleted)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded, size: 40, color: AppTheme.success),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.downloading_rounded, size: 40, color: primary),
              ),

            const SizedBox(height: 18),

            // Modal Title
            Text(
              _hasError
                  ? 'Download Error'
                  : _isCompleted
                      ? 'Download Complete!'
                      : 'Downloading Material',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 8),

            // File Details Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.fileName,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.fileSize > 0 ? formatFileSize(widget.fileSize) : 'Study Document',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Progress Bar / Status
            if (!_hasError) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _isCompleted ? 1.0 : _progress,
                  backgroundColor: AppTheme.border.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _isCompleted ? AppTheme.success : primary,
                  ),
                  minHeight: 7,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _statusText,
                style: TextStyle(
                  fontSize: 12,
                  color: _isCompleted ? AppTheme.success : AppTheme.textSecondary,
                  fontWeight: _isCompleted ? FontWeight.bold : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              if (_isCompleted && _savedPath != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Saved to: $_savedPath',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ] else ...[
              Text(
                _errorMessage ?? 'An unexpected error occurred during download.',
                style: TextStyle(fontSize: 12, color: AppTheme.error),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 22),

            // Modal Actions
            Row(
              children: [
                if (_hasError) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _startDownload,
                      child: const Text('Retry'),
                    ),
                  ),
                ] else if (_isCompleted) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Done'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openFile();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text(
                        'Open File',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Background Download',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to trigger document download with animated loading modal.
Future<void> downloadMaterialFileHelper({
  required BuildContext context,
  required Map<String, dynamic> content,
  MaterialFileInfo? fileInfo,
}) async {
  final title = content['title']?.toString() ?? fileInfo?.fileName ?? 'Curriculum_Material';
  final rawName = fileInfo?.fileName ?? '$title.pdf';
  await AiraDownloadProgressDialog.show(
    context,
    fileName: rawName,
    fileSize: fileInfo?.fileSize ?? 0,
    content: content,
    fileInfo: fileInfo,
  );
}
