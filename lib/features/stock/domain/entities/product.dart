import '../../../../core/constants/app_enums.dart';

/// Un tarif fournisseur à une date donnée.
///
/// Immuable : on ne corrige pas un tarif passé, on en ajoute un nouveau.
/// C'est ce qui permet de savoir ce qu'un fournisseur facturait le mois
/// dernier, et donc de mesurer une hausse.
class SupplierPrice {
  const SupplierPrice({
    required this.unitPrice,
    this.validFrom,
    this.source = PriceSource.saisieManuelle,
    this.note,
  });

  /// Prix unitaire, **dans l'unité de stock du produit**.
  ///
  /// Une bouteille d'huile de 5 L achetée 96 MAD se saisit à 19,20 si le
  /// produit se suit en litres. Sans cette règle, aucune valorisation n'a de
  /// sens.
  final double unitPrice;

  /// Date d'entrée en vigueur.
  ///
  /// `null` = tarif d'origine, dont on ne connaît pas la date. Il est traité
  /// comme le plus ancien de tous.
  final DateTime? validFrom;

  final PriceSource source;
  final String? note;

  /// Ce tarif s'appliquait-il à [date] ?
  bool appliesOn(DateTime date) {
    final DateTime? from = validFrom;
    return from == null || !from.isAfter(date);
  }
}

/// Fournisseur associé à un produit, avec son historique de tarifs et sa
/// référence.
///
/// Volontairement local au module Stock : la fiche fournisseur complète
/// appartient au module Achats. Ce qui compte ici, c'est ce que l'onglet
/// « Fournisseurs » de la fiche produit doit afficher.
///
/// **Le tarif n'est pas un champ, c'est une lecture.** [prices] contient
/// l'historique, du plus récent au plus ancien, et [unitPrice] renvoie
/// simplement le premier. Changer un prix n'écrase rien : [withPrice] ajoute
/// une ligne. C'est l'étape 2 de la phase 6c décrite dans `ROADMAP.md`.
class ProductSupplier {
  /// [unitPrice] est le tarif **en vigueur**, [history] les tarifs
  /// antérieurs, dans n'importe quel ordre.
  ProductSupplier({
    required this.id,
    required this.name,
    required double unitPrice,
    DateTime? since,
    PriceSource source = PriceSource.saisieManuelle,
    List<SupplierPrice> history = const <SupplierPrice>[],
    this.reference,
    this.isPrimary = false,
    this.deliveryDays = 1,
  }) : prices = <SupplierPrice>[
          SupplierPrice(
            unitPrice: unitPrice,
            validFrom: since,
            source: source,
          ),
          ..._sortedDesc(history),
        ];

  /// Construit directement depuis un historique déjà constitué, le plus
  /// récent en tête. Utilisé par [withPrice] et par la couche données.
  ProductSupplier.fromPrices({
    required this.id,
    required this.name,
    required List<SupplierPrice> prices,
    this.reference,
    this.isPrimary = false,
    this.deliveryDays = 1,
  })  : assert(
          prices.isNotEmpty,
          'Un fournisseur associé porte toujours au moins un tarif : sans '
          'prix, il ne peut ni être commandé ni valoriser quoi que ce soit.',
        ),
        prices = List<SupplierPrice>.unmodifiable(prices);

