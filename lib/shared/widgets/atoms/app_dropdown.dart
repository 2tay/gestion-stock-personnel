import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// Liste déroulante alignée sur le style de [AppTextField].
///
/// Sert aux sélecteurs de catégorie, d'unité, de fournisseur et de période.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.labelBuilder,
    this.label,
    this.hint,
    this.prefixIcon,
    this.enabled = true,
    this.width,
    this.dense = false,
    super.key,
  });

  final T? value;
  final List<T> items;
  final ValueChanged<T?>? onChanged;

  /// Convertit une valeur en libellé affichable.
  final String Function(T value) labelBuilder;

  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final bool enabled;
  final double? width;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final Widget field = InputDecorator(
      isEmpty: value == null,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: enabled ? AppColors.surface : AppColors.surfaceMuted,
        hintText: hint,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(
                prefixIcon,
                size: AppSizes.iconSm,
                color: AppColors.textTertiary,
              ),
        prefixIconConstraints: const BoxConstraints(minWidth: 38),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: dense ? AppSpacing.sm : AppSpacing.md,
        ),
        border: _border(AppColors.border),
        enabledBorder: _border(AppColors.border),
        focusedBorder: _border(AppColors.primary, width: 1.5),
        disabledBorder: _border(AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: true,
          borderRadius: BorderRadius.circular(AppRadius.md),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: AppSizes.iconMd,
            color: AppColors.textTertiary,
          ),
          style: AppTypography.bodyMd,
          hint: hint == null
              ? null
              : Text(
                  hint!,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
          onChanged: enabled ? onChanged : null,
          items: <DropdownMenuItem<T>>[
            for (final T item in items)
              DropdownMenuItem<T>(
                value: item,
                child: Text(
                  labelBuilder(item),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );

    final Widget sized =
        width == null ? field : SizedBox(width: width, child: field);

    if (label == null) return sized;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label!, style: AppTypography.label),
        const SizedBox(height: AppSpacing.xs + 2),
        sized,
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
