import 'package:flutter/material.dart';

ThemeData buildTheme() {
  const canvas = Color(0xFFF7F1EA);
  const surface = Colors.white;
  const ink = Color(0xFF1C1A19);
  const muted = Color(0xFF6E655F);
  const primary = Color(0xFF9C6B4F);
  const accent = Color(0xFFD7B8A2);
  const success = Color(0xFF2F6B57);

  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: canvas,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
      surface: surface,
      onPrimary: Colors.white,
      onSecondary: ink,
      onSurface: ink,
      brightness: Brightness.light,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: ink),
      displayMedium: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: ink),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: ink),
      headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ink),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ink),
      bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: ink),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: muted),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: ink,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    chipTheme: base.chipTheme.copyWith(
      color: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return accent;
        }
        return Colors.white;
      }),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE9DED4)),
        borderRadius: BorderRadius.circular(24),
      ),
      labelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(22),
      ),
      hintStyle: const TextStyle(color: muted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: ink,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: const BorderSide(color: Color(0xFFDBCEC2)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: ink,
      unselectedItemColor: muted,
      elevation: 0,
      showUnselectedLabels: true,
    ),
    extensions: const [AppColors(success: success)],
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
  ThemeExtension<AppColors> lerp(covariant ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(success: Color.lerp(success, other.success, t) ?? success);
  }
}
