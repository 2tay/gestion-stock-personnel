import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/theme/app_theme.dart';
import 'package:gestion_stock/core/utils/formatters.dart';
import 'package:gestion_stock/features/purchasing/data/repositories/in_memory_purchasing_repositories.dart';
import 'package:gestion_stock/features/purchasing/presentation/controllers/purchasing_providers.dart';
import 'package:gestion_stock/features/purchasing/presentation/pages/purchasing_page.dart';
import 'package:gestion_stock/features/stock/data/repositories/in_memory_product_repository.dart';
import 'package:gestion_stock/features/stock/presentation/controllers/stock_providers.dart';
import 'package:gestion_stock/features/stock/presentation/pages/stock_page.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting(Formatters.locale));

  /// Bascule Achats / Stock dans un même `ProviderScope`, pour pouvoir
  /// vérifier qu'une réception se répercute bien sur les produits.
  final ValueNotifier<bool> showPurchasing = ValueNotifier<bool>(true);

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    showPurchasing.value = true;

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          purchaseOrderRepositoryProvider.overrideWithValue(
            InMemoryPurchaseOrderRepository(latency: Duration.zero),
          ),
          supplierRepositoryProvider.overrideWithValue(
            InMemorySupplierRepository(latency: Duration.zero),
          ),
          productRepositoryProvider.overrideWithValue(
            InMemoryProductRepository(latency: Duration.zero),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: ValueListenableBuilder<bool>(
            valueListenable: showPurchasing,
            builder: (BuildContext context, bool purchasing, Widget? child) =>
                purchasing ? const PurchasingPage() : const StockPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('la liste affiche les commandes de la maquette',
      (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.text('CMD-005'), findsOneWidget);
    expect(find.text('CMD-001'), findsOneWidget);
    expect(find.text('AgriPlus'), findsWidgets);
    expect(find.text('Partielle'), findsNWidgets(2));
    expect(find.text('Reçue'), findsNWidgets(3));
  });

  testWidgets("l'onglet « Partielles » ne garde que les commandes partielles",
      (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Partielles'));
    await tester.pumpAndSettle();

    expect(find.text('CMD-005'), findsOneWidget);
    expect(find.text('CMD-004'), findsOneWidget);
    expect(find.text('CMD-003'), findsNothing);
  });

  testWidgets('le détail affiche les totaux commandé et reçu',
      (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('CMD-005'));
    await tester.pumpAndSettle();

    expect(find.text('Total commandé'), findsWidgets);
    expect(find.text('Total reçu'), findsOneWidget);
    // 570,00 MAD commandés, 450,00 MAD reçus — les chiffres de la maquette.
    expect(find.text('570,00 MAD'), findsWidgets);
    expect(find.text('450,00 MAD'), findsOneWidget);
  });

  testWidgets('le bouton de réception reste inactif sans modification',
      (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('CMD-005'));
    await tester.pumpAndSettle();

    // Rien n'a changé : la saisie est un brouillon vide.
    expect(
      find.byTooltip('Aucune quantité modifiée'),
      findsOneWidget,
    );
  });

  testWidgets('« Tout recevoir » remplit le brouillon sans écrire le stock',
      (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('CMD-005'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tout recevoir'));
    await tester.pumpAndSettle();

    // Le total reçu affiché vient de la commande enregistrée, pas du
    // brouillon : tant qu'on n'a pas validé, il ne bouge pas.
    expect(find.text('450,00 MAD'), findsOneWidget);
    expect(find.byTooltip('Aucune quantité modifiée'), findsNothing);
  });

  testWidgets('enregistrer la réception met à jour la commande et le stock',
      (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('CMD-005'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tout recevoir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enregistrer la réception'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Le stock va être mis à jour'), findsOneWidget);
    await tester.tap(find.text('Enregistrer').last);
    await tester.pumpAndSettle();

    // La commande passe à « Reçue » : trois commandes déjà reçues, plus
    // celle-ci, plus le badge du panneau de détail ouvert.
    expect(find.text('Reçue'), findsNWidgets(5));
    // Total commandé et total reçu se rejoignent, en liste et en détail.
    expect(find.text('570,00 MAD'), findsNWidgets(3));

    // Côté stock, Carotte a reçu 20 kg de plus (55 → 75) et le mouvement
    // porte la référence de la commande.
    showPurchasing.value = false;
    await tester.pumpAndSettle();

    await tester.tap(find.text('Carotte'));
    await tester.pumpAndSettle();

    expect(find.text('75 kg'), findsWidgets);
    expect(find.text('CMD-005'), findsOneWidget);
    expect(find.text('Entrée'), findsWidgets);
  });

  testWidgets('la section Fournisseurs liste les fournisseurs',
      (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Fournisseurs'));
    await tester.pumpAndSettle();

    expect(find.text('DistriFood'), findsOneWidget);
    expect(find.text('Boucherie Atlas'), findsOneWidget);
    // Sodex Boissons est désactivé mais reste visible.
    expect(find.text('Inactif'), findsOneWidget);
  });

  testWidgets('créer un fournisseur l’ajoute à la liste',
      (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Fournisseurs'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nouveau fournisseur'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Primeurs du Sud');
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();

    expect(find.text('Primeurs du Sud'), findsOneWidget);
  });

  testWidgets('un fournisseur sans nom est refusé', (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Fournisseurs'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nouveau fournisseur'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();

    expect(
      find.text('Le nom du fournisseur est obligatoire.'),
      findsOneWidget,
    );
  });
}
