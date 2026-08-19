# Feuille de route — où on en est, ce qui reste

Document de reprise. À lire en premier au début d'une session de travail : il
dit ce qui est fait, ce qui reste, et surtout **les règles acquises en chemin**
qu'il ne faut pas redécouvrir à la dure.

*Dernière mise à jour : 19 août 2026 — fin de la phase 6, phase 6c ajoutée.*

---

## 1. État actuel

| Phase | Contenu | État |
|---|---|---|
| 0 | Fondations : projet, dépendances, structure, lints, i18n | ✅ |
| 1 | Design system : tokens, thème, atomes | ✅ |
| 2 | Coque de navigation : rail, routeur, contrôle d'accès | ✅ |
| 3 | Composants transverses : tableau, templates, dialogues | ✅ |
| 4 | Module **Stock** | ✅ |
| 5 | Module **Inventaire** | ✅ |
| 6 | Module **Achats** (fournisseurs, commandes, réception, liste de courses) | ✅ |
| **6c** | **Prix d'achat : historique fournisseur, coût réel, valorisation CUMP** | ⬜ **suivant** |
| 7 | Module Personnel | ⬜ |
| 8 | Tableau de bord | ⬜ |
| 9 | Rapports & analyses | ⬜ |
| 10 | Authentification réelle, droits, paramètres | ⬜ |
| 11 | Finitions : hors connexion, synchronisation, i18n, tests | ⬜ |

**Ce qui tourne aujourd'hui**, sur données de démonstration en mémoire :
les trois modules métier Stock, Inventaire et Achats, avec les trois
opérations qui traversent les modules — valider un inventaire écrit des
ajustements de stock, recevoir une commande y écrit des entrées, et la liste
de courses lit les deux.

**Ce qui n'existe pas encore** : aucun backend, aucune persistance (tout
repart des fixtures au redémarrage), aucune authentification réelle, aucun
graphique.

**Ce qui est faux aujourd'hui** : la valorisation du stock. Voir la phase 6c
ci-dessous — à traiter **avant** la phase 7, tant que les données sont encore
des fixtures.

Vérification de bonne santé : `flutter analyze` sans aucune remontée,
`flutter test` à 136 tests verts, `flutter build windows --debug` qui passe.

---

## 2. Les règles acquises — à ne pas redécouvrir

Chacune vient d'un vrai bug ou d'un vrai arbitrage. Les ignorer coûtera du
temps.

**Ne jamais redéfinir `==` sur une entité mutable.** Riverpod ne notifie ses
auditeurs que si la nouvelle valeur est `!=` de l'ancienne. Une égalité
fondée sur l'`id` seul — pourtant tentante — fige silencieusement l'écran sur
l'état précédent. C'est arrivé sur `Product` et ça a laissé la fiche produit
périmée après un mouvement. L'identité passe par `id` comparé explicitement,
et par `rowKey` dans les tableaux.

**Après avoir écrit dans un autre module, le prévenir explicitement.** Le
module propriétaire est seul à savoir ce qu'il doit invalider :
`StockController.refreshProducts(ids)` existe pour ça. Recharger la liste ne
suffit pas — l'historique des mouvements est mis en cache par produit et
resterait périmé. Un cas d'usage qui touche un autre module doit **renvoyer
les identifiants concernés** dans son résultat.

**Écrire l'écart, jamais le cumul.** L'interface saisit une valeur cumulée
(« 40 sur 50 » reçus, « 95 » comptés) parce que c'est ce qui fait sens pour
l'utilisateur. Le mouvement de stock, lui, ne porte que la différence. Sinon
une deuxième saisie double le stock. Vrai pour la réception comme pour
l'inventaire.

**Ce qui se déduit ne se stocke pas.** `Product.status`,
`PurchaseOrder.status`, l'avancement d'un inventaire : tout est calculé. Un
statut stocké est un second endroit à tenir à jour, donc un endroit qui finit
par mentir. Seules les **décisions de l'utilisateur** sont stockées
(`OrderLifecycle`, `InventoryStatus`).

**`null` n'est pas `0`.** Une ligne d'inventaire non comptée ne produit aucun
ajustement ; comptée à zéro, elle vide le stock. Confondre les deux effacerait
le stock de tout ce que personne n'a compté.

**Le stock ne bouge que par un mouvement enregistré**, avec sa quantité, sa
raison, sa date et son utilisateur. Aucun écran n'écrit `currentStock`.

