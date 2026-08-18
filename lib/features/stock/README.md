# Module Stock — guide du développeur

Ce document explique, étape par étape, comment le module Stock est construit
et pourquoi. C'est le **module de référence** : les modules Inventaire,
Achats et Personnel doivent suivre exactement la même organisation.

À lire avant de modifier quoi que ce soit ici, et avant de démarrer une
nouvelle feature.

---

## 1. Le modèle de données et ses relations

Avant de lire du code, il faut comprendre ce qu'on modélise. Tout le module
tourne autour d'une entité pivot, `Product`, à laquelle se rattachent quatre
autres.

```
              ProductCategory                     MeasurementUnit
              (Légumes, Épicerie…)                (kg, un., L…)
                      ▲                                   ▲
                      │ categoryId  N ─── 1               │ unit  N ─── 1
                      │                                   │
             ┌────────┴───────────────────────────────────┴────────┐
             │                      Product                        │
             │   currentStock · minStock · maxStock · unitPrice     │
             └────────┬────────────────────────────────┬───────────┘
                      │ 1 ─── N                        │ 1 ─── N
                      │ (embarqué dans l'objet)        │ (stocké à part)
                      ▼                                ▼
               ProductSupplier                   StockMovement
             (prix, réf., délai)          (date, type, quantité, user)
```

### Les cinq entités

| Entité | Fichier | Rôle |
|---|---|---|
| `Product` | `domain/entities/product.dart` | Le produit géré en stock — l'entité pivot |
| `ProductSupplier` | même fichier | Le lien entre un produit et un fournisseur, avec son prix |
| `StockMovement` | `stock_movement.dart` | Une entrée, une sortie ou une correction |
| `ProductCategory` | `product_category.dart` | Le regroupement (Légumes, Épicerie…) |
| `MeasurementUnit` | `measurement_unit.dart` | L'unité de mesure (kg, unité, litre…) |

### `Product` — quatre groupes de champs

```dart
// Identité
String id;  String name;  String emoji;  String? barcode;

// Classement
String categoryId;  String categoryName;  String unit;

// Niveaux — le cœur du module
double currentStock;  double minStock;  double maxStock;  double unitPrice;

// Contexte
List<ProductSupplier> suppliers;  String? notes;  DateTime? updatedAt;
```

Ces trois niveaux et ce prix suffisent à dériver tout ce que l'interface
affiche : `status`, `stockValue`, `quantityToOrder`, `fillRatio`. Aucun de
ces quatre résultats n'est stocké.

---

### Les décisions de modélisation, et pourquoi

**1. La catégorie est dénormalisée (`categoryId` + `categoryName`).**
Le produit porte les deux. L'`id` reste la source de vérité : c'est lui qui
sert au filtrage et aux agrégats. Le nom est une copie de confort. La vue la
plus fréquente du module est un tableau de 15 à 200 lignes affichant la
catégorie sur chaque ligne, et on ne veut pas chercher dans la liste des
catégories à chaque cellule rendue. Le prix à payer est connu : renommer une
catégorie devra propager le nouveau nom sur les produits concernés. C'est un
travail pour la couche `data`, pas pour l'interface.

**2. L'unité est un code (`String`), pas un objet imbriqué.**
`product.unit` vaut `'kg'` — exactement ce qui s'affiche dans les tableaux et
à côté des champs de saisie, donc le rendu ne coûte rien. `MeasurementUnit`
existe séparément pour les formulaires, où l'on veut le libellé complet
(« Kilogramme ») et la règle `allowsDecimals`. Les unités sont configurables
par l'établissement : c'est une donnée, pas une `enum`.

**3. `ProductSupplier` est une association, pas un fournisseur.**
C'est la décision la plus structurante du modèle. Un fournisseur n'a pas *un*
prix : il a un prix **pour un produit donné**. Le prix, la référence catalogue
et le délai appartiennent donc au couple (produit, fournisseur) et non au
fournisseur seul — d'où une entité de liaison qui porte ces attributs.

La fiche fournisseur complète (adresse, contact, conditions de paiement)
n'existe pas ici : elle appartiendra au module Achats, en phase 6.
`ProductSupplier` ne contient que ce que l'onglet « Fournisseurs » de la fiche
produit doit afficher, plus l'`id` qui permettra de faire le lien le moment
venu. Modéliser dès maintenant un `Supplier` complet dans le module Stock
aurait créé une entité que la phase 6 aurait dû défaire.

**4. Le fournisseur principal est un drapeau sur le lien, pas un champ du produit.**
`isPrimary` vit sur `ProductSupplier`, et non `Product.primarySupplierId` :
une seule source d'information, impossible à désynchroniser. Le getter
`primarySupplier` renvoie celui qui est marqué et retombe sur le premier de la
liste si aucun ne l'est — l'interface n'a ainsi jamais à traiter le cas
« des fournisseurs, mais aucun principal ».

**5. Les fournisseurs sont embarqués, les mouvements sont stockés à part.**
Deux relations 1—N traitées différemment, et c'est délibéré :

| | Fournisseurs | Mouvements |
|---|---|---|
| Volume | 1 à 3 par produit | des centaines, qui grossissent sans fin |
| Usage | toujours affichés avec le produit | consultés à la demande, dans un onglet |
| Conséquence | `List<ProductSupplier>` dans `Product` | `fetchMovements(productId)` séparé |

Charger la liste des produits ne doit jamais tirer l'historique complet. C'est
la raison d'être de `productMovementsProvider`, une `family` indexée par
identifiant de produit : seul l'historique de la fiche ouverte est chargé.

