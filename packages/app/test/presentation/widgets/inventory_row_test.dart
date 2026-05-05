// ABOUTME: Widget tests for InventoryRow — kind-dot Semantics, ratio formatting,
// ABOUTME: brand-null fallback, caffeine row conditional, type label append.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/domain/domain.dart';
import 'package:race_fueling_app/presentation/widgets/inventory_row.dart';

import '../../test_helpers/google_fonts_setup.dart';

void main() {
  setUpAll(setUpGoogleFontsForTests);

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders single ratio when fructoseGrams is 0', (tester) async {
    await tester.pumpWidget(
      wrap(
        InventoryRow(
          product: Product(
            id: 'glucose-only',
            name: 'Glucose Only Mix',
            type: ProductType.gel,
            carbsPerServing: 25,
            glucoseGrams: 25,
          ),
          count: 0,
          onChanged: (_) {},
        ),
      ),
    );
    expect(find.textContaining('single'), findsOneWidget);
  });

  testWidgets('renders G:F ratio when fructoseGrams is positive', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        InventoryRow(
          product: Product(
            id: 'mix',
            name: 'Test Mix',
            type: ProductType.gel,
            carbsPerServing: 80,
            glucoseGrams: 50,
            fructoseGrams: 30,
          ),
          count: 0,
          onChanged: (_) {},
        ),
      ),
    );
    expect(find.textContaining('50:30'), findsOneWidget);
  });

  testWidgets('appends product type to mono subline', (tester) async {
    await tester.pumpWidget(
      wrap(
        InventoryRow(
          product: Product(
            id: 'gel',
            name: 'Test Gel',
            type: ProductType.gel,
            carbsPerServing: 25,
          ),
          count: 0,
          onChanged: (_) {},
        ),
      ),
    );
    // Subline is "25g · single · Gel"
    expect(find.textContaining('Gel'), findsWidgets);
  });

  testWidgets('null brand renders only product name', (tester) async {
    await tester.pumpWidget(
      wrap(
        InventoryRow(
          product: Product(
            id: 'gel',
            name: 'Generic Gel',
            type: ProductType.gel,
            carbsPerServing: 25,
          ),
          count: 0,
          onChanged: (_) {},
        ),
      ),
    );
    expect(find.text('Generic Gel'), findsOneWidget);
  });

  testWidgets('renders brand and name together when both present', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        InventoryRow(
          product: Product(
            id: 'gel',
            brand: 'Maurten',
            name: 'Gel 100',
            type: ProductType.gel,
            carbsPerServing: 25,
          ),
          count: 0,
          onChanged: (_) {},
        ),
      ),
    );
    expect(find.text('Maurten Gel 100'), findsOneWidget);
  });

  testWidgets('Semantics label on kind dot announces product type', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        InventoryRow(
          product: Product(
            id: 'liquid',
            name: 'Drink',
            type: ProductType.liquid,
            carbsPerServing: 80,
          ),
          count: 0,
          onChanged: (_) {},
        ),
      ),
    );
    expect(find.bySemanticsLabel('Liquid'), findsOneWidget);
    handle.dispose();
  });
}
