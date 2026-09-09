import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../data/admin_repository.dart';

class AdminWebTeachersScreen extends ConsumerStatefulWidget {
  const AdminWebTeachersScreen({super.key});

  @override
  ConsumerState<AdminWebTeachersScreen> createState() => _AdminWebTeachersScreenState();
}

class _AdminWebTeachersScreenState extends ConsumerState<AdminWebTeachersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final teachers = ref.watch(adminTeachersProvider);
    final subjects = ref.watch(subjectsProvider);

    final filteredTeachers = teachers.where((t) {
      if (_searchQuery.isEmpty) return true;
      final name = (t['full_name'] as String? ?? '').toLowerCase();
      final email = (t['email'] as String? ?? '').toLowerCase();
      final user = (t['username'] as String? ?? '').toLowerCase();
      final subs = (t['assigned_subjects'] as List? ?? []).map((s) => (s['name'] as String? ?? '').toLowerCase()).join(' ');
      return name.contains(_searchQuery) || email.contains(_searchQuery) || user.contains(_searchQuery) || subs.contains(_searchQuery);
    }).toList();

    // Summary calculations
    final totalTeachers = teachers.length;
    final totalAssignedSubjects = teachers.fold<int>(0, (sum, t) => sum + (t['assigned_subjects_count'] as int? ?? 0));
    final allSections = <String>{};
    for (final t in teachers) {
      final secs = t['handled_sections'] as List? ?? [];
      for (final s in secs) {
        allSections.add(s.toString());
      }
    }
    final totalStudentsReached = teachers.fold<int>(0, (sum, t) => sum + (t['student_count'] as int? ?? 0));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(adminTeachersProvider.notifier).loadTeachers();
          await ref.read(subjectsProvider.notifier).reload();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Faculty & Teacher Management',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.text),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage school instructors, course assignments, handled sections, and teaching workloads',
                          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _openAddTeacherDialog(context, subjects),
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('Add New Faculty'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                      minimumSize: const Size(0, 42),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // KPI Stats Overview Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 800;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildKpiCard(
                        title: 'Total Faculty',
                        value: '$totalTeachers',
                        icon: Icons.badge_outlined,
                        color: AppTheme.primary,
                        width: isWide ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2,
                      ),
                      _buildKpiCard(
                        title: 'Assigned Courses',
                        value: '$totalAssignedSubjects',
                        icon: Icons.menu_book_outlined,
                        color: Colors.teal,
                        width: isWide ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2,
                      ),
                      _buildKpiCard(
                        title: 'Handled Sections',
                        value: '${allSections.length}',
                        icon: Icons.groups_outlined,
                        color: Colors.amber.shade700,
                        width: isWide ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2,
                      ),
                      _buildKpiCard(
                        title: 'Students Reached',
                        value: '$totalStudentsReached',
                        icon: Icons.school_outlined,
                        color: Colors.indigo,
                        width: isWide ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Search & Filter Toolbar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: AppTheme.text, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search faculty by name, email, username, or assigned subject...',
                          hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                          prefixIcon: Icon(Icons.search, size: 20, color: AppTheme.textMuted),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close, size: 18, color: AppTheme.textMuted),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: AppTheme.background,
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
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        '${filteredTeachers.length} Faculty Shown',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Faculty Table / List
              if (filteredTeachers.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.badge_outlined, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty ? 'No Faculty Registered Yet' : 'No Faculty Matching "$_searchQuery"',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _searchQuery.isEmpty
                            ? 'Click "Add New Faculty" above to onboard your school teaching staff.'
                            : 'Try adjusting your search criteria or clear the search filter.',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 900),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(AppTheme.background),
                          headingTextStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5,
                          ),
                          dataRowMaxHeight: 76,
                          horizontalMargin: 20,
                          columnSpacing: 24,
                          columns: const [
                            DataColumn(label: Text('FACULTY MEMBER')),
                            DataColumn(label: Text('CONTACT & USERNAME')),
                            DataColumn(label: Text('ASSIGNED SUBJECTS')),
                            DataColumn(label: Text('HANDLED SECTIONS')),
                            DataColumn(label: Text('STUDENTS REACH')),
                            DataColumn(label: Text('ACTIONS')),
                          ],
                          rows: filteredTeachers.map((teacher) {
                            final name = teacher['full_name'] as String? ?? 'Teacher';
                            final email = teacher['email'] as String? ?? '';
                            final username = teacher['username'] as String? ?? '';
                            final assignedSubjects = (teacher['assigned_subjects'] as List? ?? []).cast<Map<String, dynamic>>();
                            final handledSections = (teacher['handled_sections'] as List? ?? []).map((s) => s.toString()).toList();
                            final studentCount = teacher['student_count'] as int? ?? 0;

                            return DataRow(
                              cells: [
                                // Faculty Member
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                                        child: Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : 'T',
                                          style: TextStyle(
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: AppTheme.text,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Faculty Instructor',
                                              style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Contact & Username
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        email,
                                        style: TextStyle(fontSize: 13, color: AppTheme.text),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '@$username',
                                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                ),

                                // Assigned Subjects
                                DataCell(
                                  assignedSubjects.isEmpty
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'No Courses Assigned',
                                            style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600),
                                          ),
                                        )
                                      : Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: assignedSubjects.take(3).map((sub) {
                                            final code = sub['subject_code'] as String? ?? '';
                                            final title = sub['name'] as String? ?? 'Subject';
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.teal.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
                                              ),
                                              child: Text(
                                                code.isNotEmpty ? code : title,
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.teal),
                                              ),
                                            );
                                          }).toList()
                                            ..addAll(assignedSubjects.length > 3
                                                ? [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.surface,
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: AppTheme.border),
                                                      ),
                                                      child: Text(
                                                        '+${assignedSubjects.length - 3}',
                                                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                                      ),
                                                    )
                                                  ]
                                                : []),
                                        ),
                                ),

                                // Handled Sections
                                DataCell(
                                  handledSections.isEmpty
                                      ? Text('—', style: TextStyle(color: AppTheme.textMuted))
                                      : Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: handledSections.map((sec) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.purple.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
                                              ),
                                              child: Text(
                                                sec,
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.purple),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                ),

                                // Students Reach
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: studentCount > 0 ? Colors.green.withValues(alpha: 0.1) : AppTheme.background,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: studentCount > 0 ? Colors.green.withValues(alpha: 0.2) : AppTheme.border,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.people_alt_outlined,
                                          size: 14,
                                          color: studentCount > 0 ? Colors.green : AppTheme.textMuted,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$studentCount Enrolled',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: studentCount > 0 ? Colors.green : AppTheme.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Action Buttons
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.assignment_ind_outlined, size: 18),
                                        tooltip: 'Assign Courses',
                                        color: AppTheme.primary,
                                        onPressed: () => _openAssignCoursesDialog(context, teacher, subjects),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        tooltip: 'Edit Profile',
                                        color: AppTheme.textSecondary,
                                        onPressed: () => _openEditTeacherDialog(context, teacher),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18),
                                        tooltip: 'Delete Faculty',
                                        color: Colors.red.shade400,
                                        onPressed: () => _confirmDeleteTeacher(context, teacher),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Add New Faculty Dialog ─────────────────────────────────
  void _openAddTeacherDialog(BuildContext context, List<Map<String, dynamic>> availableSubjects) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController(text: 'Teacher@123');
    final selectedSubjectIds = <int>{};
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.person_add_alt_1, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text('Add New Faculty Member', style: TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Instructor Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nameCtrl,
                          style: TextStyle(color: AppTheme.text, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Full Name (e.g. Sir Juan Luna)',
                            labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            prefixIcon: Icon(Icons.person_outline, size: 20, color: AppTheme.textMuted),
                            filled: true,
                            fillColor: AppTheme.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Please enter teacher full name' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: emailCtrl,
                          style: TextStyle(color: AppTheme.text, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'School Email (e.g. juan.luna@school.edu)',
                            labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            prefixIcon: Icon(Icons.email_outlined, size: 20, color: AppTheme.textMuted),
                            filled: true,
                            fillColor: AppTheme.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Please enter email';
                            if (!v.contains('@')) return 'Please enter a valid email address';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: usernameCtrl,
                                style: TextStyle(color: AppTheme.text, fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: 'Username (Optional)',
                                  labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  prefixIcon: Icon(Icons.alternate_email, size: 20, color: AppTheme.textMuted),
                                  filled: true,
                                  fillColor: AppTheme.background,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: passwordCtrl,
                                obscureText: true,
                                style: TextStyle(color: AppTheme.text, fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: 'Initial Password',
                                  labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  prefixIcon: Icon(Icons.lock_outline, size: 20, color: AppTheme.textMuted),
                                  filled: true,
                                  fillColor: AppTheme.background,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                                ),
                                validator: (v) => v == null || v.length < 6 ? 'Minimum 6 characters' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        Text('Initial Course Assignments (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                        const SizedBox(height: 8),
                        if (availableSubjects.isEmpty)
                          Text('No subjects created in school curriculum yet.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted))
                        else
                          Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: availableSubjects.length,
                              separatorBuilder: (_, _) => Divider(height: 1, color: AppTheme.border),
                              itemBuilder: (ctx, i) {
                                final sub = availableSubjects[i];
                                final id = sub['id'] as int;
                                final name = sub['name'] as String? ?? 'Subject';
                                final code = sub['subject_code'] as String? ?? '';
                                final currentTeacher = sub['teacher_name'] as String?;
                                final isSelected = selectedSubjectIds.contains(id);

                                return CheckboxListTile(
                                  value: isSelected,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        selectedSubjectIds.add(id);
                                      } else {
                                        selectedSubjectIds.remove(id);
                                      }
                                    });
                                  },
                                  title: Text(
                                    code.isNotEmpty ? '$code — $name' : name,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text),
                                  ),
                                  subtitle: currentTeacher != null && currentTeacher.isNotEmpty
                                      ? Text('Currently: $currentTeacher', style: TextStyle(fontSize: 11, color: AppTheme.textMuted))
                                      : null,
                                  activeColor: AppTheme.primary,
                                  dense: true,
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    try {
                      await ref.read(adminTeachersProvider.notifier).addTeacher(
                            fullName: nameCtrl.text.trim(),
                            email: emailCtrl.text.trim(),
                            password: passwordCtrl.text.trim(),
                            username: usernameCtrl.text.trim().isNotEmpty ? usernameCtrl.text.trim() : null,
                            assignSubjectIds: selectedSubjectIds.toList(),
                          );
                      if (context.mounted) {
                        Navigator.of(dialogCtx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Faculty "${nameCtrl.text.trim()}" onboarded successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(0, 40),
                  ),
                  child: const Text('Add Faculty Member'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Assign Courses Dialog ──────────────────────────────────
  void _openAssignCoursesDialog(BuildContext context, Map<String, dynamic> teacher, List<Map<String, dynamic>> availableSubjects) {
    final teacherId = teacher['id'] as String;
    final teacherName = teacher['full_name'] as String? ?? 'Teacher';
    final currentAssigned = (teacher['assigned_subjects'] as List? ?? []).cast<Map<String, dynamic>>();
    final selectedIds = currentAssigned.map((s) => s['id'] as int).toSet();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.assignment_ind, color: Colors.teal, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Course Assignments', style: TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('for $teacherName', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: availableSubjects.isEmpty
                    ? Text('No subjects in school curriculum yet.', style: TextStyle(color: AppTheme.textMuted))
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select courses taught by this teacher. All sections and students enrolled in these courses will be automatically linked.',
                            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 280),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: availableSubjects.length,
                              separatorBuilder: (_, _) => Divider(height: 1, color: AppTheme.border),
                              itemBuilder: (ctx, i) {
                                final sub = availableSubjects[i];
                                final id = sub['id'] as int;
                                final name = sub['name'] as String? ?? 'Subject';
                                final code = sub['subject_code'] as String? ?? '';
                                final existingTeacherId = sub['teacher_id'] as String?;
                                final existingTeacherName = sub['teacher_name'] as String?;
                                final isSelected = selectedIds.contains(id);
                                final isAssignedOther = existingTeacherId != null && existingTeacherId != teacherId && existingTeacherId.isNotEmpty;

                                return CheckboxListTile(
                                  value: isSelected,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        selectedIds.add(id);
                                      } else {
                                        selectedIds.remove(id);
                                      }
                                    });
                                  },
                                  title: Text(
                                    code.isNotEmpty ? '$code — $name' : name,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text),
                                  ),
                                  subtitle: isAssignedOther
                                      ? Text('Currently assigned to: $existingTeacherName (will be transferred)',
                                          style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w500))
                                      : null,
                                  activeColor: Colors.teal,
                                  dense: true,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await ref.read(adminTeachersProvider.notifier).updateTeacher(
                            teacherId,
                            {},
                            assignSubjectIds: selectedIds.toList(),
                          );
                      if (context.mounted) {
                        Navigator.of(dialogCtx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Course assignments updated for $teacherName'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(0, 40),
                  ),
                  child: const Text('Save Assignments'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Edit Teacher Dialog ────────────────────────────────────
  void _openEditTeacherDialog(BuildContext context, Map<String, dynamic> teacher) {
    final teacherId = teacher['id'] as String;
    final nameCtrl = TextEditingController(text: teacher['full_name'] as String? ?? '');
    final emailCtrl = TextEditingController(text: teacher['email'] as String? ?? '');
    final usernameCtrl = TextEditingController(text: teacher['username'] as String? ?? '');
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.edit, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Text('Edit Faculty Profile', style: TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    style: TextStyle(color: AppTheme.text, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      prefixIcon: Icon(Icons.person_outline, size: 20, color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Please enter name' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: emailCtrl,
                    style: TextStyle(color: AppTheme.text, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      prefixIcon: Icon(Icons.email_outlined, size: 20, color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                    ),
                    validator: (v) => v == null || !v.contains('@') ? 'Enter valid email' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: usernameCtrl,
                    style: TextStyle(color: AppTheme.text, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Username',
                      labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      prefixIcon: Icon(Icons.alternate_email, size: 20, color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: true,
                    style: TextStyle(color: AppTheme.text, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Reset Password (leave empty to keep current)',
                      labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      prefixIcon: Icon(Icons.lock_outline, size: 20, color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  final data = <String, dynamic>{
                    'full_name': nameCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'username': usernameCtrl.text.trim(),
                  };
                  if (passwordCtrl.text.trim().isNotEmpty) {
                    data['password'] = passwordCtrl.text.trim();
                  }
                  await ref.read(adminTeachersProvider.notifier).updateTeacher(teacherId, data);
                  if (context.mounted) {
                    Navigator.of(dialogCtx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Faculty profile updated successfully'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                minimumSize: const Size(0, 40),
              ),
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }

  // ── Confirm Delete Teacher Dialog ──────────────────────────
  void _confirmDeleteTeacher(BuildContext context, Map<String, dynamic> teacher) {
    final teacherId = teacher['id'] as String;
    final teacherName = teacher['full_name'] as String? ?? 'Teacher';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 28),
              const SizedBox(width: 10),
              Text('Delete Faculty Member', style: TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Are you sure you want to remove "$teacherName"? All assigned courses will be unassigned safely.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ref.read(adminTeachersProvider.notifier).deleteTeacher(teacherId);
                  if (context.mounted) {
                    Navigator.of(dialogCtx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Faculty member "$teacherName" deleted'), backgroundColor: Colors.red),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                minimumSize: const Size(0, 40),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
