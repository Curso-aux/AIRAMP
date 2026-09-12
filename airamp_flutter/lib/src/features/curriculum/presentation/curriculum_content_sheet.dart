import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../../core/theme/app_theme.dart';
import '../../admin/data/admin_repository.dart';

/// Icon lookup based on content type
IconData getIconForType(String? type) {
  switch ((type ?? '').toLowerCase()) {
    case 'youtube':
      return Icons.play_circle_outline;
    case 'pdf':
      return Icons.picture_as_pdf_outlined;
    case 'ppt':
      return Icons.slideshow_outlined;
    case 'doc':
      return Icons.description_outlined;
    case 'image':
      return Icons.image_outlined;
    case 'video':
      return Icons.videocam_outlined;
    default:
      return Icons.article_outlined;
  }
}

/// Color lookup based on content type
Color getColorForType(String? type) {
  switch ((type ?? '').toLowerCase()) {
    case 'youtube':
      return const Color(0xFFEF4444);
    case 'pdf':
      return const Color(0xFFE11D48);
    case 'ppt':
      return const Color(0xFFEA580C);
    case 'doc':
      return const Color(0xFF2563EB);
    case 'image':
      return const Color(0xFF0D9488);
    case 'video':
      return const Color(0xFF7C3AED);
    default:
      return AppTheme.primary;
  }
}

/// Checks if the content type corresponds to an uploadable file
bool isFileType(String type) {
  return const ['pdf', 'ppt', 'doc', 'image', 'video'].contains(type.toLowerCase());
}

/// Returns allowed file extensions for file picker filtering
List<String> allowedExtensionsFor(String type) {
  switch (type.toLowerCase()) {
    case 'pdf':
      return ['pdf'];
    case 'ppt':
      return ['ppt', 'pptx', 'odp'];
    case 'doc':
      return ['doc', 'docx', 'txt', 'rtf', 'odt', 'pages'];
    case 'image':
      return ['png', 'jpg', 'jpeg', 'webp', 'gif', 'svg'];
    case 'video':
      return ['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'];
    default:
      return ['pdf', 'ppt', 'pptx', 'doc', 'docx', 'txt', 'png', 'jpg', 'mp4'];
  }
}

