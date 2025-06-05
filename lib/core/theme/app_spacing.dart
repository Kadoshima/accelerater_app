import 'package:flutter/material.dart';

/// Spacing constants for consistent layout
class AppSpacing {
  // Base unit
  static const double unit = 8.0;
  
  // Spacing values
  static const double xxs = unit * 0.5; // 4
  static const double xs = unit * 1; // 8
  static const double sm = unit * 1.5; // 12
  static const double md = unit * 2; // 16
  static const double lg = unit * 3; // 24
  static const double xl = unit * 4; // 32
  static const double xxl = unit * 5; // 40
  static const double xxxl = unit * 6; // 48
  
  // Component specific spacing
  static const double cardPadding = md;
  static const double screenPadding = lg;
  static const double buttonPadding = md;
  static const double inputPadding = sm;
  static const double listItemSpacing = xs;
  static const double sectionSpacing = xl;
  
  // Border radius values
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusXxl = 32.0;
  static const double radiusFull = 999.0;
  
  // Component specific radius
  static const double cardRadius = radiusLg;
  static const double buttonRadius = radiusMd;
  static const double inputRadius = radiusMd;
  static const double chipRadius = radiusFull;
  static const double modalRadius = radiusXl;
  
  // Elevation values
  static const double elevationNone = 0.0;
  static const double elevationXs = 1.0;
  static const double elevationSm = 2.0;
  static const double elevationMd = 4.0;
  static const double elevationLg = 8.0;
  static const double elevationXl = 16.0;
  
  // Icon sizes
  static const double iconXs = 16.0;
  static const double iconSm = 20.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 48.0;
  
  // Heights
  static const double buttonHeight = 48.0;
  static const double inputHeight = 56.0;
  static const double appBarHeight = 64.0;
  static const double listItemHeight = 72.0;
  
  // EdgeInsets helpers
  static const EdgeInsets paddingAll = EdgeInsets.all(md);
  static const EdgeInsets paddingHorizontal = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets paddingVertical = EdgeInsets.symmetric(vertical: md);
  
  static EdgeInsets paddingSymmetric({
    double horizontal = 0,
    double vertical = 0,
  }) =>
      EdgeInsets.symmetric(
        horizontal: horizontal,
        vertical: vertical,
      );
  
  static EdgeInsets paddingOnly({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) =>
      EdgeInsets.only(
        left: left,
        top: top,
        right: right,
        bottom: bottom,
      );
}