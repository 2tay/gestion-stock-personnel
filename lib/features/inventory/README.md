# Module Inventaire — guide du développeur

Ce document explique, étape par étape, comment le module Inventaire est
construit et pourquoi.

Il complète [le README du module Stock](../stock/README.md), qui reste la
référence pour l'organisation générale d'une feature. Ce qui est nouveau ici,
c'est que **deux modules se parlent** : valider un inventaire écrit dans le
stock. Le patron mis en place pour cela sera repris par le module Achats.

---

## 1. Le modèle de données et ses relations

```
                            Product (module Stock)
                                    │
                                    │  photographié à l'ouverture
                                    ▼
        ┌───────────────────────────────────────────────────┐
        │                    Inventory                      │
        │   reference · status · scope · createdAt          │
        └────────────────────────┬──────────────────────────┘
                                 │ 1 ─── N  (embarqué)
                                 ▼
                          InventoryLine
              theoreticalStock (figé) · unitPrice (figé)
                        countedStock (nullable)
                                 │
                                 │  à la validation, si écart
                                 ▼
                     StockMovement (ajustement)
```

### Les deux entités

| Entité | Fichier | Rôle |
|---|---|---|
| `Inventory` | `domain/entities/inventory.dart` | Une session de comptage sur un périmètre |
| `InventoryLine` | `inventory_line.dart` | Un produit dans cet inventaire |

`InventoryScope` (dans le même fichier que `Inventory`) décrit le périmètre :
`tous` ou `categorie`.

### `Inventory` — les champs

```dart
// Identité
String id;  String reference;      // INV-2024-007
DateTime createdAt;  String createdBy;

// Périmètre
InventoryScope scope;  String? categoryId;  String? categoryName;

// Cycle de vie
InventoryStatus status;
DateTime? closedAt;  DateTime? validatedAt;  String? validatedBy;

// Contenu
List<InventoryLine> lines;
```

Tout le reste est dérivé : `countedCount`, `remainingCount`, `progress`,
`variances`, `varianceCount`, `totalVarianceValue`, et les règles de
transition `isCountable`, `canClose`, `canValidate`, `isFinal`.

### Les décisions de modélisation, et pourquoi

**1. Le stock théorique est figé à l'ouverture.**
C'est la règle la plus importante du module. `InventoryLine.theoreticalStock`
est une **photo** du stock au moment où l'inventaire est créé, pas une lecture
en direct du produit.

Un comptage dure vingt minutes pendant lesquelles le service continue de
tourner : des sorties sont enregistrées, une livraison arrive. Si la colonne
« théorique » se recalculait, l'écart affiché changerait sous les yeux de la
personne qui compte, et le résultat serait faux. Le prix unitaire est figé
pour la même raison — l'écart valorisé doit rester celui du jour du comptage.

Un test verrouille ce comportement : `le stock théorique est figé à
l'ouverture` enregistre une sortie de 30 kg pendant le comptage et vérifie que
la ligne n'a pas bougé.

**2. « Non compté » n'est pas « compté à zéro ».**
`countedStock` est un `double?`. `null` signifie que personne n'a encore
touché à cette ligne ; `0` signifie qu'on a regardé l'étagère et qu'elle était
vide.

La distinction n'est pas cosmétique : à la validation, une ligne `null` est
**ignorée** alors qu'une ligne à `0` **vide le stock du produit**. Si les deux
valaient zéro, valider un inventaire partiel effacerait le stock de tout ce que
personne n'a compté. C'est le piège principal du module, et c'est pourquoi
`InlineNumberField` renvoie `null` quand on efface le contenu du champ.

**3. Les lignes sont embarquées dans l'inventaire.**
Contrairement aux mouvements de stock, qui sont chargés séparément, les lignes
vivent dans l'objet `Inventory`. Un inventaire a un nombre de lignes borné et
connu d'avance (le périmètre), et l'écran de comptage les affiche toutes : les
séparer n'apporterait rien et compliquerait le calcul de l'avancement.

**4. Le périmètre est un choix, pas une contrainte.**
Compter 182 références chaque semaine n'est pas réaliste en restauration.
L'inventaire tournant — les légumes le lundi, l'épicerie le jeudi — est
l'usage courant, d'où `InventoryScope.categorie`.

**5. Quatre statuts, une seule étape irréversible.**

```
brouillon ──▶ enCours ──▶ termine ──▶ valide
 (créé,       (au moins   (comptage    (écarts appliqués
  rien saisi)  une ligne)  figé)        au stock)
```

- `brouillon → enCours` : automatique, au premier comptage saisi.
- `enCours → termine` : bouton « Enregistrer le comptage ». Le comptage est
  figé, **mais le stock n'a pas encore bougé**. C'est ce palier qui permet à un
  manager de contrôler les écarts avant de les appliquer, et il justifie
  l'écart affiché en rouge ou vert dans la liste.
