# Module Stock — guide du développeur

Ce document explique, étape par étape, comment le module Stock est construit
et pourquoi. C'est le **module de référence** : les modules Inventaire,
Achats et Personnel doivent suivre exactement la même organisation.

À lire avant de modifier quoi que ce soit ici, et avant de démarrer une
nouvelle feature.

---

## 1. Ce que fait le module

| Écran | Contenu |
|---|---|
| Liste des produits | Recherche, onglets *Tous / Catégories / Stock faible*, tableau triable, scanner, création |
| Fiche produit | Stock actuel, jauge de niveau, alerte de réapprovisionnement, onglets *Mouvements / Informations / Fournisseurs* |
| Formulaire produit | Création et édition (pictogramme, catégorie, unité, seuils, code-barres, prix) |
| Formulaire mouvement | Entrée, sortie ou correction, avec aperçu du stock résultant |

---

## 2. Les trois couches

```
        ┌──────────────────────────────────────────────┐
        │  presentation/   pages, widgets, controllers │  ← Flutter + Riverpod
        └──────────────────┬───────────────────────────┘
                           │ ne connaît que l'interface
        ┌──────────────────▼───────────────────────────┐
        │  domain/         entities, repositories      │  ← Dart pur, zéro Flutter
        └──────────────────▲───────────────────────────┘
                           │ implémente l'interface
        ┌──────────────────┴───────────────────────────┐
        │  data/           fixtures, repositories      │  ← remplacé par l'API plus tard
        └──────────────────────────────────────────────┘
```

**La règle qui compte :** la flèche pointe toujours vers `domain/`.
`presentation/` n'importe jamais `data/`, sauf une seule ligne — celle qui
branche l'implémentation dans `productRepositoryProvider`. Le jour où le
backend arrive, on change cette ligne et rien d'autre.

### `domain/entities/`

Des objets immuables, sans dépendance à Flutter, qui portent les règles
métier dans leurs getters :

| Fichier | Contenu |
|---|---|
| `product.dart` | `Product` et `ProductSupplier` |
| `stock_movement.dart` | `StockMovement` — quantité **signée** |
| `product_category.dart` | `ProductCategory` |
| `measurement_unit.dart` | `MeasurementUnit` (kg, un., L…) |

Les règles vivent dans `Product`, pas dans les widgets :

```dart
StockStatus get status {
  if (currentStock <= 0) return StockStatus.rupture;
  if (currentStock <= minStock) return StockStatus.faible;
  return StockStatus.ok;
}

double get stockValue     => currentStock * unitPrice;
double get quantityToOrder => max(maxStock - currentStock, 0);
double get fillRatio       => (currentStock / maxStock).clamp(0, 1);
```

C'est important : un badge de statut, une jauge et un futur écran de
réapprovisionnement liront tous la **même** définition. Ne jamais
recalculer `currentStock <= minStock` dans un widget.

### `domain/repositories/product_repository.dart`

L'unique contrat d'accès aux données. Neuf méthodes, aucune implémentation :

```
fetchProducts()          fetchCategories()
fetchProduct(id)         fetchUnits()
findByBarcode(code)      fetchMovements(productId)
saveProduct(product)     registerMovement(movement)
deleteProduct(id)
```

### `data/`

- `fixtures/stock_fixtures.dart` — 15 produits, 5 catégories, 6 unités et un
  historique de mouvements. Les dates sont calculées à partir d'un
  `_today` fixe pour que le jeu de données reste stable d'une exécution à
  l'autre.
- `repositories/in_memory_product_repository.dart` — implémente le contrat
  au-dessus d'une `List<Product>` mutable, avec une **latence simulée de
  350 ms**. Cette latence est volontaire : elle rend les états de chargement
  visibles pendant le développement. Les tests l'annulent avec
  `InMemoryProductRepository(latency: Duration.zero)`.

Personne en dehors de `data/` n'importe `StockFixtures`.

---

## 3. L'état, étape par étape

Tout est dans `presentation/controllers/stock_providers.dart`. Il y a trois
familles de providers : **la source**, **les filtres**, **la sélection**.

### 3.1 La source de vérité

```dart
productRepositoryProvider   // Provider<ProductRepository> — le seul point
                            // de branchement du backend

stockControllerProvider     // StateNotifierProvider<StockController,
                            //   AsyncValue<List<Product>>>
```

