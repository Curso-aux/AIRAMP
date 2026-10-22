import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/components/app_toast.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/application/auth_provider.dart';
import '../data/student_repository.dart';
import '../../esp32_hub/domain/esp32_hub_models.dart';
import '../../esp32_hub/data/saved_materials_service.dart';
import '../../esp32_hub/presentation/saved_offline_materials_modal.dart';
import 'my_progress_screen.dart';

class MyCoursesScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const MyCoursesScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends ConsumerState<MyCoursesScreen> {
  final TextEditingController _keyController = TextEditingController();
  bool _isVerifying = false;
  bool _showAvailable = false;
  late int _activeTab;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

  @override
  void didUpdateWidget(covariant MyCoursesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      setState(() {
        _activeTab = widget.initialTab;
      });
    }
  }

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
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final primary = Theme.of(context).colorScheme.primary;
          final surface = Theme.of(context).colorScheme.surface;
          final onSurface = Theme.of(context).colorScheme.onSurface;
          final keyText = controller.text.trim();
          final canSubmit = keyText.isNotEmpty && !isVerifyingModal;

          Future<void> submitKey() async {
            final key = controller.text.trim();
            if (key.isEmpty || isVerifyingModal) return;

            setDialogState(() => isVerifyingModal = true);
            try {
              final verified = await ref.read(studentCoursesProvider.notifier).verifyKey(key);

              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
              }

              if (verified != null) {
                _showVerificationPreviewSheet(verified, key);
              } else {
                if (mounted) {
                  AppToast.showWarning(
                    context,
                    'Invalid Section Key "$key". Please check with your administrator.',
                  );
                }
              }
            } catch (e) {
              if (mounted) {
                AppToast.showError(
                  context,
                  'Error verifying key: ${e.toString().replaceFirst("Exception: ", "")}',
                );
              }
            } finally {
              if (dialogCtx.mounted) {
                setDialogState(() => isVerifyingModal = false);
              }
            }
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                          // Header: Icon badge + Title / Subtitle + Close icon
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: primary.withValues(alpha: 0.25),
                                    width: 1.2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.vpn_key_rounded,
                                  color: primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Section Enrollment',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: onSurface,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Provided by your school administrator',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => Navigator.pop(dialogCtx),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 20,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Informative callout card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: primary.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 18,
                                  color: primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Enter your assigned section key to load your classroom room and fixed subjects.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: onSurface.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Field Label
                          Text(
                            'SECTION KEY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Text Input Field
                          TextField(
                            controller: controller,
                            maxLength: 20,
                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                            textCapitalization: TextCapitalization.characters,
                            style: TextStyle(
                              color: onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 1.5,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: isDark
                                  ? AppTheme.darkInputBg
                                  : const Color(0xFFF8FAFC),
                              hintText: 'e.g. SEC-10A',
                              hintStyle: TextStyle(
                                color: AppTheme.textMuted.withValues(alpha: 0.6),
                                fontWeight: FontWeight.normal,
                                letterSpacing: 0.5,
                                fontSize: 14,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              prefixIcon: Icon(
                                Icons.key_rounded,
                                color: keyText.isNotEmpty ? primary : AppTheme.textMuted,
                                size: 20,
                              ),
                              suffixIcon: controller.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.cancel_rounded, size: 18),
                                      color: AppTheme.textMuted,
                                      tooltip: 'Clear',
                                      onPressed: () => setDialogState(() => controller.clear()),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.content_paste_rounded, size: 18),
                                      color: primary,
                                      tooltip: 'Paste from clipboard',
                                      onPressed: () async {
                                        final data = await Clipboard.getData(Clipboard.kTextPlain);
                                        if (data?.text != null && data!.text!.trim().isNotEmpty) {
                                          setDialogState(() {
                                            controller.text = data.text!.trim().toUpperCase();
                                          });
                                        }
                                      },
                                    ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: primary, width: 2),
                              ),
                            ),
                            onChanged: (_) => setDialogState(() {}),
                            onSubmitted: (_) => submitKey(),
                          ),
                          const SizedBox(height: 8),

                          // Helper note
                          Row(
                            children: [
                              Icon(Icons.shield_outlined, size: 12, color: AppTheme.textMuted),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  'Keys are case-insensitive and unique to each registered class section.',
                                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),

                          // Action Buttons Row
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(dialogCtx),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    foregroundColor: AppTheme.textSecondary,
                                    side: BorderSide(
                                      color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: canSubmit ? submitKey : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primary,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: primary.withValues(alpha: 0.3),
                                    disabledForegroundColor: Colors.white70,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: isVerifyingModal
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: const [
                                            Icon(Icons.check_circle_rounded, size: 18),
                                            SizedBox(width: 8),
                                            Text(
                                              'Verify Key',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
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
        },
      ),
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
                          try {
                            final success = await ref.read(studentCoursesProvider.notifier).enrollBySectionKey(key);
                            if (success && mounted) {
                              AppToast.showSuccess(
                                context,
                                'Enrolled in $sectionName successfully! All ${subjects.length} subjects loaded.',
                              );
                            } else if (mounted) {
                              AppToast.showError(
                                context,
                                'Enrollment failed. Please try again.',
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              AppToast.showError(
                                context,
                                'Enrollment error: ${e.toString().replaceFirst("Exception: ", "")}',
                              );
                            }
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
                AppToast.showInfo(
                  context,
                  'You have left the section. Enter a new key to re-enroll.',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

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
          color: primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Screen Title Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _activeTab == 0 ? 'My Courses' : 'Academic Progress',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.4,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _activeTab == 0
                                ? 'Class curriculum and room schedule'
                                : 'Track your learning journey and quiz milestones',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_activeTab == 0)
                      ValueListenableBuilder<List<HubMaterialItem>>(
                        valueListenable: SavedMaterialsService.instance.savedMaterialsNotifier,
                        builder: (context, savedList, _) {
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                SavedOfflineMaterialsModal.show(
                                  context,
                                  studentName: user?.fullName ?? 'Student',
                                  studentSection: user?.section,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.folder_outlined,
                                      size: 15,
                                      color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      savedList.isNotEmpty ? 'Materials (${savedList.length})' : 'Materials',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12.5,
                                        color: isDark ? AppTheme.darkText : const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Institutional Segmented Navigation Switch (Courses vs Progress)
                Container(
                  height: 40,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkInputBg : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            if (_activeTab != 0) setState(() => _activeTab = 0);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _activeTab == 0
                                  ? (isDark ? AppTheme.darkSurface : Colors.white)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _activeTab == 0
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.menu_book_rounded,
                                  size: 14,
                                  color: _activeTab == 0
                                      ? (isDark ? AppTheme.darkText : const Color(0xFF0F172A))
                                      : AppTheme.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Enrolled Courses (${courses.length})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _activeTab == 0 ? FontWeight.bold : FontWeight.w500,
                                    color: _activeTab == 0
                                        ? (isDark ? AppTheme.darkText : const Color(0xFF0F172A))
                                        : AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            if (_activeTab != 1) setState(() => _activeTab = 1);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _activeTab == 1
                                  ? (isDark ? AppTheme.darkSurface : Colors.white)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _activeTab == 1
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.bar_chart_rounded,
                                  size: 14,
                                  color: _activeTab == 1
                                      ? (isDark ? AppTheme.darkText : const Color(0xFF0F172A))
                                      : AppTheme.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Learning Progress',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _activeTab == 1 ? FontWeight.bold : FontWeight.w500,
                                    color: _activeTab == 1
                                        ? (isDark ? AppTheme.darkText : const Color(0xFF0F172A))
                                        : AppTheme.textMuted,
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
                const SizedBox(height: 18),

                if (_activeTab == 0) ...[
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

                const SizedBox(height: 22),

                // Curriculum Subjects Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Curriculum Subjects (${courses.length})',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (hasSection)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Standard Block',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
                          ),
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
              ] else ...[
                const MyProgressScreen(isEmbedded: true),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.school_rounded,
                  color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ENROLLED SECTION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                        letterSpacing: -0.2,
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
          Divider(height: 1, color: isDark ? AppTheme.darkBorder : const Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.meeting_room_outlined, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 5),
                  Text(
                    room,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school_outlined, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 5),
                  Text(
                    grade,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book_outlined, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 5),
                  Text(
                    '$subjectCount Subjects',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (key != null && key.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.vpn_key_outlined, size: 13, color: AppTheme.textMuted),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.vpn_key_rounded,
                  color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
                  size: 20,
                ),
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
                      'Classroom curriculum is assigned via section key',
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
                  maxLength: 20,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'e.g. SEC-10A',
                    prefixIcon: Icon(Icons.key_rounded, color: AppTheme.textMuted, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: isDark ? AppTheme.darkInputBg : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: primary, width: 1.5),
                    ),
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
                        try {
                          final verified = await ref.read(studentCoursesProvider.notifier).verifyKey(key);

                          if (verified != null) {
                            _showVerificationPreviewSheet(verified, key);
                          } else {
                            if (mounted) {
                              AppToast.showWarning(
                                context,
                                'Invalid Key "$key". Please check with your school administrator.',
                              );
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            AppToast.showError(
                              context,
                              'Error verifying key: ${e.toString().replaceFirst("Exception: ", "")}',
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isVerifying = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: _isVerifying
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Verify & Enroll', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 12, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Obtain your section key from your school adviser or administrator.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
                    size: 20,
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                code,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppTheme.darkText : const Color(0xFF1E293B),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  unlockType == 'Sequential'
                                      ? Icons.lock_outline_rounded
                                      : Icons.lock_open_rounded,
                                  size: 10,
                                  color: AppTheme.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  unlockType,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Title
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),

                      // Teacher
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 13, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Teacher: $teacherName',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Progress Indicator
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: totalLos > 0 ? (completedLos / totalLos) : 0,
                          backgroundColor: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFE2E8F0),
                          color: primary,
                          minHeight: 5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$completedLos/$totalLos LOs · $cocs Topics',
                            style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                          ),
                          Text(
                            '$progress%',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: progress > 0 ? primary : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted.withValues(alpha: 0.5), size: 20),
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.class_outlined,
              color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (code.isNotEmpty)
                  Text(
                    code,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkText : const Color(0xFF1E293B),
                    ),
                  ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
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
                AppToast.showSuccess(context, 'Enrolled in $title');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 34),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Enroll', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
