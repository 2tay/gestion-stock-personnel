import '../../../../core/constants/app_enums.dart';

/// Décision explicite de l'utilisateur sur une commande.
///
/// À distinguer de [OrderStatus], qui est ce qu'on **affiche** et qui se
/// déduit des lignes. Une commande ouverte est « En cours », « Partielle » ou
/// « Reçue » selon ce qui est arrivé — personne ne décide de ça, ça se
/// constate.
enum OrderLifecycle {
  /// En préparation, pas encore envoyée au fournisseur.
  brouillon,

  /// Envoyée : on attend la marchandise.
  ouverte,

  /// Annulée avant toute réception.
  annulee,

  /// Close avec un reliquat abandonné : ce qui est arrivé est conservé, on
  /// n'attend plus le reste.
  soldee,
}

/// Une ligne de commande : un produit, une quantité commandée, une quantité
/// reçue et un prix négocié.
class OrderLine {
  const OrderLine({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.quantityOrdered,
    required this.unitPrice,
    this.emoji = '📦',
    this.quantityReceived = 0,
  });

  final String productId;
  final String productName;
  final String emoji;
  final String unit;

  final double quantityOrdered;

  /// Quantité **cumulée** reçue, toutes réceptions confondues.
  ///
  /// Une commande peut être livrée en plusieurs fois : c'est le total qui est
  /// stocké, pas la dernière livraison. `ReceiveOrder` se charge de calculer
  /// l'écart entre l'ancien et le nouveau cumul pour n'écrire dans le stock
  /// que ce qui vient réellement d'arriver.
  final double quantityReceived;

  /// Prix unitaire négocié, figé à la commande. Il peut différer du dernier
  /// prix d'achat connu du produit.
  final double unitPrice;

  /// Valeur commandée : ce qui a été engagé auprès du fournisseur.
  double get orderedTotal => quantityOrdered * unitPrice;

  /// Valeur réellement livrée : ce qui sera facturé.
  double get receivedTotal => quantityReceived * unitPrice;

  /// Quantité restant à livrer. Négative en cas de sur-livraison.
  double get remaining => quantityOrdered - quantityReceived;

  bool get isFullyReceived => quantityReceived >= quantityOrdered;
  bool get hasReceipt => quantityReceived > 0;
  bool get isOverDelivered => quantityReceived > quantityOrdered;

  /// Avancement de la livraison entre 0 et 1.
  double get progress {
    if (quantityOrdered <= 0) return 1;
    return (quantityReceived / quantityOrdered).clamp(0.0, 1.0);
  }

