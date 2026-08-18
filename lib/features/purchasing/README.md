# Module Courses & Achats — guide du développeur

Ce document explique comment le module Achats est construit et pourquoi.

Il suppose lus [le README du module Stock](../stock/README.md), référence pour
l'organisation d'une feature, et
[celui du module Inventaire](../inventory/README.md), qui a introduit le
patron `domain/usecases/` pour les règles qui traversent deux modules. Ce
module en est le **deuxième utilisateur** : recevoir une commande écrit dans
le stock, exactement comme valider un inventaire.

**État : phases 6a et 6b terminées.** Fournisseurs, commandes, réception,
et liste de courses avec génération automatique des commandes.

---

## 1. Le modèle de données et ses relations

```
                          Supplier                     Product (module Stock)
                   (fiche complète : contact,                    │
                    conditions, délai)                           │
                            ▲                                    │
                            │ supplierId  N ─── 1                │
                            │                                    │
             ┌──────────────┴────────────────────────┐           │
             │             PurchaseOrder             │           │
             │   reference · lifecycle · createdAt   │           │
             └──────────────┬────────────────────────┘           │
                            │ 1 ─── N  (embarqué)                │
                            ▼                     productId  N ──┘
                        OrderLine
        quantityOrdered · quantityReceived · unitPrice (figé)
                            │
                            │  à la réception, si écart
                            ▼
                  StockMovement (entrée / ajustement)
```

### Les entités

| Entité | Fichier | Rôle |
|---|---|---|
| `Supplier` | `domain/entities/supplier.dart` | La fiche fournisseur complète |
| `PurchaseOrder` | `purchase_order.dart` | Une commande passée à un fournisseur |
| `OrderLine` | même fichier | Un produit dans cette commande |
| `ShoppingItem` | `shopping_item.dart` | Une proposition de commande, pas un produit |
| `ShoppingList` | même fichier | Le résultat du calcul, avec ses compteurs |

`OrderLifecycle` (même fichier que `PurchaseOrder`) porte les décisions
explicites de l'utilisateur.

### Les décisions de modélisation, et pourquoi

**1. `Supplier` naît ici, et le module Stock n'a pas bougé.**
Depuis la phase 4, Stock embarque `ProductSupplier` : le lien entre un produit
et un fournisseur, avec son prix et sa référence catalogue. La fiche complète
— contact, adresse, conditions de règlement, délai — vit ici, et les deux se
rejoignent par l'`id`.

C'était annoncé dans le README du module Stock, et c'est la preuve que le
découpage tenait : **aucun fichier du module Stock n'a été modifié** pour que
ce module existe.

Le nom du fournisseur est dénormalisé sur la commande (`supplierName`), même
raison que `categoryName` sur un produit : la liste des commandes l'affiche
sur chaque ligne.

**2. Le statut affiché est calculé, le cycle de vie est stocké.**
Ce sont deux questions différentes, et les confondre serait la source de bug
classique de ce module :

| Question | Réponse | Où |
|---|---|---|
| Qu'est-ce que l'utilisateur a décidé ? | brouillon / ouverte / annulée / soldée | `OrderLifecycle`, **stocké** |
| Où en est la livraison ? | En cours / Partielle / Reçue | `PurchaseOrder.status`, **calculé** |

Personne ne « met » une commande en partielle : elle l'est parce qu'une partie
est arrivée. Stocker ce statut créerait un second endroit à tenir à jour, donc
un endroit qui finit par mentir — même raisonnement que `Product.status`.

`OrderStatus.soldee` a été ajouté à l'énumération partagée pour cette raison :
une commande soldée n'est pas « reçue », et l'afficher comme telle serait faux.

**3. `quantityReceived` est un cumul, et c'est ce qui rend la réception
délicate.**
La ligne stocke le total reçu depuis le début, pas la dernière livraison —
c'est ce que l'utilisateur veut voir (« 40 sur 50 »). Mais le mouvement de
stock, lui, ne doit porter que ce qui vient d'arriver. Voir §2.

**4. Le prix unitaire est figé à la commande.**
C'est le prix négocié, qui peut différer du dernier prix d'achat connu du
produit. Il sert à valoriser la ligne et devient, à la réception, le nouveau
prix de référence du produit.

**5. Deux totaux, pas un.**
`orderedTotal` est ce qui a été engagé auprès du fournisseur ; `receivedTotal`
est ce qui a réellement été livré, donc ce qui sera facturé. La liste affiche
le premier, le détail totalise les deux. La maquette montrait les deux sans le
dire : 570,00 MAD en liste pour CMD-005, 450,00 MAD au bas du détail.

**6. Les entités ne redéfinissent pas `==`.**
Même règle et même raison que dans les deux autres modules.

---

## 2. La réception : la règle qui compte

`domain/usecases/receive_order.dart`. Quatre règles, et rien d'autre.

