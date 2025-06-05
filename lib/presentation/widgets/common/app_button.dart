import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Primary button with filled background
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final IconData? icon;
  final ButtonSize size;
  final double? width;
  final EdgeInsetsGeometry? padding;
  
  const AppButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.size = ButtonSize.medium,
    this.width,
    this.padding,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final buttonChild = _buildButtonContent();
    final effectiveOnPressed = (isDisabled || isLoading) ? null : onPressed;
    
    return SizedBox(
      width: width,
      height: _getHeight(),
      child: ElevatedButton(
        onPressed: effectiveOnPressed,
        style: ElevatedButton.styleFrom(
          padding: padding ?? _getPadding(),
          minimumSize: Size(width ?? 88, _getHeight()),
        ),
        child: buttonChild,
      ),
    );
  }
  
  Widget _buildButtonContent() {
    if (isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.onPrimary),
        ),
      );
    }
    
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: _getIconSize()),
          const SizedBox(width: AppSpacing.xs),
          Text(text),
        ],
      );
    }
    
    return Text(text);
  }
  
  double _getHeight() {
    switch (size) {
      case ButtonSize.small:
        return 36;
      case ButtonSize.medium:
        return AppSpacing.buttonHeight;
      case ButtonSize.large:
        return 56;
    }
  }
  
  double _getIconSize() {
    switch (size) {
      case ButtonSize.small:
        return AppSpacing.iconSm;
      case ButtonSize.medium:
        return AppSpacing.iconMd;
      case ButtonSize.large:
        return AppSpacing.iconLg;
    }
  }
  
  EdgeInsetsGeometry _getPadding() {
    switch (size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        );
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.buttonPadding,
          vertical: AppSpacing.sm,
        );
      case ButtonSize.large:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        );
    }
  }
}

/// Outlined button variant
class AppOutlinedButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final IconData? icon;
  final ButtonSize size;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  
  const AppOutlinedButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.size = ButtonSize.medium,
    this.width,
    this.padding,
    this.borderColor,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final buttonChild = _buildButtonContent();
    final effectiveOnPressed = (isDisabled || isLoading) ? null : onPressed;
    
    return SizedBox(
      width: width,
      height: _getHeight(),
      child: OutlinedButton(
        onPressed: effectiveOnPressed,
        style: OutlinedButton.styleFrom(
          padding: padding ?? _getPadding(),
          minimumSize: Size(width ?? 88, _getHeight()),
          side: BorderSide(
            color: borderColor ?? 
                   (isDisabled ? AppColors.borderDark : AppColors.borderLight),
          ),
        ),
        child: buttonChild,
      ),
    );
  }
  
  Widget _buildButtonContent() {
    if (isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
        ),
      );
    }
    
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: _getIconSize()),
          const SizedBox(width: AppSpacing.xs),
          Text(text),
        ],
      );
    }
    
    return Text(text);
  }
  
  double _getHeight() {
    switch (size) {
      case ButtonSize.small:
        return 36;
      case ButtonSize.medium:
        return AppSpacing.buttonHeight;
      case ButtonSize.large:
        return 56;
    }
  }
  
  double _getIconSize() {
    switch (size) {
      case ButtonSize.small:
        return AppSpacing.iconSm;
      case ButtonSize.medium:
        return AppSpacing.iconMd;
      case ButtonSize.large:
        return AppSpacing.iconLg;
    }
  }
  
  EdgeInsetsGeometry _getPadding() {
    switch (size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        );
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.buttonPadding,
          vertical: AppSpacing.sm,
        );
      case ButtonSize.large:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        );
    }
  }
}

/// Text button variant
class AppTextButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final IconData? icon;
  final ButtonSize size;
  final EdgeInsetsGeometry? padding;
  final Color? textColor;
  
  const AppTextButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.size = ButtonSize.medium,
    this.padding,
    this.textColor,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final buttonChild = _buildButtonContent();
    final effectiveOnPressed = (isDisabled || isLoading) ? null : onPressed;
    
    return TextButton(
      onPressed: effectiveOnPressed,
      style: TextButton.styleFrom(
        padding: padding ?? _getPadding(),
        foregroundColor: textColor ?? AppColors.accent,
      ),
      child: buttonChild,
    );
  }
  
  Widget _buildButtonContent() {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            textColor ?? AppColors.accent,
          ),
        ),
      );
    }
    
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: _getIconSize()),
          const SizedBox(width: AppSpacing.xs),
          Text(text),
        ],
      );
    }
    
    return Text(text);
  }
  
  double _getIconSize() {
    switch (size) {
      case ButtonSize.small:
        return AppSpacing.iconSm;
      case ButtonSize.medium:
        return AppSpacing.iconMd;
      case ButtonSize.large:
        return AppSpacing.iconLg;
    }
  }
  
  EdgeInsetsGeometry _getPadding() {
    switch (size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        );
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        );
      case ButtonSize.large:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        );
    }
  }
}

/// Icon button variant
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final ButtonSize size;
  final Color? iconColor;
  final Color? backgroundColor;
  final String? tooltip;
  
  const AppIconButton({
    Key? key,
    required this.icon,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.size = ButtonSize.medium,
    this.iconColor,
    this.backgroundColor,
    this.tooltip,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = (isDisabled || isLoading) ? null : onPressed;
    final buttonSize = _getSize();
    
    final iconButton = Container(
      width: buttonSize,
      height: buttonSize,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: IconButton(
        onPressed: effectiveOnPressed,
        icon: isLoading
            ? SizedBox(
                width: _getIconSize() * 0.8,
                height: _getIconSize() * 0.8,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    iconColor ?? AppColors.textPrimary,
                  ),
                ),
              )
            : Icon(
                icon,
                size: _getIconSize(),
                color: iconColor,
              ),
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(
          minWidth: buttonSize,
          minHeight: buttonSize,
        ),
      ),
    );
    
    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: iconButton,
      );
    }
    
    return iconButton;
  }
  
  double _getSize() {
    switch (size) {
      case ButtonSize.small:
        return 32;
      case ButtonSize.medium:
        return 40;
      case ButtonSize.large:
        return 48;
    }
  }
  
  double _getIconSize() {
    switch (size) {
      case ButtonSize.small:
        return AppSpacing.iconSm;
      case ButtonSize.medium:
        return AppSpacing.iconMd;
      case ButtonSize.large:
        return AppSpacing.iconLg;
    }
  }
}

/// Button size enum
enum ButtonSize {
  small,
  medium,
  large,
}