  OrderLine copyWith({
    double? quantityOrdered,
    double? quantityReceived,
    double? unitPrice,
  }) {
    return OrderLine(
      productId: productId,
      productName: productName,
      emoji: emoji,
      unit: unit,
      quantityOrdered: quantityOrdered ?? this.quantityOrdered,
      quantityReceived: quantityReceived ?? this.quantityReceived,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }
}

/// Commande passée à un fournisseur.
class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.reference,
    required this.supplierId,
    required this.supplierName,
    required this.createdAt,
    required this.lifecycle,
    required this.lines,
    required this.createdBy,
    this.expectedAt,
    this.closedAt,
    this.notes,
  });

  final String id;

  /// Référence lisible : `CMD-005`.
  final String reference;

  final String supplierId;

  /// Nom dénormalisé, pour afficher la liste sans jointure — même raison que
  /// `categoryName` sur un produit.
  final String supplierName;

  final DateTime createdAt;

  /// Date de livraison attendue, calculée depuis le délai du fournisseur.
  final DateTime? expectedAt;

  /// Date d'annulation ou de solde.
  final DateTime? closedAt;

  final OrderLifecycle lifecycle;
  final List<OrderLine> lines;
  final String createdBy;
  final String? notes;

  // --- Statut affiché ----------------------------------------------------

  /// Statut à afficher, déduit des lignes.
  ///
  /// Jamais stocké : une commande dont les lignes sont toutes servies est
  /// « Reçue », sans qu'aucun code n'ait à penser à mettre un champ à jour.
  OrderStatus get status => switch (lifecycle) {
        OrderLifecycle.brouillon => OrderStatus.brouillon,
        OrderLifecycle.annulee => OrderStatus.annulee,
        OrderLifecycle.soldee => OrderStatus.soldee,
        OrderLifecycle.ouverte => switch (receivedQuantity) {
            0 => OrderStatus.enCours,
            _ => isFullyReceived ? OrderStatus.recue : OrderStatus.partielle,
          },
      };

  // --- Quantités et montants ---------------------------------------------

  double get orderedQuantity => lines.fold<double>(
        0,
        (double sum, OrderLine l) => sum + l.quantityOrdered,
      );

  double get receivedQuantity => lines.fold<double>(
        0,
        (double sum, OrderLine l) => sum + l.quantityReceived,
      );

  /// Montant engagé auprès du fournisseur — c'est le total affiché en liste.
  double get orderedTotal => lines.fold<double>(
        0,
        (double sum, OrderLine l) => sum + l.orderedTotal,
      );

  /// Montant réellement livré — c'est ce que le détail totalise.
  double get receivedTotal => lines.fold<double>(
        0,
        (double sum, OrderLine l) => sum + l.receivedTotal,
      );

  bool get isFullyReceived =>
      lines.isNotEmpty && lines.every((OrderLine l) => l.isFullyReceived);

  int get pendingLineCount =>
      lines.where((OrderLine l) => !l.isFullyReceived).length;

  /// Avancement de la réception, en valeur commandée.
  double get progress {
    final double ordered = orderedQuantity;
    if (ordered <= 0) return 0;
    return (receivedQuantity / ordered).clamp(0.0, 1.0);
  }

  // --- Règles de transition ----------------------------------------------

  /// Les quantités reçues ne se saisissent que sur une commande ouverte.
  bool get isReceivable => lifecycle == OrderLifecycle.ouverte;

  /// Les lignes ne se modifient plus dès qu'une livraison est arrivée.
  bool get isEditable =>
      lifecycle == OrderLifecycle.brouillon ||
      (lifecycle == OrderLifecycle.ouverte && receivedQuantity == 0);

  /// Annuler n'est possible que tant que rien n'est arrivé. Au-delà, la
  /// marchandise reçue fait partie du stock et de l'historique : on solde.
  bool get canCancel =>
      lifecycle != OrderLifecycle.annulee &&
      lifecycle != OrderLifecycle.soldee &&
      receivedQuantity == 0;

  /// Solder abandonne le reliquat d'une commande partiellement livrée.
  bool get canClose =>
      lifecycle == OrderLifecycle.ouverte &&
      receivedQuantity > 0 &&
      !isFullyReceived;

  /// Une commande close ou annulée ne bouge plus.
  bool get isFinal =>
      lifecycle == OrderLifecycle.annulee ||
      lifecycle == OrderLifecycle.soldee ||
      (lifecycle == OrderLifecycle.ouverte && isFullyReceived);

  PurchaseOrder copyWith({
    OrderLifecycle? lifecycle,
    List<OrderLine>? lines,
    DateTime? expectedAt,
    DateTime? closedAt,
    String? notes,
  }) {
    return PurchaseOrder(
      id: id,
      reference: reference,
      supplierId: supplierId,
      supplierName: supplierName,
      createdAt: createdAt,
      expectedAt: expectedAt ?? this.expectedAt,
      closedAt: closedAt ?? this.closedAt,
      lifecycle: lifecycle ?? this.lifecycle,
      lines: lines ?? this.lines,
      createdBy: createdBy,
      notes: notes ?? this.notes,
    );
  }

  // Pas de redéfinition de `==` : voir le README du module Stock, décision 9.
}
