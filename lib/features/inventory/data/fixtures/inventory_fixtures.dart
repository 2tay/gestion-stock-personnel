import '../../../../core/constants/app_enums.dart';
import '../../domain/entities/inventory.dart';
import '../../domain/entities/inventory_line.dart';

/// Jeu de données de démonstration du module Inventaire.
///
/// Reprend les cinq inventaires de la maquette, avec des écarts cohérents :
/// la valeur affichée dans la colonne « Écart » est bien la somme des écarts
/// valorisés des lignes.
abstract final class InventoryFixtures {
  static final DateTime _today = DateTime(2024, 5, 30);

  static DateTime _at(int day, {int hour = 9, int minute = 0}) =>
      DateTime(2024, 5, day, hour, minute);

  /// Ligne comptée : le prix est choisi pour que l'écart tombe juste.
  static InventoryLine _line({
    required String productId,
    required String productName,
    required String emoji,
    required String unit,
    required double theoretical,
    required double unitPrice,
    double? counted,
    String categoryName = 'Légumes',
    int? countedDay,
  }) {
    return InventoryLine(
      productId: productId,
      productName: productName,
      emoji: emoji,
      categoryName: categoryName,
      unit: unit,
      theoreticalStock: theoretical,
      unitPrice: unitPrice,
      countedStock: counted,
      countedAt: counted == null ? null : _at(countedDay ?? 30, hour: 10),
    );
  }

  /// Les lignes visibles sur l'écran de comptage de la maquette.
  static List<InventoryLine> _currentLines() => <InventoryLine>[
        _line(
          productId: 'p-001',
          productName: 'Tomate',
          emoji: '🍅',
          unit: 'kg',
          theoretical: 100,
          unitPrice: 6,
          counted: 95,
        ),
        _line(
          productId: 'p-002',
          productName: 'Oignon',
          emoji: '🧅',
          unit: 'kg',
          theoretical: 50,
          unitPrice: 4.5,
          counted: 50,
        ),
        _line(
          productId: 'p-003',
          productName: 'Pomme de terre',
          emoji: '🥔',
          unit: 'kg',
          theoretical: 80,
          unitPrice: 5.2,
          counted: 82,
        ),
        _line(
          productId: 'p-004',
          productName: 'Carotte',
          emoji: '🥕',
          unit: 'kg',
          theoretical: 60,
          unitPrice: 4.8,
          counted: 55,
        ),
        _line(
          productId: 'p-005',
          productName: 'Concombre',
          emoji: '🥒',
          unit: 'kg',
          theoretical: 30,
          unitPrice: 5.5,
          counted: 30,
        ),
        // Non comptés : ils ne produiront aucun ajustement.
        _line(
          productId: 'p-006',
          productName: 'Huile 5L',
          emoji: '🫒',
          categoryName: 'Épicerie',
          unit: 'un.',
          theoretical: 25,
          unitPrice: 96,
        ),
        _line(
          productId: 'p-007',
          productName: 'Riz 10kg',
          emoji: '🍚',
          categoryName: 'Épicerie',
          unit: 'un.',
          theoretical: 38,
          unitPrice: 118,
        ),
        _line(
          productId: 'p-009',
          productName: 'Lait 1L',
          emoji: '🥛',
          categoryName: 'Produits frais',
          unit: 'un.',
          theoretical: 32,
          unitPrice: 7.5,
        ),
      ];

  /// Inventaire clos, écart de -1 250 MAD.
  static List<InventoryLine> _closedLines() => <InventoryLine>[
        _line(
          productId: 'p-006',
          productName: 'Huile 5L',
          emoji: '🫒',
          categoryName: 'Épicerie',
          unit: 'un.',
          theoretical: 30,
          unitPrice: 96,
          counted: 20,
          countedDay: 25,
        ),
        _line(
          productId: 'p-007',
          productName: 'Riz 10kg',
          emoji: '🍚',
          categoryName: 'Épicerie',
          unit: 'un.',
          theoretical: 42,
          unitPrice: 118,
          counted: 40,
          countedDay: 25,
        ),
        _line(
          productId: 'p-008',
          productName: 'Farine 25kg',
          emoji: '🌾',
          categoryName: 'Épicerie',
          unit: 'un.',
          theoretical: 12,
          unitPrice: 210,
          counted: 12,
          countedDay: 25,
        ),
      ];