- `termine → enCours` : bouton « Rouvrir », si on a clôturé trop vite.
- `termine → valide` : **irréversible**. Les ajustements sont écrits dans le
  stock. Un inventaire validé ne peut plus être ni modifié ni supprimé.

**6. Les entités ne redéfinissent pas `==`.**
Même règle que dans le module Stock, et pour la même raison : Riverpod ne
notifie ses auditeurs que si la nouvelle valeur est `!=` de l'ancienne. Une
égalité fondée sur l'`id` figerait l'écran de comptage sur l'état précédent à
chaque saisie. L'identité passe par `id` comparé explicitement, et par
`rowKey` dans les tableaux.

---

## 2. Le point nouveau : deux modules qui se parlent

Le module Inventaire a besoin du module Stock à deux moments :

| Moment | Besoin | Sens |
|---|---|---|
| Ouverture | lire le stock des produits du périmètre | Stock → Inventaire |
| Validation | écrire un ajustement par écart | Inventaire → Stock |

Trois façons de le faire étaient possibles :

| Approche | Verdict |
|---|---|
| `InventoryRepository` appelle `InMemoryProductRepository` | Non — couplage à une implémentation |
| `InventoryRepository` dépend de `ProductRepository` | Le dépôt hériterait de tout le contrat Stock |
| **Un cas d'usage qui reçoit les deux dépôts** | **Retenu** |

D'où le dossier `domain/usecases/`, nouveau dans ce module :

```
domain/usecases/
├── create_inventory.dart     Stock → Inventaire  (photographier)
└── validate_inventory.dart   Inventaire → Stock  (appliquer les écarts)
```

Chacun reçoit les deux **interfaces** de dépôt dans son constructeur et
n'implémente qu'une seule règle métier. Ils ne connaissent ni Flutter, ni
Riverpod, ni aucune implémentation concrète — ils se testent donc directement,
sans monter un seul widget.

Le module Achats reprendra exactement ce patron en phase 6 : recevoir une
commande génère des entrées de stock.

### `CreateInventory`

```
fetchProducts()                       → module Stock
   filtrer selon le périmètre
   pour chaque produit, figer theoreticalStock et unitPrice
createInventory(lines, scope, …)      → module Inventaire
```

### `ValidateInventory`

Trois règles, et rien d'autre :

1. **Seules les lignes comptées produisent un mouvement.** `countedStock ==
   null` → ignorée, stock inchangé.
2. **Seuls les écarts non nuls produisent un mouvement.** Compter exactement le
   théorique n'écrit rien.
3. **Chaque ajustement est tracé** : type `ajustement`, quantité = l'écart
   signé, `reference` = la référence de l'inventaire, `user` = qui a validé.

Il renvoie un `InventoryValidationResult` (ajustements appliqués, lignes
ignorées, écart valorisé) qui alimente le message de confirmation affiché à
l'utilisateur.

Il refuse de s'exécuter si l'inventaire n'est pas au statut `termine` :
`canValidate` est vérifié dans le cas d'usage, pas seulement dans l'interface.

---

## 3. L'état

`presentation/controllers/inventory_providers.dart`, même organisation que le
module Stock.

### Source

```dart
inventoryRepositoryProvider   // seul point de branchement du backend
createInventoryProvider       // cas d'usage, câblé sur les deux dépôts
validateInventoryProvider     // idem
inventoryControllerProvider   // StateNotifier<AsyncValue<List<Inventory>>>
```

`InventoryController` expose six opérations :

```dart
Future<void>      load();
Future<Inventory> create({scope, categoryId, categoryName, createdBy});
Future<void>      saveCount({inventoryId, productId, countedStock});
Future<void>      close(inventoryId);     // → termine
Future<void>      reopen(inventoryId);    // → enCours
Future<InventoryValidationResult> validate(inventory, {validatedBy});
Future<void>      delete(inventoryId);
```

Deux détails qui comptent :

- **`saveCount` ne recharge pas la liste.** Il remplace l'inventaire concerné
  dans l'état local (`_replace`). Recharger à chaque quantité saisie serait
  inutilisable sur un inventaire de 200 lignes. Le dépôt en mémoire
  n'applique d'ailleurs aucune latence sur cette méthode : la saisie doit
  rester instantanée, y compris hors connexion.
- **`validate` recharge le module Stock.** Le stock vient de changer :
  `stockControllerProvider.load()` est appelé pour que la liste des produits
  reflète les ajustements.

### Filtres

Deux jeux de filtres indépendants, parce qu'il y a deux écrans :

```dart
inventoryQueryProvider   → InventoryQuery  (liste : recherche + statut)
visibleInventoriesProvider
inventoryCountersProvider

countingQueryProvider    → CountingQuery   (comptage : recherche + Tous /
visibleCountingLinesProvider                Non comptés / Écarts)
```

Comme dans le module Stock, `apply()` vit sur l'objet de requête : le filtrage
est du Dart pur, testable sans widget.

