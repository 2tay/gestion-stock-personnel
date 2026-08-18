/// Énumérations partagées de l'interface.
///
/// Elles décrivent des états métier affichés dans plusieurs modules ; le
/// mapping vers une couleur/un libellé se fait dans `StatusBadge`.
library;

/// Statut de niveau de stock d'un produit.
enum StockStatus { ok, faible, rupture }

/// Type de mouvement de stock.
enum MovementType { entree, sortie, ajustement }

/// Cycle de vie d'un inventaire.
enum InventoryStatus { brouillon, enCours, termine, valide }

/// Statut d'une commande fournisseur, tel qu'il est **affiché**.
///
/// Il est calculé à partir des lignes (voir `PurchaseOrder.status`) et n'est
/// jamais stocké : une commande dont toutes les lignes sont reçues est
/// « Reçue », point. Seuls `brouillon`, `annulee` et `soldee` traduisent une
/// décision explicite de l'utilisateur.
enum OrderStatus {
  brouillon,
  enCours,
  partielle,
  recue,

  /// Commande close alors qu'il restait des quantités à recevoir : le
  /// reliquat est abandonné, ce qui a déjà été reçu est conservé.
  soldee,

  annulee,
}

/// État de pointage d'un employé.
enum AttendanceStatus { pointe, enPause, termine, absent }

/// Niveaux d'accès décrits dans le cahier des charges.
enum UserRole { patron, manager, employe }

/// Tonalité sémantique utilisée par les badges, alertes et indicateurs.
enum SemanticTone { success, warning, danger, info, neutral, primary }
