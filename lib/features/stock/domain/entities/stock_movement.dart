import '../../../../core/constants/app_enums.dart';

/// Mouvement de stock : entrée (réception), sortie (vente, perte) ou
/// ajustement (correction après inventaire).
///
/// Un mouvement est un **fait daté** : une fois écrit, il ne change plus.
/// C'est ce qui permet de rejouer l'historique et de retrouver ce qu'une
/// marchandise a réellement coûté, même si les tarifs ont changé depuis.
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
    this.unitCost,
    this.supplierId,
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

  /// Coût unitaire attaché à ce mouvement, **dans l'unité de stock du
  /// produit** et figé au moment de l'écriture.
  ///
  /// Sa signification dépend du type :
  ///
  /// - **entrée** : le prix réellement payé, repris de la ligne de commande ;
  /// - **sortie** : le coût de valorisation au moment où la marchandise part
  ///   — c'est le coût matière ;
  /// - **ajustement** : le coût de valorisation en vigueur, un écart
  ///   d'inventaire n'étant pas un achat.
  ///
  /// `null` signifie « prix inconnu » : les mouvements saisis à la main n'en
  /// ont pas encore. Le calcul de valorisation doit alors retomber sur le
  /// coût moyen du produit, jamais sur zéro.
  ///
  /// C'est ce champ qui empêche l'historique d'être réécrit : le prix
  /// appartient à la ligne, pas au produit, et rien ne peut donc l'effacer
  /// quand un tarif change. Voir `ROADMAP.md`, phase 6c.
  final double? unitCost;

  /// Fournisseur d'origine, renseigné pour les entrées issues d'une commande.
  final String? supplierId;

  bool get isIncoming => quantity > 0;

  /// Valeur signée du mouvement, ou `null` si son coût n'est pas connu.
  ///
  /// Volontairement nullable : un zéro laisserait croire que la marchandise
  /// n'a rien coûté, ce qui fausserait silencieusement toute somme.
  double? get totalCost {
    final double? cost = unitCost;
    return cost == null ? null : quantity * cost;
  }

  StockMovement copyWith({
    String? id,
    String? productId,
    DateTime? date,
    MovementType? type,
    double? quantity,
    String? user,
    String? reference,
    String? note,
    double? unitCost,
    String? supplierId,
  }) {
    return StockMovement(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      date: date ?? this.date,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      user: user ?? this.user,
      reference: reference ?? this.reference,
      note: note ?? this.note,
      unitCost: unitCost ?? this.unitCost,
      supplierId: supplierId ?? this.supplierId,
    );
  }
}
