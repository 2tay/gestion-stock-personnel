import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:gestion_stock/core/theme/app_theme.dart';
import 'package:gestion_stock/core/utils/formatters.dart';
import 'package:gestion_stock/features/stock/data/repositories/in_memory_product_repository.dart';
import 'package:gestion_stock/features/stock/domain/repositories/product_repository.dart';
import 'package:gestion_stock/features/stock/presentation/controllers/stock_providers.dart';
import 'package:gestion_stock/features/stock/presentation/pages/stock_page.dart';
import 'package:gestion_stock/features/stock/presentation/widgets/movement_form_dialog.dart';

/// Monte la page Stock avec un dépôt sans latence, sur une surface de la
/// taille d'une tablette en paysage.
Future<void> pumpStockPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        productRepositoryProvider.overrideWithValue(
          InMemoryProductRepository(latency: Duration.zero),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const StockPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // Les tableaux affichent des dates : la locale doit être chargée,
  // exactement comme le fait `main.dart` au démarrage.
  setUpAll(() => initializeDateFormatting(Formatters.locale));

  testWidgets('la liste affiche les produits et leur statut',
      (WidgetTester tester) async {
    await pumpStockPage(tester);

    expect(find.text('Stock'), findsOneWidget);
    expect(find.text('Tomate'), findsOneWidget);
    expect(find.text('Carotte'), findsOneWidget);
    // Carotte est sous son seuil, Beurre est à zéro.
    expect(find.text('Faible'), findsWidgets);
    expect(find.text('Rupture'), findsWidgets);
  });

  testWidgets("l'onglet « Stock faible » ne garde que les produits à surveiller",
      (WidgetTester tester) async {
    await pumpStockPage(tester);

    await tester.tap(find.text('Stock faible'));
    await tester.pumpAndSettle();

    expect(find.text('Carotte'), findsOneWidget);
    expect(find.text('Tomate'), findsNothing);
  });

  testWidgets("l'onglet « Catégories » affiche les catégories, et un clic "
      'filtre les produits', (WidgetTester tester) async {
    await pumpStockPage(tester);

    await tester.tap(find.text('Catégories'));
    await tester.pumpAndSettle();
    expect(find.text('Légumes'), findsOneWidget);
    expect(find.text('Tomate'), findsNothing);

    await tester.tap(find.text('Légumes'));
    await tester.pumpAndSettle();
    expect(find.text('Tomate'), findsOneWidget);
    expect(find.text('Riz 10kg'), findsNothing);
  });

  testWidgets('la sélection ouvre la fiche produit à droite',
      (WidgetTester tester) async {
    await pumpStockPage(tester);

    await tester.tap(find.text('Carotte'));
    await tester.pumpAndSettle();

    expect(find.text('Mouvements'), findsOneWidget);
    expect(find.text('Informations'), findsOneWidget);
    expect(find.text('Fournisseurs'), findsOneWidget);
    expect(find.text('Stock actuel'), findsOneWidget);
  });

  testWidgets('la fiche produit change d’onglet', (WidgetTester tester) async {
    await pumpStockPage(tester);
    await tester.tap(find.text('Carotte'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fournisseurs'));
    await tester.pumpAndSettle();
    expect(find.text('AgriPlus'), findsWidgets);
    expect(find.text('Principal'), findsOneWidget);

    await tester.tap(find.text('Informations'));
    await tester.pumpAndSettle();
    expect(find.text('Code-barres'), findsOneWidget);
  });

  testWidgets('une entrée de stock met à jour la liste et la fiche',
      (WidgetTester tester) async {
    await pumpStockPage(tester);
    await tester.tap(find.text('Carotte'));
    await tester.pumpAndSettle();

    expect(find.text('Faible'), findsWidgets);

    await tester.tap(find.text('Entrée de stock'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byKey(quantityFieldKey),
        matching: find.byType(TextField),
      ),
      '60',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enregistrer le mouvement'));
    await tester.pumpAndSettle();

    // 55 + 60 = 115, au-dessus du seuil de 60.
    expect(find.text('115 kg'), findsWidgets);
  });

  testWidgets('la recherche filtre le tableau', (WidgetTester tester) async {
    await pumpStockPage(tester);

    await tester.enterText(find.byType(TextField).first, 'riz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Riz 10kg'), findsOneWidget);
    expect(find.text('Tomate'), findsNothing);
  });

  testWidgets('le dépôt satisfait bien le contrat du domaine', (_) async {
    expect(
      InMemoryProductRepository(latency: Duration.zero),
      isA<ProductRepository>(),
    );
  });
}
