import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Theme for Smart Ranch (Supports Light and Dark Mode)
class AppTheme {
  // --- Global Theme State ---
  static bool isDark = true;

  // --- Brand Colors ---
  static const Color primary = Color(0xFF2596BE); // Blue accent
  static const Color primaryDark = Color(0xFF1E7A9B);
  static const Color secondary = Color(0xFFFF6D00); // Warm orange (alerts)

  static Color get surface => isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
  static Color get surfaceVariant => isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3F4F6);
  static Color get card => isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);
  static Color get cardBright => isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0FDF4);
  static Color get background => isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  
  static Color get textPrimary => isDark ? const Color(0xFFF0F0F5) : const Color(0xFF111827);
  static Color get textSecondary => isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  static Color get divider => isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB);

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
    return _buildTheme(Brightness.dark);
  }
  
  static ThemeData get lightTheme {
    return _buildTheme(Brightness.light);
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isDarkTheme = brightness == Brightness.dark;
    final bg = isDarkTheme ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final surf = isDarkTheme ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final txt = isDarkTheme ? const Color(0xFFF0F0F5) : const Color(0xFF111827);
    final txtSec = isDarkTheme ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cardCol = isDarkTheme ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        primary: primary,
        secondary: secondary,
        surface: surf,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: txt,
      ),
      textTheme: GoogleFonts.interTextTheme(
        isDarkTheme ? ThemeData.dark().textTheme : ThemeData.light().textTheme
      ).copyWith(
            headlineLarge: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: txt,
            ),
            headlineMedium: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: txt,
            ),
            titleLarge: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: txt,
            ),
            titleMedium: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: txtSec,
            ),
            bodyLarge: GoogleFonts.inter(fontSize: 16, color: txt),
            bodyMedium: GoogleFonts.inter(fontSize: 14, color: txtSec),
            labelLarge: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: txt,
            ),
          ),
      cardTheme: CardThemeData(
        color: cardCol,
        elevation: isDarkTheme ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isDarkTheme ? BorderSide.none : const BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surf,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: txt),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: txt,
        ),
      ),
    );
  }
}
