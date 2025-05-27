import 'package:flutter/material.dart';

class ResponsiveHelper {
  static bool isTablet(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    return shortestSide >= 600;
  }

  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  static double getAdaptivePadding(BuildContext context) {
    if (isTablet(context)) {
      return 24.0;
    }
    return 16.0;
  }

  static double getAdaptiveSpacing(BuildContext context) {
    if (isTablet(context)) {
      return 24.0;
    }
    return 16.0;
  }

  static double getButtonHeight(BuildContext context) {
    if (isTablet(context)) {
      return 60.0;
    }
    return 50.0;
  }

  static double getSliderWidth(BuildContext context) {
    if (isTablet(context)) {
      return 250.0;
    }
    return 160.0;
  }

  static double getFontSize(BuildContext context, {required double baseSize}) {
    if (isTablet(context)) {
      return baseSize * 1.2;
    }
    return baseSize;
  }

  static bool shouldUseTwoColumnLayout(BuildContext context) {
    return isTablet(context) && isLandscape(context);
  }

  static double getChartHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    if (isTablet(context)) {
      return screenHeight * 0.5;
    }
    return 300.0;
  }
}