**On écrit l'écart, jamais le cumul.**

```
saisie utilisateur : « reçu 50 sur 50 »   (cumul)
ligne en base      : quantityReceived = 40
                     ↓
delta = 50 − 40 = 10
mouvement de stock : entrée de +10
```

Sans cela, recevoir 40 puis compléter à 50 ajouterait 90 au stock. C'est la
même leçon que l'ajustement relatif du module Inventaire, et elle a son test :
`deux réceptions successives n'additionnent pas le cumul`.

**Une correction à la baisse est un ajustement, pas une entrée.**
Si on s'est trompé et qu'on ramène 40 à 35, le stock baisse de 5 avec le type
`ajustement` et la note « Correction de réception ». Une entrée négative
n'aurait aucun sens dans l'historique du produit.

**Le prix d'achat de référence du produit suit celui de la commande.**
`Product.unitPrice` est défini comme le dernier prix d'achat et sert au calcul
de la valeur du stock. Recevoir à un nouveau prix le met donc à jour — ce qui
fait bouger la valorisation, et c'est voulu. `repricedProductIds` remonte la
liste des produits concernés pour pouvoir l'annoncer à l'utilisateur.

**Chaque mouvement porte la référence de la commande**, sa date et son
utilisateur.

### Prévenir le module Stock

`OrderReceptionResult.touchedProductIds` réunit les produits reçus, corrigés
et re-tarifés. `OrderController.receive` appelle ensuite :

```dart
stockController.refreshProducts(result.touchedProductIds);
```

Recharger la liste des produits ne suffirait pas : l'historique des mouvements
est mis en cache par produit. C'est exactement le bug qui avait été trouvé sur
la validation d'inventaire, et la méthode `refreshProducts` existe depuis pour
que le module Stock reste propriétaire de ses caches.

---

## 3. La liste de courses

`domain/usecases/build_shopping_list.dart`. Troisième cas d'usage
inter-modules du projet, et le premier à croiser **trois** sources : les
produits (Stock), les commandes en cours (Achats) et les fournisseurs
(Achats).

### Trois règles

**1. On part du seuil, pas du vide.** Un produit entre dans la liste dès que
son stock passe sous `minStock`, et la quantité proposée est celle qui le
ramène à `maxStock` — c'est `Product.quantityToOrder`, que le module Stock
calcule depuis la phase 4. Rien de nouveau n'a été ajouté au produit.

**2. Ce qui est déjà en route ne se recommande pas.**

```
Riz 10kg : stock 38, seuil 40, maximum 100
   besoin brut          = 100 − 38 = 62
   déjà commandé (CMD-004, non livré) = 3
   quantité proposée    = 59
```

Sans cette déduction, on recommanderait les mêmes produits chaque jour tant
que la livraison n'est pas arrivée. Un produit dont le manque est
**entièrement** couvert sort de la liste ; `coveredByPendingOrders` les
compte pour pouvoir l'expliquer à l'écran plutôt que de les faire disparaître
sans raison apparente.

Seules les commandes `ouverte` comptent : une commande annulée ou soldée
n'apportera plus rien, et son reliquat revient donc à la liste.

**3. Le fournisseur principal est une proposition, pas une contrainte.** Il
est retenu par défaut, mais toutes les alternatives connues du produit sont
fournies (`supplierOptions`) pour qu'une ligne puisse basculer avant
génération — le prix suit alors celui du nouveau fournisseur.

### `ShoppingItem` n'est pas un produit

C'est un **arbitrage en cours** : quantité, fournisseur et case à cocher sont
modifiables sans que rien ne soit écrit. Ni le catalogue ni les commandes ne
bougent avant `generateOrders`. C'est pourquoi cette entité vit dans le module
Achats et non dans Stock, et pourquoi elle ne référence pas `Product`.

### La génération

`ShoppingListController.generateOrders` regroupe les lignes cochées par
fournisseur et crée **une commande par fournisseur**. `onlySupplierId` permet
de n'en générer qu'une, depuis le bouton d'un groupe.

Après génération, la liste est recalculée : les produits commandés en sortent
d'eux-mêmes, puisque la quantité en attente est déduite du besoin. Aucune
gestion d'état spéciale n'a été nécessaire — c'est la règle 2 qui s'en charge.

Un produit sans fournisseur reste affiché, dans un groupe « Sans
fournisseur » placé en dernier, avec une invitation à lui en associer un. Il
ne peut pas être commandé, et c'est visible.

---

## 4. Annulation et solde

| Situation | Action possible | Effet |
|---|---|---|
| Rien reçu | **Annuler** | La commande passe en `annulee`. Le stock n'est pas touché. |
| Partiellement reçue | **Solder** | La commande passe en `soldee`. Le reliquat est abandonné, ce qui est arrivé reste en stock. |
| Entièrement reçue | — | Rien à faire. |

