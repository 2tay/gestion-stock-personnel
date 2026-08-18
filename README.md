# Gestion Stock & Personnel

Application tablette Android pour la gestion du stock, des inventaires, des
achats et du personnel d'un établissement.

**État actuel : phases 0 à 5 terminées.** Le socle est en place (design
system, navigation, composants partagés) et les modules **Stock** et
**Inventaire** sont fonctionnels sur données de démonstration — y compris la
validation d'un inventaire, qui écrit de vrais ajustements dans le stock. Les
autres modules sont encore des pages d'attente. Aucun backend à ce stade : la
couche `data` renvoie des fixtures en mémoire.

---

## Démarrer

```bash
flutter pub get
flutter run                # tablette Android ou Windows (pratique en dev)
flutter analyze            # doit rester à « No issues found »
flutter test
```

La vitrine du design system est accessible sur la route `/design-system` :
c'est la référence visuelle de tous les composants partagés.

## Stack

| Rôle | Choix |
|---|---|
| State management | `flutter_riverpod` |
| Navigation | `go_router` (ShellRoute pour le rail permanent) |
| Injection de dépendances | `get_it` (prêt, vide tant qu'il n'y a pas de couche data) |
| Formatage & i18n | `intl` + `flutter_localizations`, ARB dans `lib/l10n/` |
| Graphiques | `fl_chart` |

Aucune police téléchargée au runtime : l'application doit fonctionner hors
connexion.

## Structure

```
lib/
├── main.dart                  Point d'entrée : orientation, intl, DI
├── app/                       Racine applicative
│   ├── app.dart               MaterialApp.router, thème, locales
│   ├── router/
│   │   ├── app_routes.dart    Routes + destinations du rail + droits par rôle
│   │   ├── app_router.dart    go_router, ShellRoute, redirections d'accès
│   │   └── app_shell.dart     Coque : rail de navigation + page courante
│   └── di/service_locator.dart
│
├── core/                      Noyau technique, sans widget métier
│   ├── theme/                 Couleurs, typo, espacements, ombres, ThemeData
│   ├── constants/             Enums d'état, durées d'animation
│   ├── extensions/            context.theme, Gap, helpers de layout
│   ├── responsive/            Breakpoints, ResponsiveBuilder
│   └── utils/formatters.dart  MAD, dates FR, quantités, heures
│
├── shared/                    Composants réutilisables — le cœur du projet
│   ├── widgets/
│   │   ├── atoms/             AppButton, AppTextField, AppDropdown, AppCard,
│   │   │                      AppChip, AppAvatar, AppIconButton
│   │   ├── molecules/         SearchField, FilterTabs, StatusBadge, KpiCard,
│   │   │                      SectionHeader, LabeledValue, PeriodSelector,
│   │   │                      EmptyState / ErrorState / LoadingState
│   │   ├── organisms/         AppDataTable, AppNavRail, AppTopBar,
│   │   │                      FormDialog, ConfirmDialog, Paginator,
│   │   │                      ScannerSheet
│   │   └── charts/            (phase 9)
│   ├── layout/                AppScaffold, MasterDetailLayout, DetailPanel,
│   │                          ListPageTemplate
│   └── shared.dart            Barrel
│
├── l10n/app_fr.arb            Libellés FR
└── features/                  Un dossier par module
    ├── auth/         domain/ + presentation/ (session simulée, login)
    ├── dashboard/    presentation/
    ├── stock/        ✅ complet — voir ci-dessous
    ├── inventory/    ✅ complet — voir son README
    ├── purchasing/   presentation/
    ├── staff/        presentation/
    ├── reports/      presentation/
    ├── settings/     presentation/
    └── gallery/      vitrine du design system (interne)
```

### Le module Stock, comme modèle

```
features/stock/
├── domain/
│   ├── entities/        Product, ProductSupplier, StockMovement,
│   │                    ProductCategory, MeasurementUnit
│   └── repositories/    ProductRepository (interface pure)
├── data/
│   ├── fixtures/        StockFixtures — 15 produits, 5 catégories, historique
│   └── repositories/    InMemoryProductRepository (latence simulée)
└── presentation/
    ├── controllers/     stock_providers.dart — Riverpod
    ├── widgets/         ProductDetailPanel, ProductFormDialog,
    │                    MovementFormDialog, StockLevelBar, ProductNameCell
    └── pages/           StockPage
```

Les autres modules doivent suivre exactement ce découpage.
Le fonctionnement détaillé de chaque module — couches, providers, flux de
données et règles à ne pas casser — est documenté dans son propre README :

- [`lib/features/stock/README.md`](lib/features/stock/README.md)
- [`lib/features/inventory/README.md`](lib/features/inventory/README.md) —
  ajoute le patron `domain/usecases/` pour les règles qui traversent deux
  modules

Chaque feature suit `domain/` (entités + interfaces de repository),
`data/` (modèles + source de données) et `presentation/`
(`pages/`, `widgets/`, `controllers/`). En phase frontend, `data/` renvoie des
fixtures ; le branchement du backend ne touchera que cette couche.

## Règles de contribution

1. **Aucune couleur, taille ou police en dur.** Tout passe par
   `core/theme/`. Un `Color(0xFF...)` dans une feature est un bug.
2. **Avant d'écrire un widget, ouvrir `/design-system`.** S'il existe déjà,
   le réutiliser ; s'il manque une variante, l'ajouter au composant partagé
   plutôt que d'en créer un local.
3. **Les pages de liste passent par `ListPageTemplate`**, les fiches par
   `DetailPanel`, les écrans par `AppScaffold`. Ne pas réimplémenter la
   structure barre de recherche / filtres / tableau.
4. **Pas de `Theme.of`, `NumberFormat` ou `DateFormat` direct** : utiliser
   `context.theme` et `Formatters`.
5. **`shared/` ne dépend jamais de `features/` ni de `app/`.** La
   configuration (routes, rôles, données) lui est passée en paramètre.
6. **Les libellés visibles vont dans `lib/l10n/app_fr.arb`** au fur et à
   mesure de leur stabilisation.
7. **Le stock ne se modifie que par un mouvement.** Aucun écran ne doit
   écrire `currentStock` directement : on passe par `registerMovement`, qui
   enregistre la quantité, la raison, la date et l'utilisateur.
8. `flutter analyze` doit rester vert avant chaque commit, et `flutter test`
   passer intégralement.

## Rôles et accès

Trois niveaux, appliqués côté interface par `AppDestinations` et la
redirection de `app_router.dart` :

| Rôle | Accès |
|---|---|
| Patron | Tous les modules, y compris Paramètres |
| Manager | Accueil, Stock, Inventaire, Achats, Personnel, Rapports |
| Employé | Stock, Inventaire, Personnel (pointage) — arrive sur `/personnel` |

La session est simulée (`SessionController`) et démarre connectée en Patron.
L'écran de connexion permet de basculer de rôle pour vérifier l'interface.

## Suite du plan

| Phase | Contenu |
|---|---|
| ~~4~~ | ~~Module Stock~~ — terminé |
| ~~5~~ | ~~Module Inventaire~~ — terminé |
| 6 | Achats : commandes, réception, fournisseurs |
| 7 | Personnel : employés, pointage, heures supplémentaires |
| 8 | Tableau de bord |
| 9 | Rapports & graphiques |
| 10 | Auth réelle, droits, paramètres |
| 11 | Finitions, hors connexion, tests |