  /// Inventaire validé, écart de +320 MAD.
  static List<InventoryLine> _validatedLines() => <InventoryLine>[
        _line(
          productId: 'p-014',
          productName: 'Poulet entier',
          emoji: '🍗',
          categoryName: 'Viandes',
          unit: 'kg',
          theoretical: 40,
          unitPrice: 38,
          counted: 45,
          countedDay: 20,
        ),
        _line(
          productId: 'p-015',
          productName: 'Viande hachée',
          emoji: '🥩',
          categoryName: 'Viandes',
          unit: 'kg',
          theoretical: 20,
          unitPrice: 92,
          counted: 18.5,
          countedDay: 20,
        ),
      ];

  /// Inventaire clos, écart de -460 MAD.
  static List<InventoryLine> _oldClosedLines() => <InventoryLine>[
        _line(
          productId: 'p-011',
          productName: 'Fromage râpé 1kg',
          emoji: '🧀',
          categoryName: 'Produits frais',
          unit: 'un.',
          theoretical: 22,
          unitPrice: 68,
          counted: 17,
          countedDay: 15,
        ),
        _line(
          productId: 'p-010',
          productName: 'Beurre 500g',
          emoji: '🧈',
          categoryName: 'Produits frais',
          unit: 'un.',
          theoretical: 8,
          unitPrice: 42,
          counted: 5,
          countedDay: 15,
        ),
      ];

  static List<Inventory> inventories() => <Inventory>[
        Inventory(
          id: 'inv-007',
          reference: 'INV-2024-007',
          createdAt: _at(30, hour: 8),
          status: InventoryStatus.enCours,
          scope: InventoryScope.tous,
          createdBy: 'Admin Demo',
          lines: _currentLines(),
        ),
        Inventory(
          id: 'inv-006',
          reference: 'INV-2024-006',
          createdAt: _at(25, hour: 8, minute: 30),
          closedAt: _at(25, hour: 11),
          status: InventoryStatus.termine,
          scope: InventoryScope.categorie,
          categoryId: 'cat-2',
          categoryName: 'Épicerie',
          createdBy: 'Fatima',
          lines: _closedLines(),
        ),
        Inventory(
          id: 'inv-005',
          reference: 'INV-2024-005',
          createdAt: _at(20, hour: 9),
          closedAt: _at(20, hour: 10, minute: 30),
          validatedAt: _at(20, hour: 14),
          validatedBy: 'Admin Demo',
          status: InventoryStatus.valide,
          scope: InventoryScope.categorie,
          categoryId: 'cat-5',
          categoryName: 'Viandes',
          createdBy: 'Ahmed',
          lines: _validatedLines(),
        ),
        Inventory(
          id: 'inv-004',
          reference: 'INV-2024-004',
          createdAt: _at(15, hour: 8),
          closedAt: _at(15, hour: 9, minute: 45),
          status: InventoryStatus.termine,
          scope: InventoryScope.categorie,
          categoryId: 'cat-3',
          categoryName: 'Produits frais',
          createdBy: 'Youssef',
          lines: _oldClosedLines(),
        ),
        Inventory(
          id: 'inv-003',
          reference: 'INV-2024-003',
          createdAt: _at(10, hour: 16),
          status: InventoryStatus.brouillon,
          scope: InventoryScope.categorie,
          categoryId: 'cat-4',
          categoryName: 'Boissons',
          createdBy: 'Samira',
          lines: <InventoryLine>[
            _line(
              productId: 'p-012',
              productName: 'Eau minérale 1,5L',
              emoji: '💧',
              categoryName: 'Boissons',
              unit: 'un.',
              theoretical: 240,
              unitPrice: 4,
            ),
            _line(
              productId: 'p-013',
              productName: 'Soda 33cl',
              emoji: '🥤',
              categoryName: 'Boissons',
              unit: 'un.',
              theoretical: 84,
              unitPrice: 5.5,
            ),
          ],
        ),
      ];

  /// Prochain numéro de référence, à la suite des fixtures.
  static int nextSequence = 8;

  static String nextReference() =>
      'INV-${_today.year}-${nextSequence.toString().padLeft(3, '0')}';
}
