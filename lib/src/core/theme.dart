import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

ThemeData buildTheme() {
  const canvas = Color(0xFFF8F5EF);
  const surface = Color(0xFFFFFCF7);
  const ink = Color(0xFF08294A);
  const muted = Color(0xFF66727C);
  const primary = Color(0xFF062B55);
  const primarySoft = Color(0xFFE7F4F2);
  const outline = Color(0xFFDDE7E3);
  const success = Color(0xFF36B8A5);
  // Field errors are small text, so this is the readable red used for
  // destructive actions (about 6:1 on white).
  const danger = Color(0xFFB33A3A);

  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: canvas,
    splashFactory: InkRipple.splashFactory,
    fontFamily: 'Manrope',
    textTheme: ThemeData.light().textTheme.apply(
          bodyColor: ink,
          displayColor: ink,
          fontFamily: 'Manrope',
        ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      secondary: const Color(0xFFFF7759),
      onSecondary: Colors.white,
      surface: surface,
      onSurface: ink,
      outline: outline,
      error: danger,
      onError: Colors.white,
    ),
  );

  return base.copyWith(
    textTheme: _buildTextTheme(base.textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: ink,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: surface,
      shadowColor: const Color(0x140B0401),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: outline),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      color: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primarySoft;
        }
        return surface;
      }),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: outline),
        borderRadius: BorderRadius.circular(18),
      ),
      labelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w700),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFFFCF7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: const TextStyle(
        color: muted,
        fontWeight: FontWeight.w700,
      ),
      border: OutlineInputBorder(
        borderSide: const BorderSide(color: outline),
        borderRadius: BorderRadius.circular(16),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: outline),
        borderRadius: BorderRadius.circular(16),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: primary, width: 1.4),
        borderRadius: BorderRadius.circular(16),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: danger),
        borderRadius: BorderRadius.circular(16),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: danger, width: 1.4),
        borderRadius: BorderRadius.circular(16),
      ),
      hintStyle: const TextStyle(color: muted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFE1E8E5),
        disabledForegroundColor: muted.withValues(alpha: 0.72),
        shadowColor: Colors.transparent,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: const BorderSide(color: outline),
        backgroundColor: surface,
        disabledForegroundColor: muted.withValues(alpha: 0.7),
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        // Darker than the brand teal so small link text stays readable.
        foregroundColor: const Color(0xFF0D6E6D),
        disabledForegroundColor: muted.withValues(alpha: 0.64),
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: primary,
        disabledForegroundColor: muted.withValues(alpha: 0.62),
        minimumSize: const Size(44, 44),
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        focusColor: primarySoft,
        hoverColor: primarySoft.withValues(alpha: 0.72),
        highlightColor: primarySoft.withValues(alpha: 0.88),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: primarySoft,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          fontFamily: 'Manrope',
          fontSize: 12,
          height: 1.15,
          color: states.contains(WidgetState.selected) ? ink : muted,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w600,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected) ? ink : muted,
        );
      }),
      elevation: 0,
      shadowColor: Colors.transparent,
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    dividerColor: outline,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF062B55),
      contentTextStyle: const TextStyle(
        fontFamily: 'Manrope',
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      behavior: SnackBarBehavior.fixed,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
      ),
    ),
    extensions: const [AppColors(success: success)],
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}

TextTheme _buildTextTheme(TextTheme base) {
  return base.copyWith(
    displayLarge: _editorialSerif(
      fontSize: 54,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF08294A),
      letterSpacing: 0,
      height: 1.02,
    ),
    displayMedium: _editorialSerif(
      fontSize: 40,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF08294A),
      letterSpacing: 0,
      height: 1.04,
    ),
    headlineMedium: _editorialSerif(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF08294A),
      letterSpacing: 0,
      height: 1.08,
    ),
    headlineSmall: _editorialSerif(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF08294A),
      letterSpacing: 0,
      height: 1.1,
    ),
    titleLarge: _cleanSans(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF08294A),
    ),
    titleMedium: _cleanSans(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF08294A),
    ),
    titleSmall: _cleanSans(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF08294A),
    ),
    bodyLarge: _cleanSans(
      fontSize: 16,
      height: 1.55,
      color: const Color(0xFF08294A),
    ),
    bodyMedium: _cleanSans(
      fontSize: 14,
      height: 1.55,
      color: const Color(0xFF66727C),
    ),
    labelLarge: _cleanSans(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
    ),
    labelMedium: _cleanSans(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    ),
  );
}

TextStyle _cleanSans({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: 'Manrope',
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

TextStyle _editorialSerif({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: 'Newsreader',
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({required this.success});

  final Color success;

  @override
  ThemeExtension<AppColors> copyWith({Color? success}) {
    return AppColors(success: success ?? this.success);
  }

  @override
  ThemeExtension<AppColors> lerp(
      covariant ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(success: Color.lerp(success, other.success, t) ?? success);
  }
}
