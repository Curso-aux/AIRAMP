import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/components/placeholders_and_vanish_input.dart';
import '../../../../core/components/typewriter_effect.dart';
import '../../../../core/theme/app_theme.dart';

/// Interactive Academic & School Management Assistant powered by the
/// PlaceholdersAndVanishInput capsule component.
///
/// Provides instant answers to common questions about enrollment, access keys,
/// teacher scorebooks, offline reviews, and platform navigation. For complex
/// or account-specific inquiries, users are guided to proceed to log in and
/// contact their concern directly inside their portal.
class PlaceholdersAndVanishInputDemo extends StatefulWidget {
  final bool isDark;
  final bool isCompact;

  const PlaceholdersAndVanishInputDemo({
    super.key,
    required this.isDark,
    this.isCompact = false,
  });

  @override
  State<PlaceholdersAndVanishInputDemo> createState() =>
      _PlaceholdersAndVanishInputDemoState();
}

class _PlaceholdersAndVanishInputDemoState
    extends State<PlaceholdersAndVanishInputDemo> {
  static const List<String> placeholders = [
    "How do students join a section using an access key?",
    "How do teachers record grades and track LO mastery?",
    "Can I take review modules and quizzes offline?",
    "What DepEd Senior High School competencies are covered?",
    "How does the Admin Console track institutional pass rates?",
    "Where can students message faculty for academic inquiries?",
  ];

  String? _submittedQuery;
  String? _answer;
  bool _copied = false;

  void _handleChange(String value) {
    debugPrint('School management query input: $value');
  }

  void _handleSubmit(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _submittedQuery = trimmed;
      _answer = _resolveAnswer(trimmed);
      _copied = false;
    });
  }

  String _resolveAnswer(String query) {
    final q = query.toLowerCase().trim();
    if (q.length < 2) {
      return 'Please enter a complete question or keyword (e.g., section key, offline review, scorebook) to receive guidance.';
    }

    if (q.contains('join') ||
        q.contains('key') ||
        q.contains('enroll') ||
        q.contains('code') ||
        q.contains('section')) {
      return 'Section Key Enrollment:\nTo join a class section, navigate to your Student Portal, select "Join Section", and enter the 6-character access key provided by your teacher or school administrator. All curriculum topics, lesson modules, and quizzes will link immediately to your account.';
    } else if (q.contains('grade') ||
        q.contains('score') ||
        q.contains('mastery') ||
        q.contains('teacher') ||
        q.contains('scorebook') ||
        q.contains('faculty')) {
      return 'Faculty members use the Teacher Portal to manage class scorebooks, record assessment results, evaluate competency mastery per Learning Outcome (LO), and export institutional grade summaries.';
    } else if (q.contains('offline') ||
        q.contains('cache') ||
        q.contains('sync') ||
        q.contains('desktop') ||
        q.contains('internet')) {
      return 'Yes. Both the Windows Desktop Application and Mobile PWA cache lessons, review topics, and Gizmo flashcards in local SQLite storage. All offline assessment answers automatically sync to Firebase Cloud once an internet connection is restored.';
    } else if (q.contains('deped') ||
        q.contains('curriculum') ||
        q.contains('shs') ||
        q.contains('competenc') ||
        q.contains('lo')) {
      return 'AIRAMP directly aligns with DepEd Senior High School curriculum standards across STEM, ABM, HUMSS, and TVL tracks—organizing study material into structured Topics, Lesson Modules, and verifiable Learning Outcomes.';
    } else if (q.contains('admin') ||
        q.contains('pass rate') ||
        q.contains('analytic') ||
        q.contains('kpi') ||
        q.contains('school')) {
      return 'The Admin Web Console provides administrators with live institutional pass rates, section capacities, student rosters, curriculum pacing, and school-wide broadcast announcements.';
    } else if (q.contains('message') ||
        q.contains('consult') ||
        q.contains('chat') ||
        q.contains('inquir')) {
      return 'Students can message their designated subject teachers directly through the integrated consultation hub for guidance on review modules, quiz questions, and study material.';
    } else {
      return 'AIRAMP coordinates school administration, teacher scorebooks, and personalized student learning modules across Web, Desktop, and Mobile. If you have an account-specific or complex inquiry, please log in to reach your teacher or administrator directly.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isMobile = MediaQuery.sizeOf(context).width < 640;

    final words = [
      const TypewriterWord(text: 'Ask'),
      const TypewriterWord(text: 'AIRA'),
      const TypewriterWord(text: 'School'),
      TypewriterWord(
        text: 'Management',
        color: AppTheme.primary,
        className: 'text-blue-500 dark:text-blue-500',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: widget.isCompact ? 16 : (isMobile ? 18 : 36),
        vertical: widget.isCompact ? 18 : (isMobile ? 28 : 42),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Headline: "Ask AIRA School Management" ───────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.school_rounded,
                  size: widget.isCompact ? 18 : 22,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: TypewriterEffect(
                  words: words,
                  textAlign: TextAlign.center,
                  textStyle: TextStyle(
                    fontSize: widget.isCompact
                        ? (isMobile ? 19 : 24)
                        : (isMobile ? 22 : 32),
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    height: 1.2,
                  ),
                  cursorColor: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Subtitle with Instruction for Complicated Inquiries ──
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.isCompact ? 540 : 640),
            child: Text(
              'Ask any question about AIRA School Management. If it\'s a complicated question, you can proceed to log in and contact your concern inside.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: widget.isCompact ? 12 : 13.5,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ),
          SizedBox(height: widget.isCompact ? 16 : 22),

          // ── Placeholders and Vanish Pill Input ────────────────────
          Center(
            child: PlaceholdersAndVanishInput(
              placeholders: placeholders,
              onChange: _handleChange,
              onSubmit: _handleSubmit,
              width: widget.isCompact ? 540 : 640,
            ),
          ),

          // ── Minimalist & Elegant Answer Card (Appears upon submit) ────
          if (_submittedQuery != null && _answer != null) ...[
            const SizedBox(height: 16),
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                constraints: BoxConstraints(
                  maxWidth: widget.isCompact ? 540 : 640,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF131A29)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar: Clean pill badge + actions
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 12,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Answer',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            _copied ? Icons.check_rounded : Icons.copy_rounded,
                            size: 15,
                            color: _copied
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                          tooltip: _copied ? 'Copied' : 'Copy Answer',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _answer!));
                            setState(() => _copied = true);
                            Future.delayed(const Duration(seconds: 2), () {
                              if (mounted) setState(() => _copied = false);
                            });
                          },
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          tooltip: 'Dismiss',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                          onPressed: () {
                            setState(() {
                              _submittedQuery = null;
                              _answer = null;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Clear, readable response text
                    SelectableText(
                      _answer!,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                        height: 1.55,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Subtle footer divider and one-line help link
                    Container(
                      padding: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.help_outline_rounded,
                            size: 13,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Complicated concern? Log in to your portal to contact your teacher or administrator.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
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
          ],
        ],
      ),
    );
  }
}