`StockController` détient la liste complète et les quatre opérations qui la
modifient. Chacune se termine par un `load()`, donc **l'interface se
rafraîchit toute seule** — aucun écran n'a besoin de recharger à la main :

```dart
Future<void> load();                              // recharge tout
Future<void> save(Product product);               // crée ou met à jour
Future<void> delete(String productId);            // supprime + désélectionne
Future<void> registerMovement(StockMovement m);   // entrée / sortie / correction
```

`registerMovement` fait en plus `ref.invalidate(productMovementsProvider(id))`
pour que l'onglet Mouvements de la fiche se recharge lui aussi.

Trois providers annexes complètent la source :

```dart
categoriesProvider          // FutureProvider<List<ProductCategory>>
unitsProvider               // FutureProvider<List<MeasurementUnit>>
productMovementsProvider    // FutureProvider.family<List<StockMovement>, String>
```

### 3.2 Les filtres

```dart
stockQueryProvider          // StateNotifierProvider<StockQueryController, StockQuery>
visibleProductsProvider     // Provider<AsyncValue<List<Product>>>
```

`StockQuery` porte trois critères — `search`, `filter` (`StockFilter.tous` /
`categories` / `faible`) et `categoryId` — et **sait les appliquer
lui-même** :

```dart
List<Product> apply(List<Product> products) { … }
```

C'est délibéré : le filtrage est du Dart pur, testable sans monter le moindre
widget (voir `stock_domain_test.dart`).

`visibleProductsProvider` est la simple composition des deux :

```dart
ref.watch(stockControllerProvider).whenData((list) => query.apply(list));
```

**La page ne filtre jamais elle-même.** Elle lit `visibleProductsProvider`.

Deux providers dérivés alimentent l'affichage :

- `stockCountersProvider` → les compteurs des onglets (total, faibles, catégories)
- `categoryStatsProvider` → une ligne par catégorie (nombre de produits,
  produits à surveiller, valeur du stock) pour l'onglet *Catégories*

### 3.3 La sélection

```dart
selectedProductIdProvider   // StateProvider<String?>  — l'id, pas l'objet
selectedProductProvider     // Provider<Product?>      — résolution de l'id
```

On stocke **l'identifiant**, pas le produit. Ainsi, quand un mouvement
modifie le stock, la fiche ouverte affiche automatiquement la nouvelle valeur
sans qu'on ait à la rafraîchir : `selectedProductProvider` relit l'objet dans
la liste à jour.

---

## 4. Le flux complet, écran par écran

### Ouvrir la page

```
StockPage
 └─ MasterDetailLayout
     ├─ master : _ProductListCard   → ListPageTemplate (partagé)
     └─ detail : ProductDetailPanel → DetailPanel (partagé)
                 (null si aucun produit sélectionné)
```

`MasterDetailLayout` gère seul l'adaptation : côte à côte au-dessus de
1100 px, sinon le détail remplace la liste.

### Rechercher

```
SearchField (300 ms d'anti-rebond)
   → queryController.setSearch(value)
   → stockQueryProvider change
   → visibleProductsProvider recalcule
   → le tableau se reconstruit
```

### Changer d'onglet

`StockFilter.categories` est un cas particulier : la page rend un
`ListPageTemplate<CategoryStats, StockFilter>` au lieu d'un
`ListPageTemplate<Product, StockFilter>`. Même structure, autre type de
ligne. Cliquer une catégorie appelle `selectCategory(id)`, qui repasse en
`StockFilter.tous` avec `categoryId` renseigné — d'où la puce amovible
affichée à côté des boutons.

### Sélectionner un produit

```
clic sur une ligne
   → selectedProductIdProvider = p.id
   → selectedProductProvider résout l'objet
   → StockPage reconstruit avec un detail non nul
```

### Scanner un code-barres

```
ScannerSheet.show(context)          → code saisi ou scanné
  → repository.findByBarcode(code)
       ├─ trouvé   → selectedProductIdProvider = found.id
       └─ inconnu  → ConfirmDialog → ProductFormDialog(prefilledBarcode: code)
```

### Enregistrer un mouvement

```
MovementFormDialog
  → validation (quantité > 0 ; une sortie ne peut dépasser le stock)
  → stockController.registerMovement(StockMovement(id: '', …))
       → repository met à jour currentStock et ajoute la ligne d'historique
  → invalidate(productMovementsProvider) + load()
  → la liste, le badge de statut, la jauge et l'historique se remettent à jour
```

