import 'package:flutter/material.dart';

class EditorialSectionHeader extends StatelessWidget {
  const EditorialSectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.body,
  });

  final String eyebrow;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasEyebrow = eyebrow.trim().isNotEmpty;
    final hasTitle = title.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasEyebrow) ...[
          Text(
            eyebrow.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: const Color(0xFF138B8A),
              letterSpacing: 0,
            ),
          ),
          if (hasTitle) const SizedBox(height: 8),
        ],
        if (hasTitle) Text(title, style: theme.textTheme.headlineSmall),
        if (body != null && body!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(body!, style: theme.textTheme.bodyLarge),
        ],
      ],
    );
  }
}

class EditorialFeatureTile extends StatelessWidget {
  const EditorialFeatureTile({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.backgroundColor = const Color(0xFFFFFCF7),
    this.borderColor = const Color(0xFFDDE7E3),
    this.iconBackgroundColor = const Color(0xFFE7F4F2),
    this.iconColor = const Color(0xFF138B8A),
  });

  final IconData icon;
  final String title;
  final String body;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconBackgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBackgroundColor,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 14),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class EditorialMetricTile extends StatelessWidget {
  const EditorialMetricTile({
    super.key,
    required this.value,
    required this.label,
    required this.detail,
    this.backgroundColor = const Color(0xFFEAF7F5),
    this.borderColor = const Color(0xFFDDE7E3),
  });

  final String value;
  final String label;
  final String detail;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(height: 1),
          ),
          const SizedBox(height: 8),
          Text(label, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(detail, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class EditorialTimelineStep extends StatelessWidget {
  const EditorialTimelineStep({
    super.key,
    required this.step,
    required this.title,
    required this.body,
    this.icon,
  });

  final int step;
  final String title;
  final String body;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF062B55),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: icon != null
              ? Icon(icon, color: const Color(0xFFEAF7F5), size: 18)
              : Text(
                  '$step',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(body, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class EditorialFaqTile extends StatelessWidget {
  const EditorialFaqTile({
    super.key,
    required this.question,
    required this.answer,
    this.icon = Icons.help_outline_rounded,
  });

  final String question;
  final String answer;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDE7E3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F4F2),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: const Color(0xFF138B8A), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(question, style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(answer, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EditorialResponsiveWrap extends StatelessWidget {
  const EditorialResponsiveWrap({
    super.key,
    required this.children,
    this.minChildWidth = 240,
    this.maxColumns = 3,
    this.spacing = 12,
    this.runSpacing = 12,
  });

  final List<Widget> children;
  final double minChildWidth;
  final int maxColumns;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        var columns = (width / minChildWidth).floor();
        if (columns < 1) columns = 1;
        if (columns > maxColumns) columns = maxColumns;

        final itemWidth = columns == 1
            ? width
            : (width - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(
                width: itemWidth,
                child: child,
              ),
          ],
        );
      },
    );
  }
}
