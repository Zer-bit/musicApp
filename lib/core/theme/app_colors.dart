import 'package:flutter/material.dart';

class AppColors {
  // Purple shades
  static const Color purple = Color(0xFF9C27B0); // Deep Purple
  static const Color purpleLight = Color(0xFFBA68C8); // Light Purple
  static const Color purpleDark = Color(0xFF7B1FA2); // Dark Purple

  // Blue shades
  static const Color blue = Color(0xFF2196F3); // Blue
  static const Color blueLight = Color(0xFF64B5F6); // Light Blue
  static const Color blueDark = Color(0xFF1976D2); // Dark Blue

  // Accent colors
  static const Color accent = Color(0xFF00BCD4); // Cyan accent
  static const Color accentPink = Color(0xFFE91E63); // Pink accent

  // Backgrounds
  static const Color background = Colors.black;
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceLight = Color(0xFF2A2A2A);

  // Gradients
  static LinearGradient get purpleBlueGradient => const LinearGradient(
    colors: [Color(0xFF9C27B0), Color(0xFF2196F3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get bluePurpleGradient => const LinearGradient(
    colors: [Color(0xFF2196F3), Color(0xFF9C27B0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get lightGradient => const LinearGradient(
    colors: [Color(0xFFBA68C8), Color(0xFF64B5F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get darkGradient => const LinearGradient(
    colors: [Color(0xFF7B1FA2), Color(0xFF1976D2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get accentGradient => const LinearGradient(
    colors: [Color(0xFFE91E63), Color(0xFF00BCD4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
