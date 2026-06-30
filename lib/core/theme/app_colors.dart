import 'package:flutter/material.dart';

class AppColors {
  // Green shades (Primary Theme Color)
  static const Color purple = Color(
      0xFF10B981); // Emerald/Mint Green (renamed internally for compatibility)
  static const Color purpleLight = Color(0xFF34D399);
  static const Color purpleDark = Color(0xFF059669);

  // Blue shades (Secondary Theme Color)
  static const Color blue = Color(0xFF3B82F6); // Royal Blue
  static const Color blueLight = Color(0xFF60A5FA);
  static const Color blueDark = Color(0xFF2563EB);

  // Yellow shades (Accent Color)
  static const Color accent = Color(0xFFF59E0B); // Amber Yellow
  static const Color accentPink = Color(0xFFFBBF24);

  // Backgrounds (Dark Mode Default)
  static const Color background = Color(0xFF0B0F19); // Deep Obsidian
  static const Color surface = Color(0xFF1E293B); // Deep Slate Card
  static const Color surfaceLight = Color(0xFF334155);

  // Flat Color Gradients for compatibility (returns solid color values)
  static LinearGradient get purpleBlueGradient => const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF10B981)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get bluePurpleGradient => const LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF3B82F6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get lightGradient => const LinearGradient(
        colors: [Color(0xFF60A5FA), Color(0xFF60A5FA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get darkGradient => const LinearGradient(
        colors: [Color(0xFF059669), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get accentGradient => const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFF59E0B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