### Sélection

```dart
selectedInventoryIdProvider   // StateProvider<String?> — l'id
selectedInventoryProvider     // Provider<Inventory?>   — l'objet à jour
```

`null` = on est sur la liste ; non nul = on est dans le comptage.

---

## 4. Les écrans

```
InventoryPage
 ├─ selectedInventory == null → _InventoryListCard   (ListPageTemplate)
 └─ sinon                     → CountingScreen
                                 ├─ _CountingHeader   (avancement, actions)
                                 └─ _CountingTable    (ListPageTemplate)
```

**Pourquoi pas un `MasterDetailLayout` comme dans Stock ?** Parce qu'ouvrir un
inventaire, ce n'est pas consulter une fiche : c'est entrer dans une tâche. Le
comptage a besoin de toute la largeur de la tablette et de l'attention de
l'utilisateur. Les deux écrans se remplacent donc, avec une flèche de retour.

C'est une divergence assumée avec le module Stock, pas un oubli.

### Le flux de saisie

```
InlineNumberField (cellule « Stock réel »)
   validation à la sortie du champ ou sur Entrée — jamais à chaque frappe
   → saveCount(inventoryId, productId, valeur)
   → _replace() met à jour l'état local
   → l'écart, l'avancement et l'écart valorisé se recalculent
```

Le champ vide renvoie `null` : la ligne repasse en « non comptée ».

### Le scan

Scanner un code-barres **filtre la liste** sur le produit trouvé, au lieu de
sauter à sa ligne. Sur une tablette, isoler la ligne est plus fiable qu'un
défilement automatique, et le champ devient immédiatement atteignable.

---

## 5. Les règles à ne pas casser

1. **Ne jamais relire le stock d'un produit pour recalculer un théorique.**
   La photo prise à l'ouverture fait foi.
2. **Ne jamais traiter `null` comme `0`** dans un comptage.
3. **Le stock ne bouge qu'à la validation**, via `ValidateInventory`, jamais
   depuis un widget ni depuis le dépôt Inventaire.
4. **Un inventaire validé est immuable** : ni comptage, ni suppression.
5. **La logique inter-modules vit dans `usecases/`**, pas dans un dépôt ni
   dans un contrôleur.
6. **Ne jamais redéfinir `==` sur `Inventory` ou `InventoryLine`.**

---

## 6. Composants partagés créés pour ce module

Deux, tous deux dans `shared/` car le module Achats en aura besoin :

| Composant | Usage |
|---|---|
| `InlineNumberField` | Saisie numérique dans une cellule de tableau |
| `AppProgressBar` | Barre de progression fine (avancement, réception partielle) |

`StatusBadge.inventory()`, `Formatters.signedQuantity` et
`Formatters.signedMoney` existaient déjà : ils avaient été prévus en phase 1
et 3 pour ce module.

---

## 7. Tests

```bash
flutter test test/features/inventory/
```

- `inventory_domain_test.dart` — les règles métier sans interface : écart
  signé et valorisé, distinction non compté / compté à zéro, avancement,
  transitions de statut, périmètre, gel du stock théorique, et les trois
  règles de `ValidateInventory`. Dart pur.
- `inventory_page_test.dart` — les écrans : liste, filtres, ouverture du
  comptage, saisie d'une quantité, effacement d'une saisie, clôture,
  validation, création d'un inventaire par catégorie.

Comme pour le module Stock, un test de widget doit initialiser la locale et
surcharger **les deux** dépôts :

```dart
setUpAll(() => initializeDateFormatting(Formatters.locale));

ProviderScope(
  overrides: <Override>[
    inventoryRepositoryProvider.overrideWithValue(
      InMemoryInventoryRepository(latency: Duration.zero),
    ),
    productRepositoryProvider.overrideWithValue(
      InMemoryProductRepository(latency: Duration.zero),
    ),
  ],
  …
)
```

Les champs de comptage sont adressables par clé :
`ValueKey('count-<productId>')`.

---

## 8. Brancher le vrai backend, plus tard

Comme pour le module Stock, la couche `presentation/` ne bouge pas :

1. `data/models/inventory_model.dart` avec `fromJson` / `toJson`.
2. `data/repositories/api_inventory_repository.dart` implémentant
   `InventoryRepository`.
3. Une ligne à changer dans `inventory_providers.dart`.

Les cas d'usage ne changent pas non plus : ils ne connaissent que les
interfaces.

**Point d'attention pour le mode hors connexion.** Le comptage doit
fonctionner sans réseau — c'est explicitement demandé par le cahier des
charges. `saveCount` est déjà conçu pour cela : écriture locale immédiate,
sans latence ni attente réseau. L'implémentation locale (Drift) devra
conserver ce comportement et ne synchroniser qu'en arrière-plan. La
validation, elle, peut légitimement exiger une connexion : elle écrit dans le
stock et engage l'ensemble des tablettes.
