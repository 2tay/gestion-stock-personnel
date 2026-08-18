import '../../../../core/constants/app_enums.dart';
import 'inventory_line.dart';

/// Périmètre d'un inventaire.
///
/// Compter les 182 produits à chaque fois est irréaliste en restauration :
/// l'usage courant est l'inventaire tournant, une catégorie à la fois.
enum InventoryScope {
  tous,
  categorie;

  String get label => switch (this) {
        InventoryScope.tous => 'Tous les produits',
        InventoryScope.categorie => 'Une catégorie',
      };
}

/// Un inventaire : une session de comptage sur un périmètre de produits.
///
/// Cycle de vie :
/// ```
/// brouillon ──▶ enCours ──▶ termine ──▶ valide
///  (créé)      (comptage)   (comptage    (écarts appliqués
///                            figé)        au stock, définitif)
/// ```
/// Le passage à `valide` est la seule étape irréversible : c'est elle qui
/// génère les mouvements d'ajustement dans le module Stock.
class Inventory {
  const Inventory({
    required this.id,
    required this.reference,
    required this.createdAt,
    required this.status,
    required this.scope,
    required this.lines,
    required this.createdBy,
    this.categoryId,
    this.categoryName,
    this.closedAt,
    this.validatedAt,
    this.validatedBy,
    this.note,
  });

  final String id;

  /// Référence lisible affichée partout : `INV-2024-007`.
  final String reference;

  final DateTime createdAt;
  final InventoryStatus status;
  final InventoryScope scope;

  /// Renseignés uniquement si [scope] vaut [InventoryScope.categorie].
  final String? categoryId;
  final String? categoryName;

  final List<InventoryLine> lines;
  final String createdBy;

  /// Date de clôture du comptage (passage à `termine`).
  final DateTime? closedAt;

  final DateTime? validatedAt;
  final String? validatedBy;
  final String? note;

  // --- Avancement --------------------------------------------------------

  int get totalCount => lines.length;

  int get countedCount => lines.where((InventoryLine l) => l.isCounted).length;

  int get remainingCount => totalCount - countedCount;

  /// Avancement entre 0 et 1, pour la barre de progression.
  double get progress => totalCount == 0 ? 0 : countedCount / totalCount;

  // --- Écarts ------------------------------------------------------------

  /// Lignes comptées dont la quantité diffère du théorique.
  List<InventoryLine> get variances =>
      lines.where((InventoryLine l) => l.hasVariance).toList();

  int get varianceCount => variances.length;

  /// Écart total valorisé, en MAD. C'est la colonne « Écart » de la liste.
  double get totalVarianceValue => lines.fold<double>(
        0,
        (double sum, InventoryLine l) => sum + l.varianceValue,
      );

  // --- Règles de transition ----------------------------------------------

  /// Le comptage est modifiable tant que l'inventaire n'est pas clos.
  bool get isCountable =>
      status == InventoryStatus.brouillon || status == InventoryStatus.enCours;

  /// On peut clore le comptage dès qu'au moins une ligne a été comptée.
  bool get canClose => isCountable && countedCount > 0;

  /// Seul un inventaire clos peut être validé.
  bool get canValidate => status == InventoryStatus.termine;

  /// Une fois validé, plus rien ne bouge.
  bool get isFinal => status == InventoryStatus.valide;

  /// Libellé du périmètre, affiché dans l'en-tête du comptage.
  String get scopeLabel => scope == InventoryScope.tous
      ? 'Tous les produits'
      : (categoryName ?? 'Catégorie');

  Inventory copyWith({
    InventoryStatus? status,
    List<InventoryLine>? lines,
    DateTime? closedAt,
    DateTime? validatedAt,
    String? validatedBy,
    String? note,
  }) {
    return Inventory(
      id: id,
      reference: reference,
      createdAt: createdAt,
      status: status ?? this.status,
      scope: scope,
      categoryId: categoryId,
      categoryName: categoryName,
      lines: lines ?? this.lines,
      createdBy: createdBy,
      closedAt: closedAt ?? this.closedAt,
      validatedAt: validatedAt ?? this.validatedAt,
      validatedBy: validatedBy ?? this.validatedBy,
      note: note ?? this.note,
    );
  }

  // Pas de redéfinition de `==` : deux instances distinctes sont deux états
  // distincts.
  //
  // Une égalité fondée sur l'`id` seul paraissait tentante (« c'est le même
  // inventaire »), mais elle casse la réactivité : Riverpod ne notifie ses
  // auditeurs que si la nouvelle valeur est `!=` de l'ancienne. Un objet
  // modifié mais « égal » par son id laissait donc les écrans afficher l'état
  // précédent. L'identité d'entité est portée par `id`, comparé explicitement
  // là où c'est nécessaire — et par `rowKey` dans les tableaux.
}