/// Formats byte size into human readable string (KB / MB)
String formatFileSize(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Structured metadata for uploaded files stored in [contents.content_data]
class MaterialFileInfo {
  final bool isFile;
  final String fileName;
  final int fileSize;
  final String fileExtension;
  final String? filePath;
  final String? description;

  const MaterialFileInfo({
    required this.isFile,
    required this.fileName,
    required this.fileSize,
    required this.fileExtension,
    this.filePath,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'is_file': true,
        'file_name': fileName,
        'file_size': fileSize,
        'file_extension': fileExtension,
        if (filePath != null) 'file_path': filePath,
        if (description != null) 'description': description,
      };

  static MaterialFileInfo? tryParse(String? data) {
    if (data == null || data.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic> && decoded['is_file'] == true) {
        return MaterialFileInfo(
          isFile: true,
          fileName: decoded['file_name']?.toString() ?? 'File',
          fileSize: (decoded['file_size'] as num?)?.toInt() ?? 0,
          fileExtension: decoded['file_extension']?.toString() ?? '',
          filePath: decoded['file_path']?.toString(),
          description: decoded['description']?.toString(),
        );
      }
    } catch (_) {}
    return null;
  }
}

// ─────────────────────────────────────────────────────────────
// Add Content Sheet with Real File Drop & Pick
// ─────────────────────────────────────────────────────────────

class AddContentSheet extends ConsumerStatefulWidget {
  final int loId;
  final int subjectId;

  const AddContentSheet({
    super.key,
    required this.loId,
    required this.subjectId,
  });

  @override
  ConsumerState<AddContentSheet> createState() => _AddContentSheetState();
}

class _AddContentSheetState extends ConsumerState<AddContentSheet> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedType = 'Text';

  // File state
  String? _pickedFileName;
  int _pickedFileSize = 0;
  String? _pickedFilePath;
  bool _isDragging = false;
  bool _isProcessing = false;

  final List<Map<String, dynamic>> _types = [
    {'name': 'Text', 'icon': Icons.article_outlined},
    {'name': 'YouTube', 'icon': Icons.play_circle_outline},
    {'name': 'PDF', 'icon': Icons.picture_as_pdf_outlined},
    {'name': 'PPT', 'icon': Icons.slideshow_outlined},
    {'name': 'Doc', 'icon': Icons.description_outlined},
    {'name': 'Image', 'icon': Icons.image_outlined},
    {'name': 'Video', 'icon': Icons.videocam_outlined},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onTypeChanged(String type) {
    setState(() {
      _selectedType = type;
    });
  }

  Future<void> _pickFile() async {
    setState(() => _isProcessing = true);
    try {
      final allowed = allowedExtensionsFor(_selectedType);
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowed,
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final size = await file.length();
        _applyFileSelection(
          name: file.name,
          size: size,
          path: file.path,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick file: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _applyFileSelection({
    required String name,
    required int size,
    String? path,
  }) {
    setState(() {
      _pickedFileName = name;
      _pickedFileSize = size;
      _pickedFilePath = path;

      // Auto-fill title if empty
      if (_titleController.text.trim().isEmpty) {
        final dotIndex = name.lastIndexOf('.');
        final cleanName = (dotIndex != -1) ? name.substring(0, dotIndex) : name;
        _titleController.text = cleanName.replaceAll(RegExp(r'[_+\-]'), ' ');
      }
    });
  }

  Future<void> _onFileDropped(DropItem item) async {
    final length = await item.length();
    _applyFileSelection(
      name: item.name,
      size: length,
      path: item.path,
    );
  }

  void _removeSelectedFile() {
    setState(() {
      _pickedFileName = null;
      _pickedFileSize = 0;
      _pickedFilePath = null;
    });
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a content title'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    String contentData = '';

    if (isFileType(_selectedType)) {
      if (_pickedFileName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select or drop a real $_selectedType file'),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }

      final fileInfo = MaterialFileInfo(
        isFile: true,
        fileName: _pickedFileName!,
        fileSize: _pickedFileSize,
        fileExtension: _pickedFileName!.contains('.')
            ? _pickedFileName!.split('.').last.toLowerCase()
            : _selectedType.toLowerCase(),
        filePath: _pickedFilePath,
        description: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );
      contentData = jsonEncode(fileInfo.toJson());
    } else {
      contentData = _contentController.text.trim();
      if (contentData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_selectedType == 'YouTube'
                ? 'Please enter a YouTube video URL'
                : 'Please enter content text'),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }
    }

    ref.read(subjectDetailProvider.notifier).addContent(widget.loId, {
      'title': title,
      'content_type': _selectedType,
      'content_data': contentData,
    });

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Learning material "$title" added successfully'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _CurriculumBottomSheetContainer(
      title: 'Add Learning Material',
      onSave: _save,
      saveLabel: 'Save Material',
      children: [
        // Content Type selector
        Text(
          'Content Type',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _types.map((type) {
              final isSelected = _selectedType == type['name'];
              final color = getColorForType(type['name']);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: Icon(
                    type['icon'],
                    color: isSelected ? Colors.black : color,
                    size: 16,
                  ),
                  label: Text(type['name']),
                  selected: isSelected,
                  onSelected: (_) => _onTypeChanged(type['name']),
                  selectedColor: AppTheme.primary,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : AppTheme.textMuted,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppTheme.primary : AppTheme.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Title input
        Text(
          'Material Title',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _titleController,
          hintText: 'e.g. Lesson 1 Slides or Guide',
        ),
        const SizedBox(height: 16),

        // Dynamic body based on type
        if (isFileType(_selectedType)) ...[
          Text(
            'Upload File ($_selectedType)',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildFileDropZone(),
          const SizedBox(height: 16),
          Text(
            'Instructions / Notes (Optional)',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _notesController,
            hintText: 'Add supplementary instructions or objectives...',
            maxLines: 2,
          ),
        ] else if (_selectedType == 'YouTube') ...[
          Text(
            'YouTube Video Link',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _contentController,
            hintText: 'https://www.youtube.com/watch?v=...',
            prefixIcon: const Icon(Icons.link, size: 18),
          ),
        ] else ...[
          Text(
            'Text Content / Lecture Notes',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _contentController,
            hintText: 'Enter complete lesson text, definitions, or instructions...',
            maxLines: 6,
          ),
        ],
      ],
    );
  }

  Widget _buildFileDropZone() {
    final hasFile = _pickedFileName != null;
    final color = getColorForType(_selectedType);

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) async {
        setState(() => _isDragging = false);
        if (details.files.isNotEmpty) {
          await _onFileDropped(details.files.first);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isDragging
              ? color.withValues(alpha: 0.12)
              : hasFile
                  ? Theme.of(context).colorScheme.surface
                  : AppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isDragging
                ? color
                : hasFile
                    ? AppTheme.primary
                    : AppTheme.border,
            width: _isDragging || hasFile ? 1.5 : 1,
            style: BorderStyle.solid,
          ),
        ),
        child: hasFile
            ? _buildSelectedFileCard(color)
            : _buildUploadPlaceholder(color),
      ),
    );
  }

  Widget _buildUploadPlaceholder(Color color) {
    final allowedExts = allowedExtensionsFor(_selectedType).map((e) => '.$e').join(', ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isDragging ? Icons.file_download_outlined : Icons.cloud_upload_outlined,
            size: 28,
            color: color,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _isDragging
              ? 'Drop your file right here!'
              : 'Drop your $_selectedType file here',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Supports $allowedExts',
          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _isProcessing ? null : _pickFile,
          icon: _isProcessing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : const Icon(Icons.folder_open, size: 16),
          label: Text(
            _isProcessing ? 'Selecting...' : 'Browse File',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedFileCard(Color color) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(getIconForType(_selectedType), color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _pickedFileName ?? 'File',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Ready',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.success,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatFileSize(_pickedFileSize),
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Change File',
          icon: Icon(Icons.sync, size: 18, color: AppTheme.primary),
          onPressed: _pickFile,
        ),
        IconButton(
          tooltip: 'Remove',
          icon: Icon(Icons.close, size: 18, color: AppTheme.error),
          onPressed: _removeSelectedFile,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Edit Content Sheet with Real File Drop & Pick
// ─────────────────────────────────────────────────────────────

class EditContentSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> contentItem;
  final int subjectId;

  const EditContentSheet({
    super.key,
    required this.contentItem,
    required this.subjectId,
  });

  @override
  ConsumerState<EditContentSheet> createState() => _EditContentSheetState();
}

class _EditContentSheetState extends ConsumerState<EditContentSheet> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _notesController;
  late String _selectedType;

  String? _pickedFileName;
  int _pickedFileSize = 0;
  String? _pickedFilePath;
  bool _isDragging = false;
  bool _isProcessing = false;

  final List<Map<String, dynamic>> _types = [
    {'name': 'Text', 'icon': Icons.article_outlined},
    {'name': 'YouTube', 'icon': Icons.play_circle_outline},
    {'name': 'PDF', 'icon': Icons.picture_as_pdf_outlined},
    {'name': 'PPT', 'icon': Icons.slideshow_outlined},
    {'name': 'Doc', 'icon': Icons.description_outlined},
    {'name': 'Image', 'icon': Icons.image_outlined},
    {'name': 'Video', 'icon': Icons.videocam_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.contentItem['title']);
    _selectedType = widget.contentItem['content_type'] ?? 'Text';

    final rawData = widget.contentItem['content_data']?.toString() ?? '';
    final fileInfo = MaterialFileInfo.tryParse(rawData);

    if (fileInfo != null) {
      _pickedFileName = fileInfo.fileName;
      _pickedFileSize = fileInfo.fileSize;
      _pickedFilePath = fileInfo.filePath;
      _notesController = TextEditingController(text: fileInfo.description ?? '');
      _contentController = TextEditingController();
    } else {
      _contentController = TextEditingController(text: rawData);
      _notesController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() => _isProcessing = true);
    try {
      final allowed = allowedExtensionsFor(_selectedType);
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowed,
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final size = await file.length();
        setState(() {
          _pickedFileName = file.name;
          _pickedFileSize = size;
          _pickedFilePath = file.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick file: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _onFileDropped(DropItem item) async {
    final length = await item.length();
    setState(() {
      _pickedFileName = item.name;
      _pickedFileSize = length;
      _pickedFilePath = item.path;
    });
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Please enter a content title'), backgroundColor: AppTheme.error),
      );
      return;
    }

    String contentData = '';
    if (isFileType(_selectedType)) {
      if (_pickedFileName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select or drop a $_selectedType file'), backgroundColor: AppTheme.error),
        );
        return;
      }
      final fileInfo = MaterialFileInfo(
        isFile: true,
        fileName: _pickedFileName!,
        fileSize: _pickedFileSize,
        fileExtension: _pickedFileName!.contains('.')
            ? _pickedFileName!.split('.').last.toLowerCase()
            : _selectedType.toLowerCase(),
        filePath: _pickedFilePath,
        description: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );
      contentData = jsonEncode(fileInfo.toJson());
    } else {
      contentData = _contentController.text.trim();
    }

    ref.read(subjectDetailProvider.notifier).updateContent(widget.contentItem['id'], {
      'title': title,
      'content_type': _selectedType,
      'content_data': contentData,
    });

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Updated "$title" successfully'), backgroundColor: AppTheme.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _CurriculumBottomSheetContainer(
      title: 'Edit Learning Material',
      onSave: _save,
      saveLabel: 'Update Material',
      children: [
        Text(
          'Content Type',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _types.map((type) {
              final isSelected = _selectedType == type['name'];
              final color = getColorForType(type['name']);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: Icon(type['icon'], color: isSelected ? Colors.black : color, size: 16),
                  label: Text(type['name']),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedType = type['name']),
                  selectedColor: AppTheme.primary,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : AppTheme.textMuted,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Material Title',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _buildTextField(controller: _titleController, hintText: 'Content title'),
        const SizedBox(height: 16),

        if (isFileType(_selectedType)) ...[
          Text(
            'Uploaded File ($_selectedType)',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _buildFileDropZone(),
          const SizedBox(height: 16),
          Text(
            'Instructions / Notes (Optional)',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _notesController,
            hintText: 'Add supplementary instructions or notes...',
            maxLines: 2,
          ),
        ] else if (_selectedType == 'YouTube') ...[
          Text(
            'YouTube Video Link',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _contentController,
            hintText: 'https://www.youtube.com/watch?v=...',
            prefixIcon: const Icon(Icons.link, size: 18),
          ),
        ] else ...[
          Text(
            'Text Content / Lecture Notes',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _contentController,
            hintText: 'Enter text content...',
            maxLines: 6,
          ),
        ],
      ],
    );
  }

  Widget _buildFileDropZone() {
    final hasFile = _pickedFileName != null;
    final color = getColorForType(_selectedType);

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) async {
        setState(() => _isDragging = false);
        if (details.files.isNotEmpty) {
          await _onFileDropped(details.files.first);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isDragging
              ? color.withValues(alpha: 0.12)
              : hasFile
                  ? Theme.of(context).colorScheme.surface
                  : AppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isDragging
                ? color
                : hasFile
                    ? AppTheme.primary
                    : AppTheme.border,
            width: _isDragging || hasFile ? 1.5 : 1,
          ),
        ),
        child: hasFile
            ? Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(getIconForType(_selectedType), color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pickedFileName!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          formatFileSize(_pickedFileSize),
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Replace File',
                    icon: Icon(Icons.sync, size: 18, color: AppTheme.primary),
                    onPressed: _isProcessing ? null : _pickFile,
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 28, color: color),
                  const SizedBox(height: 8),
                  Text('Drop replacement file here or browse', style: TextStyle(fontSize: 12, color: AppTheme.text)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isProcessing ? null : _pickFile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    ),
                    child: Text(_isProcessing ? 'Selecting...' : 'Browse', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared Helper Widgets for Curriculum Sheets
// ─────────────────────────────────────────────────────────────

Widget _buildTextField({
  required TextEditingController controller,
  required String hintText,
  int maxLines = 1,
  Widget? prefixIcon,
}) {
  return TextField(
    controller: controller,
    maxLines: maxLines,
    style: TextStyle(color: AppTheme.text, fontSize: 13),
    decoration: InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: AppTheme.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
      ),
    ),
  );
}

class _CurriculumBottomSheetContainer extends StatelessWidget {
  final String title;
  final VoidCallback onSave;
  final String saveLabel;
  final List<Widget> children;

  const _CurriculumBottomSheetContainer({
    required this.title,
    required this.onSave,
    this.saveLabel = 'Save',
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                saveLabel,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
