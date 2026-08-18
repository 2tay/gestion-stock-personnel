import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/theme/app_theme.dart';
import 'package:gestion_stock/core/utils/formatters.dart';
import 'package:gestion_stock/features/inventory/data/repositories/in_memory_inventory_repository.dart';
import 'package:gestion_stock/features/inventory/domain/entities/inventory.dart';
import 'package:gestion_stock/features/inventory/domain/usecases/validate_inventory.dart';
import 'package:gestion_stock/features/inventory/presentation/controllers/inventory_providers.dart';
import 'package:gestion_stock/features/inventory/presentation/pages/inventory_page.dart';
import 'package:gestion_stock/features/stock/data/repositories/in_memory_product_repository.dart';
import 'package:gestion_stock/features/stock/presentation/controllers/stock_providers.dart';
import 'package:gestion_stock/features/stock/presentation/pages/stock_page.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Cohérence entre le module Inventaire et le module Stock.
///
/// Ces tests naviguent entre les deux modules **dans un même
/// `ProviderScope`**, comme dans l'application : c'est la seule façon
/// d'attraper les problèmes de cohérence de cache entre features. Un test qui
/// ne monterait que le module Inventaire verrait l'ajustement écrit dans le
/// dépôt et conclurait à tort que tout va bien.
void main() {
  setUpAll(() => initializeDateFormatting(Formatters.locale));

  /// Bascule entre les deux modules sans recréer le `ProviderScope`, donc
  /// sans perdre l'état ni les caches — exactement comme le rail de
  /// navigation de l'application.
  final ValueNotifier<bool> showStock = ValueNotifier<bool>(true);

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    showStock.value = true;

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
          home: ValueListenableBuilder<bool>(
            valueListenable: showStock,
            builder: (BuildContext context, bool stock, Widget? child) =>
                stock ? const StockPage() : const InventoryPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> goTo(WidgetTester tester, {required bool stock}) async {
    showStock.value = stock;
    await tester.pumpAndSettle();
  }

  testWidgets(
      'l’ajustement apparaît dans l’historique du produit, même si sa fiche '
      'a été consultée avant la validation', (WidgetTester tester) async {
    await pumpApp(tester);

    // 1. Ouvrir la fiche met l'historique du produit en cache : c'est
    //    exactement la situation qui masquait l'ajustement.
    await tester.tap(find.text('Huile 5L'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun mouvement'), findsOneWidget);

    // 2. Aller valider INV-2024-006, qui corrige Huile 5L de 30 à 20 unités.
    await goTo(tester, stock: false);
    await tester.tap(find.text('INV-2024-006'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Valider l’inventaire'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider l’inventaire').last);
    await tester.pumpAndSettle();

    // 3. Revenir au stock : la fiche d'Huile 5L est toujours ouverte et doit
    //    montrer le nouveau stock ET le mouvement qui l'explique.
    await goTo(tester, stock: true);

    // L'ajustement est **relatif**, pas absolu : le stock ne devient pas la
    // quantité comptée (20), il est corrigé de l'écart constaté (-10). Le
    // produit était à 25 dans le stock, il passe donc à 15.
    //
    // C'est voulu : le stock théorique de l'inventaire (30) a été figé le
    // 25/05, et des mouvements ont eu lieu depuis. Forcer le stock à 20
    // effacerait ces mouvements postérieurs au comptage.
    expect(find.text('15 un.'), findsWidgets);
    expect(find.text('Aucun mouvement'), findsNothing);
    expect(find.text('Ajustement'), findsOneWidget);
    expect(find.text('INV-2024-006'), findsOneWidget);
    expect(find.text('-10 un.'), findsOneWidget);
  });

  testWidgets('un produit conforme ne reçoit aucun mouvement',
      (WidgetTester tester) async {
    await pumpApp(tester);

    await goTo(tester, stock: false);
    await tester.tap(find.text('INV-2024-006'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider l’inventaire'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider l’inventaire').last);
    await tester.pumpAndSettle();

    // Farine 25kg a été comptée à sa valeur théorique : rien à corriger.
    await goTo(tester, stock: true);
    await tester.tap(find.text('Farine 25kg'));
    await tester.pumpAndSettle();

    expect(find.text('Aucun mouvement'), findsOneWidget);
  });

  test('le résultat de validation nomme les produits corrigés', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        inventoryRepositoryProvider.overrideWithValue(
          InMemoryInventoryRepository(latency: Duration.zero),
        ),
        productRepositoryProvider.overrideWithValue(
          InMemoryProductRepository(latency: Duration.zero),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(inventoryControllerProvider.notifier).load();
    final Inventory inventory = container
        .read(inventoryControllerProvider)
        .value!
        .firstWhere((Inventory i) => i.reference == 'INV-2024-006');

    final InventoryValidationResult result =
        await container.read(inventoryControllerProvider.notifier).validate(
              inventory,
              validatedBy: 'Admin Demo',
            );

    // Huile 5L et Riz 10kg sont en écart ; Farine 25kg est conforme.
    expect(result.adjustedProductIds, <String>['p-006', 'p-007']);
    expect(result.adjustmentsApplied, 2);
  });
}
