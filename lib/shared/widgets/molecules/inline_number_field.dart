import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/theme.dart';

/// Champ numérique compact destiné à une cellule de tableau.
///
/// Conçu pour la saisie en série sur tablette — comptage d'inventaire,
/// quantités reçues d'une commande :
///
/// * la valeur est validée à la sortie du champ **ou** à l'appui sur Entrée,
///   jamais à chaque frappe, pour ne pas déclencher une écriture par
///   caractère ;
/// * un champ vide renvoie `null`, ce qui signifie « non saisi » — à
///   distinguer d'un `0` saisi volontairement ;
/// * le champ se distingue visuellement une fois renseigné, pour qu'on voie
///   d'un coup d'œil où on en est dans une liste de deux cents lignes.
class InlineNumberField extends StatefulWidget {
  const InlineNumberField({
    required this.value,
    required this.onSubmitted,
    this.suffix,
    this.hint = '—',
    this.enabled = true,
    this.width = 110,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    super.key,
  });

  /// Valeur courante. `null` = non saisi.
  final double? value;

  /// Appelé avec la nouvelle valeur, ou `null` si le champ a été vidé.
  final ValueChanged<double?> onSubmitted;

  /// Unité affichée à droite du nombre (`kg`, `un.`).
  final String? suffix;

  final String hint;
  final bool enabled;
  final double width;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;

  @override
  State<InlineNumberField> createState() => _InlineNumberFieldState();
}

class _InlineNumberFieldState extends State<InlineNumberField> {
  late final TextEditingController _controller =
      TextEditingController(text: _format(widget.value));
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(InlineNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ne jamais écraser ce que l'utilisateur est en train de taper : on ne
    // resynchronise que si le champ n'a pas le focus.
    if (!_hasFocus && widget.value != oldWidget.value) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..let((FocusNode node) {
        if (widget.focusNode == null) node.dispose();
      });
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    final bool hasFocus = _focusNode.hasFocus;
    if (hasFocus == _hasFocus) return;
    setState(() => _hasFocus = hasFocus);
    // La sortie du champ vaut validation.
    if (!hasFocus) _commit();
  }

  static String _format(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  void _commit() {
    final String raw = _controller.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) {
      if (widget.value != null) widget.onSubmitted(null);
      return;
    }
    final double? parsed = double.tryParse(raw);
    if (parsed == null) {
      // Saisie invalide : on revient à la dernière valeur connue.
      _controller.text = _format(widget.value);
      return;
    }
    if (parsed != widget.value) widget.onSubmitted(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final bool filled = widget.value != null;

    final Color borderColor = _hasFocus
        ? AppColors.primary
        : (filled ? AppColors.borderStrong : AppColors.border);

    return SizedBox(
      width: widget.width,
      height: 38,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        textAlign: TextAlign.right,
        textInputAction: widget.textInputAction,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,3}')),
        ],
        onSubmitted: (_) => _commit(),
        onTapOutside: (_) => _focusNode.unfocus(),
        style: AppTypography.numeric.copyWith(
          fontWeight: filled ? FontWeight.w600 : FontWeight.w400,
        ),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: widget.enabled
              ? (filled ? AppColors.surface : AppColors.surfaceMuted)
              : AppColors.surfaceMuted,
          hintText: widget.hint,
          hintStyle: AppTypography.numeric.copyWith(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w400,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          suffixIcon: widget.suffix == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Text(
                    widget.suffix!,
                    style: AppTypography.caption,
                    textAlign: TextAlign.right,
                  ),
                ),
          suffixIconConstraints: const BoxConstraints(minWidth: 0),
          border: _border(borderColor),
          enabledBorder: _border(borderColor),
          focusedBorder: _border(AppColors.primary, width: 1.5),
          disabledBorder: _border(AppColors.divider),
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

extension<T> on T {
  void let(void Function(T value) action) => action(this);
}
