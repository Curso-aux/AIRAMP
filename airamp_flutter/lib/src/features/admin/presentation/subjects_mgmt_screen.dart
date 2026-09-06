import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../data/admin_repository.dart';

class SubjectsMgmtScreen extends ConsumerStatefulWidget {
  const SubjectsMgmtScreen({super.key});

  @override
  ConsumerState<SubjectsMgmtScreen> createState() => _SubjectsMgmtScreenState();
}

class _SubjectsMgmtScreenState extends ConsumerState<SubjectsMgmtScreen> {
  int _selectedFilter = 0;
  final List<String> _filterLabels = ['All', 'My Subjects', 'Adopted', 'Global & Shared'];

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Manage Subjects',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 4),
              const Text(
                'Create and manage subjects',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Create New Subject Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showCreateSubjectDialog(context),
                  icon: const Icon(Icons.add, color: Colors.black),
                  label: const Text('Create New Subject'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Adopt Global Subject Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showCreateSubjectDialog(context, autoExpandGlobal: true),
                  icon: Icon(Icons.public, color: Theme.of(context).colorScheme.onSurface),
                  label: const Text('Adopt Global Subject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Theme.of(context).dividerColor),
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Filter Chips
              Wrap(
                spacing: 8,
                children: List.generate(_filterLabels.length, (index) {
                  final isSelected = _selectedFilter == index;
                  return ChoiceChip(
                    label: Text(_filterLabels[index]),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedFilter = index);
                    },
                    selectedColor: Theme.of(context).colorScheme.primary,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: isSelected ? AppTheme.primary : AppTheme.border,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Subjects List or Empty State
              if (subjects.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: Column(
                      children: [
                        Icon(Icons.menu_book, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4).withOpacity(0.5)),
                        const SizedBox(height: 16),
                        const Text(
                          'No subjects created yet',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: subjects.length,
                  itemBuilder: (context, index) {
                    final subject = subjects[index];
                    return _buildSubjectCard(context, subject, ref);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectCard(BuildContext context, Map<String, dynamic> subject, WidgetRef ref) {
    final code = subject['subject_code']?.toString() ?? '';
    final unlockType = subject['unlock_type']?.toString() ?? 'Sequential';
    final isAdopted = code.isNotEmpty && (code == 'CSS-NC-II' || code == 'VGD-NC-III' || code == 'EMP-TECH');

    return GestureDetector(
      onTap: () {
        context.push('/admin/subjects/${subject['id']}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: badges
            Row(
              children: [
                if (code.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      code,
                      style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                if (code.isNotEmpty) const SizedBox(width: 8),
                if (isAdopted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 12, color: Theme.of(context).colorScheme.primary),
                        SizedBox(width: 4),
                        Text('Adapted Copy', style: TextStyle(color: AppTheme.primary, fontSize: 11)),
                      ],
                    ),
                  ),
                const Spacer(),
                // Unlock type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        unlockType == 'Sequential' ? Icons.lock_outline : Icons.lock_open_outlined,
                        size: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        unlockType,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Subject name
            Text(
              subject['name'] ?? '',
              style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),

            // Description
            Text(
              subject['description'] ?? '',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Bottom row: student count + action buttons
            Row(
              children: [
                Icon(Icons.groups_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 4),
                const Text(
                  '0 students',
                  style: TextStyle(color: AppTheme.primary, fontSize: 13),
                ),
                const Spacer(),
                if (isAdopted)
                  _actionIconButton(
                    icon: Icons.cancel_outlined,
                    color: Theme.of(context).colorScheme.error,
                    bgColor: AppTheme.error.withValues(alpha: 0.15),
                    onTap: () => _confirmDelete(context, subject, ref),
                  ),
                if (isAdopted) const SizedBox(width: 8),
                _actionIconButton(
                  icon: Icons.edit_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  bgColor: AppTheme.primary.withValues(alpha: 0.15),
                  onTap: () => _showEditSubjectDialog(context, subject, ref),
                ),
                const SizedBox(width: 8),
                _actionIconButton(
                  icon: Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                  bgColor: AppTheme.error.withValues(alpha: 0.15),
                  onTap: () => _confirmDelete(context, subject, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionIconButton({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Map<String, dynamic> subject, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Delete Subject', style: TextStyle(color: AppTheme.text)),
        content: Text('Are you sure you want to delete "${subject['name']}"?',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              ref.read(subjectsProvider.notifier).deleteSubject(subject['id']);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  void _showEditSubjectDialog(BuildContext context, Map<String, dynamic> subject, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _EditSubjectSheet(subject: subject);
      },
    );
  }

  void _showCreateSubjectDialog(BuildContext context, {bool autoExpandGlobal = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CreateSubjectSheet(autoExpandGlobal: autoExpandGlobal);
      },
    );
  }
}

// ========================
// Create Subject Bottom Sheet
// ========================

class _CreateSubjectSheet extends ConsumerStatefulWidget {
  final bool autoExpandGlobal;
  const _CreateSubjectSheet({this.autoExpandGlobal = false});

  @override
  ConsumerState<_CreateSubjectSheet> createState() => _CreateSubjectSheetState();
}

class _CreateSubjectSheetState extends ConsumerState<_CreateSubjectSheet> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descController = TextEditingController();

  late bool _isExpanded;
  String? _selectedGrade;
  String? _selectedSemester;
  String _selectedUnlock = 'Sequential';

  final List<String> _semesters = ['1st Semester', '2nd Semester', '3rd Semester'];

  final List<String> _gradeLevels = ['Grade 7', 'Grade 8', 'Grade 9', 'Grade 10', 'Grade 11', 'Grade 12'];

  final List<Map<String, String>> _globalSubjects = [
    {
      'code': 'CSS-NC-II',
      'name': 'CSS NC II - Computer Systems Servicing',
      'desc': 'Technical Education and Skills Development Authority (TESDA) qualification for Computer Systems Servicing NC...',
    },
    {
      'code': 'VGD-NC-III',
      'name': 'VGD NC III - Visual Graphic Design',
      'desc': 'TESDA qualification for Visual Graphic Design NC III covering design principles and software.',
    },
    {
      'code': 'EMP-TECH',
      'name': 'Empowerment Technology',
      'desc': 'General education subject covering ICT basics, online platforms, and digital productivity.',
    }
  ];

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.autoExpandGlobal;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _saveSubject({String? code, String? name, String? desc}) {
    ref.read(subjectsProvider.notifier).addSubject({
      'name': name ?? _nameController.text.trim(),
      'subject_code': code ?? _codeController.text.trim(),
      'description': desc ?? _descController.text.trim(),
      'grade_level': _selectedGrade,
      'semester': _selectedSemester,
      'unlock_type': _selectedUnlock,
      'created_at': DateTime.now().toIso8601String(),
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Create New Subject',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Integrate existing subjects expander
                  GestureDetector(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.link, color: Theme.of(context).colorScheme.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Integrate existing subjects?',
                                    style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                  'Super Admin has ${_globalSubjects.length} subject(s) available to adopt as independent copies.',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                        ],
                      ),
                    ),
                  ),

                  if (_isExpanded) ...[
                    const SizedBox(height: 16),
                    ..._globalSubjects.map((sub) => _buildGlobalSubjectCard(sub)),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Row(
                        children: [
                          const Expanded(child: Divider(color: AppTheme.border)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text('or create your own below',
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4).withValues(alpha: 0.5),
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic)),
                          ),
                          const Expanded(child: Divider(color: AppTheme.border)),
                        ],
                      ),
                    ),
                  ] else
                    const SizedBox(height: 24),

                  // Form Fields
                  _buildTextField(_nameController, 'Subject Name'),
                  const SizedBox(height: 12),
                  _buildTextField(_codeController, 'Subject Code (e.g., CSS-NC-II)'),
                  const SizedBox(height: 12),
                  _buildTextField(_descController, 'Description', maxLines: 3),
                  const SizedBox(height: 24),

                  // Grade Level
                  const Text('Grade Level', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _gradeLevels.map((grade) {
                      final isSelected = _selectedGrade == grade;
                      return ChoiceChip(
                        label: Text(grade),
                        selected: isSelected,
                        onSelected: (selected) => setState(() => _selectedGrade = selected ? grade : null),
                        selectedColor: Theme.of(context).colorScheme.surface,
                        labelStyle: TextStyle(
                          color: isSelected ? AppTheme.text : AppTheme.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(color: isSelected ? AppTheme.border : Colors.transparent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Semester
                  const Text('Semester', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _semesters.map((sem) {
                      final isSelected = _selectedSemester == sem;
                      return ChoiceChip(
                        label: Text(sem),
                        selected: isSelected,
                        onSelected: (selected) => setState(() => _selectedSemester = selected ? sem : null),
                        selectedColor: Theme.of(context).colorScheme.surface,
                        labelStyle: TextStyle(
                          color: isSelected ? AppTheme.text : AppTheme.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(color: isSelected ? AppTheme.border : Colors.transparent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Unlock Type
                  const Text('Unlock Type', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  const SizedBox(height: 12),
                  _buildUnlockTypeSelector(
                    title: 'Sequential', subtitle: 'Must pass quiz to unlock next',
                    icon: Icons.lock_outline, isSelected: _selectedUnlock == 'Sequential',
                    onTap: () => setState(() => _selectedUnlock = 'Sequential'),
                  ),
                  const SizedBox(height: 12),
                  _buildUnlockTypeSelector(
                    title: 'Flexible', subtitle: 'All topics available, quiz once',
                    icon: Icons.lock_open_outlined, isSelected: _selectedUnlock == 'Flexible',
                    onTap: () => setState(() => _selectedUnlock = 'Flexible'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      side: BorderSide(color: Theme.of(context).dividerColor),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveSubject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalSubjectCard(Map<String, String> sub) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(sub['code']!,
                    style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.language, size: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    SizedBox(width: 4),
                    Text('Global', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(sub['name']!, style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(sub['desc']!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _saveSubject(code: sub['code'], name: sub['name'], desc: sub['desc']),
              icon: const Icon(Icons.person_add_alt, size: 18, color: Colors.black),
              label: const Text('Adopt This', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppTheme.text),
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildUnlockTypeSelector({
    required String title, required String subtitle,
    required IconData icon, required bool isSelected, required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? null : Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.black : AppTheme.textSecondary),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(
                    color: isSelected ? Colors.black : AppTheme.text, fontWeight: FontWeight.bold, fontSize: 15)),
                Text(subtitle, style: TextStyle(
                    color: isSelected ? Colors.black87 : AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ========================
// Edit Subject Bottom Sheet
// ========================

class _EditSubjectSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> subject;
  const _EditSubjectSheet({required this.subject});

  @override
  ConsumerState<_EditSubjectSheet> createState() => _EditSubjectSheetState();
}

class _EditSubjectSheetState extends ConsumerState<_EditSubjectSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _descController;
  String? _selectedGrade;
  String? _selectedSemester;
  late String _selectedUnlock;

  final List<String> _gradeLevels = ['Grade 7', 'Grade 8', 'Grade 9', 'Grade 10', 'Grade 11', 'Grade 12'];
  final List<String> _semesters = ['1st Semester', '2nd Semester', '3rd Semester'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.subject['name'] ?? '');
    _codeController = TextEditingController(text: widget.subject['subject_code'] ?? '');
    _descController = TextEditingController(text: widget.subject['description'] ?? '');
    _selectedGrade = widget.subject['grade_level'];
    _selectedSemester = widget.subject['semester'];
    _selectedUnlock = widget.subject['unlock_type'] ?? 'Sequential';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Edit Subject',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(_nameController, 'Subject Name'),
                  const SizedBox(height: 12),
                  _buildTextField(_codeController, 'Subject Code (e.g., CSS-NC-II)'),
                  const SizedBox(height: 12),
                  _buildTextField(_descController, 'Description', maxLines: 3),
                  const SizedBox(height: 24),

                  // Grade Level
                  const Text('Grade Level', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _gradeLevels.map((grade) {
                      final isSelected = _selectedGrade == grade;
                      return ChoiceChip(
                        label: Text(grade),
                        selected: isSelected,
                        onSelected: (selected) => setState(() => _selectedGrade = selected ? grade : null),
                        selectedColor: Theme.of(context).colorScheme.surface,
                        labelStyle: TextStyle(
                          color: isSelected ? AppTheme.text : AppTheme.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(color: isSelected ? AppTheme.border : Colors.transparent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Semester
                  const Text('Semester', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _semesters.map((sem) {
                      final isSelected = _selectedSemester == sem;
                      return ChoiceChip(
                        label: Text(sem),
                        selected: isSelected,
                        onSelected: (selected) => setState(() => _selectedSemester = selected ? sem : null),
                        selectedColor: Theme.of(context).colorScheme.surface,
                        labelStyle: TextStyle(
                          color: isSelected ? AppTheme.text : AppTheme.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(color: isSelected ? AppTheme.border : Colors.transparent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Unlock Type
                  const Text('Unlock Type', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  const SizedBox(height: 12),
                  _buildUnlockTypeSelector(
                    title: 'Sequential', subtitle: 'Must pass quiz to unlock next',
                    icon: Icons.lock_outline, isSelected: _selectedUnlock == 'Sequential',
                    onTap: () => setState(() => _selectedUnlock = 'Sequential'),
                  ),
                  const SizedBox(height: 12),
                  _buildUnlockTypeSelector(
                    title: 'Flexible', subtitle: 'All topics available, quiz once',
                    icon: Icons.lock_open_outlined, isSelected: _selectedUnlock == 'Flexible',
                    onTap: () => setState(() => _selectedUnlock = 'Flexible'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      side: BorderSide(color: Theme.of(context).dividerColor),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(subjectsProvider.notifier).updateSubject(widget.subject['id'], {
                        'name': _nameController.text.trim(),
                        'subject_code': _codeController.text.trim(),
                        'description': _descController.text.trim(),
                        'grade_level': _selectedGrade,
                        'semester': _selectedSemester,
                        'unlock_type': _selectedUnlock,
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppTheme.text),
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildUnlockTypeSelector({
    required String title, required String subtitle,
    required IconData icon, required bool isSelected, required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? null : Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.black : AppTheme.textSecondary),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(
                    color: isSelected ? Colors.black : AppTheme.text, fontWeight: FontWeight.bold, fontSize: 15)),
                Text(subtitle, style: TextStyle(
                    color: isSelected ? Colors.black87 : AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
