import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/supplier.dart';

/// Jeu de données de démonstration du module Achats.
///
/// Reprend les cinq commandes de la maquette, avec les montants exacts :
/// `CMD-005` totalise 570,00 MAD commandés dont 450,00 MAD reçus.
abstract final class PurchasingFixtures {
  static DateTime _at(int day, {int hour = 9, int minute = 0}) =>
      DateTime(2024, 5, day, hour, minute);

  static const List<Supplier> _suppliers = <Supplier>[
    Supplier(
      id: 'sup-1',
      name: 'AgriPlus',
      contactName: 'Karim Belhaj',
      phone: '05 22 45 12 30',
      email: 'commandes@agriplus.ma',
      address: 'Zone maraîchère, Berrechid',
      paymentTerms: '30 jours fin de mois',
      notes: 'Livraison le matin avant 9 h.',
    ),
    Supplier(
      id: 'sup-2',
      name: 'FreshFood',
      contactName: 'Nadia Amrani',
      phone: '05 22 78 04 15',
      email: 'contact@freshfood.ma',
      address: 'Quartier industriel, Casablanca',
      paymentTerms: 'Comptant',
      deliveryDays: 2,
    ),
    Supplier(
      id: 'sup-3',
      name: 'DistriFood',
      contactName: 'Omar Tazi',
      phone: '05 22 33 88 61',
      email: 'ventes@distrifood.ma',
      address: 'Route de Rabat, Ain Sebaa',
      paymentTerms: '15 jours',
      deliveryDays: 2,
    ),
    Supplier(
      id: 'sup-4',
      name: 'Boucherie Atlas',
      contactName: 'Rachid Idrissi',
      phone: '06 61 20 47 93',
      paymentTerms: 'Comptant',
      notes: 'Commande à passer la veille avant 16 h.',
    ),
    Supplier(
      id: 'sup-5',
      name: 'Sodex Boissons',
      phone: '05 22 91 10 04',
      paymentTerms: '30 jours',
      deliveryDays: 3,
      isActive: false,
      notes: 'Fournisseur suspendu — ruptures répétées.',
    ),
  ];

  static List<Supplier> suppliers() => List<Supplier>.of(_suppliers);

  static List<PurchaseOrder> orders() => <PurchaseOrder>[
        // CMD-005 : la commande détaillée dans la maquette.
        // 570,00 MAD commandés, 450,00 MAD reçus.
        PurchaseOrder(
          id: 'ord-005',
          reference: 'CMD-005',
          supplierId: 'sup-1',
          supplierName: 'AgriPlus',
          createdAt: _at(30, hour: 8),
          expectedAt: _at(31, hour: 8),
          lifecycle: OrderLifecycle.ouverte,
          createdBy: 'Admin Demo',
          lines: const <OrderLine>[
            OrderLine(
              productId: 'p-001',
              productName: 'Tomate',
              emoji: '🍅',
              unit: 'kg',
              quantityOrdered: 50,
              quantityReceived: 40,
              unitPrice: 6,
            ),
            OrderLine(
              productId: 'p-002',
              productName: 'Oignon',
              emoji: '🧅',
              unit: 'kg',
              quantityOrdered: 30,
              quantityReceived: 30,
              unitPrice: 4,
            ),
            OrderLine(
              productId: 'p-004',
              productName: 'Carotte',
              emoji: '🥕',
              unit: 'kg',
              quantityOrdered: 50,
              quantityReceived: 30,
              unitPrice: 3,
            ),
          ],
        ),
        // CMD-004 : partielle, 830,00 MAD.
        PurchaseOrder(
          id: 'ord-004',
          reference: 'CMD-004',
          supplierId: 'sup-3',
          supplierName: 'DistriFood',
          createdAt: _at(28, hour: 10),
          expectedAt: _at(30, hour: 10),
          lifecycle: OrderLifecycle.ouverte,
          createdBy: 'Fatima',
          lines: const <OrderLine>[
            OrderLine(
              productId: 'p-006',
              productName: 'Huile 5L',
              emoji: '🫒',
              unit: 'un.',
              quantityOrdered: 5,
              quantityReceived: 5,
              unitPrice: 94,
            ),
            OrderLine(
              productId: 'p-007',
              productName: 'Riz 10kg',
              emoji: '🍚',
              unit: 'un.',
              quantityOrdered: 3,
              quantityReceived: 0,
              unitPrice: 120,
            ),
          ],
        ),
        // CMD-003 : entièrement reçue, 1 250,00 MAD.
        PurchaseOrder(
          id: 'ord-003',
          reference: 'CMD-003',
          supplierId: 'sup-2',
          supplierName: 'FreshFood',
          createdAt: _at(27, hour: 9),
          expectedAt: _at(29, hour: 9),
          lifecycle: OrderLifecycle.ouverte,
          createdBy: 'Admin Demo',
          lines: const <OrderLine>[
            OrderLine(
              productId: 'p-009',
              productName: 'Lait 1L',
              emoji: '🥛',
              unit: 'un.',
              quantityOrdered: 100,
              quantityReceived: 100,
              unitPrice: 7.5,
            ),
            OrderLine(
              productId: 'p-011',
              productName: 'Fromage râpé 1kg',
              emoji: '🧀',
              unit: 'un.',
              quantityOrdered: 5,
              quantityReceived: 5,
              unitPrice: 100,
            ),
          ],
        ),
        // CMD-002 : reçue, 430,00 MAD.
        PurchaseOrder(
          id: 'ord-002',
          reference: 'CMD-002',
          supplierId: 'sup-1',
          supplierName: 'AgriPlus',
          createdAt: _at(26, hour: 8, minute: 30),
          lifecycle: OrderLifecycle.ouverte,
          createdBy: 'Youssef',
          lines: const <OrderLine>[
            OrderLine(
              productId: 'p-003',
              productName: 'Pomme de terre',
              emoji: '🥔',
              unit: 'kg',
              quantityOrdered: 50,
              quantityReceived: 50,
              unitPrice: 5,
            ),
            OrderLine(
              productId: 'p-005',
              productName: 'Concombre',
              emoji: '🥒',
              unit: 'kg',
              quantityOrdered: 30,
              quantityReceived: 30,
              unitPrice: 6,
            ),
          ],
        ),
        // CMD-001 : reçue, 980,00 MAD.
        PurchaseOrder(
          id: 'ord-001',
          reference: 'CMD-001',
          supplierId: 'sup-3',
          supplierName: 'DistriFood',
          createdAt: _at(25, hour: 11),
          lifecycle: OrderLifecycle.ouverte,
          createdBy: 'Admin Demo',
          lines: const <OrderLine>[
            OrderLine(
              productId: 'p-008',
              productName: 'Farine 25kg',
              emoji: '🌾',
              unit: 'un.',
              quantityOrdered: 4,
              quantityReceived: 4,
              unitPrice: 200,
            ),
            OrderLine(
              productId: 'p-012',
              productName: 'Eau minérale 1,5L',
              emoji: '💧',
              unit: 'un.',
              quantityOrdered: 45,
              quantityReceived: 45,
              unitPrice: 4,
            ),
          ],
        ),
      ];

  /// Numéro de la prochaine commande créée depuis l'interface.
  static const int nextSequence = 6;
}
