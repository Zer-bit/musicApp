import 'package:flutter/material.dart';

class AppColors {
  // Primary Theme Accent Color: Deep raspberry/muted rose (#854F6C)
  static const Color purple = Color(0xFF854F6C); 
  static const Color purpleLight = Color(0xFFAC7693);
  static const Color purpleDark = Color(0xFF5E2B49);

  // Secondary/Accent Color: Complimenting rose-gold shade
  static const Color blue = Color(0xFFAC7693);
  static const Color blueLight = Color(0xFFD6B2C6);
  static const Color blueDark = Color(0xFF854F6C);

  // Accent Colors
  static const Color accent = Color(0xFF854F6C); 
  static const Color accentPink = Color(0xFFD6B2C6);

  // Backgrounds (Dark Mode Default)
  static const Color background = Color(0xFF191919); // Matte Dark Grey (#191919)
  static const Color surface = Color(0xFF242424);    // Slate Card (#242424)
  static const Color surfaceLight = Color(0xFF2E2E2E);

  // Flat Color Gradients for compatibility (returns solid color values)
  static LinearGradient get purpleBlueGradient => const LinearGradient(
        colors: [Color(0xFF854F6C), Color(0xFFAC7693)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get bluePurpleGradient => const LinearGradient(
        colors: [Color(0xFFAC7693), Color(0xFF854F6C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get lightGradient => const LinearGradient(
        colors: [Color(0xFFD6B2C6), Color(0xFFAC7693)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get darkGradient => const LinearGradient(
        colors: [Color(0xFF5E2B49), Color(0xFF854F6C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get accentGradient => const LinearGradient(
        colors: [Color(0xFF854F6C), Color(0xFF854F6C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
