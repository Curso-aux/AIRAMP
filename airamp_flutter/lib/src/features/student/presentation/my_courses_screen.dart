import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/application/auth_provider.dart';
import '../data/student_repository.dart';

class MyCoursesScreen extends ConsumerStatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  ConsumerState<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends ConsumerState<MyCoursesScreen> {
  final TextEditingController _keyController = TextEditingController();
  bool _isVerifying = false;
  bool _showAvailable = false;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  void _showEnterKeyDialog({String? initialKey}) {
    final controller = TextEditingController(text: initialKey ?? '');
    bool isVerifyingModal = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.vpn_key_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Section Enrollment Key',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Provided by your school admin',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter your assigned section key to load your classroom room and fixed subjects.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    textCapitalization: TextCapitalization.characters,
                    style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, letterSpacing: 1),
                    decoration: InputDecoration(
                      labelText: 'Section Key',
                      hintText: 'e.g., SEC-EMR10',
                      prefixIcon: Icon(Icons.key, color: Theme.of(context).colorScheme.primary, size: 20),
                      suffixIcon: controller.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setDialogState(() => controller.clear()),
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Quick Sample Keys:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildQuickKeyChip('SEC-EMR10', 'Grade 10 Emerald', controller, setDialogState),
                      _buildQuickKeyChip('SEC-STEM11', 'Grade 11 STEM', controller, setDialogState),
                      _buildQuickKeyChip('SEC-GOLD12', 'Grade 12 Gold', controller, setDialogState),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
              ),
              ElevatedButton.icon(
                onPressed: isVerifyingModal
                    ? null
                    : () async {
                        final key = controller.text.trim();
                        if (key.isEmpty) return;

                        setDialogState(() => isVerifyingModal = true);
                        final verified = await ref.read(studentCoursesProvider.notifier).verifyKey(key);
                        setDialogState(() => isVerifyingModal = false);

                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                        }

                        if (verified != null) {
                          _showVerificationPreviewSheet(verified, key);
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Invalid Section Key "$key". Please check with your administrator.'),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                        }
                      },
                icon: isVerifyingModal
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Verify Key'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuickKeyChip(
    String key,
    String label,
    TextEditingController controller,
    StateSetter setDialogState,
  ) {
    return ActionChip(
      avatar: Icon(Icons.copy, size: 12, color: Theme.of(context).colorScheme.primary),
      label: Text('$key ($label)'),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.primary,
      ),
      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)),
      onPressed: () {
        setDialogState(() {
          controller.text = key;
        });
      },
    );
  }

  void _showVerificationPreviewSheet(Map<String, dynamic> verifiedData, String key) {
    final section = verifiedData['section'] as Map<String, dynamic>;
    final subjects = (verifiedData['subjects'] as List<dynamic>?) ?? [];
    final sectionName = section['name']?.toString() ?? 'Class Section';
    final room = section['room']?.toString() ?? 'Main Building';
    final grade = section['grade']?.toString() ?? 'Grade 10';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.verified, color: AppTheme.success, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Section Verified',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Review your room & curriculum before enrolling',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Information Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    sectionName,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    grade,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.meeting_room_outlined, size: 16, color: AppTheme.accent),
                                const SizedBox(width: 6),
                                Text(
                                  'Classroom: $room',
                                  style: TextStyle(
                                    color: AppTheme.accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.vpn_key_outlined, size: 14, color: AppTheme.textMuted),
                                const SizedBox(width: 6),
                                Text(
                                  'Key: $key',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Fixed Subjects Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Fixed Curriculum (${subjects.length} Subjects)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Assigned Faculty',
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Subjects list
                      ...subjects.map((sub) {
                        final subName = sub['name']?.toString() ?? '';
                        final subCode = sub['subject_code']?.toString() ?? '';
                        final teacher = sub['teacher_name']?.toString() ?? 'Sir John Reyes';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.menu_book, color: Theme.of(context).colorScheme.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (subCode.isNotEmpty)
                                      Text(
                                        subCode,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    Text(
                                      subName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(Icons.person_outline, size: 12, color: AppTheme.textMuted),
                                        const SizedBox(width: 4),
                                        Text(
                                          teacher,
                                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // Action buttons
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(top: BorderSide(color: AppTheme.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(sheetCtx);
                          final messenger = ScaffoldMessenger.of(context);
                          final success = await ref.read(studentCoursesProvider.notifier).enrollBySectionKey(key);
                          if (success && mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Enrolled in $sectionName successfully! All ${subjects.length} subjects loaded.'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          } else if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: const Text('Enrollment failed. Please try again.'),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Confirm & Load Subjects'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLeaveSectionDialog(String sectionName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Leave Section', style: TextStyle(color: AppTheme.text)),
        content: Text(
          'Are you sure you want to leave "$sectionName"?\n\nYou will need an enrollment key from the admin to rejoin or change sections.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(studentCoursesProvider.notifier).leaveSection();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('You have left the section. Enter a new key to re-enroll.'),
                    backgroundColor: AppTheme.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave Section'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final user = ref.watch(authProvider);
    final courses = ref.watch(studentCoursesProvider);
    final sectionDetailsAsync = ref.watch(studentSectionDetailsProvider);
    final sectionData = sectionDetailsAsync.value;
    final available = ref.watch(availableCoursesProvider);

    final hasSection = (user?.section != null && user!.section!.isNotEmpty) ||
        (sectionData != null && (sectionData['name']?.toString().isNotEmpty ?? false));

    final currentSectionName = sectionData?['name']?.toString() ?? user?.section ?? 'Assigned Section';
    final currentRoom = sectionData?['room']?.toString() ?? 'Room 201 - Main Bldg';
    final currentGrade = sectionData?['grade']?.toString() ?? user?.grade ?? 'Grade 10';
    final currentKey = sectionData?['enrollment_key']?.toString();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.read(studentCoursesProvider.notifier).reload(),
              ref.refresh(studentSectionDetailsProvider.future),
              ref.read(availableCoursesProvider.notifier).reload(),
            ]);
          },
          color: AppTheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Screen Title Header
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Courses',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Class curriculum and room schedule',
                      style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Section Banner or Welcome Enroll Card
                if (hasSection)
                  _buildSectionHeaderCard(
                    name: currentSectionName,
                    room: currentRoom,
                    grade: currentGrade,
                    key: currentKey,
                    subjectCount: courses.length,
                  )
                else
                  _buildEnrollWelcomeCard(),

                const SizedBox(height: 24),

                // Curriculum Subjects Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Curriculum Subjects (${courses.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (hasSection)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 6, height: 6, decoration: BoxDecoration(color: AppTheme.success, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(
                              'Standard Block',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.success),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Enrolled Courses List
                if (courses.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.school_outlined, size: 52, color: AppTheme.textMuted.withValues(alpha: 0.6)),
                          const SizedBox(height: 14),
                          Text(
                            'No subjects enrolled yet',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Please enter your Section Key provided by the admin above to automatically load your fixed subjects.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showEnterKeyDialog(),
                            icon: const Icon(Icons.vpn_key_rounded, size: 16),
                            label: const Text('Enter Section Key'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...courses.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildCurriculumCourseCard(
                          id: c['id'] as int,
                          title: c['name']?.toString() ?? '',
                          code: c['subject_code']?.toString() ?? '',
                          teacherName: c['teacher_name']?.toString() ?? 'Sir John Reyes',
                          room: currentRoom,
                          progress: (c['progress'] as int?) ?? 0,
                          unlockType: c['unlock_type']?.toString() ?? 'Flexible',
                          completedLos: (c['completed_los'] as int?) ?? 0,
                          totalLos: (c['total_los'] as int?) ?? 0,
                          cocs: (c['cocs'] as int?) ?? 0,
                        ),
                      )),

                const SizedBox(height: 20),

                // Collapsible Optional Electives Section (Clean & Non-Intrusive)
                if (available.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => setState(() => _showAvailable = !_showAvailable),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _showAvailable ? Icons.expand_less : Icons.expand_more,
                            color: AppTheme.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Additional / Elective Subjects (${available.length} Available)',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showAvailable) ...[
                    const SizedBox(height: 12),
                    ...available.map((sub) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildElectiveCourseCard(
                            id: sub['id'] as int,
                            title: sub['name']?.toString() ?? '',
                            code: sub['subject_code']?.toString() ?? '',
                            description: sub['description']?.toString() ?? '',
                            unlockType: sub['unlock_type']?.toString() ?? 'Flexible',
                          ),
                        )),
                  ],
                ],

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeaderCard({
    required String name,
    required String room,
    required String grade,
    String? key,
    required int subjectCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.school, color: Theme.of(context).colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppTheme.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'ENROLLED SECTION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: AppTheme.textMuted, size: 20),
                onSelected: (val) {
                  if (val == 'switch') {
                    _showEnterKeyDialog(initialKey: key);
                  } else if (val == 'leave') {
                    _showLeaveSectionDialog(name);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'switch',
                    child: Row(
                      children: [
                        Icon(Icons.vpn_key_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        const Text('Enter Another Key'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'leave',
                    child: Row(
                      children: [
                        Icon(Icons.exit_to_app, size: 18, color: AppTheme.error),
                        const SizedBox(width: 8),
                        Text('Leave Section', style: TextStyle(color: AppTheme.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.meeting_room_outlined, size: 15, color: AppTheme.accent),
                  const SizedBox(width: 5),
                  Text(
                    room,
                    style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school_outlined, size: 15, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 5),
                  Text(
                    grade,
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book_outlined, size: 15, color: AppTheme.textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    '$subjectCount Fixed Subjects',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if (key != null && key.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.vpn_key_outlined, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 5),
                    Text(
                      'Key: $key',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnrollWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.key, color: Theme.of(context).colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter Section Enrollment Key',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Admins assign your room & subjects via enrollment key',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keyController,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, letterSpacing: 1),
                  decoration: InputDecoration(
                    hintText: 'e.g. SEC-EMR10',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isVerifying
                    ? null
                    : () async {
                        final key = _keyController.text.trim();
                        if (key.isEmpty) return;

                        setState(() => _isVerifying = true);
                        final verified = await ref.read(studentCoursesProvider.notifier).verifyKey(key);
                        setState(() => _isVerifying = false);

                        if (verified != null) {
                          _showVerificationPreviewSheet(verified, key);
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Invalid Key "$key". Please check with your school administrator.'),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isVerifying
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Verify & Enroll', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Sample Keys: ', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              InkWell(
                onTap: () => setState(() => _keyController.text = 'SEC-EMR10'),
                child: Text('SEC-EMR10', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold)),
              ),
              Text(' · ', style: TextStyle(color: AppTheme.textMuted)),
              InkWell(
                onTap: () => setState(() => _keyController.text = 'SEC-STEM11'),
                child: Text('SEC-STEM11', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurriculumCourseCard({
    required int id,
    required String title,
    required String code,
    required String teacherName,
    required String room,
    required int progress,
    required String unlockType,
    required int completedLos,
    required int totalLos,
    required int cocs,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => context.push('/student/course/$id'),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.menu_book,
                    color: Theme.of(context).colorScheme.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge Row
                      Row(
                        children: [
                          if (code.isNotEmpty) ...[
                            Text(
                              code,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  unlockType == 'Sequential' ? Icons.lock : Icons.lock_open,
                                  size: 10,
                                  color: unlockType == 'Sequential' ? AppTheme.warning : Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  unlockType,
                                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Title
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // Teacher & Room Indicator
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 13, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Teacher: $teacherName',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Progress Indicator
                      LinearProgressIndicator(
                        value: totalLos > 0 ? (completedLos / totalLos) : 0,
                        backgroundColor: AppTheme.border,
                        color: Theme.of(context).colorScheme.primary,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$completedLos/$totalLos LOs · $cocs Topics',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          Text(
                            '$progress%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: AppTheme.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildElectiveCourseCard({
    required int id,
    required String title,
    required String code,
    required String description,
    required String unlockType,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.class_, color: Theme.of(context).colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (code.isNotEmpty)
                  Text(
                    code,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                  ),
                Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(studentCoursesProvider.notifier).enrollCourse(id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Enrolled in $title'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Enroll', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
