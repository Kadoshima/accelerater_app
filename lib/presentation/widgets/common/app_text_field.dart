import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Styled text field component
class AppTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? errorText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefix;
  final Widget? suffix;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final FocusNode? focusNode;
  final TextAlign textAlign;
  final TextStyle? style;
  final Color? fillColor;
  final EdgeInsetsGeometry? contentPadding;
  
  const AppTextField({
    Key? key,
    this.label,
    this.hint,
    this.errorText,
    this.controller,
    this.onChanged,
    this.onTap,
    this.onEditingComplete,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.inputFormatters,
    this.prefix,
    this.suffix,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.focusNode,
    this.textAlign = TextAlign.start,
    this.style,
    this.fillColor,
    this.contentPadding,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onTap: onTap,
      onEditingComplete: onEditingComplete,
      onSubmitted: onSubmitted,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      enabled: enabled,
      readOnly: readOnly,
      autofocus: autofocus,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      focusNode: focusNode,
      textAlign: textAlign,
      style: style ?? AppTypography.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        fillColor: fillColor ?? AppColors.inputBackground,
        filled: true,
        contentPadding: contentPadding ?? 
            const EdgeInsets.all(AppSpacing.inputPadding),
        prefix: prefix,
        suffix: suffix,
        prefixIcon: prefixIcon != null 
            ? Icon(prefixIcon, size: AppSpacing.iconMd) 
            : null,
        suffixIcon: suffixIcon != null
            ? IconButton(
                icon: Icon(suffixIcon, size: AppSpacing.iconMd),
                onPressed: onSuffixTap ?? () {},
              )
            : null,
        counterStyle: AppTypography.caption,
      ),
    );
  }
}

/// Password text field with visibility toggle
class AppPasswordField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? errorText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  
  const AppPasswordField({
    Key? key,
    this.label,
    this.hint,
    this.errorText,
    this.controller,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.textInputAction,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
  }) : super(key: key);
  
  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscureText = true;
  
  void _toggleVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label ?? 'Password',
      hint: widget.hint,
      errorText: widget.errorText,
      controller: widget.controller,
      onChanged: widget.onChanged,
      onEditingComplete: widget.onEditingComplete,
      onSubmitted: widget.onSubmitted,
      textInputAction: widget.textInputAction,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      obscureText: _obscureText,
      keyboardType: TextInputType.visiblePassword,
      suffixIcon: _obscureText ? Icons.visibility_off : Icons.visibility,
      onSuffixTap: _toggleVisibility,
    );
  }
}

/// Search text field with search icon
class AppSearchField extends StatelessWidget {
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  
  const AppSearchField({
    Key? key,
    this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return AppTextField(
      hint: hint ?? 'Search...',
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      enabled: enabled,
      autofocus: autofocus,
      focusNode: focusNode,
      textInputAction: TextInputAction.search,
      prefixIcon: Icons.search,
      suffixIcon: controller?.text.isNotEmpty == true ? Icons.clear : null,
      onSuffixTap: () {
        controller?.clear();
        onClear?.call();
        onChanged?.call('');
      },
    );
  }
}

/// Multi-line text area
class AppTextArea extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? errorText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool enabled;
  final bool readOnly;
  final FocusNode? focusNode;
  
  const AppTextArea({
    Key? key,
    this.label,
    this.hint,
    this.errorText,
    this.controller,
    this.onChanged,
    this.maxLines = 5,
    this.minLines = 3,
    this.maxLength,
    this.enabled = true,
    this.readOnly = false,
    this.focusNode,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      hint: hint,
      errorText: errorText,
      controller: controller,
      onChanged: onChanged,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      enabled: enabled,
      readOnly: readOnly,
      focusNode: focusNode,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      contentPadding: const EdgeInsets.all(AppSpacing.md),
    );
  }
}