  static List<SupplierPrice> _sortedDesc(List<SupplierPrice> prices) {
    final List<SupplierPrice> sorted = List<SupplierPrice>.of(prices)
      ..sort((SupplierPrice a, SupplierPrice b) {
        final DateTime? da = a.validFrom;
        final DateTime? db = b.validFrom;
        // Un tarif sans date est le plus ancien de tous.
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
    return sorted;
  }

  final String id;
  final String name;

  /// Historique des tarifs, du plus récent au plus ancien. Jamais vide.
  final List<SupplierPrice> prices;

  /// Référence du produit chez ce fournisseur.
  final String? reference;

  /// Fournisseur principal : celui proposé par défaut à la commande.
  final bool isPrimary;

  /// Délai de livraison indicatif, en jours.
  final int deliveryDays;

  /// Tarif en vigueur.
  SupplierPrice get currentPrice => prices.first;

  /// Prix unitaire en vigueur, dans l'unité du produit.
  double get unitPrice => currentPrice.unitPrice;

  /// Tarif précédent, s'il y en a un.
  SupplierPrice? get previousPrice =>
      prices.length > 1 ? prices[1] : null;

  bool get hasPriceHistory => prices.length > 1;

  /// Écart avec le tarif précédent, en valeur absolue puis en proportion.
  ///
  /// `null` quand il n'y a pas de tarif antérieur : afficher « 0 % » ferait
  /// croire à une stabilité qui n'a jamais été observée.
  double? get priceChange {
    final SupplierPrice? previous = previousPrice;
    return previous == null ? null : unitPrice - previous.unitPrice;
  }

  double? get priceChangeRatio {
    final SupplierPrice? previous = previousPrice;
    if (previous == null || previous.unitPrice == 0) return null;
    return (unitPrice - previous.unitPrice) / previous.unitPrice;
  }

  /// Tarif applicable à une date passée — pour relire une ancienne commande
  /// au tarif qui était le sien.
  SupplierPrice? priceOn(DateTime date) {
    for (final SupplierPrice price in prices) {
      if (price.appliesOn(date)) return price;
    }
    return null;
  }

  /// Ajoute un tarif **sans rien effacer**, et renvoie un nouveau
  /// fournisseur.
  ///
  /// Un prix identique au tarif en vigueur ne crée pas de ligne : l'historique
  /// consigne les changements, pas les confirmations.
  ProductSupplier withPrice(
    double newUnitPrice, {
    DateTime? validFrom,
    PriceSource source = PriceSource.saisieManuelle,
    String? note,
  }) {
    if (newUnitPrice == unitPrice) return this;
    return ProductSupplier.fromPrices(
      id: id,
      name: name,
      reference: reference,
      isPrimary: isPrimary,
      deliveryDays: deliveryDays,
      prices: <SupplierPrice>[
        SupplierPrice(
          unitPrice: newUnitPrice,
          validFrom: validFrom,
          source: source,
          note: note,
        ),
        ...prices,
      ],
    );
  }

  ProductSupplier copyWith({
    String? name,
    String? reference,
    bool? isPrimary,
    int? deliveryDays,
  }) {
    return ProductSupplier.fromPrices(
      id: id,
      name: name ?? this.name,
      reference: reference ?? this.reference,
      isPrimary: isPrimary ?? this.isPrimary,
      deliveryDays: deliveryDays ?? this.deliveryDays,
      prices: prices,
    );
  }
}

/// Produit géré en stock.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.unit,
    required this.currentStock,
    required this.minStock,
    required this.maxStock,
    required this.averageCost,
    this.emoji = '📦',
    this.barcode,
    this.suppliers = const <ProductSupplier>[],
    this.notes,
    this.updatedAt,
    this.lastPurchasePrice,
    this.lastPurchaseDate,
    this.lastSupplierId,
  });

  final String id;
  final String name;
  final String categoryId;

  /// Nom de catégorie dénormalisé : évite une jointure pour afficher le
  /// tableau, qui est la vue la plus fréquente.
  final String categoryName;

  /// Code de l'unité (`kg`, `un.`…).
  final String unit;

  final double currentStock;

  /// Seuil d'alerte : en dessous, le produit est signalé comme faible.
  final double minStock;

  /// Stock cible, utilisé pour calculer la quantité à commander.
  final double maxStock;

  /// Coût unitaire moyen pondéré (CUMP) : ce que vaut **une unité de ce que
  /// l'on détient**, tous approvisionnements confondus.
  ///
  /// Recalculé à chaque entrée par le cas d'usage de réception, jamais saisi
  /// à la main hors création du produit. C'est la base de la valeur du stock.
  ///
  /// Ce champ remplace l'ancien `unitPrice`, qui portait le *dernier* prix
  /// payé et revalorisait donc tout le stock déjà détenu au prix de la
  /// dernière livraison — 100 kg achetés à 12 puis 20 kg à 18 affichaient
  /// 2 160 MAD au lieu des 1 560 MAD réellement dépensés.
  ///
  /// **Ce n'est pas un état dérivé stocké par confort.** Le CUMP ne se déduit
  /// pas de l'état courant : il dépend de la suite ordonnée des
  /// approvisionnements. Seul un rejeu de l'historique des mouvements peut le
  /// reconstituer.
  final double averageCost;

  final String emoji;
  final String? barcode;
  final List<ProductSupplier> suppliers;
  final String? notes;
  final DateTime? updatedAt;

  /// Dernier prix effectivement payé, et à qui.
  ///
  /// Purement informatif : ces trois champs alimentent la fiche produit, pas
  /// la valorisation. Confondre « dernier prix payé » et « valeur du stock »
  /// est précisément l'erreur que la phase 6c corrige.
  ///
  /// `null` tant qu'aucune réception n'a eu lieu — et `null` veut dire
  /// « jamais acheté », pas « gratuit ».
  final double? lastPurchasePrice;
  final DateTime? lastPurchaseDate;
  final String? lastSupplierId;

  bool get hasPurchaseHistory => lastPurchasePrice != null;

  /// Statut affiché par le badge de la liste.
  StockStatus get status {
    if (currentStock <= 0) return StockStatus.rupture;
    if (currentStock <= minStock) return StockStatus.faible;
    return StockStatus.ok;
  }

  /// Valeur du stock détenu pour ce produit, au coût moyen.
  double get stockValue => currentStock * averageCost;

  /// Coût moyen pondéré **après** une entrée de [quantity] unités payées
  /// [unitPrice].
  ///
  /// À appeler sur le produit *avant* le mouvement : c'est le stock d'avant
  /// qui pondère l'ancien coût.
  ///
  /// ```
  /// 100 kg à 12 MAD  +  20 kg à 18 MAD
  ///   (100 × 12 + 20 × 18) / 120  =  1 560 / 120  =  13 MAD
  ///   valeur du stock = 120 × 13 = 1 560 MAD, exactement ce qui a été payé
  /// ```
  ///
  /// Une [quantity] négative annule une entrée : la même formule s'applique
  /// et restitue le coût moyen d'avant, à condition de repasser le prix de
  /// l'entrée d'origine. C'est pourquoi `StockMovement` porte son prix.
  ///
  /// Trois cas limites, tous rendus au coût le plus honnête disponible
  /// plutôt qu'à une division impossible :
  ///
  /// - stock nul ou négatif avant une entrée : il ne reste rien à pondérer,
  ///   la marchandise qui arrive fixe seule le coût ;
  /// - stock nul ou négatif après : le coût moyen n'a plus d'objet, on
  ///   conserve le dernier connu plutôt que de le perdre ;
  /// - valeur totale négative : donnée incohérente, on conserve également.
  double averageCostAfter({
    required double quantity,
    required double unitPrice,
  }) {
    if (currentStock <= 0 && quantity > 0) return unitPrice;

    final double stockAfter = currentStock + quantity;
    if (stockAfter <= 0) return averageCost;

    final double value = currentStock * averageCost + quantity * unitPrice;
    if (value <= 0) return averageCost;

    return value / stockAfter;
  }

  /// Quantité à commander pour revenir au stock maximum.
  double get quantityToOrder {
    final double missing = maxStock - currentStock;
    return missing > 0 ? missing : 0;
  }

  /// Position du stock entre 0 et 1 par rapport au maximum, pour la jauge.
  double get fillRatio {
    if (maxStock <= 0) return 0;
    final double ratio = currentStock / maxStock;
    return ratio.clamp(0, 1).toDouble();
  }

  /// Le fournisseur associé portant cet identifiant, ou `null`.
  ProductSupplier? supplierById(String supplierId) {
    for (final ProductSupplier s in suppliers) {
      if (s.id == supplierId) return s;
    }
    return null;
  }

  ProductSupplier? get primarySupplier {
    for (final ProductSupplier s in suppliers) {
      if (s.isPrimary) return s;
    }
    return suppliers.isEmpty ? null : suppliers.first;
  }

  Product copyWith({
    String? name,
    String? categoryId,
    String? categoryName,
    String? unit,
    double? currentStock,
    double? minStock,
    double? maxStock,
    double? averageCost,
    String? emoji,
    String? barcode,
    List<ProductSupplier>? suppliers,
    String? notes,
    DateTime? updatedAt,
    double? lastPurchasePrice,
    DateTime? lastPurchaseDate,
    String? lastSupplierId,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      unit: unit ?? this.unit,
      currentStock: currentStock ?? this.currentStock,
      minStock: minStock ?? this.minStock,
      maxStock: maxStock ?? this.maxStock,
      averageCost: averageCost ?? this.averageCost,
      emoji: emoji ?? this.emoji,
      barcode: barcode ?? this.barcode,
      suppliers: suppliers ?? this.suppliers,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
      lastPurchasePrice: lastPurchasePrice ?? this.lastPurchasePrice,
      lastPurchaseDate: lastPurchaseDate ?? this.lastPurchaseDate,
      lastSupplierId: lastSupplierId ?? this.lastSupplierId,
    );
  }

  // Pas de redéfinition de `==` : deux instances distinctes sont deux états
  // distincts.
  //
  // Une égalité fondée sur l'`id` seul paraissait tentante (« c'est le même
  // produit »), mais elle casse la réactivité : Riverpod ne notifie ses
  // auditeurs que si la nouvelle valeur est `!=` de l'ancienne. Un objet
  // modifié mais « égal » par son id laissait donc les écrans afficher l'état
  // précédent. L'identité d'entité est portée par `id`, comparé explicitement
  // là où c'est nécessaire — et par `rowKey` dans les tableaux.
}
