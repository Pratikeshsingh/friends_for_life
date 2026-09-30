import 'package:flutter/material.dart' hide Text;
import '../core/i18n.dart';

class SelectionField extends StatelessWidget {
  const SelectionField({
    super.key,
    required this.icon,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.label,
  });

  final IconData icon;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value != null && value!.trim().isNotEmpty;
    final displayValue = hasValue ? value! : placeholder;

    return Semantics(
      button: true,
      label: label == null ? displayValue : '$label, $displayValue',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDDE7E3)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 24),
            child: Row(
              children: [
                Icon(icon),
                const SizedBox(width: 12),
                Expanded(
                  child: label == null
                      ? Text(
                          displayValue,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: hasValue ? null : const Color(0xFF66727C),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label!,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: const Color(0xFF60727A),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              displayValue,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: hasValue
                                    ? const Color(0xFF062B55)
                                    : const Color(0xFF66727C),
                                fontWeight: hasValue ? FontWeight.w700 : null,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
