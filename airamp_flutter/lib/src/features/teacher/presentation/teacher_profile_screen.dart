import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/components/app_toast.dart';
import '../../../core/components/otp_verification_dialog.dart';
import '../../../core/components/skeleton_loader.dart';
import '../../../core/services/otp_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/application/auth_provider.dart';
import '../data/teacher_repository.dart';
import '../data/teacher_schedule_repository.dart';

class TeacherProfileScreen extends ConsumerStatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  ConsumerState<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends ConsumerState<TeacherProfileScreen> {
  bool _isEditing = false;
  bool _showPasswordForm = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSavingPassword = false;
  bool _quizAlerts = true;
  bool _scheduleReminders = true;
  bool _hapticsEnabled = true;

  final GlobalKey _passwordSectionKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  late TextEditingController _fullNameController;
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider);
    _fullNameController = TextEditingController(text: user?.fullName ?? '');
    _usernameController = TextEditingController(text: user?.username ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');

    _newPasswordController.addListener(_onPasswordFieldsChanged);
    _confirmPasswordController.addListener(_onPasswordFieldsChanged);

    if (user?.mustChangePassword == true) {
      _showPasswordForm = true;
    }
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _quizAlerts = prefs.getBool('teacher_pref_quiz_alerts') ?? true;
          _scheduleReminders = prefs.getBool('teacher_pref_schedule_reminders') ?? true;
          _hapticsEnabled = prefs.getBool('teacher_pref_haptics') ?? true;
        });
      }
    } catch (_) {}
  }

  Future<void> _savePreference(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  void _onPasswordFieldsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_onPasswordFieldsChanged);
    _confirmPasswordController.removeListener(_onPasswordFieldsChanged);
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider);
    final themeState = ref.watch(themeProvider);
    final subjects = ref.watch(teacherSubjectsProvider);
    final handledSections = ref.watch(teacherHandledSectionsProvider).value ?? [];
    final handledSectionsDetails = ref.watch(teacherHandledSectionsDetailsProvider).value ?? [];
    final students = ref.watch(teacherStudentsProvider);
    final schedules = ref.watch(teacherSchedulesProvider);

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
                SkeletonLoader.circle(size: 80),
                SizedBox(height: 16),
                SkeletonLoader(width: 160, height: 20),
                SizedBox(height: 8),
                SkeletonLoader(width: 100, height: 14),
                SizedBox(height: 24),
                SkeletonCard(),
                SkeletonCard(),
              ],
            ),
          ),
        ),
      );
    }

    final initial = currentUser.fullName.isNotEmpty
        ? currentUser.fullName[0].toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _handleBackNavigation();
        },
        child: currentUser.mustChangePassword
            ? _buildMandatoryPasswordChangeView(currentUser)
            : SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            child: Column(
              children: [
                // 1. App Bar Header with Back navigation & Active Faculty pill
                _buildHeaderBar(context, currentUser),
                const SizedBox(height: 12),

                // 2. Hero Faculty Identity Card (Avatar, Badges & 4 Quick KPIs)
                _buildHeroFacultyCard(
                  context: context,
                  currentUser: currentUser,
                  initial: initial,
                  subjects: subjects,
                  handledSections: handledSections,
                  students: students,
                  schedules: schedules,
                ),
                const SizedBox(height: 16),

                // 3. Academic Portfolio & Teaching Load Card
                _buildAcademicPortfolioCard(
                  context: context,
                  subjects: subjects,
                  handledSections: handledSections,
                  sectionDetails: handledSectionsDetails,
                  schedules: schedules,
                ),
                const SizedBox(height: 16),

                // 4. Personal & Institutional Information Card
                _buildPersonalInfoCard(currentUser),
                const SizedBox(height: 16),

                // 6. Account Security & Password Management Card
                _buildChangePasswordCard(currentUser),
                const SizedBox(height: 16),

                // 7. Classroom Experience & Preferences Card (Theme & Notifications)
                _buildPreferencesCard(themeState),
                const SizedBox(height: 16),

                // 8. Institutional App & Support Information Card
                _buildAboutAndSupportCard(context),
                const SizedBox(height: 24),

                // 9. Sign Out Button
                _buildSignOutButton(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleBackNavigation() {
    final user = ref.read(authProvider);
    if (user?.mustChangePassword == true) {
      _showMustChangePasswordBackAlert(isTeacher: true);
      return;
    }

    try {
      if (GoRouter.maybeOf(context)?.canPop() == true) {
        context.pop();
        return;
      }
    } catch (_) {}

    try {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
        return;
      }
    } catch (_) {}

    try {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
        return;
      }
    } catch (_) {}

    // Fallback: If stack cannot be popped, navigate directly to teacher dashboard
    context.go('/teacher/dashboard');
  }

  Widget _buildHeaderBar(BuildContext context, User currentUser) {
    if (currentUser.mustChangePassword) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: AppTheme.text),
            tooltip: 'Back to Dashboard',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: _handleBackNavigation,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Faculty Profile & Settings',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroFacultyCard({
    required BuildContext context,
    required User currentUser,
    required String initial,
    required List<Map<String, dynamic>> subjects,
    required List<String> handledSections,
    required List<Map<String, dynamic>> students,
    required List<Map<String, dynamic>> schedules,
  }) {
    final advisorySection = currentUser.section;
    final hasAdvisory = advisorySection != null && advisorySection.isNotEmpty && advisorySection != 'null';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              children: [
                // Avatar with Camera Overlay
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.35),
                          width: 2.5,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 42,
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                        backgroundImage: (currentUser.profileImage != null && currentUser.profileImage!.isNotEmpty)
                            ? NetworkImage(currentUser.profileImage!)
                            : null,
                        child: (currentUser.profileImage == null || currentUser.profileImage!.isEmpty)
                            ? Text(
                                initial,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: GestureDetector(
                        onTap: () {
                          AppToast.showInfo(
                            context,
                            'Profile photo updates are managed by School Admin LIS.',
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.surface, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Full Name
                Text(
                  currentUser.fullName.isNotEmpty ? currentUser.fullName : 'Faculty Member',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),

                // Username / Tag
                Text(
                  '@${currentUser.username}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 12),

                // Faculty Badges
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildBadge(
                      icon: Icons.school_rounded,
                      label: 'Teacher / Faculty',
                      color: AppTheme.primary,
                    ),
                    _buildBadge(
                      icon: Icons.verified_user_rounded,
                      label: 'DepEd Verified',
                      color: AppTheme.success,
                    ),
                    if (hasAdvisory)
                      _buildBadge(
                        icon: Icons.group_work_rounded,
                        label: 'Adviser: $advisorySection',
                        color: const Color(0xFF2563EB),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Divider
          Divider(height: 1, color: AppTheme.border),

          // Quick Teaching Workload Metrics Bar (4 KPIs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildWorkloadStat(
                    context: context,
                    icon: Icons.auto_stories_rounded,
                    count: '${subjects.length}',
                    label: 'Subjects',
                    onTap: () => context.push('/teacher/subjects'),
                  ),
                ),
                Container(width: 1, height: 32, color: AppTheme.border),
                Expanded(
                  child: _buildWorkloadStat(
                    context: context,
                    icon: Icons.grid_view_rounded,
                    count: '${handledSections.length}',
                    label: 'Sections',
                    onTap: () => context.push('/teacher/dashboard'),
                  ),
                ),
                Container(width: 1, height: 32, color: AppTheme.border),
                Expanded(
                  child: _buildWorkloadStat(
                    context: context,
                    icon: Icons.people_alt_rounded,
                    count: '${students.length}',
                    label: 'Students',
                    onTap: () => context.push('/teacher/students'),
                  ),
                ),
                Container(width: 1, height: 32, color: AppTheme.border),
                Expanded(
                  child: _buildWorkloadStat(
                    context: context,
                    icon: Icons.calendar_month_rounded,
                    count: '${schedules.length}',
                    label: 'Classes',
                    onTap: () => context.push('/teacher/schedule'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkloadStat({
    required BuildContext context,
    required IconData icon,
    required String count,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: AppTheme.primary),
                const SizedBox(width: 4),
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.5, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicPortfolioCard({
    required BuildContext context,
    required List<Map<String, dynamic>> subjects,
    required List<String> handledSections,
    required List<Map<String, dynamic>> sectionDetails,
    required List<Map<String, dynamic>> schedules,
  }) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Manage button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.auto_stories_rounded, size: 18, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Academic Portfolio',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => context.push('/teacher/subjects'),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Assigned Subjects Sub-section
          Text(
            'ASSIGNED SUBJECTS (${subjects.length})',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),

          if (subjects.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.inputBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppTheme.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No subjects currently assigned to your teaching load.',
                      style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: subjects.map((sub) {
                final code = sub['subject_code'] ?? 'SUBJ';
                final name = sub['name'] ?? 'Subject';
                final id = sub['id'];

                return InkWell(
                  onTap: () {
                    if (id != null) {
                      context.push('/teacher/subjects/$id');
                    } else {
                      context.push('/teacher/subjects');
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.inputBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            code,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppTheme.textMuted),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 16),

          // Handled Sections Sub-section
          Text(
            'HANDLED SECTIONS & CLASSROOMS (${handledSections.length})',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),

          if (handledSections.isEmpty)
            Text(
              'No sections assigned yet.',
              style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: handledSections.map((secName) {
                Map<String, dynamic> detail = const {};
                for (final d in sectionDetails) {
                  if (d['name'] == secName) {
                    detail = d;
                    break;
                  }
                }
                final studentCount = detail['studentCount'] ?? detail['student_count'];
                final room = detail['room'];

                return Container(
                  constraints: const BoxConstraints(maxWidth: 280),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.meeting_room_outlined, size: 13, color: AppTheme.primary),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          secName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.text,
                          ),
                        ),
                      ),
                      if (studentCount != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          '($studentCount sts)',
                          style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                        ),
                      ],
                      if (room != null && room.toString().isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          '• $room',
                          style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 14),

          // Weekly Schedule Quick Link
          InkWell(
            onTap: () => context.push('/teacher/schedule'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weekly Class Schedule',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.text,
                          ),
                        ),
                        Text(
                          '${schedules.length} periods active across the school week',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard(User currentUser) {
    final advisory = (currentUser.section != null && currentUser.section!.isNotEmpty && currentUser.section != 'null')
        ? currentUser.section!
        : 'None Assigned';
    final schoolId = (currentUser.schoolId != null && currentUser.schoolId!.isNotEmpty)
        ? currentUser.schoolId!
        : 'sch_main (DepEd Central)';

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.badge_outlined, size: 18, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Personal & Institutional Info',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!_isEditing)
                GestureDetector(
                  onTap: () => setState(() => _isEditing = true),
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 14, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                GestureDetector(
                  onTap: _handleSaveProfile,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.save, size: 14, color: Colors.black),
                        SizedBox(width: 4),
                        Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFieldRow(
            icon: Icons.person_outline,
            label: 'Full Name',
            value: currentUser.fullName,
            controller: _fullNameController,
            isEditing: _isEditing,
            showBorder: true,
          ),
          _buildFieldRow(
            icon: Icons.alternate_email_rounded,
            label: 'Username',
            value: currentUser.username,
            controller: _usernameController,
            isEditing: _isEditing,
            showBorder: true,
          ),
          _buildFieldRow(
            icon: Icons.email_outlined,
            label: 'Email Address (DepEd LIS)',
            value: currentUser.email,
            controller: _emailController,
            isEditing: _isEditing,
            showBorder: true,
            keyboardType: TextInputType.emailAddress,
          ),
          // Institutional non-editable fields
          _buildStaticInfoRow(
            icon: Icons.group_work_outlined,
            label: 'Advisory Section',
            value: advisory,
            showBorder: true,
          ),
          _buildStaticInfoRow(
            icon: Icons.apartment_rounded,
            label: 'Institutional Campus / Division ID',
            value: schoolId,
            showBorder: true,
          ),
          _buildStaticInfoRow(
            icon: Icons.security_rounded,
            label: 'System Access Tier',
            value: 'Faculty / Educator (Level 2 Access)',
            showBorder: false,
          ),
          if (_isEditing) ...[
            const SizedBox(height: 10),
            Text(
              '* Note: Advisory class, school division, and security roles are managed by the School LIS Administrator.',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChangePasswordCard(User currentUser) {
    final isRequired = currentUser.mustChangePassword;

    return Container(
      key: _passwordSectionKey,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRequired ? Colors.amberAccent : AppTheme.border,
          width: isRequired ? 2 : 1,
        ),
        boxShadow: isRequired
            ? [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.28),
                  blurRadius: 20,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visual Guide Highlight Banner if password change is required
          if (isRequired) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amberAccent.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.amber.withValues(alpha: 0.2),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amberAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MANDATORY: CHANGE DEFAULT PASSWORD',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amberAccent,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'For your security, set a new password before accessing classes and faculty tools.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Toggle row
          GestureDetector(
            onTap: () {
              if (isRequired) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password change is required to unlock your account.'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              setState(() => _showPasswordForm = !_showPasswordForm);
            },
            child: Row(
              children: [
                Icon(
                  isRequired ? Icons.lock_reset_rounded : Icons.lock_outline,
                  size: 18,
                  color: isRequired ? Colors.amberAccent : AppTheme.accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Change Password',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.text,
                        ),
                      ),
                      if (isRequired) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)),
                          ),
                          child: const Text(
                            'Required',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.amberAccent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isRequired)
                  Icon(
                    _showPasswordForm
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppTheme.textMuted,
                    size: 20,
                  ),
              ],
            ),
          ),

          // Expandable password form
          if (_showPasswordForm || isRequired) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Column(
                children: [
                  // New Password
                  TextField(
                    controller: _newPasswordController,
                    maxLength: 16,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    obscureText: true,
                    style: TextStyle(color: AppTheme.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'New Password',
                      counterText: '',
                      hintStyle: TextStyle(color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isRequired ? Colors.amberAccent.withValues(alpha: 0.5) : AppTheme.border,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isRequired ? Colors.amberAccent.withValues(alpha: 0.5) : AppTheme.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isRequired ? Colors.amberAccent : AppTheme.primary,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Confirm Password
                  TextField(
                    controller: _confirmPasswordController,
                    maxLength: 16,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    obscureText: true,
                    style: TextStyle(color: AppTheme.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Confirm Password',
                      counterText: '',
                      hintStyle: TextStyle(color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isRequired ? Colors.amberAccent.withValues(alpha: 0.5) : AppTheme.border,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isRequired ? Colors.amberAccent.withValues(alpha: 0.5) : AppTheme.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isRequired ? Colors.amberAccent : AppTheme.primary,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Update Password button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _handleChangePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRequired ? Colors.amber.shade400 : AppTheme.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isRequired ? Icons.lock_open_rounded : Icons.check_circle_outline,
                            size: 18,
                            color: Colors.black,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isRequired
                                ? 'Save Password & Unlock Account'
                                : 'Update Password',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreferencesCard(ThemeState themeState) {
    final isDark = themeState.isDark;

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.tune_rounded, size: 18, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Classroom Preferences',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Theme Switcher
          Text(
            'VISUAL THEME',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.inputBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (isDark) {
                        ref.read(themeProvider.notifier).setTheme(AppThemeMode.light);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: !isDark ? AppTheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.light_mode_rounded,
                            size: 16,
                            color: !isDark ? Colors.black : AppTheme.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Light Mode',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: !isDark ? Colors.black : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (!isDark) {
                        ref.read(themeProvider.notifier).setTheme(AppThemeMode.dark);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.dark_mode_rounded,
                            size: 16,
                            color: isDark ? Colors.black : AppTheme.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Dark Mode',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.black : AppTheme.textMuted,
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

          // Teaching Notifications & Feedback Toggles
          Text(
            'TEACHING NOTIFICATIONS & FEEDBACK',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),

          _buildToggleRow(
            title: 'Quiz Submissions Alert',
            subtitle: 'Notify instantly when a student completes an offline quiz',
            value: _quizAlerts,
            onChanged: (val) {
              setState(() => _quizAlerts = val);
              _savePreference('teacher_pref_quiz_alerts', val);
            },
          ),
          Divider(height: 1, color: AppTheme.border),

          _buildToggleRow(
            title: 'Class Schedule Reminders',
            subtitle: 'Receive alerts 15 minutes prior to scheduled periods',
            value: _scheduleReminders,
            onChanged: (val) {
              setState(() => _scheduleReminders = val);
              _savePreference('teacher_pref_schedule_reminders', val);
            },
          ),
          Divider(height: 1, color: AppTheme.border),

          _buildToggleRow(
            title: 'Haptic Touch Feedback',
            subtitle: 'Provide tactile vibration feedback during grading and approvals',
            value: _hapticsEnabled,
            onChanged: (val) {
              setState(() => _hapticsEnabled = val);
              _savePreference('teacher_pref_haptics', val);
              if (val) HapticFeedback.selectionClick();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAboutAndSupportCard(BuildContext context) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.shield_outlined, size: 18, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Institutional Support & Info',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.inputBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                _buildSystemSpecRow(
                  label: 'Software Platform',
                  value: 'AIRAMP DepEd Classroom Suite',
                ),
                const SizedBox(height: 6),
                _buildSystemSpecRow(
                  label: 'App Version',
                  value: 'v1.4.0 (Build 2026.10)',
                ),
                const SizedBox(height: 6),
                _buildSystemSpecRow(
                  label: 'Offline Engine',
                  value: 'SQLite 3.45 + Local Mesh Client',
                ),
                const SizedBox(height: 6),
                _buildSystemSpecRow(
                  label: 'License',
                  value: 'DepEd ICT Educational Program',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          InkWell(
            onTap: _showFacultyHelpDialog,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  Icon(Icons.help_outline_rounded, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Faculty Quick Help & Offline Guide',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.text,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.textMuted),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: AppTheme.border),

          InkWell(
            onTap: _showPrivacyDialog,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  Icon(Icons.policy_outlined, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Data Privacy & DepEd Compliance',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.text,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.textMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppTheme.primary,
            activeTrackColor: AppTheme.primary.withValues(alpha: 0.4),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSystemSpecRow({
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.text,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStaticInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool showBorder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: showBorder ? Border(bottom: BorderSide(color: AppTheme.border, width: 1)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: AppTheme.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: AppTheme.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFacultyHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.help_outline_rounded, color: AppTheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Faculty User Guide',
                style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpItem(
                title: 'Offline Quiz Submissions',
                desc: 'Students submit quizzes directly to the ESP32 Hub. Scores and answers will synchronize to your device view once connected to the classroom mesh.',
              ),
              const SizedBox(height: 10),
              _buildHelpItem(
                title: 'Managing Sections & Roster',
                desc: 'Class sections and student rosters are provisioned by the School Admin. Tap "Station Hub" above to review live connected student clients.',
              ),
              const SizedBox(height: 10),
              _buildHelpItem(
                title: 'ESP32 Station Hotspot',
                desc: 'Ensure your device is connected to the classroom AIRAMP-HUB Access Point to distribute lesson materials and activate timed quizzes.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem({required String title, required String desc}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
        ),
        const SizedBox(height: 2),
        Text(
          desc,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
        ),
      ],
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.policy_outlined, color: AppTheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Data Privacy & Compliance',
                style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'AIRAMP complies with Republic Act 10173 (Data Privacy Act of 2012) and DepEd institutional data handling standards.\n\nAll student records, grades, and teaching assets are stored within local encrypted SQLite databases on-premises and are never transmitted to unauthorized third parties.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Understood', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldRow({required IconData icon, required String label, required String value, required TextEditingController controller, required bool isEditing, required bool showBorder, TextInputType keyboardType = TextInputType.text, int? maxLength}) {
    final int effectiveLimit = maxLength ?? (
      label.toLowerCase().contains('phone') ? 15 :
      label.toLowerCase().contains('user') ? 30 :
      label.toLowerCase().contains('email') ? 50 : 50
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: showBorder ? Border(bottom: BorderSide(color: AppTheme.border, width: 1)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: AppTheme.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                const SizedBox(height: 2),
                if (isEditing)
                  TextField(
                    controller: controller,
                    maxLength: effectiveLimit,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    keyboardType: keyboardType,
                    style: TextStyle(color: AppTheme.text, fontSize: 15),
                    decoration: InputDecoration(
                      counterText: '',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      filled: true,
                      fillColor: AppTheme.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.primary),
                      ),
                    ),
                  )
                else
                  Text(value, style: TextStyle(color: AppTheme.text, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleLogout,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppTheme.error.withValues(alpha: 0.12),
        highlightColor: AppTheme.error.withValues(alpha: 0.06),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.error.withValues(alpha: 0.28),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.error.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.logout_rounded,
                  size: 20,
                  color: AppTheme.error,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.error,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'End current faculty session safely',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: AppTheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSaveProfile() async {
    final fullName = _fullNameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    if (fullName.isEmpty || username.isEmpty || email.isEmpty) {
      _showAlert('Error', 'All fields are required.');
      return;
    }

    final user = ref.read(authProvider);
    if (user == null) return;

    final isEmailChanged = email.toLowerCase() != user.email.toLowerCase();

    if (isEmailChanged) {
      // Require OTP verification for new email address
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                CircularProgressIndicator(color: AppTheme.primary),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    'Sending verification code to $email...',
                    style: TextStyle(color: AppTheme.text, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final otpResult = await OtpService().requestEmailVerificationOtp(
        targetEmail: email,
        fullName: fullName,
        userId: user.id,
        role: user.role,
        purpose: 'Faculty Email Update',
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (!otpResult.success) {
        _showAlert('Verification Failed', otpResult.message);
        return;
      }

      final verified = await OtpVerificationDialog.show(
        context: context,
        email: email,
        userId: user.id,
        fullName: fullName,
        role: user.role,
        onVerify: (code) async {
          return await OtpService().verifyOtp(
            identifier: email,
            enteredCode: code,
          );
        },
        onResend: () async {
          final res = await OtpService().requestEmailVerificationOtp(
            targetEmail: email,
            fullName: fullName,
            userId: user.id,
            role: user.role,
            purpose: 'Faculty Email Update',
          );
          return res.success;
        },
      );

      if (verified != true) {
        _emailController.text = user.email;
        return;
      }
    }

    await ref.read(authProvider.notifier).updateProfile(fullName: fullName, username: username, email: email);
    setState(() => _isEditing = false);
    if (!mounted) return;
    _showAlert(
      'Success',
      isEmailChanged ? 'Email verified and profile updated successfully!' : 'Profile updated successfully!',
    );
  }

  Future<void> _handleChangePassword() async {
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;
    if (newPass.isEmpty || newPass.length < 6) {
      _showAlert('Error', 'Password must be at least 6 characters.');
      return;
    }
    if (newPass != confirmPass) {
      _showAlert('Error', 'Passwords do not match.');
      return;
    }

    final user = ref.read(authProvider);
    if (user == null) {
      _showAlert('Error', 'Teacher account session not found.');
      return;
    }

    // MANDATORY FIRST-TIME PASSWORD CHANGE: INSTANT UPDATE WITHOUT OTP!
    if (user.mustChangePassword) {
      setState(() => _isSavingPassword = true);
      try {
        await ref.read(authProvider.notifier).updateProfile(password: newPass);
        if (!mounted) return;
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _showSuccessUnlockedDialog(isTeacher: true);
      } catch (e) {
        if (!mounted) return;
        _showAlert('Error', 'Failed to update password: $e');
      } finally {
        if (mounted) setState(() => _isSavingPassword = false);
      }
      return;
    }

    if (user.email.isEmpty) {
      _showAlert('Error', 'Teacher account or email could not be determined.');
      return;
    }

    // Show sending progress indicator for voluntary password change
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Sending verification code to your email...',
                  style: TextStyle(color: AppTheme.text, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final otpResult = await OtpService().requestOtpDirect(
      userId: user.id,
      email: user.email,
      fullName: user.fullName,
      role: user.role,
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog

    if (!otpResult.success) {
      _showAlert('Failed to Send Code', otpResult.message);
      return;
    }

    // Prompt teacher for OTP verification
    final verified = await OtpVerificationDialog.show(
      context: context,
      email: user.email,
      userId: user.id,
      fullName: user.fullName,
      role: user.role,
      onVerify: (otpCode) async {
        return await OtpService().verifyOtp(
          identifier: user.id,
          enteredCode: otpCode,
        );
      },
      onResend: () async {
        final res = await OtpService().requestOtpDirect(
          userId: user.id,
          email: user.email,
          fullName: user.fullName,
          role: user.role,
        );
        return res.success;
      },
    );

    if (verified == true) {
      final wasMustChange = user.mustChangePassword;
      await ref.read(authProvider.notifier).updateProfile(password: newPass);
      if (!mounted) return;
      setState(() => _showPasswordForm = false);
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (wasMustChange) {
        _showSuccessUnlockedDialog(isTeacher: true);
      } else {
        _showAlert('Success', 'Password changed successfully!');
      }
    }
  }

  void _showMustChangePasswordBackAlert({required bool isTeacher}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Password Required',
                style: TextStyle(
                  color: AppTheme.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'For your account security, you must set a new password before you can use AIRAMP. You cannot go back or access courses until this step is completed.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleLogout();
            },
            child: Text(
              'Sign Out',
              style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Set Password Now', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  MANDATORY PASSWORD CHANGE VIEW (Unskippable First-Login)
  // ═══════════════════════════════════════════════════════════
  Widget _buildMandatoryPasswordChangeView(User currentUser) {
    final isDark = AppTheme.isDark;
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;
    final hasMinLength = newPass.length >= 6;
    final doPasswordsMatch = newPass.isNotEmpty && newPass == confirmPass;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Glowing Security Shield
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.amber.shade400,
                        const Color(0xFFFF8F00),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.35),
                        blurRadius: 22,
                        spreadRadius: 2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.lock_reset_rounded,
                      size: 42,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'Password Change Required',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),

                // Personalized welcome & security notice
                Text(
                  'Welcome to AIRAMP, ${currentUser.fullName}!\nThis is a new account with a temporary password. You must set your personal password immediately to unlock your teaching dashboard.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppTheme.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),

                // Form Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.amberAccent.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create New Password',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // New Password Field
                      TextField(
                        controller: _newPasswordController,
                        obscureText: _obscureNewPassword,
                        style: TextStyle(color: AppTheme.text, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Enter new password',
                          hintStyle: TextStyle(color: AppTheme.textMuted),
                          prefixIcon: Icon(Icons.lock_outline_rounded, color: AppTheme.accent, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: AppTheme.textMuted,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                          ),
                          filled: true,
                          fillColor: AppTheme.inputBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text(
                        'Confirm New Password',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Confirm Password Field
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: TextStyle(color: AppTheme.text, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Re-enter new password',
                          hintStyle: TextStyle(color: AppTheme.textMuted),
                          prefixIcon: Icon(Icons.lock_clock_outlined, color: AppTheme.accent, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: AppTheme.textMuted,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                          filled: true,
                          fillColor: AppTheme.inputBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Criteria checklist
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildRequirementRow(
                              text: 'At least 6 characters',
                              isMet: hasMinLength,
                            ),
                            const SizedBox(height: 6),
                            _buildRequirementRow(
                              text: 'Passwords match',
                              isMet: doPasswordsMatch,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Submit Button (Instant save)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSavingPassword ? null : _handleChangePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade400,
                            foregroundColor: Colors.black,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSavingPassword
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.black,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.black),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Save Password & Unlock Account',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Sign Out Option
                TextButton.icon(
                  onPressed: _handleLogout,
                  icon: Icon(Icons.logout_rounded, size: 18, color: AppTheme.error),
                  label: Text(
                    'Sign out to switch account',
                    style: TextStyle(
                      color: AppTheme.error,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequirementRow({required String text, required bool isMet}) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 16,
          color: isMet ? Colors.greenAccent : AppTheme.textMuted,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            color: isMet ? AppTheme.text : AppTheme.textMuted,
            fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  void _showSuccessUnlockedDialog({required bool isTeacher}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.withValues(alpha: 0.15),
                    border: Border.all(color: Colors.greenAccent, width: 2),
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 38),
                ),
                const SizedBox(height: 16),
                Text(
                  'Account Secured! 🎉',
                  style: TextStyle(
                    color: AppTheme.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your faculty password has been set successfully. All teacher dashboards, classes, and tools are now fully unlocked.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context.go(isTeacher ? '/teacher/dashboard' : '/student/home');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      isTeacher ? 'Proceed to Dashboard' : 'Proceed to Home',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppTheme.border.withValues(alpha: 0.8),
            width: 1,
          ),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon Header Badge
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.error.withValues(alpha: 0.22),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    size: 26,
                    color: AppTheme.error,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                    letterSpacing: -0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Body Message
                Text(
                  'Are you sure you want to sign out? Your offline classroom records and cache will remain safely stored on this device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons Row
                Row(
                  children: [
                    // Cancel
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(
                            color: AppTheme.border,
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: AppTheme.background.withValues(alpha: 0.5),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.text,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Confirm Sign Out
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await ref.read(authProvider.notifier).logout();
                        },
                        icon: const Icon(
                          Icons.logout_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Sign Out',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(backgroundColor: AppTheme.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), title: Text(title, style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold)), content: Text(message, style: TextStyle(color: AppTheme.textSecondary)), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('OK', style: TextStyle(color: AppTheme.primary)))]),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border, width: 1)), child: child);
  }
}
