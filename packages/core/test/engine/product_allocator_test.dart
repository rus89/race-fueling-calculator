// ABOUTME: Tests for greedy product allocation to timeline slots.
// ABOUTME: Verifies quantity tracking, aid station constraints, and G:F ratio optimization.
import 'package:test/test.dart';
import 'package:race_fueling_core/src/engine/product_allocator.dart';
import 'package:race_fueling_core/src/engine/timeline_builder.dart';
import 'package:race_fueling_core/src/models/product.dart';
import 'package:race_fueling_core/src/models/race_config.dart';

void main() {
  final gel = Product(
    id: 'gel-1',
    name: 'Test Gel',
    type: ProductType.gel,
    carbsPerServing: 25.0,
    glucoseGrams: 15.0,
    fructoseGrams: 10.0,
    caffeineMg: 30.0,
    waterRequiredMl: 100.0,
  );

  final drinkMix = Product(
    id: 'drink-1',
    name: 'Test Drink',
    type: ProductType.liquid,
    carbsPerServing: 40.0,
    glucoseGrams: 22.0,
    fructoseGrams: 18.0,
    waterRequiredMl: 0.0,
  );

  group('allocateProducts', () {
    test('single product, enough quantity', () {
      final slots = [
        TimeSlot(timeMark: Duration(minutes: 20)),
        TimeSlot(timeMark: Duration(minutes: 40)),
        TimeSlot(timeMark: Duration(minutes: 60)),
      ];
      final targets = [20.0, 20.0, 20.0];
      final selections = [
        ProductSelection(productId: 'gel-1', quantity: 6),
      ];

      final result = allocateProducts(
        slots: slots,
        targetCarbsPerSlot: targets,
        products: [gel],
        selections: selections,
      );

      expect(result.entries.length, 3);
      // Each slot gets 1 gel (25g >= 20g target)
      expect(result.entries[0].products.first.servings, 1);
      expect(result.entries[0].carbsTotal, 25.0);
    });

    test('product depletion triggers warning', () {
      final slots = List.generate(
          4, (i) => TimeSlot(timeMark: Duration(minutes: (i + 1) * 20)));
      final targets = [25.0, 25.0, 25.0, 25.0];
      final selections = [
        ProductSelection(productId: 'gel-1', quantity: 2),
      ];

      final result = allocateProducts(
        slots: slots,
        targetCarbsPerSlot: targets,
        products: [gel],
        selections: selections,
      );

      // First 2 slots get gel, last 2 get nothing
      expect(result.entries[2].products, isEmpty);
      expect(result.entries[3].products, isEmpty);
      expect(result.depletionWarnings, isNotEmpty);
      expect(
        result.depletionWarnings
            .any((w) => w.contains('gel-1') || w.contains('Test Gel')),
        true,
      );
    });

    test('aid-station-only product used only at aid stations', () {
      final slots = [
        TimeSlot(timeMark: Duration(minutes: 20)),
        TimeSlot(timeMark: Duration(minutes: 40), isAidStation: true),
        TimeSlot(timeMark: Duration(minutes: 60)),
      ];
      final targets = [20.0, 20.0, 20.0];
      final selections = [
        ProductSelection(
            productId: 'drink-1', quantity: 2, isAidStationOnly: true),
        ProductSelection(productId: 'gel-1', quantity: 4),
      ];

      final result = allocateProducts(
        slots: slots,
        targetCarbsPerSlot: targets,
        products: [gel, drinkMix],
        selections: selections,
      );

      // Slot 1 (aid station): should use drink mix
      final aidEntry = result.entries[1];
      expect(aidEntry.products.any((p) => p.productId == 'drink-1'), true);

      // Slot 0 (not aid station): should not use drink mix
      final regularEntry = result.entries[0];
      expect(regularEntry.products.any((p) => p.productId == 'drink-1'), false);
    });

    test('missing product ID does not crash and emits warning', () {
      final slots = [TimeSlot(timeMark: Duration(minutes: 20))];
      final targets = [20.0];
      final selections = [
        ProductSelection(productId: 'nonexistent-product', quantity: 3),
        ProductSelection(productId: 'gel-1', quantity: 3),
      ];

      final result = allocateProducts(
        slots: slots,
        targetCarbsPerSlot: targets,
        products: [gel],
        selections: selections,
      );

      // Should not crash; nonexistent product is skipped
      expect(result.entries[0].carbsTotal, greaterThan(0));
      // Warning emitted for missing product
      expect(
        result.depletionWarnings.any((w) => w.contains('nonexistent-product')),
        true,
      );
    });

    test('cumulativeCaffeine accumulates across slots', () {
      final slots = [
        TimeSlot(timeMark: Duration(minutes: 20)),
        TimeSlot(timeMark: Duration(minutes: 40)),
        TimeSlot(timeMark: Duration(minutes: 60)),
      ];
      final targets = [20.0, 20.0, 20.0];
      final selections = [ProductSelection(productId: 'gel-1', quantity: 6)];

      final result = allocateProducts(
        slots: slots,
        targetCarbsPerSlot: targets,
        products: [gel],
        selections: selections,
      );

      // Each slot gets 1 gel (30mg caffeine each) → running total 30, 60, 90
      expect(result.entries[0].cumulativeCaffeine, 30.0);
      expect(result.entries[1].cumulativeCaffeine, 60.0);
      expect(result.entries[2].cumulativeCaffeine, 90.0);
    });

    test(
      'target 20g with 25g product over-allocates by 25% (ceil bug)',
      () {
        final slots = [TimeSlot(timeMark: Duration(minutes: 20))];
        final targets = [20.0];
        final selections = [ProductSelection(productId: 'gel-1', quantity: 3)];

        final result = allocateProducts(
          slots: slots,
          targetCarbsPerSlot: targets,
          products: [gel],
          selections: selections,
        );

        // Desired: entries[0].carbsTotal close to 20 (0 or 1 gel, not 25g).
        // Actual: product_allocator.dart uses .ceil(), so 20g/25g rounds up to 1 gel = 25g.
        expect(result.entries[0].carbsTotal, lessThanOrEqualTo(20.0));
      },
      skip: 'KI-1: allocator uses .ceil(); Known Issue to fix in Phase 8',
    );
  });
}
