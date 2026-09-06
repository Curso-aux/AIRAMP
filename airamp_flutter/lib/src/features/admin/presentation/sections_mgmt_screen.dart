import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SectionsMgmtScreen extends StatefulWidget {
  const SectionsMgmtScreen({super.key});

  @override
  State<SectionsMgmtScreen> createState() => _SectionsMgmtScreenState();
}

class _SectionsMgmtScreenState extends State<SectionsMgmtScreen> {
  bool _showForm = false;
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedGrade = '';

  final List<String> _grades = [
    'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10',
    'Grade 11', 'Grade 12',
  ];

  // Mock existing sections
  final List<Map<String, dynamic>> _sections = [
    {
      'name': 'Grade 11 - STEM B',
      'description': 'STEM Strand Section B - Admin 2',
      'grade': 'Grade 11',
      'studentCount': 1,
    },
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manage Sections',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_sections.length} active sections',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                  FloatingActionButton.small(
                    onPressed: () {
                      setState(() => _showForm = !_showForm);
                    },
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Icon(_showForm ? Icons.close : Icons.add, color: Colors.black),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Add New Section Form
              if (_showForm) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add New Section',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: AppTheme.text),
                        decoration: const InputDecoration(
                          hintText: 'Section Name (e.g., Grade 12 - ICT A)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descController,
                        style: const TextStyle(color: AppTheme.text),
                        decoration: const InputDecoration(
                          hintText: 'Description (optional)',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Assign Grade Level',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _grades.map((grade) {
                          final isSelected = _selectedGrade == grade;
                          return ChoiceChip(
                            label: Text(grade),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() => _selectedGrade = selected ? grade : '');
                            },
                            selectedColor: Theme.of(context).colorScheme.primary,
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.black : AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _showForm = false;
                                  _nameController.clear();
                                  _descController.clear();
                                  _selectedGrade = '';
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                side: BorderSide(color: Theme.of(context).dividerColor),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (_nameController.text.isNotEmpty) {
                                  setState(() {
                                    _sections.add({
                                      'name': _nameController.text,
                                      'description': _descController.text,
                                      'grade': _selectedGrade,
                                      'studentCount': 0,
                                    });
                                    _showForm = false;
                                    _nameController.clear();
                                    _descController.clear();
                                    _selectedGrade = '';
                                  });
                                }
                              },
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Section Cards
              ..._sections.map((section) => _SectionCard(
                section: section,
                onDelete: () => setState(() => _sections.remove(section)),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatefulWidget {
  final Map<String, dynamic> section;
  final VoidCallback onDelete;

  const _SectionCard({required this.section, required this.onDelete});

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _isExpanded = false;
  int _selectedTab = 0; // 0 for Students, 1 for Progress Chart
  String _selectedSubject = 'VGD-NC-III';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.section['name'],
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                    ),
                    if (widget.section['description'] != null && widget.section['description'].toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.section['description'],
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.school_outlined, size: 14, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          widget.section['grade'] ?? 'No grade',
                          style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.people_outline, size: 14, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.section['studentCount']} students',
                          style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primarySoft,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: widget.onDelete,
                    icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.errorSoft,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), size: 20),
                  ),
                ],
              ),
            ],
          ),
          
          if (_isExpanded) ...[
            const SizedBox(height: 16),
            // Tabs
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 16, color: _selectedTab == 0 ? Colors.black : AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Text('Students', style: TextStyle(
                              color: _selectedTab == 0 ? Colors.black : AppTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bar_chart, size: 16, color: _selectedTab == 1 ? Colors.black : AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Text('Progress Chart', style: TextStyle(
                              color: _selectedTab == 1 ? Colors.black : AppTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            if (_selectedTab == 0) _buildStudentsList() else _buildProgressChart(),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentsList() {
    return Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF63B3ED), // Light blue
              child: const Text('M', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Maria Lopez', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  const Text('@Maria Lopez · maria@student.com · Grade 11', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {},
                  icon: Icon(Icons.visibility_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
                  style: IconButton.styleFrom(backgroundColor: AppTheme.background, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.vpn_key_outlined, size: 16, color: Colors.amber),
                  style: IconButton.styleFrom(backgroundColor: AppTheme.background, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () {},
                  icon: Icon(Icons.archive_outlined, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                  style: IconButton.styleFrom(backgroundColor: AppTheme.background, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () {},
                  icon: Icon(Icons.delete_outline, size: 16, color: Theme.of(context).colorScheme.error),
                  style: IconButton.styleFrom(backgroundColor: AppTheme.background, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(color: AppTheme.border, height: 1),
      ],
    );
  }

  Widget _buildProgressChart() {
    final subjects = ['VGD-NC-III', 'M1', 'E1'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: subjects.map((sub) {
              final isSelected = _selectedSubject == sub;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(sub),
                  selected: isSelected,
                  onSelected: (val) => setState(() => _selectedSubject = sub),
                  selectedColor: Theme.of(context).colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.background),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppTheme.background),
              dataRowMinHeight: 40,
              dataRowMaxHeight: 40,
              columnSpacing: 24,
              horizontalMargin: 16,
              headingTextStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
              columns: const [
                DataColumn(label: Text('Student')),
                DataColumn(label: Text('LO1')),
                DataColumn(label: Text('LO2')),
                DataColumn(label: Text('LO3')),
                DataColumn(label: Text('LO4')),
                DataColumn(label: Text('LO5')),
              ],
              rows: [
                DataRow(cells: [
                  const DataCell(Text('Maria Lopez', style: TextStyle(color: AppTheme.text, fontSize: 12, fontWeight: FontWeight.bold))),
                  DataCell(_buildCheckbox(true)),
                  DataCell(_buildCheckbox(true)),
                  DataCell(_buildCheckbox(false)),
                  DataCell(_buildCheckbox(false)),
                  DataCell(_buildCheckbox(false)),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Sequential: Check marks require admin validation',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckbox(bool isChecked) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: isChecked ? AppTheme.primary : Colors.transparent,
        border: Border.all(color: isChecked ? AppTheme.primary : AppTheme.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: isChecked ? const Icon(Icons.check, size: 14, color: Colors.black) : null,
    );
  }
}