`id: ''` signale au dépôt qu'il doit générer l'identifiant.

---

## 5. Les règles à ne pas casser

1. **Le stock ne se modifie que par un mouvement.**
   Aucun écran n'écrit `currentStock` directement. C'est pourquoi le champ
   « Stock actuel » du formulaire est désactivé en mode édition : la
   traçabilité exige qu'on sache toujours *qui*, *quand*, *combien* et
   *pourquoi*. Seuls `registerMovement` et, plus tard, la validation d'un
   inventaire, font bouger la quantité.

2. **Le statut est calculé, jamais stocké.**
   `product.status` uniquement. Pas de champ `isLow` en base, pas de
   comparaison recopiée dans un widget.

3. **Le filtrage vit dans `StockQuery.apply`, pas dans la page.**
   Un nouveau critère de filtre s'ajoute là, et il est testable sans widget.

4. **Aucune couleur ni taille en dur.**
   Tout passe par `core/theme/`. Aucune date ni aucun montant formaté à la
   main : `Formatters.money`, `Formatters.quantity`, `Formatters.date`.

5. **Les composants génériques restent dans `shared/`.**
   `ListPageTemplate`, `AppDataTable`, `StatusBadge`, `DetailPanel`,
   `FormDialog`, `UnderlineTabs` ne connaissent pas `Product`. Si un widget
   du module devient utile ailleurs, il déménage dans `shared/` — il ne se
   duplique pas.

6. **Les droits sont lus depuis la session.**
   `canManageCatalogProvider` masque *Nouveau produit*, *Modifier* et
   *Supprimer* pour un employé. Ne jamais tester `role == …` dans un widget :
   ajouter un getter à `SessionUser` si un nouveau droit est nécessaire.

---

## 6. Les widgets du module

| Widget | Rôle |
|---|---|
| `ProductNameCell` / `ProductAvatar` | Cellule « Produit » : pictogramme + nom |
| `StockLevelBar` | Jauge 0 → stock max, avec le repère du seuil minimum |
| `ProductDetailPanel` | Fiche complète et ses trois onglets |
| `ProductFormDialog` | Création et édition d'un produit |
| `MovementFormDialog` | Saisie d'un mouvement de stock |

Ils sont tous **spécifiques au produit**. Tout ce qui ne l'est pas — tableau,
badge, dialogue, onglets — vient de `shared/`.

---

## 7. Tests

```bash
flutter test test/features/stock/
```

- `stock_domain_test.dart` — règles métier (`status`, `stockValue`,
  `quantityToOrder`), filtrage `StockQuery.apply`, et comportement du dépôt
  (une entrée augmente le stock, une sortie ne descend jamais sous zéro, la
  suppression retire aussi l'historique…). Dart pur, instantané.
- `stock_page_test.dart` — l'écran : affichage, onglets, sélection,
  changement d'onglet de la fiche, enregistrement d'un mouvement, recherche.

Deux points à connaître pour écrire un test de widget ici :

```dart
// 1. La locale doit être chargée : les tableaux affichent des dates.
setUpAll(() => initializeDateFormatting(Formatters.locale));

// 2. Injecter un dépôt sans latence.
ProviderScope(
  overrides: <Override>[
    productRepositoryProvider.overrideWithValue(
      InMemoryProductRepository(latency: Duration.zero),
    ),
  ],
  …
)
```

Et pour viser un champ précis plutôt que compter les `TextField` de l'écran,
utiliser les clés exportées — par exemple `quantityFieldKey` dans
`movement_form_dialog.dart`.

---

## 8. Brancher le vrai backend, plus tard

Rien dans `presentation/` ne bouge. La marche à suivre :

1. Créer `data/models/product_model.dart` avec `fromJson` / `toJson`.
2. Créer `data/repositories/api_product_repository.dart`, qui implémente
   `ProductRepository`.
3. Changer **une ligne** dans `stock_providers.dart` :

```dart
final Provider<ProductRepository> productRepositoryProvider =
    Provider<ProductRepository>((Ref ref) => ApiProductRepository(…));
```

4. Pour le mode hors connexion, glisser une implémentation locale (Drift) qui
   enveloppe l'API et rejoue les mouvements en attente à la reconnexion —
   toujours derrière la même interface.

C'est précisément à cela que sert la séparation des trois couches : le
travail du jour J tient dans un fichier et une ligne.
