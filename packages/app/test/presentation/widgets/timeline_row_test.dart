// ABOUTME: Widget tests for TimelineRow — bar geometry, items list, aid markers.
// ABOUTME: Covers cumulative readout, sip-bottle line, and aid station marker.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/presentation/widgets/timeline_row.dart';
import 'package:race_fueling_core/core.dart';

import '../../test_helpers/google_fonts_setup.dart';

void main() {
  setUpAll(setUpGoogleFontsForTests);

  testWidgets('row-level Semantics composes time, target, and cumulative', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TimelineRow(
            entry: PlanEntry(
              timeMark: Duration(minutes: 30),
              products: [],
              carbsGlucose: 7,
              carbsFructose: 6,
              carbsTotal: 13,
              cumulativeCarbs: 26,
              cumulativeCaffeine: 0,
              waterMl: 125,
              effectiveDrinkCarbs: 13,
            ),
            targetG: 20,
            peakG: 25,
            productsById: {},
          ),
        ),
      ),
    );
    final handle = tester.ensureSemantics();
    final data = tester
        .getSemantics(find.byType(TimelineRow))
        .getSemanticsData();
    expect(data.label, contains('Time'));
    expect(data.label, contains('cumulative'));
    handle.dispose();
  });

  testWidgets('renders cumulative carbs readout', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TimelineRow(
            entry: PlanEntry(
              timeMark: Duration(minutes: 30),
              products: [],
              carbsGlucose: 7,
              carbsFructose: 6,
              carbsTotal: 13,
              cumulativeCarbs: 26,
              cumulativeCaffeine: 0,
              waterMl: 125,
              effectiveDrinkCarbs: 13,
            ),
            targetG: 20,
            peakG: 25,
            productsById: {},
          ),
        ),
      ),
    );
    expect(find.textContaining('26', findRichText: true), findsWidgets);
  });

  testWidgets('shows aid station marker (singular) with item suffix', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TimelineRow(
            entry: PlanEntry(
              timeMark: Duration(minutes: 90),
              products: [],
              carbsGlucose: 0,
              carbsFructose: 0,
              carbsTotal: 0,
              cumulativeCarbs: 50,
              cumulativeCaffeine: 0,
              waterMl: 0,
              aidStation: AidStation(timeMinutes: 90, refill: ['x']),
            ),
            targetG: 20,
            peakG: 25,
            productsById: {},
          ),
        ),
      ),
    );
    expect(find.text('Aid station — refill 1 item'), findsOneWidget);
  });

  testWidgets('aid station marker pluralizes refill items', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TimelineRow(
            entry: PlanEntry(
              timeMark: Duration(minutes: 90),
              products: [],
              carbsGlucose: 0,
              carbsFructose: 0,
              carbsTotal: 0,
              cumulativeCarbs: 50,
              cumulativeCaffeine: 0,
              waterMl: 0,
              aidStation: AidStation(timeMinutes: 90, refill: ['x', 'y']),
            ),
            targetG: 20,
            peakG: 25,
            productsById: {},
          ),
        ),
      ),
    );
    expect(find.text('Aid station — refill 2 items'), findsOneWidget);
  });

  testWidgets('shows sip-bottle line when only effectiveDrinkCarbs > 0', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TimelineRow(
            entry: PlanEntry(
              timeMark: Duration(minutes: 30),
              products: [],
              carbsGlucose: 7,
              carbsFructose: 6,
              carbsTotal: 13,
              cumulativeCarbs: 26,
              cumulativeCaffeine: 0,
              waterMl: 125,
              effectiveDrinkCarbs: 13,
            ),
            targetG: 20,
            peakG: 25,
            productsById: {},
          ),
        ),
      ),
    );
    expect(find.textContaining('sipping bottle'), findsOneWidget);
  });

  testWidgets('sip-bottle line is hidden when entry has an isDrinkStart '
      'product (allocator already emitted the start)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TimelineRow(
            entry: PlanEntry(
              timeMark: Duration(minutes: 30),
              products: [
                ProductServing(
                  productId: 'mix-1',
                  productName: 'Maurten Mix (sip start)',
                  servings: 1,
                  isDrinkStart: true,
                ),
              ],
              carbsGlucose: 7,
              carbsFructose: 6,
              carbsTotal: 13,
              cumulativeCarbs: 26,
              cumulativeCaffeine: 0,
              waterMl: 125,
              effectiveDrinkCarbs: 13,
            ),
            targetG: 20,
            peakG: 25,
            productsById: {},
          ),
        ),
      ),
    );
    expect(find.textContaining('sipping bottle'), findsNothing);
  });

  testWidgets(
    'renders normally when products contain only non-drink-start items',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimelineRow(
              entry: const PlanEntry(
                timeMark: Duration(minutes: 30),
                products: [
                  ProductServing(
                    productId: 'gel-1',
                    productName: 'Maurten Gel 100',
                    servings: 1,
                  ),
                ],
                carbsGlucose: 16,
                carbsFructose: 9,
                carbsTotal: 25,
                cumulativeCarbs: 25,
                cumulativeCaffeine: 0,
                waterMl: 0,
              ),
              targetG: 20,
              peakG: 25,
              productsById: {
                'gel-1': Product(
                  id: 'gel-1',
                  name: 'Maurten Gel 100',
                  brand: 'Maurten',
                  type: ProductType.gel,
                  carbsPerServing: 25,
                  glucoseGrams: 16,
                  fructoseGrams: 9,
                  caffeineMg: 0,
                  waterRequiredMl: 100,
                ),
              },
            ),
          ),
        ),
      );
      expect(find.text('Maurten Gel 100'), findsOneWidget);
      expect(find.textContaining('sipping bottle'), findsNothing);
    },
  );
}
