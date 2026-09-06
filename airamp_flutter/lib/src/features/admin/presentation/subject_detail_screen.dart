import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../data/admin_repository.dart';

class SubjectDetailScreen extends ConsumerStatefulWidget {
  final String subjectId;
  const SubjectDetailScreen({super.key, required this.subjectId});

  @override
  ConsumerState<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends ConsumerState<SubjectDetailScreen> {
  int _selectedTab = 0; // 0 = Topics, 1 = Quizzes
  Map<String, dynamic>? _subject;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSubject();
  }

  Future<void> _loadSubject() async {
    final id = int.tryParse(widget.subjectId);
    if (id == null) return;
    final subject = await ref.read(subjectsProvider.notifier).getSubjectById(id);
    if (mounted) {
      setState(() {
        _subject = subject;
        _loading = false;
      });
      ref.read(subjectDetailProvider.notifier).loadHierarchy(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (_subject == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Subject not found', style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Go Back', style: TextStyle(color: AppTheme.primary)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final subjectId = int.parse(widget.subjectId);
    final subjectName = _subject!['name'] ?? 'Untitled';
    final unlockType = _subject!['unlock_type'] ?? 'Sequential';
    final topics = ref.watch(subjectDetailProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Text(
                    'Manage Subjects',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.text),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'COCs, LOs, content & quizzes',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // Back link
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back, color: AppTheme.primary, size: 18),
                        SizedBox(width: 4),
                        Text(
                          'Back to Subjects',
                          style: TextStyle(color: AppTheme.primary, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Subject Info Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, Color(0xFF0A9B8A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subjectName,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Private subject · Unlock: $unlockType',
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Topics / Quizzes Tab
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedTab = 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedTab == 0 ? AppTheme.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.layers_outlined,
                                    size: 18,
                                    color: _selectedTab == 0 ? Colors.black : AppTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Topics',
                                    style: TextStyle(
                                      color: _selectedTab == 0 ? Colors.black : AppTheme.textSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedTab = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedTab == 1 ? AppTheme.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.help_outline,
                                    size: 18,
                                    color: _selectedTab == 1 ? Colors.black : AppTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Quizzes',
                                    style: TextStyle(
                                      color: _selectedTab == 1 ? Colors.black : AppTheme.textSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Add Topic button
                  if (_selectedTab == 0) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showAddTopicSheet(context, subjectId);
                        },
                        icon: const Icon(
                          Icons.add,
                          color: Colors.black,
                          size: 20,
                        ),
                        label: const Text(
                          'Add Topic',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: _selectedTab == 0 
                  ? _buildTopicsList(topics, subjectId)
                  : _buildQuizzesList(topics, subjectId),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicsList(List<Map<String, dynamic>> topics, int subjectId) {
    if (topics.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.layers_outlined,
              size: 64,
              color: AppTheme.textMuted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'No topics yet. Add your first topic.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: topics.length,
      itemBuilder: (context, index) {
        final topic = topics[index];
        return _TopicCard(topic: topic, topicIndex: index + 1, subjectId: subjectId);
      },
    );
  }

  Widget _buildQuizzesList(List<Map<String, dynamic>> topics, int subjectId) {
    if (topics.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.help_outline,
              size: 64,
              color: AppTheme.textMuted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'No quizzes yet. Add your first quiz.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: topics.length,
      itemBuilder: (context, index) {
        final topic = topics[index];
        return _QuizTopicCard(topic: topic, topicIndex: index + 1, subjectId: subjectId);
      },
    );
  }

  void _showAddTopicSheet(BuildContext context, int subjectId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddTopicSheet(subjectId: subjectId),
    );
  }
}

// ========================
// Expandable Topic Card
// ========================
class _TopicCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> topic;
  final int topicIndex;
  final int subjectId;

  const _TopicCard({required this.topic, required this.topicIndex, required this.subjectId});

  @override
  ConsumerState<_TopicCard> createState() => _TopicCardState();
}

class _TopicCardState extends ConsumerState<_TopicCard> {
  bool _isExpanded = false;

  void _confirmDeleteTopic() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete Topic', style: TextStyle(color: AppTheme.text)),
        content: Text('Are you sure you want to delete "${widget.topic['title']}" and all its contents?',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              ref.read(subjectDetailProvider.notifier).deleteTopic(widget.topic['id']);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final los = widget.topic['learning_outcomes'] as List<Map<String, dynamic>>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Topic Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Topic ${widget.topicIndex}',
                          style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.topic['title'],
                          style: const TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${los.length} Learning Outcomes',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 20),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => _EditTopicSheet(topic: widget.topic, subjectId: widget.subjectId),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                        onPressed: _confirmDeleteTopic,
                      ),
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: AppTheme.textSecondary,
                        size: 24,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (_isExpanded) ...[
            if (widget.topic['description'] != null && widget.topic['description'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Text(
                  widget.topic['description'],
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ),

            // Add LO Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => _AddLOSheet(topicId: widget.topic['id'], subjectId: widget.subjectId),
                  );
                },
                icon: const Icon(Icons.add, color: AppTheme.primary, size: 18),
                label: const Text('Add Learning Outcome'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // LOs List
            if (los.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Center(
                  child: Text('No Learning Outcomes yet', style: TextStyle(color: AppTheme.textMuted, fontStyle: FontStyle.italic)),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 16),
                child: Column(
                  children: los.asMap().entries.map((entry) {
                    return _LOCard(lo: entry.value, loIndex: entry.key + 1, subjectId: widget.subjectId);
                  }).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ========================
// Expandable LO Card
// ========================
class _LOCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> lo;
  final int loIndex;
  final int subjectId;

  const _LOCard({required this.lo, required this.loIndex, required this.subjectId});

  @override
  ConsumerState<_LOCard> createState() => _LOCardState();
}

class _LOCardState extends ConsumerState<_LOCard> {
  bool _isExpanded = false;

  void _confirmDeleteLO() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete Learning Outcome', style: TextStyle(color: AppTheme.text)),
        content: Text('Are you sure you want to delete "${widget.lo['title']}" and all its contents?',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              ref.read(subjectDetailProvider.notifier).deleteLearningOutcome(widget.lo['id']);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contents = widget.lo['contents'] as List<Map<String, dynamic>>? ?? [];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LO Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4, right: 8),
                    child: Icon(Icons.drag_indicator, color: AppTheme.textMuted, size: 16),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LO ${widget.loIndex}',
                          style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.lo['title'],
                          style: const TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${contents.length} content items',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 16),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => _EditLOSheet(lo: widget.lo, subjectId: widget.subjectId),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 16),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        onPressed: _confirmDeleteLO,
                      ),
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (_isExpanded) ...[
            if (widget.lo['description'] != null && widget.lo['description'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 36, right: 12, bottom: 12),
                child: Text(
                  widget.lo['description'],
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ),

            if (widget.lo['performance_criteria'] != null && widget.lo['performance_criteria'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 36, right: 12, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Performance Criteria:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    ...widget.lo['performance_criteria'].toString().split('\n').map((criteria) {
                      if (criteria.trim().isEmpty) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: AppTheme.textMuted)),
                            Expanded(child: Text(criteria, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

            // Add Content Button
            Padding(
              padding: const EdgeInsets.only(left: 36, right: 12, bottom: 16),
              child: OutlinedButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => _AddContentSheet(loId: widget.lo['id'], subjectId: widget.subjectId),
                  );
                },
                icon: const Icon(Icons.add, color: AppTheme.primary, size: 16),
                label: const Text('Add Content', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.15)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  minimumSize: const Size(double.infinity, 36),
                ),
              ),
            ),

            // Content List
            if (contents.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Center(
                  child: Text('No content yet', style: TextStyle(color: AppTheme.textMuted, fontStyle: FontStyle.italic, fontSize: 12)),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 36, right: 12, bottom: 12),
                child: Column(
                  children: contents.map((content) {
                    return _ContentCard(content: content, subjectId: widget.subjectId);
                  }).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ========================
// Content Card
// ========================
class _ContentCard extends ConsumerWidget {
  final Map<String, dynamic> content;
  final int subjectId;

  const _ContentCard({required this.content, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    IconData getIconForType(String type) {
      switch (type) {
        case 'Text': return Icons.article_outlined;
        case 'YouTube': return Icons.play_circle_outline;
        case 'PDF': return Icons.picture_as_pdf_outlined;
        case 'PPT': return Icons.slideshow_outlined;
        case 'Doc': return Icons.description_outlined;
        case 'Image': return Icons.image_outlined;
        case 'Video': return Icons.videocam_outlined;
        default: return Icons.insert_drive_file_outlined;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(getIconForType(content['content_type']), color: AppTheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content['title'],
                  style: const TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  content['content_type'],
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 16),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => _EditContentSheet(contentItem: content, subjectId: subjectId),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 16),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppTheme.surface,
                  title: const Text('Delete Content', style: TextStyle(color: AppTheme.text)),
                  content: Text('Are you sure you want to delete "${content['title']}"?',
                      style: const TextStyle(color: AppTheme.textSecondary)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(subjectDetailProvider.notifier).deleteContent(content['id']);
                        Navigator.pop(context);
                      },
                      child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ========================
// Bottom Sheets
// ========================

class _AddTopicSheet extends ConsumerStatefulWidget {
  final int subjectId;
  const _AddTopicSheet({required this.subjectId});

  @override
  ConsumerState<_AddTopicSheet> createState() => _AddTopicSheetState();
}

class _AddTopicSheetState extends ConsumerState<_AddTopicSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  void _save() {
    ref.read(subjectDetailProvider.notifier).addTopic({
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _BaseBottomSheet(
      title: 'Add Topic',
      onSave: _save,
      children: [
        const Text('Title', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        _buildTextField(_titleController, 'Title of Topic'),
        const SizedBox(height: 16),
        const Text('Description', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        _buildTextField(_descController, 'Description', maxLines: 4),
      ],
    );
  }
}

class _AddLOSheet extends ConsumerStatefulWidget {
  final int topicId;
  final int subjectId;
  const _AddLOSheet({required this.topicId, required this.subjectId});

  @override
  ConsumerState<_AddLOSheet> createState() => _AddLOSheetState();
}

class _AddLOSheetState extends ConsumerState<_AddLOSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _criteriaController = TextEditingController();

  void _save() {
    ref.read(subjectDetailProvider.notifier).addLearningOutcome(widget.topicId, {
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'performance_criteria': _criteriaController.text.trim(),
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _BaseBottomSheet(
      title: 'Add LO',
      onSave: _save,
      children: [
        const Text('Title', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        _buildTextField(_titleController, 'LO title'),
        const SizedBox(height: 16),
        const Text('Description', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        _buildTextField(_descController, 'Description', maxLines: 3),
        const SizedBox(height: 16),
        const Text('Performance Criteria (one per line)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        _buildTextField(_criteriaController, 'Enter criteria...', maxLines: 4),
      ],
    );
  }
}

class _AddContentSheet extends ConsumerStatefulWidget {
  final int loId;
  final int subjectId;
  const _AddContentSheet({required this.loId, required this.subjectId});

  @override
  ConsumerState<_AddContentSheet> createState() => _AddContentSheetState();
}

class _AddContentSheetState extends ConsumerState<_AddContentSheet> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedType = 'Text';

  final List<Map<String, dynamic>> _types = [
    {'name': 'Text', 'icon': Icons.article_outlined},
    {'name': 'YouTube', 'icon': Icons.play_circle_outline},
    {'name': 'PDF', 'icon': Icons.picture_as_pdf_outlined},
    {'name': 'PPT', 'icon': Icons.slideshow_outlined},
    {'name': 'Doc', 'icon': Icons.description_outlined},
    {'name': 'Image', 'icon': Icons.image_outlined},
    {'name': 'Video', 'icon': Icons.videocam_outlined},
  ];

  void _save() {
    ref.read(subjectDetailProvider.notifier).addContent(widget.loId, {
      'title': _titleController.text.trim(),
      'content_type': _selectedType,
      'content_data': _contentController.text.trim(),
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _BaseBottomSheet(
      title: 'Add Content',
      onSave: _save,
      children: [
        const Text('Content Type', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _types.map((type) {
              final isSelected = _selectedType == type['name'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: Icon(type['icon'], color: isSelected ? Colors.black : AppTheme.textMuted, size: 16),
                  label: Text(type['name']),
                  selected: isSelected,
                  onSelected: (selected) => setState(() => _selectedType = type['name']),
                  selectedColor: AppTheme.primary,
                  backgroundColor: AppTheme.surface,
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
        const Text('Title', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        _buildTextField(_titleController, 'Content title'),
        const SizedBox(height: 16),
        const Text('Content', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        _buildTextField(_contentController, 'Enter text content...', maxLines: 5),
      ],
    );
  }
}

// Helper Widget for Bottom Sheets
class _BaseBottomSheet extends StatelessWidget {
  final String title;
  final VoidCallback onSave;
  final List<Widget> children;

  const _BaseBottomSheet({required this.title, required this.onSave, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.text)),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
  return TextField(
    controller: controller,
    style: const TextStyle(color: AppTheme.text),
    maxLines: maxLines,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textMuted),
      filled: true,
      fillColor: AppTheme.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.primary),
      ),
    ),
  );
}

// ========================
// Quiz Cards
// ========================
class _QuizTopicCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> topic;
  final int topicIndex;
  final int subjectId;

  const _QuizTopicCard({required this.topic, required this.topicIndex, required this.subjectId});

  @override
  ConsumerState<_QuizTopicCard> createState() => _QuizTopicCardState();
}

class _QuizTopicCardState extends ConsumerState<_QuizTopicCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final los = widget.topic['learning_outcomes'] as List<Map<String, dynamic>>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Topic Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Topic ${widget.topicIndex}',
                          style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.topic['title'],
                          style: const TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppTheme.textSecondary,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          
          if (_isExpanded) ...[
            if (los.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Center(
                  child: Text('No Learning Outcomes yet', style: TextStyle(color: AppTheme.textMuted, fontStyle: FontStyle.italic)),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 16),
                child: Column(
                  children: los.asMap().entries.map((entry) {
                    return _QuizLOCard(lo: entry.value, loIndex: entry.key + 1, subjectId: widget.subjectId);
                  }).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _QuizLOCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> lo;
  final int loIndex;
  final int subjectId;

  const _QuizLOCard({required this.lo, required this.loIndex, required this.subjectId});

  @override
  ConsumerState<_QuizLOCard> createState() => _QuizLOCardState();
}

class _QuizLOCardState extends ConsumerState<_QuizLOCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final questions = widget.lo['questions'] as List<Map<String, dynamic>>? ?? [];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LO Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LO ${widget.loIndex}: ${widget.lo['title']}',
                          style: const TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${questions.isEmpty ? 'No quiz yet' : '${questions.length} questions'}${widget.lo['passing_score'] != null && widget.lo['passing_score'] > 0 ? ' - Pass: ${widget.lo['passing_score']}%' : ''}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add, color: AppTheme.primary, size: 20),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => _AddQuestionSheet(loId: widget.lo['id'], subjectId: widget.subjectId),
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (_isExpanded) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.lo['passing_score'] != null && widget.lo['passing_score'] > 0
                          ? 'Passing Score: ${widget.lo['passing_score']}%'
                          : 'No passing score set.',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ),
                  if (widget.lo['passing_score'] != null && widget.lo['passing_score'] > 0)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 16),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        ref.read(subjectDetailProvider.notifier).updateLearningOutcome(widget.lo['id'], {
                          'passing_score': 0,
                        });
                      },
                    ),
                ],
              ),
            ),
            
            // Schedule Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppTheme.text, size: 18),
                      const SizedBox(width: 8),
                      const Text('Scheduled Access', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (widget.lo['schedule_start'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Available', style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (widget.lo['schedule_start'] == null) ...[
                    const Text('No schedule set. Quiz is available anytime once lesson is done.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.calendar_month, size: 16),
                      label: const Text('Set Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => _ScheduleQuizSheet(lo: widget.lo),
                        );
                      },
                    ),
                  ] else ...[
                    Row(
                      children: [
                        const Icon(Icons.date_range, color: AppTheme.primary, size: 14),
                        const SizedBox(width: 8),
                        Text('Opens: ${widget.lo['schedule_start']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.event_busy, color: AppTheme.error, size: 14),
                        const SizedBox(width: 8),
                        Text('Closes: ${widget.lo['schedule_end']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: AppTheme.textMuted, size: 14),
                        const SizedBox(width: 8),
                        Text('Timezone: ${widget.lo['timezone']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                    if (widget.lo['allow_extend'] == 1) ...[
                      const SizedBox(height: 6),
                      const Row(
                        children: [
                          Icon(Icons.timer, color: Colors.orange, size: 14),
                          SizedBox(width: 8),
                          Text('End time can be extended', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.edit_calendar, size: 16),
                      label: const Text('Edit Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => _ScheduleQuizSheet(lo: widget.lo),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Questions List
            if (questions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Center(
                  child: Text('No questions yet.', style: TextStyle(color: AppTheme.textMuted, fontStyle: FontStyle.italic, fontSize: 12)),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                child: Column(
                  children: questions.map((q) {
                    return _QuestionCard(question: q, subjectId: widget.subjectId);
                  }).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _QuestionCard extends ConsumerWidget {
  final Map<String, dynamic> question;
  final int subjectId;

  const _QuestionCard({required this.question, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final correctOption = question['correct_option'] as String;

    Widget _buildOption(String letter, String text) {
      final isCorrect = correctOption == letter;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(
              isCorrect ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isCorrect ? AppTheme.primary : AppTheme.textSecondary,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$letter. $text',
                style: TextStyle(
                  color: isCorrect ? AppTheme.primary : AppTheme.text,
                  fontSize: 13,
                  fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question['question_text'],
                  style: const TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildOption('A', question['option_a']),
                _buildOption('B', question['option_b']),
                _buildOption('C', question['option_c']),
                _buildOption('D', question['option_d']),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 16),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => _EditQuestionSheet(question: question, subjectId: subjectId),
                  );
                },
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 16),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: AppTheme.surface,
                      title: const Text('Delete Question', style: TextStyle(color: AppTheme.text)),
                      content: const Text('Are you sure you want to delete this question?',
                          style: TextStyle(color: AppTheme.textSecondary)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                        ),
                        TextButton(
                          onPressed: () {
                            ref.read(subjectDetailProvider.notifier).deleteQuestion(question['id']);
                            Navigator.pop(context);
                          },
                          child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddQuestionSheet extends ConsumerStatefulWidget {
  final int loId;
  final int subjectId;
  const _AddQuestionSheet({required this.loId, required this.subjectId});

  @override
  ConsumerState<_AddQuestionSheet> createState() => _AddQuestionSheetState();
}

class _AddQuestionSheetState extends ConsumerState<_AddQuestionSheet> {
  final _questionController = TextEditingController();
  final _optionAController = TextEditingController();
  final _optionBController = TextEditingController();
  final _optionCController = TextEditingController();
  final _optionDController = TextEditingController();
  String _correctOption = 'A';

  void _save() {
    ref.read(subjectDetailProvider.notifier).addQuestion(widget.loId, {
      'question_text': _questionController.text.trim(),
      'option_a': _optionAController.text.trim(),
      'option_b': _optionBController.text.trim(),
      'option_c': _optionCController.text.trim(),
      'option_d': _optionDController.text.trim(),
      'correct_option': _correctOption,
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    Widget _buildOptionRow(String letter, TextEditingController controller) {
      final isSelected = _correctOption == letter;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _correctOption = letter),
              child: Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTextField(controller, 'Option $letter'),
            ),
          ],
        ),
      );
    }

    return _BaseBottomSheet(
      title: 'Add Question',
      onSave: _save,
      children: [
        const Text('Question', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        _buildTextField(_questionController, 'Question text', maxLines: 3),
        const SizedBox(height: 16),
        const Text('Options (tap radio for correct answer)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 12),
        _buildOptionRow('A', _optionAController),
        _buildOptionRow('B', _optionBController),
        _buildOptionRow('C', _optionCController),
        _buildOptionRow('D', _optionDController),
      ],
    );
  }
}

// ========================
// Edit Bottom Sheets
// ========================

class _EditTopicSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> topic;
  final int subjectId;
  const _EditTopicSheet({required this.topic, required this.subjectId});

  @override
  ConsumerState<_EditTopicSheet> createState() => _EditTopicSheetState();
}

class _EditTopicSheetState extends ConsumerState<_EditTopicSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.topic['title']);
    _descController = TextEditingController(text: widget.topic['description'] ?? '');
  }

  void _save() {
    ref.read(subjectDetailProvider.notifier).updateTopic(widget.topic['id'], {
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _BaseBottomSheet(
      title: 'Edit Topic',
      onSave: _save,
      children: [
        const Text('Title', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        _buildTextField(_titleController, 'Title of Topic'),
        const SizedBox(height: 16),
        const Text('Description', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        _buildTextField(_descController, 'Description', maxLines: 4),
      ],
    );
  }
}

class _EditLOSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> lo;
  final int subjectId;
  const _EditLOSheet({required this.lo, required this.subjectId});

  @override
  ConsumerState<_EditLOSheet> createState() => _EditLOSheetState();
}

class _EditLOSheetState extends ConsumerState<_EditLOSheet> {
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

  void _save() {
    ref.read(subjectDetailProvider.notifier).updateLearningOutcome(widget.lo['id'], {
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'performance_criteria': _criteriaController.text.trim(),
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _BaseBottomSheet(
      title: 'Edit LO',
      onSave: _save,
      children: [
        const Text('Title', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        _buildTextField(_titleController, 'LO title'),
        const SizedBox(height: 16),
        const Text('Description', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        _buildTextField(_descController, 'Description', maxLines: 3),
        const SizedBox(height: 16),
        const Text('Performance Criteria (one per line)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        _buildTextField(_criteriaController, 'Enter criteria...', maxLines: 4),
      ],
    );
  }
}

class _EditContentSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> contentItem;
  final int subjectId;
  const _EditContentSheet({required this.contentItem, required this.subjectId});

  @override
  ConsumerState<_EditContentSheet> createState() => _EditContentSheetState();
}

class _EditContentSheetState extends ConsumerState<_EditContentSheet> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late String _selectedType;

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
    _contentController = TextEditingController(text: widget.contentItem['content_data']);
    _selectedType = widget.contentItem['content_type'] ?? 'Text';
  }

  void _save() {
    ref.read(subjectDetailProvider.notifier).updateContent(widget.contentItem['id'], {
      'title': _titleController.text.trim(),
      'content_type': _selectedType,
      'content_data': _contentController.text.trim(),
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _BaseBottomSheet(
      title: 'Edit Content',
      onSave: _save,
      children: [
        const Text('Content Type', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _types.map((type) {
              final isSelected = _selectedType == type['name'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: Icon(type['icon'], color: isSelected ? Colors.black : AppTheme.textMuted, size: 16),
                  label: Text(type['name']),
                  selected: isSelected,
                  onSelected: (selected) => setState(() => _selectedType = type['name']),
                  selectedColor: AppTheme.primary,
                  backgroundColor: AppTheme.surface,
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
        const Text('Title', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        _buildTextField(_titleController, 'Content title'),
        const SizedBox(height: 16),
        const Text('Content', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        _buildTextField(_contentController, 'Enter text content...', maxLines: 5),
      ],
    );
  }
}

class _EditQuestionSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> question;
  final int subjectId;
  const _EditQuestionSheet({required this.question, required this.subjectId});

  @override
  ConsumerState<_EditQuestionSheet> createState() => _EditQuestionSheetState();
}

class _EditQuestionSheetState extends ConsumerState<_EditQuestionSheet> {
  late TextEditingController _questionController;
  late TextEditingController _optionAController;
  late TextEditingController _optionBController;
  late TextEditingController _optionCController;
  late TextEditingController _optionDController;
  late String _correctOption;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(text: widget.question['question_text']);
    _optionAController = TextEditingController(text: widget.question['option_a']);
    _optionBController = TextEditingController(text: widget.question['option_b']);
    _optionCController = TextEditingController(text: widget.question['option_c']);
    _optionDController = TextEditingController(text: widget.question['option_d']);
    _correctOption = widget.question['correct_option'] ?? 'A';
  }

  void _save() {
    ref.read(subjectDetailProvider.notifier).updateQuestion(widget.question['id'], {
      'question_text': _questionController.text.trim(),
      'option_a': _optionAController.text.trim(),
      'option_b': _optionBController.text.trim(),
      'option_c': _optionCController.text.trim(),
      'option_d': _optionDController.text.trim(),
      'correct_option': _correctOption,
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    Widget _buildOptionRow(String letter, TextEditingController controller) {
      final isSelected = _correctOption == letter;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _correctOption = letter),
              child: Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTextField(controller, 'Option $letter'),
            ),
          ],
        ),
      );
    }

    return _BaseBottomSheet(
      title: 'Edit Question',
      onSave: _save,
      children: [
        const Text('Question', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        _buildTextField(_questionController, 'Question text', maxLines: 3),
        const SizedBox(height: 16),
        const Text('Options (tap radio for correct answer)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 12),
        _buildOptionRow('A', _optionAController),
        _buildOptionRow('B', _optionBController),
        _buildOptionRow('C', _optionCController),
        _buildOptionRow('D', _optionDController),
      ],
    );
  }
}

class _ScheduleQuizSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> lo;
  const _ScheduleQuizSheet({required this.lo});

  @override
  ConsumerState<_ScheduleQuizSheet> createState() => _ScheduleQuizSheetState();
}

class _ScheduleQuizSheetState extends ConsumerState<_ScheduleQuizSheet> {
  late TextEditingController _passingScoreController;
  late TextEditingController _startController;
  late TextEditingController _endController;
  late TextEditingController _timezoneController;
  bool _allowExtend = false;

  @override
  void initState() {
    super.initState();
    _passingScoreController = TextEditingController(text: widget.lo['passing_score']?.toString() ?? '0');
    _startController = TextEditingController(text: widget.lo['schedule_start'] ?? '2026-09-06T07:23');
    _endController = TextEditingController(text: widget.lo['schedule_end'] ?? '2026-09-07T07:23');
    _timezoneController = TextEditingController(text: widget.lo['timezone'] ?? 'Asia/Shanghai');
    _allowExtend = widget.lo['allow_extend'] == 1;
  }

  void _save() {
    ref.read(subjectDetailProvider.notifier).updateLearningOutcome(widget.lo['id'], {
      'passing_score': int.tryParse(_passingScoreController.text) ?? 0,
      'schedule_start': _startController.text.trim(),
      'schedule_end': _endController.text.trim(),
      'timezone': _timezoneController.text.trim(),
      'allow_extend': _allowExtend ? 1 : 0,
    });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_outline, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Quiz schedule saved successfully!', style: TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: AppTheme.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppTheme.primary),
        ),
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _BaseBottomSheet(
      title: 'Schedule Quiz Access',
      onSave: _save,
      children: [
        const Text('Set when students can access this quiz. Before the start time, the quiz shows a countdown. After the end time, the quiz is closed.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 16),

        const Text('Passing Score (%)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        _buildTextField(_passingScoreController, 'e.g. 80'),
        const SizedBox(height: 16),

        const Text('Start Date & Time', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        _buildTextField(_startController, 'YYYY-MM-DDTHH:MM'),
        const SizedBox(height: 16),

        const Text('End Date & Time', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        _buildTextField(_endController, 'YYYY-MM-DDTHH:MM'),
        const SizedBox(height: 16),

        const Text('Time Zone', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        _buildTextField(_timezoneController, 'e.g. Asia/Shanghai'),
        const SizedBox(height: 16),

        Container(
          decoration: BoxDecoration(
            color: AppTheme.background,
            border: Border.all(color: _allowExtend ? AppTheme.primary : AppTheme.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: CheckboxListTile(
            value: _allowExtend,
            onChanged: (val) => setState(() => _allowExtend = val ?? false),
            activeColor: AppTheme.primary,
            checkColor: Colors.black,
            title: const Text('Allow extending end time', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: const Text('Permit editing the end time even after students have started the quiz.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        ),
      ],
    );
  }
}
