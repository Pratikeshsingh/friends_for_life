import 'package:flutter/material.dart';

class OptionPickerSheet extends StatefulWidget {
  const OptionPickerSheet({
    super.key,
    required this.title,
    required this.currentValue,
    required this.options,
    this.searchHintText,
    this.supportingText,
    this.emptyStateTitle,
    this.emptyStateBody,
  });

  final String title;
  final String? currentValue;
  final List<String> options;
  final String? searchHintText;
  final String? supportingText;
  final String? emptyStateTitle;
  final String? emptyStateBody;

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
    final size = MediaQuery.sizeOf(context);
    final horizontalPadding = size.width < 380 ? 16.0 : 20.0;
    final maxHeight = size.height * 0.76;
    final filteredOptions = widget.searchHintText == null
        ? widget.options
        : widget.options.where((option) {
            final lowerQuery = _query.trim().toLowerCase();
            if (lowerQuery.isEmpty) return true;
            return option.toLowerCase().contains(lowerQuery);
          }).toList();

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFBF8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            18,
            horizontalPadding,
            28,
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: theme.textTheme.headlineSmall),
                  if (widget.supportingText != null &&
                      widget.supportingText!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.supportingText!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF60727A),
                        height: 1.35,
                      ),
                    ),
                  ],
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.emptyStateTitle ?? 'No matches yet.',
                                  style: theme.textTheme.titleSmall,
                                  textAlign: TextAlign.center,
                                ),
                                if (widget.emptyStateBody != null &&
                                    widget.emptyStateBody!
                                        .trim()
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.emptyStateBody!,
                                    style: theme.textTheme.bodyMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filteredOptions.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final option = filteredOptions[index];
                              final selected = widget.currentValue == option;

                              return Material(
                                color: Colors.transparent,
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  minVerticalPadding: 12,
                                  title: Text(option),
                                  trailing: selected
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: Color(0xFF138B8A),
                                        )
                                      : const Icon(
                                          Icons.circle_outlined,
                                          color: Color(0xFF9AABA9),
                                        ),
                                  onTap: () =>
                                      Navigator.of(context).pop(option),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
