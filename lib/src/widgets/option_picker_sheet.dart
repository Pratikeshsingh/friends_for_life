import 'package:flutter/material.dart';

class OptionPickerSheet extends StatefulWidget {
  const OptionPickerSheet({
    super.key,
    required this.title,
    required this.currentValue,
    required this.options,
    this.searchHintText,
  });

  final String title;
  final String? currentValue;
  final List<String> options;
  final String? searchHintText;

  @override
  State<OptionPickerSheet> createState() => _OptionPickerSheetState();
}

class _OptionPickerSheetState extends State<OptionPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    final filteredOptions = widget.searchHintText == null
        ? widget.options
        : widget.options.where((option) {
            final lowerQuery = _query.trim().toLowerCase();
            if (lowerQuery.isEmpty) return true;
            return option.toLowerCase().contains(lowerQuery);
          }).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFBF8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: theme.textTheme.headlineSmall),
              if (widget.searchHintText != null) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: widget.searchHintText,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Flexible(
                child: filteredOptions.isEmpty
                    ? Center(
                        child: Text(
                          'No matches yet.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredOptions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final option = filteredOptions[index];
                          final selected = widget.currentValue == option;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(option),
                            trailing: selected
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF138B8A),
                                  )
                                : const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.of(context).pop(option),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
