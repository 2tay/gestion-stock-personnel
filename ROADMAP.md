# Feuille de route — où on en est, ce qui reste

Document de reprise. À lire en premier au début d'une session de travail : il
dit ce qui est fait, ce qui reste, et surtout **les règles acquises en chemin**
qu'il ne faut pas redécouvrir à la dure.

*Dernière mise à jour : 18 août 2026 — fin de la phase 6.*

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
| **7** | **Module Personnel** | ⬜ **suivant** |
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

Vérification de bonne santé : `flutter analyze` sans aucune remontée,
`flutter test` à 107 tests verts, `flutter build windows --debug` qui passe.

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

## 3. Phase 7 — Module Personnel

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

## 4. Phase 8 — Tableau de bord

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

## 5. Phase 9 — Rapports & analyses

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

## 6. Phase 10 — Authentification, droits, paramètres

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

## 7. Phase 11 — Finitions

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

## 8. Dette technique et points ouverts

| Point | Détail |
|---|---|
| `StockMovement.reference` est une `String` | « CMD-005 », « INV-2024-006 » s'affichent mais ne sont pas cliquables. À typer maintenant que les deux modules existent, pour naviguer du mouvement vers sa commande ou son inventaire. |
| `PurchaseOrderRepository.saveLines` n'est appelé par aucun écran | La modification des lignes d'une commande est prête côté dépôt et contrôleur, mais le bouton « Modifier » de la maquette n'a pas été branché. À faire ou à retirer. |
| `lib/l10n/` inutilisé | Voir phase 11. |
| `lib/shared/widgets/charts/` vide | Voir phase 9. |
| Vitrine `/design-system` | À compléter à chaque nouveau composant partagé. Elle est à jour au 18/08/2026. |
| `intl` épinglé à `0.20.2` | Contrainte de `flutter_localizations`. Ne pas « corriger » en `^0.20.3` : la résolution échoue. |
| Riverpod 2.6 | La 3.x existe. Migration hors périmètre V1, à évaluer après la mise en production. |

---

## 9. Comment reprendre

```bash
flutter pub get
flutter analyze      # doit rester à « No issues found »
flutter test         # 107 tests au 18/08/2026
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
