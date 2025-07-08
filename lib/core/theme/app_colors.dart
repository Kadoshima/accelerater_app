import 'package:flutter/material.dart';

/// App color palette with a dark theme focus
class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF000000); // Black
  static const Color onPrimary = Color(0xFFFFFFFF); // White
  
  // Background colors
  static const Color background = Color(0xFF1A1A1A); // Dark grey instead of pure black
  static const Color surface = Color(0xFF2D2D2D); // Medium dark grey
  static const Color surfaceContainerHighest = Color(0xFF383838); // Lighter grey for cards
  
  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF); // White
  static const Color textSecondary = Color(0xFFB3B3B3); // Light gray
  static const Color textTertiary = Color(0xFF808080); // Medium gray
  static const Color textDisabled = Color(0xFF4D4D4D); // Dark gray
  
  // Accent colors
  static const Color accent = Color(0xFF2196F3); // Blue accent
  static const Color accentLight = Color(0xFF64B5F6);
  static const Color accentDark = Color(0xFF1976D2);
  
  // Semantic colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF29B6F6);
  
  // Border colors
  static const Color borderLight = Color(0xFF5A5A5A); // Lighter grey for better visibility
  static const Color borderMedium = Color(0xFF4A4A4A); // Medium grey for cards
  static const Color borderDark = Color(0xFF3A3A3A); // Darker grey
  
  // Overlay colors
  static const Color overlay = Color(0x80000000); // 50% black
  static const Color overlayLight = Color(0x40000000); // 25% black
  static const Color overlayDark = Color(0xCC000000); // 80% black
  
  // Component specific
  static const Color cardBackground = surface; // Use medium dark grey for cards
  static const Color inputBackground = Color(0xFF0A0A0A);
  static const Color inputBorder = borderLight;
  static const Color buttonBackground = accent;
  static const Color buttonDisabled = Color(0xFF2A2A2A);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentDark],
  );
  
  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [surface, background],
  );
}