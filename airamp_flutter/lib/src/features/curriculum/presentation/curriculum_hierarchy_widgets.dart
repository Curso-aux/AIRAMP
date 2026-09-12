import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../admin/data/admin_repository.dart';
import 'curriculum_content_sheet.dart';

// ─────────────────────────────────────────────────────────────
// Expandable Topic Card
// ─────────────────────────────────────────────────────────────

class TopicCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> topic;
  final int topicIndex;
  final int subjectId;
  final bool canEdit;

  const TopicCard({
    super.key,
    required this.topic,
    required this.topicIndex,
    required this.subjectId,
    this.canEdit = true,
  });

  @override
  ConsumerState<TopicCard> createState() => _TopicCardState();
}

class _TopicCardState extends ConsumerState<TopicCard> {
  bool _isExpanded = false;

  void _confirmDeleteTopic() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Delete Topic', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "${widget.topic['title']}" and all associated learning materials?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              ref.read(subjectDetailProvider.notifier).deleteTopic(widget.topic['id']);
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final los = (widget.topic['learning_outcomes'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Topic Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.topicIndex}',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOPIC ${widget.topicIndex}',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.topic['title'] ?? 'Untitled Topic',
                          style: TextStyle(
                            color: AppTheme.text,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${los.length} Learning Outcome${los.length == 1 ? '' : 's'}',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (widget.canEdit) ...[
                    IconButton(
                      icon: Icon(Icons.edit_outlined, color: AppTheme.primary, size: 18),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                      tooltip: 'Edit Topic',
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => EditTopicSheet(topic: widget.topic, subjectId: widget.subjectId),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: AppTheme.error, size: 18),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                      tooltip: 'Delete Topic',
                      onPressed: _confirmDeleteTopic,
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4),
                    child: Icon(
                      _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: AppTheme.textMuted,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            if (widget.topic['description'] != null &&
                widget.topic['description'].toString().trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                child: Text(
                  widget.topic['description'],
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                ),
              ),

            // Add LO Button
            if (widget.canEdit)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: OutlinedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => AddLOSheet(topicId: widget.topic['id'], subjectId: widget.subjectId),
                    );
                  },
                  icon: Icon(Icons.add, color: AppTheme.primary, size: 16),
                  label: const Text('Add Learning Outcome', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(double.infinity, 38),
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // LOs List
            if (los.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 20, top: 8),
                child: Center(
                  child: Text(
                    'No learning outcomes added yet.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 16),
                child: Column(
                  children: los.asMap().entries.map((entry) {
                    return LOCard(
                      lo: entry.value,
                      loIndex: entry.key + 1,
                      subjectId: widget.subjectId,
                      canEdit: widget.canEdit,
                    );
                  }).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Expandable Learning Outcome Card
// ─────────────────────────────────────────────────────────────

class LOCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> lo;
  final int loIndex;
  final int subjectId;
  final bool canEdit;

  const LOCard({
    super.key,
    required this.lo,
    required this.loIndex,
    required this.subjectId,
    this.canEdit = true,
  });

  @override
  ConsumerState<LOCard> createState() => _LOCardState();
}

class _LOCardState extends ConsumerState<LOCard> {
  bool _isExpanded = false;

  void _confirmDeleteLO() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Delete Learning Outcome', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "${widget.lo['title']}" and its materials?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              ref.read(subjectDetailProvider.notifier).deleteLearningOutcome(widget.lo['id']);
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contents = (widget.lo['contents'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 8),
                    child: Icon(
                      Icons.flag_outlined,
                      color: AppTheme.primary,
                      size: 16,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LO ${widget.loIndex}',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.lo['title'] ?? 'Untitled LO',
                          style: TextStyle(
                            color: AppTheme.text,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${contents.length} material${contents.length == 1 ? '' : 's'}',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (widget.canEdit) ...[
                    IconButton(
                      icon: Icon(Icons.edit_outlined, color: AppTheme.primary, size: 16),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      tooltip: 'Edit LO',
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => EditLOSheet(lo: widget.lo, subjectId: widget.subjectId),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: AppTheme.error, size: 16),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      tooltip: 'Delete LO',
                      onPressed: _confirmDeleteLO,
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 2),
                    child: Icon(
                      _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: AppTheme.textMuted,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            if (widget.lo['description'] != null &&
                widget.lo['description'].toString().trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Text(
                  widget.lo['description'],
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.3),
                ),
              ),

            // Performance criteria
            if (widget.lo['performance_criteria'] != null &&
                widget.lo['performance_criteria'].toString().trim().isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle_outline, size: 14, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Performance Criteria',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.lo['performance_criteria'],
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.4),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 6),

            // Learning Materials Header + Add Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Learning Materials (${contents.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.text,
                    ),
                  ),
                  if (widget.canEdit)
                    ElevatedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => AddContentSheet(
                            loId: widget.lo['id'],
                            subjectId: widget.subjectId,
                          ),
                        );
                      },
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Add Material', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(0, 30),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                ],
              ),
            ),

            // Content List
            if (contents.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: Text(
                    'No learning materials yet. Add notes or upload real files.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12).copyWith(bottom: 12),
                child: Column(
                  children: contents.map((c) {
                    return ContentItemTile(
                      content: c,
                      subjectId: widget.subjectId,
                      canEdit: widget.canEdit,
                    );
                  }).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Content Item Tile (Real File & Text Aware)
// ─────────────────────────────────────────────────────────────

class ContentItemTile extends ConsumerWidget {
  final Map<String, dynamic> content;
  final int subjectId;
  final bool canEdit;

  const ContentItemTile({
    super.key,
    required this.content,
    required this.subjectId,
    this.canEdit = true,
  });

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Delete Material', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "${content['title']}"?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              ref.read(subjectDetailProvider.notifier).deleteContent(content['id']);
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = content['content_type']?.toString() ?? 'Text';
    final rawData = content['content_data']?.toString() ?? '';
    final fileInfo = MaterialFileInfo.tryParse(rawData);
    final color = getColorForType(type);
    final icon = getIconForType(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content['title'] ?? 'Material',
                  style: TextStyle(
                    color: AppTheme.text,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                if (fileInfo != null)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          fileInfo.fileExtension.toUpperCase(),
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formatFileSize(fileInfo.fileSize),
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                      ),
                      if (fileInfo.description != null && fileInfo.description!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          '• ${fileInfo.description}',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  )
                else
                  Text(
                    type == 'YouTube' ? 'Video URL' : 'Text Lesson',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (canEdit) ...[
            IconButton(
              icon: Icon(Icons.edit_outlined, color: AppTheme.primary, size: 16),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
              tooltip: 'Edit Material',
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => EditContentSheet(
                    contentItem: content,
                    subjectId: subjectId,
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: AppTheme.error, size: 16),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
              tooltip: 'Delete Material',
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Add & Edit Topic Sheets
// ─────────────────────────────────────────────────────────────

class AddTopicSheet extends ConsumerStatefulWidget {
  final int subjectId;
  const AddTopicSheet({super.key, required this.subjectId});

  @override
  ConsumerState<AddTopicSheet> createState() => _AddTopicSheetState();
}

class _AddTopicSheetState extends ConsumerState<AddTopicSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Please enter a topic title'), backgroundColor: AppTheme.error),
      );
      return;
    }

    ref.read(subjectDetailProvider.notifier).addTopic({
      'title': title,
      'description': _descController.text.trim(),
    });

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Topic "$title" added successfully'), backgroundColor: AppTheme.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _CurriculumModalSheet(
      title: 'Add New Topic',
      onSave: _save,
      saveLabel: 'Create Topic',
      children: [
        Text('Topic Title', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _buildTextField(_titleController, 'e.g. Introduction to Variables and Types'),
        const SizedBox(height: 16),
        Text('Description (Optional)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _buildTextField(_descController, 'Brief topic overview or prerequisites...', maxLines: 3),
      ],
    );
  }
}

class EditTopicSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> topic;
  final int subjectId;
  const EditTopicSheet({super.key, required this.topic, required this.subjectId});

  @override
  ConsumerState<EditTopicSheet> createState() => _EditTopicSheetState();
}

class _EditTopicSheetState extends ConsumerState<EditTopicSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.topic['title']);
    _descController = TextEditingController(text: widget.topic['description'] ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    ref.read(subjectDetailProvider.notifier).updateTopic(widget.topic['id'], {
      'title': title,
      'description': _descController.text.trim(),
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _CurriculumModalSheet(
      title: 'Edit Topic',
      onSave: _save,
      saveLabel: 'Save Changes',
      children: [
        Text('Topic Title', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _buildTextField(_titleController, 'Topic title'),
        const SizedBox(height: 16),
        Text('Description', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _buildTextField(_descController, 'Description', maxLines: 3),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Add & Edit Learning Outcome Sheets
// ─────────────────────────────────────────────────────────────

class AddLOSheet extends ConsumerStatefulWidget {
  final int topicId;
  final int subjectId;
  const AddLOSheet({super.key, required this.topicId, required this.subjectId});

  @override
  ConsumerState<AddLOSheet> createState() => _AddLOSheetState();
}

class _AddLOSheetState extends ConsumerState<AddLOSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _criteriaController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _criteriaController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Please enter an outcome title'), backgroundColor: AppTheme.error),
      );
      return;
    }

    ref.read(subjectDetailProvider.notifier).addLearningOutcome(widget.topicId, {
      'title': title,
      'description': _descController.text.trim(),
      'performance_criteria': _criteriaController.text.trim(),
    });

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Learning outcome "$title" added successfully'), backgroundColor: AppTheme.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _CurriculumModalSheet(
      title: 'Add Learning Outcome',
      onSave: _save,
      saveLabel: 'Create LO',
      children: [
        Text('LO Title', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _buildTextField(_titleController, 'e.g. Understand State Management Patterns'),
        const SizedBox(height: 16),
        Text('Description (Optional)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _buildTextField(_descController, 'Detailed objective for students...', maxLines: 2),
        const SizedBox(height: 16),
        Text('Performance Criteria (One per line)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _buildTextField(_criteriaController, '1. Identifies state types\n2. Demonstrates Riverpod usage', maxLines: 3),
      ],
    );
  }
}

class EditLOSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> lo;
  final int subjectId;
  const EditLOSheet({super.key, required this.lo, required this.subjectId});

  @override
  ConsumerState<EditLOSheet> createState() => _EditLOSheetState();
}

class _EditLOSheetState extends ConsumerState<EditLOSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _criteriaController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.lo['title']);
    _descController = TextEditingController(text: widget.lo['description'] ?? '');
    _criteriaController = TextEditingController(text: widget.lo['performance_criteria'] ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _criteriaController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    ref.read(subjectDetailProvider.notifier).updateLearningOutcome(widget.lo['id'], {
      'title': title,
      'description': _descController.text.trim(),
      'performance_criteria': _criteriaController.text.trim(),
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _CurriculumModalSheet(
      title: 'Edit Learning Outcome',
      onSave: _save,
      saveLabel: 'Save Changes',
      children: [
        Text('LO Title', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _buildTextField(_titleController, 'LO title'),
        const SizedBox(height: 16),
        Text('Description', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _buildTextField(_descController, 'Description', maxLines: 2),
        const SizedBox(height: 16),
        Text('Performance Criteria', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _buildTextField(_criteriaController, 'Performance criteria', maxLines: 3),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Modal Bottom Sheet Layout Helper
// ─────────────────────────────────────────────────────────────

Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
  return TextField(
    controller: controller,
    maxLines: maxLines,
    style: TextStyle(color: AppTheme.text, fontSize: 13),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
      filled: true,
      fillColor: AppTheme.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.primary, width: 1.5)),
    ),
  );
}

class _CurriculumModalSheet extends StatelessWidget {
  final String title;
  final VoidCallback onSave;
  final String saveLabel;
  final List<Widget> children;

  const _CurriculumModalSheet({
    required this.title,
    required this.onSave,
    required this.saveLabel,
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
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              IconButton(
                icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
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
              child: Text(saveLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
