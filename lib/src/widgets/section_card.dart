import 'package:flutter/material.dart';

import '../core/responsive.dart';
import 'motion.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.highlight = false,
    this.backgroundColor,
    this.borderColor,
    this.motionIndex = 0,
    this.enableReveal = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool highlight;
  final Color? backgroundColor;
  final Color? borderColor;
  final int motionIndex;
  final bool enableReveal;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final effectivePadding =
        isCompactWidth(width) && padding == const EdgeInsets.all(22)
            ? const EdgeInsets.all(18)
            : padding;
    final resolvedBackgroundColor = backgroundColor ??
        (highlight ? const Color(0xFFEAF7F5) : const Color(0xFFFFFCF7));
    final resolvedBorderColor = borderColor ??
        (highlight ? const Color(0xFFB9E3DC) : const Color(0xFFDDE7E3));

    final content = MotionPressable(
      child: Card(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: resolvedBackgroundColor,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10062B55),
                blurRadius: 22,
                offset: Offset(0, 8),
              ),
            ],
            border: Border.all(color: resolvedBorderColor),
          ),
          child: Padding(
            padding: effectivePadding,
            child: child,
          ),
        ),
      ),
    );

    if (!enableReveal) {
      return content;
    }

    return MotionReveal(
      index: motionIndex,
      child: content,
    );
  }
}
