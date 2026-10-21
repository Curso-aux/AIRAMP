import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/application/auth_provider.dart';
import '../../curriculum/presentation/components/pdf_module_upload_dialog.dart';
import '../data/admin_repository.dart';
import 'components/teacher_picker_field.dart';

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
    ref.watch(themeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(authProvider);
    final isAdmin = currentUser == null || currentUser.role == 'admin' || currentUser.role == 'super_admin';
    final isTeacher = currentUser?.role == 'teacher';

    var rawSubjects = ref.watch(subjectsProvider);
    if (isTeacher && currentUser != null) {
      rawSubjects = rawSubjects.where((s) {
        final tId = s['teacher_id']?.toString();
        return tId == currentUser.id || tId == null || tId.isEmpty;
      }).toList();
    }
    final allRoleSubjects = rawSubjects;

    // Filter subjects by selected category
    var subjects = allRoleSubjects;
    if (_selectedFilter == 1) {
      // My Subjects
      subjects = allRoleSubjects.where((s) {
        final tId = s['teacher_id']?.toString();
        return currentUser != null && tId == currentUser.id;
      }).toList();
    } else if (_selectedFilter == 2) {
      // Adopted
      subjects = allRoleSubjects.where((s) {
        final code = s['subject_code']?.toString() ?? '';
        return (code.isNotEmpty &&
                (code == 'CSS-NC-II' || code == 'VGD-NC-III' || code == 'EMP-TECH')) ||
            s['is_adopted'] == true;
      }).toList();
    } else if (_selectedFilter == 3) {
      // Global & Shared
      subjects = allRoleSubjects.where((s) {
        final isGlobal = s['is_global'] == true || s['is_shared'] == true;
        final tId = s['teacher_id']?.toString();
        return isGlobal || tId == null || tId.isEmpty;
      }).toList();
    }

    int countForFilter(int index) {
      if (index == 0) return allRoleSubjects.length;
      if (index == 1) {
        return allRoleSubjects.where((s) {
          final tId = s['teacher_id']?.toString();
          return currentUser != null && tId == currentUser.id;
        }).length;
      }
      if (index == 2) {
        return allRoleSubjects.where((s) {
          final code = s['subject_code']?.toString() ?? '';
          return (code.isNotEmpty &&
                  (code == 'CSS-NC-II' || code == 'VGD-NC-III' || code == 'EMP-TECH')) ||
              s['is_adopted'] == true;
        }).length;
      }
      if (index == 3) {
        return allRoleSubjects.where((s) {
          final isGlobal = s['is_global'] == true || s['is_shared'] == true;
          final tId = s['teacher_id']?.toString();
          return isGlobal || tId == null || tId.isEmpty;
        }).length;
      }
      return 0;
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Responsive Action Bar
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 860;
                  final titleSection = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manage Subjects',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAdmin
                            ? 'Create subjects and designate faculty permissions'
                            : 'Manage topics, lessons, and quizzes for your assigned subjects',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                    ],
                  );

                  final actionButtons = isAdmin
                      ? Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showCreateSubjectDialog(autoExpandGlobal: true),
                              icon: Icon(Icons.public, size: 16, color: AppTheme.text),
                              label: const Text('Adopt Global Subject', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.text,
                                side: BorderSide(color: AppTheme.border),
                                backgroundColor: AppTheme.surface,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                minimumSize: const Size(0, 40),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _openCreateSubjectFromPdf,
                              icon: Icon(Icons.upload_file_outlined, size: 16, color: AppTheme.primary),
                              label: const Text('Create Subject from PDF Module (Auto-Scan)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
                                backgroundColor: AppTheme.primary.withValues(alpha: 0.05),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                minimumSize: const Size(0, 40),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _showCreateSubjectDialog(),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Create New Subject', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                minimumSize: const Size(0, 40),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink();

                  if (isWide) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: titleSection),
                        const SizedBox(width: 16),
                        actionButtons,
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleSection,
                      if (isAdmin) ...[
                        const SizedBox(height: 16),
                        actionButtons,
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Teacher Role Notice (Compact & Informational)
              if (isTeacher) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: isDark ? 0.12 : 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Faculty Assignment Notice',
                              style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Courses are designated by School Administration. You may manage topics, lessons, and quizzes for assigned subjects below.',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Horizontal Single-Line Filter Strip with Live Counts & Haptics
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _filterLabels.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final isSelected = _selectedFilter == index;
                    final count = countForFilter(index);

                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedFilter = index);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary : AppTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? AppTheme.primary : AppTheme.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _filterLabels[index],
                              style: TextStyle(
                                color: isSelected
                                    ? (isDark ? const Color(0xFF0A1420) : Colors.white)
                                    : AppTheme.text,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                            if (count > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark
                                          ? Colors.black.withValues(alpha: 0.25)
                                          : Colors.white.withValues(alpha: 0.25))
                                      : AppTheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? (isDark ? const Color(0xFF0A1420) : Colors.white)
                                        : AppTheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),

              // Subjects List or Empty State
              if (subjects.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 32.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.menu_book,
                          size: 56,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _selectedFilter != 0
                              ? 'No ${_filterLabels[_selectedFilter]} subjects found'
                              : (isTeacher ? 'No assigned subjects found' : 'No subjects created yet'),
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                        if (_selectedFilter != 0) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedFilter = 0);
                            },
                            icon: const Icon(Icons.clear_all_rounded, size: 16),
                            label: const Text('Show All Subjects', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppTheme.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
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
                    return _buildSubjectCard(context, subject, ref, isAdmin: isAdmin);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectCard(BuildContext context, Map<String, dynamic> subject, WidgetRef ref, {bool isAdmin = true}) {
    final code = subject['subject_code']?.toString() ?? '';
    final unlockType = subject['unlock_type']?.toString() ?? 'Sequential';
    final semester = subject['semester']?.toString() ?? '';
    final isAdopted = code.isNotEmpty && (code == 'CSS-NC-II' || code == 'VGD-NC-III' || code == 'EMP-TECH');
    final teacherName = subject['teacher_name']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        final basePath = isAdmin ? '/admin/subjects' : '/teacher/subjects';
        context.push('$basePath/${subject['id']}');
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
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (code.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          code,
                          style: TextStyle(color: AppTheme.text, fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (isAdopted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkSurfaceLight : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_outlined, size: 12, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text('Adapted Copy', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (semester.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkSurfaceLight : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 11, color: AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              semester,
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    // Unlock type badge (interactive toggle for teacher and admin)
                    GestureDetector(
                      onTap: () => _showUnlockTypeDialog(context, subject['id'] as int, unlockType, ref),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkSurfaceLight : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              unlockType == 'Sequential' ? Icons.lock_outline : Icons.lock_open_outlined,
                              size: 12,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              unlockType,
                              style: TextStyle(color: AppTheme.text, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 3),
                            Icon(Icons.arrow_drop_down, size: 14, color: AppTheme.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Subject name
            Text(
              subject['name'] ?? '',
              style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),

            // Description
            Text(
              subject['description'] ?? '',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // Teacher / Faculty Assignment Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkSurfaceLight : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_outline, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      teacherName.isNotEmpty
                          ? 'Faculty: $teacherName'
                          : 'Faculty: Unassigned',
                      style: TextStyle(
                        color: teacherName.isNotEmpty
                            ? AppTheme.text
                            : AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Bottom row: student count + action buttons
            Row(
              children: [
                Icon(Icons.people_alt_outlined, size: 15, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Text(
                  '0 students',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                ),
                const Spacer(),
                if (isAdmin) ...[
                  if (isAdopted) ...[
                    _actionIconButton(
                      icon: Icons.cancel_outlined,
                      color: AppTheme.error,
                      tooltip: 'Remove Adapted Subject',
                      onTap: () => _confirmDelete(context, subject, ref),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _actionIconButton(
                    icon: Icons.picture_as_pdf_outlined,
                    color: AppTheme.primary,
                    tooltip: 'Upload PDF Syllabus',
                    onTap: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => PdfModuleUploadDialog(
                          subjectId: subject['id'] as int,
                          subjectName: subject['name']?.toString() ?? 'Subject',
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _actionIconButton(
                    icon: Icons.edit_outlined,
                    color: AppTheme.textSecondary,
                    tooltip: 'Edit Subject Details',
                    onTap: () => _showEditSubjectDialog(context, subject, ref),
                  ),
                  const SizedBox(width: 8),
                  _actionIconButton(
                    icon: Icons.delete_outline,
                    color: AppTheme.error,
                    tooltip: 'Delete Subject',
                    onTap: () => _confirmDelete(context, subject, ref),
                  ),
                ] else ...[
                  // Teacher Action: Direct Curriculum Navigation
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Curriculum',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 14, color: AppTheme.primary),
                      ],
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

  Widget _actionIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );

    if (tooltip != null && tooltip.isNotEmpty) {
      return Tooltip(message: tooltip, child: btn);
    }
    return btn;
  }

  void _confirmDelete(BuildContext context, Map<String, dynamic> subject, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Delete Subject', style: TextStyle(color: AppTheme.text)),
        content: Text('Are you sure you want to delete "${subject['name']}"?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              ref.read(subjectsProvider.notifier).deleteSubject(subject['id']);
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: AppTheme.error)),
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

  void _showUnlockTypeDialog(BuildContext context, int subjectId, String currentUnlockType, WidgetRef ref) {
    String selected = currentUnlockType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Curriculum Progression Mode',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppTheme.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Configure whether students advance sequentially or access all lessons flexibly.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),

              // Option 1: Sequential
              _buildProgressionOption(
                title: 'Sequential Progression',
                subtitle: 'Students must pass quizzes to unlock subsequent learning outcomes.',
                icon: Icons.lock_outline,
                isSelected: selected == 'Sequential',
                onTap: () => setModalState(() => selected = 'Sequential'),
              ),
              const SizedBox(height: 12),

              // Option 2: Flexible
              _buildProgressionOption(
                title: 'Flexible Progression',
                subtitle: 'All topics and learning materials are open. Students can study at their own pace.',
                icon: Icons.lock_open_outlined,
                isSelected: selected == 'Flexible',
                onTap: () => setModalState(() => selected = 'Flexible'),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await ref.read(subjectsProvider.notifier).updateUnlockType(subjectId, selected);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Progression mode set to "$selected"'),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save Progression Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressionOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primary : AppTheme.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? AppTheme.primary : AppTheme.text,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateSubjectDialog({bool autoExpandGlobal = false}) async {
    final result = await showModalBottomSheet<_SubjectCreationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _CreateSubjectSheet(autoExpandGlobal: autoExpandGlobal);
      },
    );

    if (result == null || !mounted) return;

    final newSubjectId = await ref.read(subjectsProvider.notifier).addSubject({
      'name': result.name,
      'subject_code': result.code ?? '',
      'description': result.desc ?? '',
      'grade_level': result.grade,
      'semester': result.semester,
      'unlock_type': result.unlock,
      'teacher_id': result.teacherId,
      'teacher_name': result.teacherName,
      'created_at': DateTime.now().toIso8601String(),
    });

    if (!mounted) return;

    // Prompt user to immediately upload a PDF Module
    final uploadNow = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.picture_as_pdf, color: Color(0xFFE11D48), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Upload PDF Module?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'Subject "${result.name}" was created successfully!\n\nWould you like to upload a PDF module now to automatically scan Topics, Learning Outcomes, and Quiz Practice Flashcards?',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Later', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Upload PDF Module'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (uploadNow == true) {
      context.push('/admin/subjects/$newSubjectId');
    } else {
      context.push('/admin/subjects/$newSubjectId');
    }
  }

  Future<void> _openCreateSubjectFromPdf() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PdfModuleUploadDialog(
        subjectId: null,
      ),
    );

    if (result == true && mounted) {
      ref.read(subjectsProvider.notifier).reload();
    }
  }
}

class _SubjectCreationResult {
  final String name;
  final String? code;
  final String? desc;
  final String? grade;
  final String? semester;
  final String unlock;
  final String? teacherId;
  final String? teacherName;

  const _SubjectCreationResult({
    required this.name,
    this.code,
    this.desc,
    this.grade,
    this.semester,
    required this.unlock,
    this.teacherId,
    this.teacherName,
  });
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
  String? _selectedTeacherId;
  String? _selectedTeacherName;

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
    final sName = (name ?? _nameController.text).trim();
    if (sName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a subject name')),
      );
      return;
    }
    final sCode = (code ?? _codeController.text).trim();
    final sDesc = (desc ?? _descController.text).trim();

    Navigator.pop(
      context,
      _SubjectCreationResult(
        name: sName,
        code: sCode.isNotEmpty ? sCode : null,
        desc: sDesc.isNotEmpty ? sDesc : null,
        grade: _selectedGrade,
        semester: _selectedSemester,
        unlock: _selectedUnlock,
        teacherId: _selectedTeacherId,
        teacherName: _selectedTeacherName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                                Text('Integrate existing subjects?',
                                    style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                  'Super Admin has ${_globalSubjects.length} subject(s) available to adopt as independent copies.',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
                          Expanded(child: Divider(color: AppTheme.border)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text('or create your own below',
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4).withValues(alpha: 0.5),
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic)),
                          ),
                          Expanded(child: Divider(color: AppTheme.border)),
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
                  Text('Grade Level', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
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
                  Text('Semester', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
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
                  Text('Unlock Type', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
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

                  // Teacher Assignment Searchable Picker
                  TeacherPickerField(
                    selectedTeacherId: _selectedTeacherId,
                    selectedTeacherName: _selectedTeacherName,
                    onTeacherSelected: (teacher) {
                      setState(() {
                        if (teacher != null) {
                          _selectedTeacherId = teacher['id']?.toString();
                          _selectedTeacherName = teacher['full_name']?.toString();
                        } else {
                          _selectedTeacherId = null;
                          _selectedTeacherName = null;
                        }
                      });
                    },
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
                      foregroundColor: AppTheme.textSecondary,
                      side: BorderSide(color: AppTheme.border),
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
                    style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
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
                    const SizedBox(width: 4),
                    Text('Global', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(sub['name']!, style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(sub['desc']!, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1, int? maxLength}) {
    final int effectiveLimit = maxLength ?? (
      hint.toLowerCase().contains('code') ? 20 :
      maxLines > 1 ? 500 : 80
    );
    return TextField(
      controller: controller,
      maxLength: effectiveLimit,
      buildCounter: maxLines == 1 ? (context, {required currentLength, required isFocused, maxLength}) => null : null,
      style: TextStyle(color: AppTheme.text),
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        counterText: maxLines == 1 ? '' : null,
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
  String? _selectedTeacherId;
  String? _selectedTeacherName;

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
    _selectedTeacherId = widget.subject['teacher_id']?.toString();
    _selectedTeacherName = widget.subject['teacher_name']?.toString();
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  Text('Grade Level', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
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
                  Text('Semester', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
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
                  Text('Unlock Type', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
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

                  // Teacher Assignment Searchable Picker
                  TeacherPickerField(
                    selectedTeacherId: _selectedTeacherId,
                    selectedTeacherName: _selectedTeacherName,
                    onTeacherSelected: (teacher) {
                      setState(() {
                        if (teacher != null) {
                          _selectedTeacherId = teacher['id']?.toString();
                          _selectedTeacherName = teacher['full_name']?.toString();
                        } else {
                          _selectedTeacherId = null;
                          _selectedTeacherName = null;
                        }
                      });
                    },
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
                      foregroundColor: AppTheme.textSecondary,
                      side: BorderSide(color: AppTheme.border),
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
                        'teacher_id': _selectedTeacherId,
                        'teacher_name': _selectedTeacherName,
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

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1, int? maxLength}) {
    final int effectiveLimit = maxLength ?? (
      hint.toLowerCase().contains('code') ? 20 :
      maxLines > 1 ? 500 : 80
    );
    return TextField(
      controller: controller,
      maxLength: effectiveLimit,
      buildCounter: maxLines == 1 ? (context, {required currentLength, required isFocused, maxLength}) => null : null,
      style: TextStyle(color: AppTheme.text),
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        counterText: maxLines == 1 ? '' : null,
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
