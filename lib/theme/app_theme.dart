import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized Design Token system for DhikrFlow.
/// All colors, spacing, typography and decoration constants live here.
class AppColors {
  AppColors._();

  // Background
  static const Color darkBackground = Color(0xFF0A0E1A);
  static const Color cardBackground = Color(0x1AFFFFFF); // 10% white glass
  static const Color cardBorder = Color(0x33FFFFFF); // 20% white

  // Accent / Brand
  static const Color emerald = Color(0xFF2ECC71);
  static const Color gold = Color(0xFFF1C40F);
  static const Color teal = Color(0xFF1ABC9C);
  static const Color indigo = Color(0xFF3498DB);
  static const Color violet = Color(0xFF9B59B6);
  static const Color rose = Color(0xFFE74C3C);

  // Text
  static const Color textPrimary = Color(0xFFF0F4FF);
  static const Color textSecondary = Color(0xFFAAB4CC);
  static const Color textMuted = Color(0xFF5C6A88);

  // Ring
  static const Color ringBackground = Color(0x22FFFFFF);
  static const Color ringFill = Color(0xFF2ECC71);

  // Gradients per dhikr card
  static const List<List<Color>> cardGradients = [
    [Color(0xFF11998E), Color(0xFF38EF7D)], // SubhanAllah – teal-green
    [Color(0xFF1A1A2E), Color(0xFF16213E)], // placeholder
    [Color(0xFFF7971E), Color(0xFFFFD200)], // Alhamdulillah – amber
    [Color(0xFF8E2DE2), Color(0xFF4A00E0)], // Allahu Akbar – violet
    [Color(0xFFCC2B5E), Color(0xFF753A88)], // Astaghfirullah – rose-purple
    [Color(0xFF2193B0), Color(0xFF6DD5ED)], // Custom – sky blue
  ];
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

class AppRadius {
  AppRadius._();
  static const double sm = 12.0;
  static const double md = 20.0;
  static const double lg = 28.0;
  static const double full = 999.0;
}

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.emerald,
        secondary: AppColors.gold,
        surface: AppColors.darkBackground,
      ),
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      useMaterial3: true,
    );
  }
}
