import 'package:flutter/material.dart';

ThemeData responsiveThemeForWidth(ThemeData theme, double width) {
  if (width >= 420) return theme;

  final veryCompact = width < 360;
  final textTheme = theme.textTheme.copyWith(
    displayMedium: theme.textTheme.displayMedium?.copyWith(
      fontSize: veryCompact ? 32 : 36,
      height: veryCompact ? 1.02 : 0.98,
    ),
    headlineMedium: theme.textTheme.headlineMedium?.copyWith(
      fontSize: veryCompact ? 28 : 30,
    ),
    headlineSmall: theme.textTheme.headlineSmall?.copyWith(
      fontSize: veryCompact ? 22 : 23,
    ),
    titleLarge: theme.textTheme.titleLarge?.copyWith(
      fontSize: veryCompact ? 18 : 19,
    ),
    titleMedium: theme.textTheme.titleMedium?.copyWith(
      fontSize: veryCompact ? 15 : 16,
    ),
    labelLarge: theme.textTheme.labelLarge?.copyWith(
      fontSize: veryCompact ? 14 : 15,
    ),
    labelMedium: theme.textTheme.labelMedium?.copyWith(
      fontSize: veryCompact ? 12 : 13,
    ),
  );

  return theme.copyWith(textTheme: textTheme);
}

double responsiveHorizontalPadding(double width) {
  if (width >= 1200) return 40;
  if (width >= 900) return 32;
  if (width >= 600) return 28;
  return 16;
}

double responsiveContentMaxWidth(double width) {
  final availableWidth = width - (responsiveHorizontalPadding(width) * 2);
  final safeAvailableWidth = availableWidth > 0 ? availableWidth : width;
  final targetWidth = switch (width) {
    >= 1280 => 1180.0,
    >= 900 => 1040.0,
    >= 700 => 760.0,
    _ => width,
  };

  return targetWidth > safeAvailableWidth ? safeAvailableWidth : targetWidth;
}

bool isCompactWidth(double width) => width < 420;

bool isVeryCompactWidth(double width) => width < 360;

bool isWideContentWidth(double width) => width >= 900;

double responsiveChipMaxWidth(double width) {
  if (width < 360) return width * 0.86;
  if (width < 420) return width * 0.88;
  if (width < 700) return 320;
  return 420;
}

TextStyle? responsiveDisplayStyle(BuildContext context) {
  return Theme.of(context).textTheme.displayMedium;
}

TextStyle? responsiveHeadlineStyle(
  BuildContext context, {
  Color? color,
  double? height,
}) {
  final base = Theme.of(context).textTheme.headlineMedium;

  return base?.copyWith(
    color: color,
    height: height,
  );
}
