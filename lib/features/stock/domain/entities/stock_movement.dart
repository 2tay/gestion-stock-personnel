import '../../../../core/constants/app_enums.dart';

/// Mouvement de stock : entrée (réception), sortie (vente, perte) ou
/// ajustement (correction après inventaire).
class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.date,
    required this.type,
    required this.quantity,
    required this.user,
    this.reference,
    this.note,
  });

  final String id;
  final String productId;
  final DateTime date;
  final MovementType type;

  /// Quantité signée : positive pour une entrée, négative pour une sortie.
  /// Un ajustement peut être dans les deux sens.
  final double quantity;

  /// Origine du mouvement : numéro de commande, « Vente », « Inventaire »…
  final String? reference;

  /// Utilisateur à l'origine du mouvement — exigence de traçabilité du
  /// cahier des charges.
  final String user;

  final String? note;

  bool get isIncoming => quantity > 0;
}
