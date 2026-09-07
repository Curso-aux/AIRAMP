import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';

class RegLinksScreen extends ConsumerStatefulWidget {
  const RegLinksScreen({super.key});

  @override
  ConsumerState<RegLinksScreen> createState() => _RegLinksScreenState();
}

class _RegLinksScreenState extends ConsumerState<RegLinksScreen> {
  final _expirationController = TextEditingController();
  final _maxUsesController = TextEditingController(text: '1');
  final List<Map<String, dynamic>> _links = [];

  @override
  void dispose() {
    _expirationController.dispose();
    _maxUsesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Student Access',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Create student registration links for your organization.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 20),

              // Info Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Registration links are scoped to your organization and never expose another Admin\'s students.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Expiration and Max Uses Row
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expiration',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _expirationController,
                          style: TextStyle(color: AppTheme.text),
                          decoration: InputDecoration(
                            hintText: 'YYYY-MM-DD (optional)',
                            prefixIcon: Icon(
                              Icons.calendar_today,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                              size: 18,
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Max uses',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _maxUsesController,
                          style: TextStyle(color: AppTheme.text),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Generate Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final code = 'AIRA-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                    setState(() {
                      _links.add({
                        'code': code,
                        'maxUses': int.tryParse(_maxUsesController.text) ?? 1,
                        'usedCount': 0,
                        'expiration': _expirationController.text.isNotEmpty
                            ? _expirationController.text
                            : null,
                        'createdAt': '${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}',
                        'isActive': true,
                      });
                    });
                    _showGeneratedCodeModal(code);
                  },
                  icon: const Icon(Icons.add, color: Colors.black),
                  label: const Text('Generate Student Link'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Your Student Links Section
              Text(
                'Your student links',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),

              if (_links.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.vpn_key_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4).withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No student links yet',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._links.map((link) => _buildLinkCard(link)),
            ],
          ),
        ),
      ),
    );
  }

  void _showGeneratedCodeModal(String code) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text('Link Generated Successfully', style: TextStyle(color: AppTheme.text)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Here is your new student registration code:', style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      code,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code copied!'), duration: Duration(seconds: 1)),
                );
                Navigator.pop(context);
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy Code'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLinkCard(Map<String, dynamic> link) {
    final createdDate = link['createdAt'] ?? '9/7/2026';
    final expires = link['expiration'] ?? 'Never';
    final uses = '${link['usedCount']} / ${link['maxUses']}';
    final bool isActive = link['isActive'] ?? true;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    link['code'],
                    style: TextStyle(
                      color: AppTheme.text,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.content_copy, color: Theme.of(context).colorScheme.primary, size: 18),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied!'), duration: Duration(seconds: 1)));
                    },
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.primarySoft.withValues(alpha: 0.2) : Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(isActive ? 'Active' : 'Inactive', style: TextStyle(color: isActive ? AppTheme.primary : Theme.of(context).colorScheme.error, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Created', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(createdDate, style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Expires', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(expires, style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Uses', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(uses, style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(width: 24), // Spacing for alignment
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (isActive)
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Share'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      backgroundColor: AppTheme.primarySoft.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              if (isActive) const SizedBox(width: 12),
              if (isActive)
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => setState(() => link['isActive'] = false),
                    icon: const Icon(Icons.block, size: 18),
                    label: const Text('Deactivate'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange,
                      backgroundColor: Colors.orange.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              if (!isActive)
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _links.remove(link)),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete permanently'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      backgroundColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
