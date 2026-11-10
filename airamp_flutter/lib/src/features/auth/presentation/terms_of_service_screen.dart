import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/components/app_logo.dart';

class TermsOfServiceScreen extends StatefulWidget {
  const TermsOfServiceScreen({super.key});

  @override
  State<TermsOfServiceScreen> createState() => _TermsOfServiceScreenState();
}

class _TermsOfServiceScreenState extends State<TermsOfServiceScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _sectionKeys = {
    0: GlobalKey(),
    1: GlobalKey(),
    2: GlobalKey(),
    3: GlobalKey(),
    4: GlobalKey(),
    5: GlobalKey(),
    6: GlobalKey(),
    7: GlobalKey(),
  };

  int _selectedFilter = 0;

  final List<String> _quickFilters = [
    'Overview',
    'In-Scope',
    'Non-Scope',
    'Roles & Access',
    'Offline & Sync',
    'Integrity',
    'Disclaimers',
    'Institutional',
  ];

  void _scrollToSection(int index) {
    setState(() => _selectedFilter = index);
    if (index == 0) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    final key = _sectionKeys[index];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Professional, low-saturation institutional palette
    final primaryColor = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? const Color(0xFF26354A) : const Color(0xFFE2E8F0);
    final textColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B111A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor, size: 20),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo.mark(size: 24, isDark: isDark),
            const SizedBox(width: 10),
            Text(
              'Terms of Service & Conditions',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 5),
                Text(
                  'DepEd SHS Aligned',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Quick Filter Bar ──────────────────────────────────────────
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(bottom: BorderSide(color: borderColor, width: 0.8)),
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              itemCount: _quickFilters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isSelected = _selectedFilter == index;
                return InkWell(
                  onTap: () => _scrollToSection(index),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? const Color(0xFF334155) : const Color(0xFF0F172A))
                          : (isDark ? const Color(0xFF161F2E) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? (isDark ? const Color(0xFF64748B) : const Color(0xFF0F172A))
                            : borderColor,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      _quickFilters[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Main Content Area ─────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card with Official AIRA Logo
                      _buildHeaderCard(isDark, surfaceColor, borderColor, textColor, textSecondary),
                      const SizedBox(height: 20),

                      // Section 1: Acceptance & Institutional Purpose
                      _buildSectionCard(
                        key: _sectionKeys[1],
                        icon: Icons.description,
                        badgeText: 'FOUNDATIONAL GOVERNANCE',
                        title: '1. Acceptance of Terms & Institutional Purpose',
                        subtitle: 'Official User Agreement, Eligibility, and DepEd Senior High School Alignment',
                        content:
                            'Welcome to AIRAMP (Academic Integrated Review & Assessment Management Platform, also operating as AIRA). '
                            'By logging into, accessing, downloading, or utilizing this platform on Android, Web, or authorized local offline hubs, '
                            'you agree to be legally bound by these Terms of Service and Conditions.\n\n'
                            'AIRAMP is engineered strictly for institutional educational use across DepEd Senior High School (SHS) curriculum competencies. '
                            'The platform coordinates classroom learning, modular reviews, quizzes, and assessment analytics between students, teachers, '
                            'school administrators, and regional oversight officers.',
                        isDark: isDark,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        textSecondary: textSecondary,
                      ),
                      const SizedBox(height: 20),

                      // Section 2: In-Scope Capabilities
                      _buildScopeCard(
                        key: _sectionKeys[2],
                        isScope: true,
                        title: '2. System Scope: What AIRAMP Delivers & Guarantees',
                        subtitle: 'Authorized Features, Instructional Tools, and Operational Capabilities',
                        items: const [
                          _ScopeItem(
                            title: 'Curriculum & Modular Learning Competencies',
                            description:
                                'Full digital hosting, indexing, and presentation of DepEd Senior High School curriculum topics, modules, competencies, and learning outcomes across core, applied, and specialized tracks.',
                          ),
                          _ScopeItem(
                            title: 'Interactive Review, Quizzes & Flashcard Gizmos',
                            description:
                                'Interactive review modules, randomized timed quizzes, multiple-choice assessments with automatic score computation, flashcards ("Gizmos"), and individual mastery progress metrics.',
                          ),
                          _ScopeItem(
                            title: 'Assignment Dispatch & Digital Submissions',
                            description:
                                'Teacher assignment publishing with deadline controls, and digital student submissions supporting structured text explanations and compressed photographic attachments of handwritten schoolwork.',
                          ),
                          _ScopeItem(
                            title: 'Multi-Platform RBAC Operations (Android & Web)',
                            description:
                                'Role-based access boundaries separating Super Admin, School Admin, Teacher, and Student roles across Web (desktop administration and faculty portal) and Android mobile devices.',
                          ),
                          _ScopeItem(
                            title: 'Hybrid Offline Persistence & Cloud Synchronization',
                            description:
                                'Offline operational capability via an encrypted local SQLite database on Android phones, with automated bi-directional synchronization to Cloud Firestore and ESP32 Micro-Hubs whenever connectivity is established.',
                          ),
                          _ScopeItem(
                            title: 'Moderated Academic Communications',
                            description:
                                'Section-specific group discussions moderated by designated teacher Room Administrators, and confidential 1-on-1 faculty consultations restricted strictly to enrolled participants.',
                          ),
                          _ScopeItem(
                            title: 'AIRA Voice Assistive Reader',
                            description:
                                'Integrated text-to-speech module reader and screen text synthesizer designed to provide accessibility support for auditory and visually impaired learners.',
                          ),
                        ],
                        isDark: isDark,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        textSecondary: textSecondary,
                      ),
                      const SizedBox(height: 20),

                      // Section 3: Non-Scope & Boundaries
                      _buildScopeCard(
                        key: _sectionKeys[3],
                        isScope: false,
                        title: '3. System Non-Scope: Boundaries & Operational Exclusions',
                        subtitle: 'Explicit Limitations, Legal Exclusions, and Non-Guaranteed Items',
                        items: const [
                          _ScopeItem(
                            title: 'No Independent Government Accreditation or Legal Diploma Granting',
                            description:
                                'AIRAMP is an instructional support, review, and assessment management software. It does NOT independently issue state diplomas, certificates of graduation, or replace the official DepEd Learner Information System (LIS) as the legal registry of student educational records.',
                          ),
                          _ScopeItem(
                            title: 'Exclusion of Telecommunication, Hardware & Utility Guarantees',
                            description:
                                'AIRAMP does NOT provide cellular data plans, ISP internet bandwidth, SIM cards, smartphone hardware, or electrical power. Operation in offline zones requires functional device batteries and local Wi-Fi or ESP32 hardware within valid radio range.',
                          ),
                          _ScopeItem(
                            title: 'AI & Assistive Voice Infallibility Disclaimer',
                            description:
                                'The AIRA Voice synthesizer and automated review suggestions are auxiliary study aids. They do NOT replace human educators, nor do they offer professional legal, psychological, or medical counseling. The system is not responsible for auditory misinterpretations.',
                          ),
                          _ScopeItem(
                            title: 'Institutional Content Ownership & Grading Discretion',
                            description:
                                'The platform does not author institution-specific lessons. Individual schools and faculty members are solely responsible for syllabus accuracy, copyright clearances, and final grade adjudication. The platform does not overturn teacher scoring decisions.',
                          ),
                          _ScopeItem(
                            title: 'Prohibition of Public Social Media & Commercial Uses',
                            description:
                                'The messaging infrastructure is restricted exclusively to academic curriculum inquiries. It does NOT support unmoderated chat rooms, commercial advertising, financial solicitations, video broadcasting, or non-academic social networking.',
                          ),
                          _ScopeItem(
                            title: 'Zero Financial Transactions or Fee Processing',
                            description:
                                'AIRAMP does NOT handle, process, record, or facilitate school tuition payments, uniform fees, cash collections, book purchases, or banking transactions of any nature.',
                          ),
                        ],
                        isDark: isDark,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        textSecondary: textSecondary,
                      ),
                      const SizedBox(height: 20),

                      // Section 4: Roles & RBAC Rules
                      _buildSectionCard(
                        key: _sectionKeys[4],
                        icon: Icons.admin_panel_settings,
                        badgeText: 'ACCESS CONTROL & RBAC',
                        title: '4. User Accounts, Credentials & RBAC Security',
                        subtitle: 'Account Provisioning, Role Boundaries, and Section Gating',
                        content:
                            '• Account Identification: User accounts are provisioned with institutional Account IDs (e.g., S-100-XXXX for students, T-100-XXXX for teachers, A-100-XXXX for admins). Users are solely responsible for maintaining credential confidentiality.\n\n'
                            '• Mandatory Credential Updates: Newly provisioned accounts must update temporary credentials on initial sign-in before accessing institutional modules.\n\n'
                            '• Section Enrollment Keys: Access to specific sections, classroom chats, and subject assignments requires an authorized enrollment key issued by school administrators. Transferring keys to unauthorized external individuals constitutes a breach of institutional policy.',
                        isDark: isDark,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        textSecondary: textSecondary,
                      ),
                      const SizedBox(height: 20),

                      // Section 5: Offline & Sync Policy
                      _buildSectionCard(
                        key: _sectionKeys[5],
                        icon: Icons.sync,
                        badgeText: 'SYNCHRONIZATION & STORAGE',
                        title: '5. Offline Storage & Cloud Synchronization Policy',
                        subtitle: 'Local SQLite Storage, ESP32 Hub Connections, and Conflict Resolution',
                        content:
                            '• Local Data Caching: Android mobile installations cache modules, flashcards, and draft quiz answers in a local SQLite database for offline review.\n\n'
                            '• Sync Precedence: When transitioning from offline to online status, local submission timestamps are validated against institutional deadlines. Sync conflicts are resolved prioritizing teacher grade books and timestamped cloud audit records.\n\n'
                            '• Data Freshness on Web: Web portal sessions operate in-memory with real-time Cloud Firestore listeners and local cache hydration. Browser cache clears may require re-syncing from the cloud.',
                        isDark: isDark,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        textSecondary: textSecondary,
                      ),
                      const SizedBox(height: 20),

                      // Section 6: Academic Integrity
                      _buildSectionCard(
                        key: _sectionKeys[6],
                        icon: Icons.verified,
                        badgeText: 'ACADEMIC INTEGRITY',
                        title: '6. Academic Integrity & Acceptable Use Policy',
                        subtitle: 'Honesty Standards, Submission Verification, and Anti-Cheating Provisions',
                        content:
                            '• Honest Work: Students must submit original responses. Submitting plagiarized text or photos of assignments completed by third parties will result in institutional disciplinary action.\n\n'
                            '• Quiz Timers & Tab Navigation: Quiz attempts enforce strict time constraints. Attempting to tamper with local system clocks or reverse-engineer local databases to reveal answer keys violates platform integrity.\n\n'
                            '• Civil Communications: Chat channels must remain respectful and academic. Harassment, profanity, bullying, and distribution of non-academic files will lead to immediate channel muting or account suspension.',
                        isDark: isDark,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        textSecondary: textSecondary,
                      ),
                      const SizedBox(height: 20),

                      // Section 7: Disclaimers & Alignment
                      _buildSectionCard(
                        key: _sectionKeys[7],
                        icon: Icons.policy,
                        badgeText: 'LEGAL DISCLAIMERS & COMPLIANCE',
                        title: '7. Disclaimers, Warranty & DepEd Alignment',
                        subtitle: 'Limitation of Liability, Service Availability, and Force Majeure',
                        content:
                            '• As-Is Provision: AIRAMP is delivered on an "AS IS" and "AS AVAILABLE" basis for institutional instructional assistance without warranties of uninterrupted uptime or error-free continuous service.\n\n'
                            '• Force Majeure: System developers, school administrations, and hosting providers are not liable for transmission delays caused by power blackouts, severe weather disruptions in rural hubs, or telecommunications network outages.\n\n'
                            '• Curriculum Compliance: Competency codes and lesson tracks reflect DepEd K-12 Senior High School guidelines as interpreted and curated by the administering educational institution.',
                        isDark: isDark,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        textSecondary: textSecondary,
                      ),
                      const SizedBox(height: 24),

                      // Bottom Return / Navigation Card
                      _buildBottomReturnCard(context, isDark, primaryColor, surfaceColor, borderColor, textColor, textSecondary),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header Card ─────────────────────────────────────────────────────────
  Widget _buildHeaderCard(
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Official AIRA Logo in circular frame
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    width: 1.0,
                  ),
                ),
                child: Center(
                  child: AppLogo.mark(
                    size: 26,
                    isDark: isDark,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Official Service Agreement & System Scope',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'AIRAMP Platform v2.0 • Last Revised: November 2026',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'This document sets forth the comprehensive terms, conditions, operational boundaries, '
            'and explicit scope of the Academic Integrated Review & Assessment Management Platform (AIRAMP). '
            'Please review the designated capabilities (In-Scope) and excluded responsibilities (Non-Scope) '
            'prior to participating in classroom or administrative activities.',
            style: TextStyle(
              fontSize: 13,
              color: textSecondary,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  // ── Standard Section Card (Professional Monochrome Badge) ───────────────
  Widget _buildSectionCard({
    Key? key,
    required IconData icon,
    required String badgeText,
    required String title,
    required String subtitle,
    required String content,
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color textSecondary,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 0.8,
                  ),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: borderColor),
          const SizedBox(height: 14),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: textSecondary,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  // ── Scope Comparison Card (In-Scope / Non-Scope) ────────────────────────
  Widget _buildScopeCard({
    Key? key,
    required bool isScope,
    required String title,
    required String subtitle,
    required List<_ScopeItem> items,
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color textSecondary,
  }) {
    // Professional restrained colors: quiet emerald for In-Scope, neutral slate for Non-Scope
    final badgeLabel = isScope ? 'SYSTEM IN-SCOPE' : 'OPERATIONAL BOUNDARIES & NON-SCOPE';
    final badgeTextColor = isScope
        ? (isDark ? const Color(0xFF10B981) : const Color(0xFF047857))
        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569));
    final badgeBg = isScope
        ? (isDark ? const Color(0x1F10B981) : const Color(0x14047857))
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9));
    final cardBorderColor = isScope
        ? (isDark ? const Color(0x3D10B981) : const Color(0x2E047857))
        : borderColor;

    return Container(
      key: key,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cardBorderColor,
          width: isScope ? 1.0 : 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isScope
                        ? (isDark ? const Color(0x4D10B981) : const Color(0x33047857))
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    width: 0.8,
                  ),
                ),
                child: Center(
                  child: Icon(
                    isScope ? Icons.check_circle_outline : Icons.shield_outlined,
                    color: badgeTextColor,
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isScope
                              ? (isDark ? const Color(0x4D10B981) : const Color(0x33047857))
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        badgeLabel,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: badgeTextColor,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: borderColor),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 13),
            itemBuilder: (context, index) {
              final item = items[index];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: isScope
                          ? (isDark ? const Color(0x2610B981) : const Color(0x1A047857))
                          : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isScope
                            ? (isDark ? const Color(0x4D10B981) : const Color(0x33047857))
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        width: 0.8,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isScope ? Icons.check : Icons.remove,
                      size: 11,
                      color: isScope
                          ? (isDark ? const Color(0xFF10B981) : const Color(0xFF047857))
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                            height: 1.48,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Bottom Return Card ──────────────────────────────────────────────────
  Widget _buildBottomReturnCard(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Understood and Ready to Proceed?',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Return to the login screen to access your institutional portal.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/login');
              }
            },
            icon: const Icon(Icons.arrow_back, size: 15),
            label: const Text('Back to Login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFF0F172A),
                  width: 0.8,
                ),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeItem {
  final String title;
  final String description;

  const _ScopeItem({
    required this.title,
    required this.description,
  });
}