**La logique inter-modules vit dans `domain/usecases/`**, jamais dans un dépôt
ni dans un contrôleur. Le cas d'usage reçoit les **interfaces** de dépôt et se
teste sans monter un widget. Trois exemples en place : `ValidateInventory`,
`ReceiveOrder`, `BuildShoppingList`.

**Un test qui ne monte qu'un module ne prouve rien sur la cohérence.** Pour
les opérations qui traversent, monter les deux modules dans un même
`ProviderScope` et naviguer entre eux — voir
`test/features/inventory/inventory_stock_sync_test.dart`.

**Les débordements de mise en page sont des bugs.** Les tests de widgets les
font échouer, et c'est voulu : ils se produiraient sur une tablette 10". Les
corriger **dans le composant partagé**, pas dans l'écran appelant.

**Deux réflexes avant d'écrire un widget** : ouvrir `/design-system`, et
vérifier qu'un composant de `shared/` ne fait pas déjà le travail. Les phases
5 et 6 n'ont eu besoin d'aucun composant partagé supplémentaire.

---

## 3. Phase 6c — Prix d'achat et valorisation du stock

**À faire avant la phase 7.** Correction d'un défaut de modélisation, pas une
nouvelle fonctionnalité. Le coût est faible tant que tout est en fixtures ; il
devient une migration de données dès qu'un backend existe — et les anciens
prix nécessaires pour la reconstruire auront déjà été écrasés.

### Le défaut

`Product.unitPrice` est un champ unique, écrasé à chaque réception
(`ReceiveOrder`, règle 3). Trois conséquences :

```
100 kg de riz achetés à 12 MAD      → valeur 1 200 MAD   ✅
+ 20 kg reçus à 18 MAD              → unitPrice = 18, le 12 est perdu
                                    → valeur 120 × 18 = 2 160 MAD   ❌
```

Le stock déjà détenu est revalorisé au dernier prix : 600 MAD apparaissent de
nulle part. La somme réellement dépensée est 1 560 MAD.

Deux pertes s'ajoutent :

- `ProductSupplier.unitPrice` est également un champ unique. Quand un
  fournisseur augmente, l'ancien tarif disparaît — la phase 9 ne pourra pas
  tracer l'évolution des prix.
- `StockMovement` ne porte aucun prix. Une fois `unitPrice` écrasé, ce qu'a
  coûté une entrée passée n'existe plus nulle part.

### Trois prix, pas un

Le mot « prix » recouvre trois notions de cycles de vie différents :

| Notion | Question | Nature | Règle |
|---|---|---|---|
| **Tarif fournisseur** | « Combien Métro facture la farine *aujourd'hui* ? » | Prospective, par fournisseur | Versionné, jamais écrasé |
| **Prix d'achat réel** | « Combien a-t-on payé sur CMD-004 le 12 août ? » | Fait historique | Figé à l'écriture |
| **Coût de valorisation** | « Que valent les 120 kg en réserve ? » | Calculé par une méthode | Recalculé, jamais saisi |

**Règle générale : on n'écrase jamais un fait, seulement un pointeur vers
« l'actuel ».**

### Méthode de valorisation retenue : CUMP

Coût unitaire moyen pondéré, recalculé à chaque entrée :

```
nouveau CUMP = (stock × CUMP + quantité reçue × prix payé) / (stock + quantité reçue)
             = (100 × 12 + 20 × 18) / 120
             = 1 560 / 120 = 13 MAD

valeur du stock = 120 × 13 = 1 560 MAD   ✅ exactement ce qui a été payé
```

Standard comptable au Maroc comme en France, et un seul nombre stocké par
produit. FIFO par lots serait plus exact — et serait la base d'un suivi des
DLC — mais complique chaque sortie et chaque ajustement. Comme le prix est
porté par chaque mouvement (étape 1 ci-dessous), une migration vers FIFO
resterait possible plus tard sans perte de données.

**Note sur la règle « l'état dérivé ne se stocke pas ».** Le CUMP est stocké
sur `Product` et ce n'est pas une entorse : il ne dérive pas de l'état
courant mais d'une **suite ordonnée d'événements**. Il est impossible de le
recalculer à partir de `currentStock` et des tarifs du jour — seulement en
rejouant l'historique des mouvements. Stocké, donc, avec une fonction de
recalcul depuis les mouvements comme filet de sécurité.

### Plan d'implémentation, dans l'ordre

Chaque étape laisse le projet compilable et les tests verts.

