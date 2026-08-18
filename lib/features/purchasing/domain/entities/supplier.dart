/// Fournisseur de l'établissement.
///
/// C'est ici que vit la fiche complète. Le module Stock ne connaît, lui, que
/// `ProductSupplier` : le lien entre un produit et un fournisseur, avec son
/// prix et sa référence catalogue. Les deux se rejoignent par l'`id`.
///
/// Cette séparation était prévue depuis la phase 4 — Stock n'a pas eu besoin
/// d'être modifié pour que ce module existe.
class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    this.contactName,
    this.phone,
    this.email,
    this.address,
    this.paymentTerms,
    this.deliveryDays = 1,
    this.isActive = true,
    this.notes,
  });

  final String id;
  final String name;

  /// Interlocuteur habituel chez ce fournisseur.
  final String? contactName;

  final String? phone;
  final String? email;
  final String? address;

  /// Conditions de règlement : « 30 jours fin de mois », « Comptant »…
  final String? paymentTerms;

  /// Délai de livraison habituel, en jours. Sert à proposer une date de
  /// réception prévisionnelle à la création d'une commande.
  final int deliveryDays;

  /// Un fournisseur désactivé n'est plus proposé pour une nouvelle commande,
  /// mais reste visible dans l'historique des commandes passées.
  final bool isActive;

  final String? notes;

  /// Première ligne de contact affichable, pour les tableaux.
  String get contactLine {
    final List<String> parts = <String>[
      if (contactName != null && contactName!.isNotEmpty) contactName!,
      if (phone != null && phone!.isNotEmpty) phone!,
    ];
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  Supplier copyWith({
    String? name,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    String? paymentTerms,
    int? deliveryDays,
    bool? isActive,
    String? notes,
  }) {
    return Supplier(
      id: id,
      name: name ?? this.name,
      contactName: contactName ?? this.contactName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      deliveryDays: deliveryDays ?? this.deliveryDays,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
    );
  }

  // Pas de redéfinition de `==` : deux instances distinctes sont deux états
  // distincts, sans quoi Riverpod cesse de notifier. Voir le README du module
  // Stock, décision 9.
}