**6. La quantité d'un mouvement est signée.**
`+50` pour une entrée, `-20` pour une sortie. `MovementType` reste présent,
mais pour l'affichage et le filtrage — pas pour le calcul. Appliquer un
mouvement devient une addition, sans branchement :

```dart
final double updatedStock = product.currentStock + movement.quantity;
```

Et un futur rapport se réduit à une somme. La contrepartie : le signe et le
type doivent rester cohérents. Un seul endroit en est garant —
`registerMovement` — et c'est aussi le seul chemin autorisé pour faire varier
le stock.

**7. Le mouvement porte `user`, `date` et `reference`.**
Ce n'est pas décoratif : le cahier des charges impose de savoir *qui* a fait
*quoi* et *quand*. `reference` relie le mouvement à son origine
(« CMD-005 », « Vente », « INV-2024-005 »). C'est aujourd'hui une chaîne, ce
qui suffit à l'affichage ; quand les modules Achats et Inventaire existeront,
elle pourra devenir un identifiant typé.

**8. Le statut n'est pas un champ.**
Ni `isLow` ni `status` stockés : `Product.status` est calculé depuis
`currentStock` et `minStock`. Une valeur stockée serait un second endroit à
maintenir, donc un endroit qui finit par mentir. Le badge de la liste, la
jauge de la fiche, le compteur « stocks faibles » du tableau de bord et le
futur écran de réapprovisionnement lisent tous cette même définition.

**9. Les entités ne redéfinissent pas `==`.**
Deux instances distinctes sont deux états distincts. Une égalité fondée sur
l'`id` seul semblait pourtant naturelle — « c'est le même produit » — et c'est
ce qui avait été écrit au départ. C'était un bug : Riverpod ne notifie ses
auditeurs que si la nouvelle valeur est `!=` de l'ancienne, donc un produit
modifié mais « égal » par son `id` laissait le panneau de détail figé sur le
stock précédent après un mouvement.

L'identité d'entité est portée par `id`, comparé explicitement là où c'est
nécessaire (`_indexOf` dans le dépôt) et par `rowKey` dans les tableaux. La
fiche ouverte ne se referme pas pour autant : c'est
`selectedProductIdProvider` qui retient **l'identifiant**, et
`selectedProductProvider` qui relit l'objet à jour dans la liste — voir §4.3.
La règle vaut pour toutes les entités mutables du projet.

**10. Les entités sont immuables, avec `copyWith`.**
Tous les champs sont `final`. Une modification produit un nouvel objet, ce qui
rend les comparaisons d'état fiables et empêche un widget de modifier
silencieusement une donnée partagée.

**11. Ce qui est nullable l'est pour une raison.**
`barcode` (tous les produits ne sont pas étiquetés), `notes`, `reference`,
`updatedAt` (un produit tout juste créé n'a pas d'historique). Le reste est
obligatoire : un produit sans unité ni catégorie n'a pas de sens et ne doit
pas pouvoir exister.

**12. Le pictogramme est un emoji, pas une image.**
`emoji: '🍅'`. Rien à téléverser, rien à télécharger, rien à mettre en cache :
l'application doit rester utilisable hors connexion, et une URL d'image serait
un point de rupture pour un gain purement décoratif.

---

### Ce qui n'est délibérément pas modélisé ici

| Manque | Où cela ira |
|---|---|
| `Supplier` complet (contact, adresse, conditions) | Module Achats — phase 6 |
| Lien typé mouvement → commande / inventaire | Phases 5 et 6, en remplaçant `reference` |
| Lignes d'inventaire et écarts | Module Inventaire — phase 5 |
| Historique des prix d'achat | Après la V1 |
| Lots et dates de péremption | Hors périmètre V1 |

Le principe : chaque module possède ses propres entités et n'expose aux autres
que le minimum. Le module Stock ne doit pas devenir le dépotoir des entités de
toute l'application.

---

## 2. Ce que fait le module

| Écran | Contenu |
|---|---|
| Liste des produits | Recherche, onglets *Tous / Catégories / Stock faible*, tableau triable, scanner, création |
| Fiche produit | Stock actuel, jauge de niveau, alerte de réapprovisionnement, onglets *Mouvements / Informations / Fournisseurs* |
| Formulaire produit | Création et édition (pictogramme, catégorie, unité, seuils, code-barres, prix) |
| Formulaire mouvement | Entrée, sortie ou correction, avec aperçu du stock résultant |

---

## 3. Les trois couches

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

## 4. L'état, étape par étape

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

Et pour les écritures venues d'ailleurs :

```dart
Future<void> refreshProducts(Iterable<String> productIds);
```

À appeler quand un **autre module** a modifié le stock sans passer par ce
contrôleur — la validation d'un inventaire aujourd'hui, la réception d'une
commande demain. Elle invalide l'historique des produits nommés puis recharge
la liste. Ce contrôleur est propriétaire des caches du module Stock : les
autres modules annoncent seulement ce qu'ils ont touché, ils n'invalident
jamais eux-mêmes.

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

## 5. Le flux complet, écran par écran

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

## 6. Les règles à ne pas casser

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

6. **Ne jamais redéfinir `==` sur une entité mutable.**
   Riverpod s'en sert pour décider s'il doit notifier : une égalité partielle
   fige silencieusement l'interface. Pour identifier une entité, comparer son
   `id` explicitement ou passer `rowKey` au tableau.

7. **Les droits sont lus depuis la session.**
   `canManageCatalogProvider` masque *Nouveau produit*, *Modifier* et
   *Supprimer* pour un employé. Ne jamais tester `role == …` dans un widget :
   ajouter un getter à `SessionUser` si un nouveau droit est nécessaire.

---

## 7. Les widgets du module

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

## 8. Tests

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

## 9. Brancher le vrai backend, plus tard

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
