import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/theme/app_theme.dart';
import 'package:gestion_stock/core/utils/formatters.dart';
import 'package:gestion_stock/features/inventory/data/repositories/in_memory_inventory_repository.dart';
import 'package:gestion_stock/features/inventory/presentation/controllers/inventory_providers.dart';
import 'package:gestion_stock/features/inventory/presentation/pages/inventory_page.dart';
import 'package:gestion_stock/features/stock/data/repositories/in_memory_product_repository.dart';
import 'package:gestion_stock/features/stock/presentation/controllers/stock_providers.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Monte le module Inventaire avec des dépôts sans latence, sur une surface
/// de la taille d'une tablette en paysage.
Future<void> pumpInventoryPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        inventoryRepositoryProvider.overrideWithValue(
          InMemoryInventoryRepository(latency: Duration.zero),
        ),
        productRepositoryProvider.overrideWithValue(
          InMemoryProductRepository(latency: Duration.zero),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const InventoryPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting(Formatters.locale));

  testWidgets('la liste affiche les inventaires et leurs statuts',
      (WidgetTester tester) async {
    await pumpInventoryPage(tester);

    expect(find.text('INV-2024-007'), findsOneWidget);
    expect(find.text('INV-2024-005'), findsOneWidget);
    expect(find.text('En cours'), findsWidgets);
    expect(find.text('Validé'), findsWidgets);
    expect(find.text('Brouillon'), findsWidgets);
  });

  testWidgets('un brouillon affiche un tiret dans la colonne Écart',
      (WidgetTester tester) async {
    await pumpInventoryPage(tester);
    expect(find.text('—'), findsWidgets);
  });

  testWidgets("l'onglet « Brouillon » ne garde que les brouillons",
      (WidgetTester tester) async {
    await pumpInventoryPage(tester);

    await tester.tap(find.text('Brouillon').first);
    await tester.pumpAndSettle();

    expect(find.text('INV-2024-003'), findsOneWidget);
    expect(find.text('INV-2024-007'), findsNothing);
  });

  testWidgets('ouvrir un inventaire affiche l’écran de comptage',
      (WidgetTester tester) async {
    await pumpInventoryPage(tester);

    await tester.tap(find.text('INV-2024-007'));
    await tester.pumpAndSettle();

    expect(find.text('Stock théorique'.toUpperCase()), findsOneWidget);
    expect(find.text('Stock réel'.toUpperCase()), findsOneWidget);
    expect(find.text('5 / 8 produits comptés'), findsOneWidget);
    expect(find.text('Tomate'), findsOneWidget);
  });

  testWidgets('saisir une quantité met à jour l’écart et l’avancement',
      (WidgetTester tester) async {
    await pumpInventoryPage(tester);
    await tester.tap(find.text('INV-2024-007'));
    await tester.pumpAndSettle();

    // Huile 5L n'est pas comptée : théorique 25.
    await tester.enterText(
      find.byKey(const ValueKey<String>('count-p-006')),
      '20',
    );
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    expect(find.text('6 / 8 produits comptés'), findsOneWidget);
    expect(find.text('-5 un.'), findsOneWidget);
  });

  testWidgets('vider une saisie repasse la ligne en non comptée',
      (WidgetTester tester) async {
    await pumpInventoryPage(tester);
    await tester.tap(find.text('INV-2024-007'));
    await tester.pumpAndSettle();

    // Tomate (-5 kg) et Carotte (-5 kg) sont toutes deux en écart.
    expect(find.text('-5 kg'), findsNWidgets(2));

    await tester.enterText(
      find.byKey(const ValueKey<String>('count-p-001')),
      '',
    );
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    expect(find.text('4 / 8 produits comptés'), findsOneWidget);
    expect(find.text('-5 kg'), findsOneWidget);
  });

  testWidgets("l'onglet « Non comptés » ne garde que les lignes vides",
      (WidgetTester tester) async {
    await pumpInventoryPage(tester);
    await tester.tap(find.text('INV-2024-007'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Non comptés'));
    await tester.pumpAndSettle();

    expect(find.text('Huile 5L'), findsOneWidget);
    expect(find.text('Tomate'), findsNothing);
  });

  testWidgets('un comptage clos affiche la validation et désactive la saisie',
      (WidgetTester tester) async {
    await pumpInventoryPage(tester);

    await tester.tap(find.text('INV-2024-006'));
    await tester.pumpAndSettle();

    expect(find.text('Valider l’inventaire'), findsOneWidget);
    expect(find.text('Rouvrir'), findsOneWidget);
    expect(find.text('Comptage clos'), findsOneWidget);
  });

  testWidgets('valider un inventaire applique les écarts au stock',
      (WidgetTester tester) async {
    await pumpInventoryPage(tester);
    await tester.tap(find.text('INV-2024-006'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Valider l’inventaire'));
    await tester.pumpAndSettle();

    // La confirmation annonce ce qui va être écrit.
    expect(find.textContaining('2 ajustements'), findsOneWidget);
    expect(find.textContaining('Cette opération est définitive'), findsOneWidget);

    await tester.tap(find.text('Valider l’inventaire').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Validé le'), findsOneWidget);
  });

  testWidgets('le retour ramène à la liste', (WidgetTester tester) async {
    await pumpInventoryPage(tester);
    await tester.tap(find.text('INV-2024-007'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Retour à la liste'));
    await tester.pumpAndSettle();

    expect(find.text('INV-2024-005'), findsOneWidget);
    expect(find.text('Nouvel inventaire'), findsOneWidget);
  });

  testWidgets('créer un inventaire par catégorie ouvre le comptage',
      (WidgetTester tester) async {
    await pumpInventoryPage(tester);

    await tester.tap(find.text('Nouvel inventaire'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Une catégorie'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Épicerie').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ouvrir l’inventaire'));
    await tester.pumpAndSettle();

    // 3 produits en Épicerie, aucun compté.
    expect(find.text('0 / 3 produits comptés'), findsOneWidget);
  });
}
