import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium dark theme for Smart Ranch
class AppTheme {
  // --- Brand Colors ---
  static const Color primary = Color(0xFF00C853); // Vibrant green
  static const Color primaryDark = Color(0xFF009624);
  static const Color secondary = Color(0xFFFF6D00); // Warm orange (alerts)
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceVariant = Color(0xFF16213E);
  static const Color card = Color(0xFF1E2A47);
  static const Color cardBright = Color(0xFF243356);
  static const Color background = Color(0xFF0F0F1E);
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFF9BA4B8);
  static const Color divider = Color(0xFF2A3555);

  // --- THI Level Colors ---
  static const Color thiNormal = Color(0xFF00C853);
  static const Color thiAlert = Color(0xFFFFD600);
  static const Color thiDanger = Color(0xFFFF6D00);
  static const Color thiEmergency = Color(0xFFFF1744);

  static Color thiColor(String level) => switch (level) {
    'normal' => thiNormal,
    'alert' => thiAlert,
    'danger' => thiDanger,
    'emergency' => thiEmergency,
    _ => textSecondary,
  };

  static String thiLabel(String level) => switch (level) {
    'normal' => 'Normal',
    'alert' => 'Alerta',
    'danger' => 'Peligro',
    'emergency' => 'Emergencia',
    _ => 'Desconocido',
  };

  static IconData thiIcon(String level) => switch (level) {
    'normal' => Icons.check_circle_rounded,
    'alert' => Icons.warning_amber_rounded,
    'danger' => Icons.local_fire_department_rounded,
    'emergency' => Icons.crisis_alert_rounded,
    _ => Icons.help_outline_rounded,
  };

  // --- Theme Data ---
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
          .copyWith(
            headlineLarge: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
            headlineMedium: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
            titleLarge: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
            titleMedium: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
            bodyLarge: GoogleFonts.inter(fontSize: 16, color: textPrimary),
            bodyMedium: GoogleFonts.inter(fontSize: 14, color: textSecondary),
            labelLarge: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
    );
  }
}
