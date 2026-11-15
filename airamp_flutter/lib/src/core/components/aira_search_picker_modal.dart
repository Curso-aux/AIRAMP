import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AiraSearchPickerItem<T> {
  final T value;
  final String title;
  final String? subtitle;
  final String? badge;
  final Color? badgeColor;
  final Widget? leading;
  final List<String> searchKeywords;

  const AiraSearchPickerItem({
    required this.value,
    required this.title,
    this.subtitle,
    this.badge,
    this.badgeColor,
    this.leading,
    this.searchKeywords = const [],
  });

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase().trim();
    if (title.toLowerCase().contains(q)) return true;
    if (subtitle != null && subtitle!.toLowerCase().contains(q)) return true;
    if (badge != null && badge!.toLowerCase().contains(q)) return true;
    for (final kw in searchKeywords) {
      if (kw.toLowerCase().contains(q)) return true;
    }
    return false;
  }
}

class AiraSearchPickerModal<T> extends StatefulWidget {
  final String title;
  final String searchHint;
  final List<AiraSearchPickerItem<T>> items;
  final T? selectedValue;
  final String? emptyMessage;

  const AiraSearchPickerModal({
    super.key,
    required this.title,
    required this.searchHint,
    required this.items,
    this.selectedValue,
    this.emptyMessage,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required String searchHint,
    required List<AiraSearchPickerItem<T>> items,
    T? selectedValue,
    String? emptyMessage,
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    if (isDesktop) {
      return showDialog<T>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 580),
            child: AiraSearchPickerModal<T>(
              title: title,
              searchHint: searchHint,
              items: items,
              selectedValue: selectedValue,
              emptyMessage: emptyMessage,
            ),
          ),
        ),
      );
    } else {
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: AiraSearchPickerModal<T>(
            title: title,
            searchHint: searchHint,
            items: items,
            selectedValue: selectedValue,
            emptyMessage: emptyMessage,
          ),
        ),
      );
    }
  }

  @override
  State<AiraSearchPickerModal<T>> createState() => _AiraSearchPickerModalState<T>();
}

class _AiraSearchPickerModalState<T> extends State<AiraSearchPickerModal<T>> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = widget.items.where((i) => i.matches(_query)).toList();

    return Column(
      children: [
        // Top Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: AppTheme.textMuted, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AppTheme.border),

        // Search Input Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            style: TextStyle(color: AppTheme.text, fontSize: 14),
            decoration: InputDecoration(
              hintText: widget.searchHint,
              hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primary, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, size: 18, color: AppTheme.textMuted),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            ),
            onChanged: (val) => setState(() => _query = val),
          ),
        ),

        // Filtered Item Count / Subtitle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              Text(
                'Available (${filteredItems.length})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // List View
        Expanded(
          child: filteredItems.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 44, color: AppTheme.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          _query.isNotEmpty
                              ? 'No matches for "$_query"'
                              : (widget.emptyMessage ?? 'No options available'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.text,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_query.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Try checking spelling or using broader keywords.',
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    final isSelected = widget.selectedValue == item.value;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppTheme.primary.withValues(alpha: 0.35) : AppTheme.border.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Material(
                        color: isSelected ? AppTheme.primary.withValues(alpha: 0.08) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          leading: item.leading,
                          title: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? AppTheme.primary : AppTheme.text,
                            ),
                          ),
                          subtitle: item.subtitle != null
                              ? Text(
                                  item.subtitle!,
                                  style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.badge != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (item.badgeColor ?? AppTheme.primary).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.badge!,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: item.badgeColor ?? AppTheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (isSelected)
                                Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20)
                              else
                                Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted.withValues(alpha: 0.5), size: 18),
                            ],
                          ),
                          onTap: () => Navigator.of(context).pop(item.value),
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