**1. Le prix sur le mouvement.** ✅ **Fait le 19 août 2026.** `unitCost` et
`supplierId` ajoutés à `StockMovement`, figés à l'écriture. `ReceiveOrder`
renseigne le prix de la ligne de commande et le fournisseur ; `ValidateInventory`
renseigne le prix figé de la ligne d'inventaire. `unitCost` est nullable et
`null` signifie « inconnu », jamais « gratuit » — d'où `totalCost` qui renvoie
`double?`. Les fixtures achètent la tomate à deux prix différents (5,80 puis
6,20) pour que l'étape 4 ait un vrai calcul à faire. `InMemoryProductRepository`
utilise désormais `copyWith` au lieu d'une reconstruction champ par champ, qui
perdait silencieusement tout champ nouvellement ajouté.

Les mouvements saisis à la main n'ont pas encore de prix : le champ du
formulaire viendra à l'étape 8.

**2. Le tarif fournisseur versionné.** ✅ **Fait le 19 août 2026.**
`ProductSupplier` porte désormais une liste de `SupplierPrice`
(`unitPrice`, `validFrom`, `source`, `note`), du plus récent au plus ancien.
`unitPrice` est devenu un **getter** sur la première ligne, ce qui a laissé
tous les appelants existants intacts. `withPrice()` ajoute sans effacer, et
ignore un prix identique au tarif en vigueur. `priceOn(date)` retrouve le
tarif applicable à une date passée ; `priceChange` et `priceChangeRatio`
renvoient `null` — jamais 0 — quand il n'y a pas d'antériorité.

`validFrom` est nullable : `null` = tarif d'origine de date inconnue, trié
comme le plus ancien. `ProductRepository.recordSupplierPrice()` persiste
l'ajout et refuse un fournisseur non associé au produit. La fiche produit
gagne une colonne « Évolution » qui affiche la variation, ou « — » à défaut
d'historique.

Effet de bord assumé : `ProductSupplier` n'est plus `const`, l'historique
étant construit dans le constructeur. Les fixtures et tests concernés ont
perdu leur `const`.

**3. Le CUMP sur le produit.** ✅ **Fait le 19 août 2026.**
`Product.unitPrice` a disparu au profit de :

