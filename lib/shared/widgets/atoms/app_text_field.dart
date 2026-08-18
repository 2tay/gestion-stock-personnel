import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/theme.dart';

/// Champ de saisie unique de l'application (formulaires, recherche, comptage).
class AppTextField extends StatelessWidget {
  const AppTextField({
    this.controller,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.prefixIcon,
    this.suffix,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.focusNode,
    this.textInputAction,
    super.key,
  });

  /// Champ numérique : clavier chiffré + alignement à droite.
  /// Utilisé pour les quantités de comptage et les prix.
  factory AppTextField.numeric({
    TextEditingController? controller,
    String? label,
    String? hint,
    String? suffixText,
    bool enabled = true,
    bool autofocus = false,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    FocusNode? focusNode,
    Key? key,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      label: label,
      hint: hint,
      enabled: enabled,
      autofocus: autofocus,
      focusNode: focusNode,
      textAlign: TextAlign.right,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,3}')),
      ],
      textInputAction: TextInputAction.next,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      suffix: suffixText == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Text(suffixText, style: AppTypography.bodySm),
            ),
    );
  }

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final int maxLines;
  final TextAlign textAlign;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final bool hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (label != null) ...<Widget>[
          Text(label!, style: AppTypography.label),
          const SizedBox(height: AppSpacing.xs + 2),
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          readOnly: readOnly,
          autofocus: autofocus,
          obscureText: obscureText,
          maxLines: obscureText ? 1 : maxLines,
          textAlign: textAlign,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          onTap: onTap,
          style: AppTypography.bodyMd,
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: enabled ? AppColors.surface : AppColors.surfaceMuted,
            hintText: hint,
            hintStyle: AppTypography.bodyMd.copyWith(
              color: AppColors.textTertiary,
            ),
            prefixIcon: prefixIcon == null
                ? null
                : Icon(
                    prefixIcon,
                    size: AppSizes.iconMd,
                    color: AppColors.textTertiary,
                  ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 42,
              minHeight: AppSizes.fieldHeight,
            ),
            suffixIcon: suffix,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: AppSizes.fieldHeight,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            border: _border(AppColors.border),
            enabledBorder:
                _border(hasError ? AppColors.danger : AppColors.border),
            focusedBorder: _border(
              hasError ? AppColors.danger : AppColors.primary,
              width: 1.5,
            ),
            disabledBorder: _border(AppColors.divider),
            errorStyle: const TextStyle(height: 0, fontSize: 0),
          ),
        ),
        if (hasError) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            errorText!,
            style: AppTypography.caption.copyWith(color: AppColors.danger),
          ),
        ] else if (helper != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(helper!, style: AppTypography.caption),
        ],
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
