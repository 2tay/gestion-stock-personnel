import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../atoms/app_button.dart';
import '../atoms/app_text_field.dart';

/// Interface de scan de code-barres.
///
/// L'aperçu caméra n'est pas encore branché : cette version affiche le
/// viseur, l'état d'attente et permet la saisie manuelle du code. Quand le
/// lecteur réel sera intégré, seule la zone [_Viewfinder] changera.
class ScannerSheet extends StatefulWidget {
  const ScannerSheet({
    required this.title,
    this.hint = 'Placez le code-barres dans le cadre',
    super.key,
  });

  final String title;
  final String hint;

  /// Ouvre le scanner et renvoie le code saisi ou scanné.
  static Future<String?> show(
    BuildContext context, {
    String title = 'Scanner un produit',
  }) {
    return showDialog<String>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (BuildContext _) => ScannerSheet(title: title),
    );
  }

  @override
  State<ScannerSheet> createState() => _ScannerSheetState();
}

class _ScannerSheetState extends State<ScannerSheet> {
  final TextEditingController _manualCode = TextEditingController();

  @override
  void dispose() {
    _manualCode.dispose();
    super.dispose();
  }

  void _submit() {
    final String code = _manualCode.text.trim();
    if (code.isEmpty) return;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(widget.title, style: AppTypography.titleMd),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const _Viewfinder(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                widget.hint,
                textAlign: TextAlign.center,
                style: AppTypography.bodySm,
              ),
              const SizedBox(height: AppSpacing.xl),
              const Row(
                children: <Widget>[
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Text('ou', style: AppTypography.caption),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _manualCode,
                label: 'Saisir le code manuellement',
                hint: 'Ex. 6111234567890',
                prefixIcon: Icons.keyboard_rounded,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton.primary(
                label: 'Valider le code',
                expand: true,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cadre de visée animé, en attendant l'aperçu caméra réel.
class _Viewfinder extends StatefulWidget {
  const _Viewfinder();

  @override
  State<_Viewfinder> createState() => _ViewfinderState();
}

class _ViewfinderState extends State<_Viewfinder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            const Icon(
              Icons.qr_code_scanner_rounded,
              size: 56,
              color: Color(0x33FFFFFF),
            ),
            Container(
              width: 260,
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 2),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, Widget? child) => Align(
                alignment: Alignment(0, -0.55 + _controller.value * 1.1),
                child: Container(
                  width: 256,
                  height: 2,
                  color: AppColors.primary.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