- `averageCost` — la valorisation, écrite **uniquement** par le cas d'usage de
  réception (branchement à l'étape 4) ;
- `lastPurchasePrice`, `lastPurchaseDate`, `lastSupplierId` — informatifs,
  nullables, pour la fiche produit. `null` = jamais acheté, pas gratuit.

`stockValue` est devenu `currentStock × averageCost`. `CreateInventory` fige
désormais `averageCost` (ce qui règle par avance une partie de l'étape 6) et
la liste de courses s'y replie quand un produit n'a aucun fournisseur. La
fiche produit affiche « Coût unitaire moyen » et « Dernier prix payé » côte à
côte — deux nombres différents, et c'est le but. Le formulaire produit ne
propose plus « Prix d'achat unitaire » mais « Coût unitaire moyen ».

**État intermédiaire assumé :** la réception consigne le dernier prix payé
mais ne recalcule pas encore `averageCost`. Un test verrouille ce point pour
qu'il ne soit pas « corrigé » par un écrasement — c'était le bug d'origine.

**4. `ReceiveOrder`, règle 3 réécrite.** ✅ **Fait le 19 août 2026.**
Le calcul lui-même vit dans `Product.averageCostAfter({quantity, unitPrice})`,
parce qu'il relève du stock et non des achats — et il est ainsi testable sans
commande ni dépôt. `ReceiveOrder` lit le produit **avant** le mouvement (c'est
le stock d'avant qui pondère l'ancien coût), calcule, puis enregistre.

Une seule formule couvre l'entrée et la correction : une quantité négative au
prix de l'entrée d'origine restitue exactement le coût moyen d'avant. C'est
`StockMovement.unitCost`, posé à l'étape 1, qui rend cette réversibilité
possible.

Trois cas limites, tous rendus au coût le plus honnête disponible plutôt qu'à
une division impossible : stock nul avant une entrée (la marchandise reçue
fixe seule le coût), stock nul après (on conserve le dernier coût connu),
valeur totale négative (idem). Une correction ne réécrit pas
`lastPurchasePrice` : la livraison a bien eu lieu à ce prix-là.

**5. Le tarif ne se met plus à jour en silence.** ✅ **Fait le 19 août 2026.**
`ReceiveOrder` constate les écarts dans `priceDiscrepancies`
(`SupplierPriceDiscrepancy` : produit, fournisseur, prix payé, tarif connu,
écart en valeur et en proportion) et n'écrit rien.
`SupplierPriceUpdateDialog` pose la question, cases cochées par défaut,
« Ignorer » à un geste. `ApplySupplierPrices` — quatrième cas d'usage
inter-modules — écrit les tarifs retenus via `recordSupplierPrice` avec
`PriceSource.reception`.

Le cas d'usage est **séparé** de `ReceiveOrder`, et c'est le point de fond :
recevoir de la marchandise est un fait, apprendre un tarif est un jugement.
`repricedProductIds` a disparu au profit de `priceDiscrepancies` ;
`touchedProductIds` ne réunit plus que les produits reçus et corrigés.

Une correction à la baisse ne constate aucun tarif : ce n'est pas une
livraison.

**6. L'inventaire ne touche pas au CUMP.** Trouver 3 kg de plus n'est pas un
achat : la quantité change, le coût unitaire non. `CreateInventory` fige
`averageCost` au lieu de `unitPrice`, et l'ajustement est valorisé à ce
CUMP. Laisser un comptage modifier le coût moyen corromprait silencieusement
tout le calcul de coût matière.

**7. L'unité de stock fait foi.** Une bouteille d'huile de 5 L à 96 MAD se
saisit en **5 L à 19,20**, jamais en 1 à 96, sinon le CUMP n'a plus de sens.
La conversion se fait à la réception ; le conditionnement appartient au tarif
fournisseur, pas au produit.

**8. Fixtures, écrans et tests.** Reprendre les fixtures avec des historiques
de prix crédibles, afficher le dernier prix payé et le coût moyen sur la fiche
produit, et ajouter les tests de non-régression : le scénario 100 à 12 + 20 à
18 doit donner 1 560 MAD, un ajustement d'inventaire ne doit pas bouger le
CUMP, une correction de réception doit revenir exactement à la valeur d'avant.

### Quel prix alimente quel écran

| Usage | Prix utilisé |
|---|---|
| Valeur du stock, valeur d'écart d'inventaire | `averageCost` |
| Ligne de commande, liste de courses | Tarif en vigueur du fournisseur choisi |
| Fiche produit, « dernier prix payé » | `lastPurchasePrice` |
| Coût matière et marge (phase 9) | `unitCost` des mouvements de sortie |
| Évolution des prix (phase 9) | Historique des tarifs |

### Décisions à confirmer

Les recommandations ci-dessous sont les valeurs par défaut retenues faute de
réponse du client.

1. **CUMP ou FIFO par lots ?** → CUMP.
2. **Prix HT ou TTC ?** → HT partout, taux de TVA porté par le tarif. Mélanger
   les deux est la façon classique d'obtenir des totaux qui ne tombent jamais
   juste.
3. **Réception à un prix différent du tarif : mise à jour automatique ou
   demande ?** → demande (étape 5).
4. **Frais de livraison et remises** dans le coût produit ou au niveau de la
   commande ? → au niveau de la commande, hors périmètre V1.

---

## 4. Phase 7 — Module Personnel

### Ce que montre la maquette

**Liste des employés** : colonnes Employé · Poste · Statut · Pointage, avec
recherche et « Nouvel employé ». Les cinq lignes de référence :

| Employé | Poste | Statut | Pointage |
|---|---|---|---|
| Ahmed | Cuisinier | Pointé | 08:02 |
| Youssef | Cuisinier | Pointé | 07:55 |
| Fatima | Serveuse | En pause | 12:30 |
| Khalid | Plongeur | Pointé | 08:10 |
| Samira | Femme de ménage | Absent | — |

**Carte de pointage** (« Pointage – Ahmed », badge *Pointé*) : Début de travail
08:02 · Pause 12:00 – 12:30 (30 min) · Reprise 12:30 · Fin de travail --:--,
et à droite Heures travaillées 04:28 · Heures sup. 00:00 · Total du jour
04:28. Gros bouton rouge **Pointer la fin**.

### Ce qu'ajoute le cahier des charges

Gestion des employés, pointage début et fin, calcul automatique des heures
travaillées, **gestion de la pause selon les règles définies**, calcul des
heures supplémentaires, **estimation du montant correspondant aux heures
travaillées**, historique des pointages.

### Modèle probable

```
Employee            id, nom, poste, statut actif, taux horaire, date d'entrée
TimeEntry           employeeId, date, début, fin?, pauses[], validé?
BreakPeriod         début, fin?
```

Comme ailleurs : les heures travaillées, les heures supplémentaires et le
montant sont **calculés** depuis les horaires, jamais stockés. `TimeEntry`
sera l'entité la plus riche en getters du projet.

### Ce qui existe déjà et se réutilise

`StatusBadge.attendance()` couvre les quatre statuts (Pointé / En pause /
Terminé / Absent) — écrit en phase 3 pour ce module. `Formatters.hours()`
produit déjà le format `04:28`. `AppAvatar` affiche les initiales colorées de
la maquette. `ListPageTemplate` et `DetailPanel` pour la structure.

### Décisions à trancher avant de coder

**La règle de pause.** Le cahier des charges dit « selon les règles définies »
sans les donner. Trois modèles possibles : pause pointée manuellement (ce que
suggère la maquette avec ses horaires précis), déduction automatique d'une
durée fixe au-delà d'un certain temps de travail, ou pause paramétrable par
établissement. **À demander au client.**

**Le seuil d'heures supplémentaires.** Journalier (au-delà de 8 h) ou
hebdomadaire (au-delà de 44 h, durée légale au Maroc) ? Le calcul et
l'affichage en dépendent.

**Qui pointe.** La maquette montre une tablette partagée : on choisit un
employé puis on pointe pour lui. Cela veut dire que le pointage n'est pas
réservé à l'employé connecté, et qu'un contrôle d'accès différent s'applique.
À confirmer.

**Qui voit les montants.** Le taux horaire et l'estimation de rémunération
sont des données sensibles. Proposition : visibles du patron uniquement, via
un nouveau droit sur `SessionUser`.

---

## 5. Phase 8 — Tableau de bord

### Ce que montre la maquette

Une salutation (« Bonjour, Admin »), cinq indicateurs — Valeur du stock
125 430,00 MAD · Produits en stock 182 · Stocks faibles 12 · Commandes en
cours 5 · Employés pointés 15 — puis trois blocs : **Produits à commander**
(Tomate −6 kg, Carotte −6 kg, Riz 10kg −2 un.), **Évolution du stock (MAD)**
sur 7 jours en courbe, et **Activités récentes** (réception de commande,
sortie de stock, pointage, inventaire validé, avec « il y a 10 min »).

### Le point à préparer

**Presque tout est déjà calculé.** Les indicateurs se lisent sur les
providers existants, et la carte « Produits à commander » peut lire
directement `shoppingListControllerProvider` : le calcul, la déduction des
commandes en cours comprise, est fait depuis la phase 6b.

**Deux choses manquent :**

*Le flux d'activités* n'existe pas. Il faut agréger les mouvements de stock,
les réceptions, les inventaires validés et les pointages en une seule liste
triée par date. C'est un quatrième cas d'usage inter-modules —
`BuildActivityFeed` — qui lira trois ou quatre dépôts. `Formatters.relative()`
produit déjà « il y a 10 min ».

*L'historique de la valeur du stock* n'est pas stocké. Il est reconstituable :
les mouvements portent une date, et les produits un prix. Reconstruire la
valeur jour par jour en remontant les mouvements est faisable mais approximatif
— le prix d'achat actuel n'est pas celui d'il y a une semaine. **Décision à
prendre** : approximation assumée, ou instantané quotidien à introduire dans
la couche `data`.

---

## 6. Phase 9 — Rapports & analyses

### Ce que montre la maquette

Menu latéral de rapports — Valeur du stock, Mouvements de stock, Achats &
Commandes, Inventaires, Pointage du personnel, Heures supplémentaires — et à
droite le rapport sélectionné : total, sélecteur de période, histogramme par
jour, et **répartition par catégorie** en anneau (Légumes 45 % / 56 443 MAD,
Épicerie 30 % / 37 629 MAD, Boissons 15 % / 18 164 MAD, Produits frais 10 % /
12 594 MAD).

### Ce qui reste à construire

`fl_chart` est en dépendance **depuis la phase 0 mais n'a jamais été importé**,
et `lib/shared/widgets/charts/` est **vide** — le dossier a été créé en phase 1
en prévision. C'est la phase qui le remplit : trois composants partagés à
écrire (courbe, histogramme, anneau), avec la même exigence que le reste du
design system — couleurs issues de `AppColors.chartSeries`, aucune valeur en
dur.

`PeriodSelector` et `ReportPeriod` existent depuis la phase 3.

---

## 7. Phase 10 — Authentification, droits, paramètres

Aujourd'hui la session est simulée : `SessionController` démarre connecté en
Patron, et l'écran de connexion sert surtout à changer de rôle pour tester
l'interface.

À faire : authentification réelle, gestion des utilisateurs et de leurs
droits, et l'écran Paramètres (profil, unités, devise, langue, appareils).

Le contrôle d'accès de l'interface est déjà en place et n'aura pas à être
réécrit : `AppDestinations` filtre le rail par rôle, la redirection de
`app_router.dart` interdit les routes non autorisées, et les écrans lisent
`canManageCatalogProvider`. Ajouter un droit = ajouter un getter à
`SessionUser`, jamais tester `role == …` dans un widget.

---

## 8. Phase 11 — Finitions

**Hors connexion et synchronisation.** Exigence explicite du cahier des
charges : stock, inventaire et pointage doivent fonctionner sans réseau. Deux
choses sont déjà prêtes pour ça — `InMemoryInventoryRepository.saveCount` et
`saveReceivedQuantities` n'appliquent **aucune latence**, parce que ces
écritures doivent rester instantanées. L'implémentation locale (Drift) devra
conserver ce comportement et ne synchroniser qu'en arrière-plan. L'indicateur
de synchronisation du rail est en place mais statique.

**Internationalisation.** `lib/l10n/app_fr.arb` existe et le délégué est
branché sur `MaterialApp`, mais **aucun widget ne l'utilise** : tous les
libellés sont écrits en dur en français. Les migrer est un travail mécanique
à faire d'un coup, une fois les écrans stabilisés — le faire plus tôt aurait
ralenti chaque phase pour rien.

**Tests.** Ajouter des tests de golden sur le design system, et des tests de
widgets sur les composants partagés (aujourd'hui couverts indirectement).

**Vitesse et densité.** Vérifier le rendu sur 10" et 12", et le comportement
clavier physique.

---

## 9. Dette technique et points ouverts

| Point | Détail |
|---|---|
| `StockMovement.reference` est une `String` | « CMD-005 », « INV-2024-006 » s'affichent mais ne sont pas cliquables. À typer maintenant que les deux modules existent, pour naviguer du mouvement vers sa commande ou son inventaire. |
| `PurchaseOrderRepository.saveLines` n'est appelé par aucun écran | La modification des lignes d'une commande est prête côté dépôt et contrôleur, mais le bouton « Modifier » de la maquette n'a pas été branché. À faire ou à retirer. |
| Valorisation du stock | ✅ Corrigée par les étapes 1 à 4 de la phase 6c. Restent les étapes 5 à 8 : demande de mise à jour du tarif, verrou côté inventaire, unités de conditionnement, écrans et fixtures. |
| Arrondi du coût moyen | `averageCost` est conservé en pleine précision et arrondi seulement à l'affichage. Arrondir à l'écriture ferait dériver la valeur du stock au fil des réceptions. |
| `lib/l10n/` inutilisé | Voir phase 11. |
| `lib/shared/widgets/charts/` vide | Voir phase 9. |
| Vitrine `/design-system` | À compléter à chaque nouveau composant partagé. Elle est à jour au 18/08/2026. |
| `intl` épinglé à `0.20.2` | Contrainte de `flutter_localizations`. Ne pas « corriger » en `^0.20.3` : la résolution échoue. |
| Riverpod 2.6 | La 3.x existe. Migration hors périmètre V1, à évaluer après la mise en production. |

---

## 10. Comment reprendre

```bash
flutter pub get
flutter analyze      # doit rester à « No issues found »
flutter test         # 136 tests au 19/08/2026
flutter run          # tablette Android, ou Windows pour le développement
```

Lire, dans cet ordre :

1. [`README.md`](README.md) — structure du projet et règles de contribution
2. [`lib/features/stock/README.md`](lib/features/stock/README.md) — le module
   de référence : couches, providers, flux de données
3. [`lib/features/inventory/README.md`](lib/features/inventory/README.md) — le
   patron `domain/usecases/` pour les règles inter-modules
4. [`lib/features/purchasing/README.md`](lib/features/purchasing/README.md) —
   son deuxième et troisième usage

Chaque nouveau module suit le même découpage que Stock, et se termine par son
propre `README.md`.
