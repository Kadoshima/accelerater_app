import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Reusable card component with rounded corners and minimal styling
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double? borderRadius;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double? width;
  final double? height;
  final Clip clipBehavior;
  
  const AppCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderRadius,
    this.border,
    this.boxShadow,
    this.onTap,
    this.onLongPress,
    this.width,
    this.height,
    this.clipBehavior = Clip.antiAliasWithSaveLayer,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.cardBackground,
        borderRadius: BorderRadius.circular(
          borderRadius ?? AppSpacing.cardRadius,
        ),
        border: border ?? Border.all(
          color: AppColors.borderMedium,
          width: 1,
        ),
        boxShadow: boxShadow,
      ),
      clipBehavior: clipBehavior,
      child: child,
    );
    
    if (onTap != null || onLongPress != null) {
      return Container(
        margin: margin,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(
            borderRadius ?? AppSpacing.cardRadius,
          ),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(
              borderRadius ?? AppSpacing.cardRadius,
            ),
            child: cardContent,
          ),
        ),
      );
    }
    
    return Container(
      margin: margin,
      child: cardContent,
    );
  }
}

/// Outlined variant of AppCard
class AppOutlinedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double? width;
  final double? height;
  final Clip clipBehavior;
  
  const AppOutlinedCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.borderColor,
    this.borderWidth = 1.0,
    this.onTap,
    this.onLongPress,
    this.width,
    this.height,
    this.clipBehavior = Clip.antiAliasWithSaveLayer,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      onLongPress: onLongPress,
      padding: padding,
      margin: margin,
      backgroundColor: Colors.transparent,
      borderRadius: borderRadius,
      width: width,
      height: height,
      clipBehavior: clipBehavior,
      border: Border.all(
        color: borderColor ?? AppColors.borderLight,
        width: borderWidth,
      ),
      child: child,
    );
  }
}

/// Gradient variant of AppCard
class AppGradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double? width;
  final double? height;
  final Clip clipBehavior;
  
  const AppGradientCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.gradient,
    this.onTap,
    this.onLongPress,
    this.width,
    this.height,
    this.clipBehavior = Clip.antiAliasWithSaveLayer,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        gradient: gradient ?? AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(
          borderRadius ?? AppSpacing.cardRadius,
        ),
      ),
      clipBehavior: clipBehavior,
      child: child,
    );
    
    if (onTap != null || onLongPress != null) {
      return Container(
        margin: margin,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(
            borderRadius ?? AppSpacing.cardRadius,
          ),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(
              borderRadius ?? AppSpacing.cardRadius,
            ),
            child: cardContent,
          ),
        ),
      );
    }
    
    return Container(
      margin: margin,
      child: cardContent,
    );
  }
}