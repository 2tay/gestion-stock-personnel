import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_durations.dart';
import '../../../core/theme/theme.dart';
import '../atoms/app_text_field.dart';

/// Champ de recherche avec anti-rebond et bouton d'effacement.
///
/// Présent en tête de chaque page de liste : « Rechercher un produit… »,
/// « Rechercher une commande… », « Rechercher un employé… ».
class SearchField extends StatefulWidget {
  const SearchField({
    required this.hint,
    required this.onChanged,
    this.controller,
    this.width,
    this.autofocus = false,
    this.debounce = AppDurations.searchDebounce,
    super.key,
  });

  final String hint;

  /// Appelé après le délai d'anti-rebond, jamais à chaque frappe.
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  /// `null` = occupe toute la largeur disponible.
  final double? width;
  final bool autofocus;
  final Duration debounce;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  Timer? _debounceTimer;
  bool _hasText = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (_hasText != value.isNotEmpty) {
      setState(() => _hasText = value.isNotEmpty);
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounce, () => widget.onChanged(value));
  }

  void _clear() {
    _controller.clear();
    _debounceTimer?.cancel();
    setState(() => _hasText = false);
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final Widget field = AppTextField(
      controller: _controller,
      hint: widget.hint,
      autofocus: widget.autofocus,
      prefixIcon: Icons.search_rounded,
      textInputAction: TextInputAction.search,
      onChanged: _onChanged,
      suffix: _hasText
          ? IconButton(
              icon: const Icon(Icons.close_rounded, size: AppSizes.iconSm),
              color: AppColors.textTertiary,
              splashRadius: 18,
              onPressed: _clear,
            )
          : null,
    );

    return widget.width == null
        ? field
        : SizedBox(width: widget.width, child: field);
  }
}
