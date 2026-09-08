import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/application/auth_provider.dart';
import '../../../student/data/student_repository.dart';
import '../../data/teacher_repository.dart';
import 'quiz_parser.dart';

class CreateQuizDialog extends ConsumerStatefulWidget {
  final int subjectId;
  final String subjectName;

  const CreateQuizDialog({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  ConsumerState<CreateQuizDialog> createState() => _CreateQuizDialogState();
}

class _CreateQuizDialogState extends ConsumerState<CreateQuizDialog> {
  int _currentStep = 0; // 0: Details, 1: Questions, 2: Students Assignment

  // Step 1: Details
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  int _timeLimitMinutes = 15;
  int _passingScore = 70;
  DateTime? _dueDate;

  // Step 2: Questions
  int _questionInputMode = 0; // 0: Bulk Paste / Upload, 1: Manual
  final _bulkTextController = TextEditingController();
  List<ParsedQuestion> _parsedQuestions = [];
  List<String> _parserErrors = [];

  // Manual Question
  final _qTextController = TextEditingController();
  final _optAController = TextEditingController();
  final _optBController = TextEditingController();
  final _optCController = TextEditingController();
  final _optDController = TextEditingController();
  String _manualCorrectOption = 'A';

  // Step 3: Students & Bulk Assignment
  List<Map<String, dynamic>> _availableStudents = [];
  final Set<String> _selectedStudentIds = {};
  bool _loadingStudents = true;
  String _activeSectionFilter = 'All Sections';
  List<String> _sections = ['All Sections'];

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _dueDate = DateTime.now().add(const Duration(days: 7));
    _loadStudents();
    _initSampleBulkText();
  }

  void _initSampleBulkText() {
    _bulkTextController.text = '''1. What is the main entry point of a Flutter application?
A) runApp()
B) main()
C) build()
D) start()
Answer: B

2. Which keyword is used to declare a compile-time constant in Dart?
A) final
B) var
C) const
D) static
Answer: C

3. What kind of widget should you use when UI elements need to change dynamically?
A) StatelessWidget
B) StatefulWidget
C) InheritedWidget
D) ViewWidget
Answer: B''';
    _parseBulkQuestions(notify: false);
  }

  Future<void> _loadStudents() async {
    try {
      final students = await DatabaseHelper().getStudentsForSubjectOrAll(widget.subjectId);
      final secSet = <String>{'All Sections'};
      for (final s in students) {
        final sec = s['section']?.toString();
        if (sec != null && sec.isNotEmpty) {
          secSet.add(sec);
        }
      }

      if (mounted) {
        setState(() {
          _availableStudents = students;
          _sections = secSet.toList();
          // By default, select all enrolled/available students
          _selectedStudentIds.addAll(students.map((s) => s['id'] as String));
          _loadingStudents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingStudents = false;
        });
      }
    }
  }

  void _parseBulkQuestions({bool notify = true}) {
    final res = QuizParser.parse(_bulkTextController.text);
    if (notify && mounted) {
      setState(() {
        _parsedQuestions = res.questions;
        _parserErrors = res.errors;
      });
    } else {
      _parsedQuestions = res.questions;
      _parserErrors = res.errors;
    }
  }

  void _addManualQuestion() {
    final qText = _qTextController.text.trim();
    final a = _optAController.text.trim();
    final b = _optBController.text.trim();
    final c = _optCController.text.trim();
    final d = _optDController.text.trim();

    if (qText.isEmpty || a.isEmpty || b.isEmpty || c.isEmpty || d.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out question text and all 4 options')),
      );
      return;
    }

    setState(() {
      _parsedQuestions.add(ParsedQuestion(
        questionText: qText,
        optionA: a,
        optionB: b,
        optionC: c,
        optionD: d,
        correctOption: _manualCorrectOption,
      ));
      _qTextController.clear();
      _optAController.clear();
      _optBController.clear();
      _optCController.clear();
      _optDController.clear();
      _manualCorrectOption = 'A';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added question #${_parsedQuestions.length}')),
    );
  }

  Future<void> _submitQuiz() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _currentStep = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a quiz title')),
      );
      return;
    }

    if (_parsedQuestions.isEmpty) {
      setState(() => _currentStep = 1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one question')),
      );
      return;
    }

    if (_selectedStudentIds.isEmpty) {
      setState(() => _currentStep = 2);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one student to assign the quiz')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(authProvider);
      final teacherId = user?.id ?? 'teacher_1';
      final teacherName = user?.fullName ?? 'Instructor';

      final quizId = await DatabaseHelper().createQuiz(
        title: title,
        description: _descController.text.trim(),
        subjectId: widget.subjectId,
        teacherId: teacherId,
        teacherName: teacherName,
        timeLimitMinutes: _timeLimitMinutes,
        passingScore: _passingScore,
        dueDate: _dueDate?.toIso8601String(),
        questions: _parsedQuestions.map((q) => q.toMap()).toList(),
      );

      final assignedCount = await DatabaseHelper().assignQuizToStudents(
        quizId: quizId,
        studentIds: _selectedStudentIds.toList(),
        dueDate: _dueDate?.toIso8601String(),
      );

      ref.invalidate(subjectQuizzesProvider(widget.subjectId));
      ref.invalidate(teacherDashboardProvider);
      ref.invalidate(studentQuizAssignmentsProvider);
      ref.invalidate(studentQuizAttemptsProvider);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: Text('Quiz "$title" created and assigned to $assignedCount students!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.error, content: Text('Error creating quiz: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _bulkTextController.dispose();
    _qTextController.dispose();
    _optAController.dispose();
    _optBController.dispose();
    _optCController.dispose();
    _optDController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create & Assign Quiz',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.subjectName,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                // Stepper Indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _buildStepPill(0, '1. Details'),
                      const SizedBox(width: 8),
                      _buildStepPill(1, '2. Questions (${_parsedQuestions.length})'),
                      const SizedBox(width: 8),
                      _buildStepPill(2, '3. Assign (${_selectedStudentIds.length})'),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Body content per step
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: _buildCurrentStepView(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentStep > 0)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _currentStep--),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back'),
                )
              else
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
              Row(
                children: [
                  if (_currentStep < 2)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: () {
                        if (_currentStep == 0 && _titleController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a quiz title')),
                          );
                          return;
                        }
                        if (_currentStep == 1 && _parsedQuestions.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please add at least one question')),
                          );
                          return;
                        }
                        setState(() => _currentStep++);
                      },
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('Next Step', style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  else
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: _isSubmitting ? null : _submitQuiz,
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check, size: 18),
                      label: Text(
                        _isSubmitting ? 'Publishing...' : 'Publish & Assign (${_selectedStudentIds.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepPill(int index, String label) {
    final isActive = _currentStep == index;
    final isDone = _currentStep > index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentStep = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primary
                : (isDone ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.background),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? AppTheme.primary : AppTheme.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.black : (isDone ? AppTheme.primary : AppTheme.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Details();
      case 1:
        return _buildStep2Questions();
      case 2:
        return _buildStep3Students();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- STEP 1: Quiz Details ---
  Widget _buildStep1Details() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quiz Title', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.text, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'e.g., CS101: Midterm Knowledge Check',
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
            ),
          ),
          const SizedBox(height: 14),

          Text('Description (Optional)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.text, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _descController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Instructions, topics covered, or notes for students...',
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Time Limit (Minutes)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.text, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: _timeLimitMinutes,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('No Limit')),
                        DropdownMenuItem(value: 5, child: Text('5 Minutes')),
                        DropdownMenuItem(value: 10, child: Text('10 Minutes')),
                        DropdownMenuItem(value: 15, child: Text('15 Minutes')),
                        DropdownMenuItem(value: 20, child: Text('20 Minutes')),
                        DropdownMenuItem(value: 30, child: Text('30 Minutes')),
                        DropdownMenuItem(value: 45, child: Text('45 Minutes')),
                        DropdownMenuItem(value: 60, child: Text('60 Minutes')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _timeLimitMinutes = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Passing Score (%)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.text, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: _passingScore,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 50, child: Text('50%')),
                        DropdownMenuItem(value: 60, child: Text('60%')),
                        DropdownMenuItem(value: 70, child: Text('70% (Standard)')),
                        DropdownMenuItem(value: 75, child: Text('75%')),
                        DropdownMenuItem(value: 80, child: Text('80%')),
                        DropdownMenuItem(value: 90, child: Text('90%')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _passingScore = val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.text, fontSize: 13)),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => _dueDate = picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    _dueDate != null
                        ? '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}'
                        : 'Select Due Date',
                    style: TextStyle(color: AppTheme.text),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 2: Questions (Bulk + Manual) ---
  Widget _buildStep2Questions() {
    return Column(
      children: [
        // Mode Selector
        Container(
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _questionInputMode = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _questionInputMode == 0 ? AppTheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Bulk Upload / Quick-Paste',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _questionInputMode == 0 ? Colors.black : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _questionInputMode = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _questionInputMode == 1 ? AppTheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Manual Entry (${_parsedQuestions.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _questionInputMode == 1 ? Colors.black : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: _questionInputMode == 0 ? _buildBulkInputTab() : _buildManualInputTab(),
        ),
      ],
    );
  }

  Widget _buildBulkInputTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Paste questions (Text or JSON)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: _initSampleBulkText,
                  child: Text('Load Sample', style: TextStyle(fontSize: 11, color: AppTheme.primary)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: _parseBulkQuestions,
                  icon: const Icon(Icons.sync, size: 14),
                  label: const Text('Parse & Preview', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          flex: 3,
          child: TextField(
            controller: _bulkTextController,
            maxLines: null,
            expands: true,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: '1. What is...\nA) ...\nB) ...\nC) ...\nD) ...\nAnswer: A',
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.border)),
            ),
            onChanged: (_) => _parseBulkQuestions(),
          ),
        ),
        const SizedBox(height: 8),

        // Status / Preview badge
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _parsedQuestions.isNotEmpty ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.border,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_parsedQuestions.length} valid questions ready',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _parsedQuestions.isNotEmpty ? AppTheme.success : AppTheme.textSecondary,
                ),
              ),
            ),
            if (_parserErrors.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_parserErrors.length} format warning(s)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.error),
                ),
              ),
            ],
          ],
        ),
        if (_parserErrors.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _parserErrors.first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: AppTheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildManualInputTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _qTextController,
            decoration: InputDecoration(
              labelText: 'Question Text',
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _optAController,
            decoration: InputDecoration(
              labelText: 'Option A',
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _optBController,
            decoration: InputDecoration(
              labelText: 'Option B',
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _optCController,
            decoration: InputDecoration(
              labelText: 'Option C',
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _optDController,
            decoration: InputDecoration(
              labelText: 'Option D',
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Text('Correct Answer:', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.text, fontSize: 12)),
              const SizedBox(width: 8),
              ...['A', 'B', 'C', 'D'].map((letter) {
                final isSel = _manualCorrectOption == letter;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(letter),
                    selected: isSel,
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(color: isSel ? Colors.black : AppTheme.text),
                    onSelected: (_) => setState(() => _manualCorrectOption = letter),
                  ),
                );
              }),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                ),
                onPressed: _addManualQuestion,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Question'),
              ),
            ],
          ),
          const Divider(height: 20),

          // List of current questions
          if (_parsedQuestions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('No questions added yet.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _parsedQuestions.length,
              itemBuilder: (context, i) {
                final q = _parsedQuestions[i];
                return Card(
                  color: AppTheme.background,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    title: Text('${i + 1}. ${q.questionText}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    subtitle: Text('Correct: Option ${q.correctOption}', style: TextStyle(color: AppTheme.primary, fontSize: 11)),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: AppTheme.error, size: 18),
                      onPressed: () {
                        setState(() => _parsedQuestions.removeAt(i));
                      },
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // --- STEP 3: Student Selection & Bulk Choosing ---
  Widget _buildStep3Students() {
    if (_loadingStudents) {
      return Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    if (_availableStudents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 12),
              Text(
                'No students found',
                style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                'No students are currently registered in this subject or system.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  setState(() => _loadingStudents = true);
                  _loadStudents();
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reload Students'),
              ),
            ],
          ),
        ),
      );
    }

    // Filter students by section
    final filtered = _activeSectionFilter == 'All Sections'
        ? _availableStudents
        : _availableStudents.where((s) => s['section'] == _activeSectionFilter).toList();

    final allFilteredSelected = filtered.isNotEmpty && filtered.every((s) => _selectedStudentIds.contains(s['id']));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bulk Select Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Checkbox(
                value: allFilteredSelected,
                activeColor: AppTheme.primary,
                checkColor: Colors.black,
                tristate: true,
                onChanged: (val) {
                  setState(() {
                    if (allFilteredSelected) {
                      // Deselect all filtered
                      for (final s in filtered) {
                        _selectedStudentIds.remove(s['id']);
                      }
                    } else {
                      // Select all filtered
                      for (final s in filtered) {
                        _selectedStudentIds.add(s['id']);
                      }
                    }
                  });
                },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select All (${filtered.length} students)',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.text, fontSize: 13),
                    ),
                    Text(
                      '${_selectedStudentIds.length} total selected to receive this quiz',
                      style: TextStyle(fontSize: 11, color: AppTheme.primary),
                    ),
                  ],
                ),
              ),
              // Fast Bulk Action Button
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                onPressed: () {
                  setState(() {
                    if (_selectedStudentIds.length == _availableStudents.length) {
                      _selectedStudentIds.clear();
                    } else {
                      _selectedStudentIds.clear();
                      _selectedStudentIds.addAll(_availableStudents.map((s) => s['id'] as String));
                    }
                  });
                },
                icon: Icon(
                  _selectedStudentIds.length == _availableStudents.length ? Icons.clear_all : Icons.done_all,
                  size: 16,
                ),
                label: Text(
                  _selectedStudentIds.length == _availableStudents.length ? 'Clear All' : 'Select All Students',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Section Filter Chips
        if (_sections.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _sections.map((sec) {
                final isSelected = _activeSectionFilter == sec;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(sec),
                    selected: isSelected,
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => setState(() => _activeSectionFilter = sec),
                  ),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 8),

        // Student checklist
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('No students found in this section.', style: TextStyle(color: AppTheme.textMuted)),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final s = filtered[index];
                    final sid = s['id'] as String;
                    final isChecked = _selectedStudentIds.contains(sid);
                    final name = s['full_name']?.toString() ?? 'Student';
                    final email = s['email']?.toString() ?? '';
                    final sec = s['section']?.toString() ?? 'No Section';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isChecked ? AppTheme.primary.withValues(alpha: 0.4) : AppTheme.border,
                        ),
                      ),
                      child: Material(
                        color: isChecked ? AppTheme.primary.withValues(alpha: 0.08) : AppTheme.background,
                        borderRadius: BorderRadius.circular(8),
                        child: CheckboxListTile(
                          value: isChecked,
                          activeColor: AppTheme.primary,
                          checkColor: Colors.black,
                          dense: true,
                        title: Text(
                          name,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.text),
                        ),
                        subtitle: Text(
                          '$email · Section: $sec',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        secondary: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'S',
                            style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        onChanged: (bool? val) {
                          setState(() {
                            if (val == true) {
                              _selectedStudentIds.add(sid);
                            } else {
                              _selectedStudentIds.remove(sid);
                            }
                          });
                        },
                      ),
                    ),
                  );
                },
                ),
        ),
      ],
    );
  }
}