On n'annule pas une commande qui a fait entrer de la marchandise : elle fait
partie de l'historique du stock, et les mouvements qu'elle a produits portent
sa référence. Pour la même raison, `Supprimer` est désactivé dès qu'une
quantité a été reçue, et un fournisseur ayant des commandes ne se supprime pas
— on le désactive (`isActive`), ce qui le retire des nouvelles commandes sans
casser l'historique.

Les lignes se figent dès la première réception (`isEditable`) : modifier une
quantité commandée après coup rendrait les écarts incompréhensibles.

---

## 5. L'état

`presentation/controllers/purchasing_providers.dart`, deux contrôleurs :

```dart
supplierRepositoryProvider        purchaseOrderRepositoryProvider
receiveOrderProvider              // réception : Achats → Stock
buildShoppingListProvider         // liste de courses : Stock + Achats → Achats

shoppingListControllerProvider    // AsyncValue<ShoppingList>
shoppingGroupsProvider            // regroupée par fournisseur

supplierControllerProvider        // AsyncValue<List<Supplier>>
orderControllerProvider           // AsyncValue<List<PurchaseOrder>>

orderQueryProvider                // recherche + onglets
visibleOrdersProvider
orderCountersProvider

activeSuppliersProvider           // fournisseurs proposables à la commande
orderCountBySupplierProvider      // pour le tableau des fournisseurs

purchasingSectionProvider         // Commandes | Fournisseurs
selectedOrderIdProvider / selectedOrderProvider
```

Comme ailleurs : `OrderQuery.apply` fait le filtrage en Dart pur, la page ne
filtre jamais elle-même, et la sélection retient **l'identifiant**.

---

## 6. Les écrans

```
PurchasingPage
 ├─ UnderlineTabs : À commander | Commandes | Fournisseurs
 ├─ À commander  → ShoppingListSection  (une carte par fournisseur)
 ├─ Commandes    → MasterDetailLayout
 │                  ├─ _OrderListCard   (ListPageTemplate)
 │                  └─ OrderDetailPanel (DetailPanel)
 └─ Fournisseurs → SuppliersSection     (ListPageTemplate)
```

Trois sections plutôt que trois entrées de rail : le rail a été dimensionné
pour sept entrées et la maquette le montre ainsi.

### La saisie de réception est un brouillon

Différence assumée avec l'écran de comptage d'inventaire :

| | Comptage d'inventaire | Réception de commande |
|---|---|---|
| Enregistrement | à chaque quantité saisie | au clic sur « Enregistrer la réception » |
| Pourquoi | un comptage dure longtemps, on ne doit rien perdre | une réception est un acte qui engage le stock et le fournisseur |

Les quantités saisies vivent donc dans un `Map<String, double> _draft` local
au panneau, et le bouton reste inactif tant que rien n'a changé. « Tout
recevoir » remplit le brouillon sans rien écrire.

---

## 7. Composants partagés

**Aucun nouveau composant n'a été nécessaire.** C'est le signe que le design
system est mature :

| Besoin | Composant existant | Créé pour |
|---|---|---|
| Colonne « Qté reçue » éditable | `InlineNumberField` | le comptage d'inventaire (phase 5) |
| Avancement de la réception | `AppProgressBar` | idem |
| Badges de statut de commande | `StatusBadge.order()` | ce module, écrit en phase 3 |
| Sections du module | `UnderlineTabs` | la fiche produit (phase 4) |

Seul ajout : `OrderStatus.soldee` dans l'énumération partagée.

---

## 8. Tests

```bash
flutter test test/features/purchasing/
```

- `purchasing_domain_test.dart` — statut déduit des lignes, totaux engagé et
  livré, règles d'annulation et de solde, et surtout les quatre règles de
  `ReceiveOrder` : écart et non cumul, réceptions successives, correction à la
  baisse, mise à jour du prix.
- `purchasing_page_test.dart` — les écrans, y compris un test qui navigue
  jusqu'au module Stock **dans le même `ProviderScope`** pour vérifier que la
  réception s'y répercute : quantité, mouvement et référence de commande.
- `shopping_list_test.dart` — le calcul de la liste (seuil, déduction des
  quantités en attente, commande annulée qui rend le besoin, produit sans
  fournisseur, sortie de liste après réception) et la génération des
  commandes.

Les fixtures reproduisent les cinq commandes de la maquette avec leurs
montants exacts ; deux tests le verrouillent, pour qu'une modification des
données de démonstration ne passe pas inaperçue.

---

## 9. Pour la suite

Le tableau de bord (phase 8) réutilisera `shoppingListControllerProvider`
pour sa carte « Produits à commander » : le calcul est déjà fait, il n'aura
qu'à en afficher les premières lignes.

Reste hors périmètre V1, conformément au cahier des charges : prévision de
consommation, recommandations automatiques de commande et détection des
risques de rupture. La liste de courses actuelle en est la brique de base.
