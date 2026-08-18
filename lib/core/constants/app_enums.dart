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

/// Cycle de vie d'une commande fournisseur.
enum OrderStatus { brouillon, enCours, partielle, recue, annulee }

/// État de pointage d'un employé.
enum AttendanceStatus { pointe, enPause, termine, absent }

/// Niveaux d'accès décrits dans le cahier des charges.
enum UserRole { patron, manager, employe }

/// Tonalité sémantique utilisée par les badges, alertes et indicateurs.
enum SemanticTone { success, warning, danger, info, neutral, primary }
