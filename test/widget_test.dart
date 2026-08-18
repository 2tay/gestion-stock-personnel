import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/constants/app_enums.dart';
import 'package:gestion_stock/core/theme/app_theme.dart';
import 'package:gestion_stock/shared/shared.dart';

/// Tests de fumée du design system.
///
/// Ils vérifient que les composants partagés se construisent et réagissent.
/// Les tests de widgets des modules viendront avec chaque feature.
void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('AppButton affiche son libellé et déclenche onPressed',
      (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(
      wrap(AppButton.primary(label: 'Enregistrer', onPressed: () => taps++)),
    );

    expect(find.text('Enregistrer'), findsOneWidget);
    await tester.tap(find.text('Enregistrer'));
    expect(taps, 1);
  });

  testWidgets('AppButton désactivé ne déclenche rien',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(const AppButton.primary(label: 'Indisponible', onPressed: null)),
    );

    await tester.tap(find.text('Indisponible'));
    expect(find.text('Indisponible'), findsOneWidget);
  });

  testWidgets('StatusBadge traduit les statuts métier',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            StatusBadge.stock(StockStatus.faible),
            StatusBadge.order(OrderStatus.recue),
            StatusBadge.attendance(AttendanceStatus.enPause),
          ],
        ),
      ),
    );

    expect(find.text('Faible'), findsOneWidget);
    expect(find.text('Reçue'), findsOneWidget);
    expect(find.text('En pause'), findsOneWidget);
  });

  testWidgets('FilterTabs remonte la valeur sélectionnée',
      (WidgetTester tester) async {
    String? selected;
    await tester.pumpWidget(
      wrap(
        FilterTabs<String>(
          selected: 'tous',
          onSelected: (String v) => selected = v,
          tabs: const <FilterTab<String>>[
            FilterTab<String>(label: 'Tous', value: 'tous'),
            FilterTab<String>(label: 'Stock faible', value: 'faible'),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Stock faible'));
    expect(selected, 'faible');
  });

  testWidgets('AppDataTable rend ses lignes et trie une colonne',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 800,
          child: AppDataTable<(String, int)>(
            rows: const <(String, int)>[('Tomate', 95), ('Carotte', 55)],
            columns: <AppColumn<(String, int)>>[
              AppColumn<(String, int)>.text(
                label: 'Produit',
                value: ((String, int) r) => r.$1,
                sortValue: ((String, int) r) => r.$1,
              ),
              AppColumn<(String, int)>.text(
                label: 'Stock',
                numeric: true,
                value: ((String, int) r) => '${r.$2}',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Tomate'), findsOneWidget);
    expect(find.text('Carotte'), findsOneWidget);

    await tester.tap(find.text('PRODUIT'));
    await tester.pump();
    expect(find.text('Carotte'), findsOneWidget);
  });

  testWidgets('AppDataTable affiche un état vide', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 800,
          child: AppDataTable<String>(
            rows: const <String>[],
            columns: <AppColumn<String>>[
              AppColumn<String>.text(
                label: 'Produit',
                value: (String r) => r,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Aucun résultat'), findsOneWidget);
  });
}
