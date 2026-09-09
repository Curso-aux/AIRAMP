import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../data/teacher_repository.dart';

class PostAnnouncementDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final String? defaultSection;

  const PostAnnouncementDialog({
    super.key,
    this.existing,
    this.defaultSection,
  });

  static Future<bool?> show(
    BuildContext context, {
    Map<String, dynamic>? existing,
    String? defaultSection,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PostAnnouncementDialog(
        existing: existing,
        defaultSection: defaultSection,
      ),
    );
  }

  @override
  ConsumerState<PostAnnouncementDialog> createState() => _PostAnnouncementDialogState();
}

class _PostAnnouncementDialogState extends ConsumerState<PostAnnouncementDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _messageController;
  late String _selectedPriority;
  late String _selectedAudience;
  late String _selectedSection;
  bool _isSubmitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ext = widget.existing;
    _titleController = TextEditingController(text: ext?['title']?.toString() ?? '');
    _messageController = TextEditingController(text: ext?['message']?.toString() ?? '');

    final extPriority = ext?['priority']?.toString().toLowerCase();
    _selectedPriority = (extPriority == 'high' || extPriority == 'medium' || extPriority == 'normal')
        ? extPriority!
        : 'normal';

    final extAudience = ext?['target_audience']?.toString().toLowerCase();
    _selectedAudience = (extAudience == 'all' || extAudience == 'students') ? extAudience! : 'students';

    _selectedSection = ext?['section']?.toString() ??
        (widget.defaultSection != null && widget.defaultSection != 'All Sections'
            ? widget.defaultSection!
            : 'All Handled Sections');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      if (_isEditing) {
        final id = widget.existing!['id'] as int;
        await ref.read(teacherAnnouncementsProvider.notifier).updateAnnouncement(id, {
          'title': _titleController.text.trim(),
          'message': _messageController.text.trim(),
          'priority': _selectedPriority,
          'target_audience': _selectedAudience,
          'section': _selectedSection,
        });
      } else {
        await ref.read(teacherAnnouncementsProvider.notifier).createAnnouncement(
              title: _titleController.text.trim(),
              message: _messageController.text.trim(),
              priority: _selectedPriority,
              targetSection: _selectedSection,
              targetAudience: _selectedAudience,
            );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save announcement: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final handledSectionsAsync = ref.watch(teacherHandledSectionsProvider);
    final handledSections = handledSectionsAsync.value ?? [];

    // Ensure our section list always has 'All Handled Sections' + all distinct sections
    final sectionOptions = <String>{
      'All Handled Sections',
      ...handledSections.where((s) => s.isNotEmpty && s != 'All Handled Sections'),
    }.toList();

    // If current selected section isn't in options, default to 'All Handled Sections'
    if (!sectionOptions.contains(_selectedSection)) {
      _selectedSection = 'All Handled Sections';
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _isEditing ? Icons.edit_note : Icons.campaign_rounded,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing ? 'Edit Announcement' : 'Post Announcement',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Target to specific section or all handled classes',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppTheme.textMuted, size: 20),
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Form body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Announcement Title
                        _buildFieldLabel('Announcement Title', isRequired: true),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _titleController,
                          style: TextStyle(color: AppTheme.text, fontSize: 14),
                          decoration: _inputDecoration(
                            hintText: 'e.g., Midterm Project Guidelines & Deadlines',
                            prefixIcon: Icons.title_rounded,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter an announcement title';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Target Section Dropdown
                        _buildFieldLabel('Target Section', isRequired: true),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedSection,
                          isExpanded: true,
                          dropdownColor: AppTheme.surface,
                          style: TextStyle(color: AppTheme.text, fontSize: 14),
                          decoration: _inputDecoration(
                            hintText: 'Select Section',
                            prefixIcon: Icons.groups_rounded,
                          ),
                          items: sectionOptions.map((sec) {
                            final isAll = sec == 'All Handled Sections';
                            return DropdownMenuItem(
                              value: sec,
                              child: Row(
                                children: [
                                  Icon(
                                    isAll ? Icons.domain : Icons.class_outlined,
                                    size: 18,
                                    color: isAll ? AppTheme.primary : AppTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      sec,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isAll ? AppTheme.primary : AppTheme.text,
                                        fontWeight: isAll ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedSection = val);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Priority Selection
                        _buildFieldLabel('Priority Level', isRequired: true),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildPriorityChip('normal', 'Normal', AppTheme.primary),
                            const SizedBox(width: 8),
                            _buildPriorityChip('medium', 'Medium', AppTheme.warning),
                            const SizedBox(width: 8),
                            _buildPriorityChip('high', 'High', AppTheme.error),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Audience Selection
                        _buildFieldLabel('Audience'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildAudienceChip('students', 'Students', Icons.school_outlined),
                            const SizedBox(width: 8),
                            _buildAudienceChip('all', 'Everyone', Icons.public),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Message Body
                        _buildFieldLabel('Announcement Message', isRequired: true),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _messageController,
                          maxLines: 4,
                          minLines: 3,
                          style: TextStyle(color: AppTheme.text, fontSize: 14),
                          decoration: _inputDecoration(
                            hintText: 'Enter complete announcement details, instructions, or reminders...',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please provide message details';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Divider(height: 1),

              // Footer Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: BorderSide(color: AppTheme.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_isEditing ? Icons.check : Icons.send_rounded, size: 16),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _isEditing ? 'Save Changes' : 'Publish Announcement',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                      ),
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

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.text,
          ),
        ),
        if (isRequired)
          const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      ],
    );
  }

  InputDecoration _inputDecoration({required String hintText, IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: AppTheme.textMuted) : null,
      filled: true,
      fillColor: AppTheme.surface,
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
    );
  }

  Widget _buildPriorityChip(String value, String label, Color color) {
    final isSelected = _selectedPriority == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPriority = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : AppTheme.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? color : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudienceChip(String value, String label, IconData icon) {
    final isSelected = _selectedAudience == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedAudience = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withValues(alpha: 0.12) : AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
