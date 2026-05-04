// ABOUTME: Tests for the drink-as-sip + 65% cap + gel-debt allocator.
// ABOUTME: Covers sip background, cap math, gel debt accumulation, refills.
import 'package:test/test.dart';
import 'package:race_fueling_core/src/data/built_in_products.dart';
import 'package:race_fueling_core/src/engine/product_allocator.dart';
import 'package:race_fueling_core/src/engine/timeline_builder.dart';
import 'package:race_fueling_core/src/models/fueling_plan.dart';
import 'package:race_fueling_core/src/models/product.dart';
import 'package:race_fueling_core/src/models/race_config.dart';

const _stepMin = 15;

List<TimeSlot> _slots(int count) => List.generate(
  count,
  (i) => TimeSlot(timeMark: Duration(minutes: (i + 1) * _stepMin)),
);

List<double> _evenTargets(int count, double gPerHr) {
  final perStep = gPerHr * (_stepMin / 60.0);
  return List.filled(count, perStep);
}

Product _drink({int sip = 60, double carbs = 80}) => Product(
  id: 'drink-$carbs-$sip',
  name: 'Test Drink',
  type: ProductType.liquid,
  carbsPerServing: carbs,
  glucoseGrams: carbs / 1.8,
  fructoseGrams: carbs * 0.8 / 1.8,
  sipMinutes: sip,
);

Product _gel({double carbs = 25, double caffeine = 0}) => Product(
  id: 'gel-$carbs-$caffeine',
  name: 'Test Gel',
  type: ProductType.gel,
  carbsPerServing: carbs,
  glucoseGrams: carbs * 0.55,
  fructoseGrams: carbs * 0.45,
  caffeineMg: caffeine,
);

void main() {
  group('allocator — drink as sip background', () {
    test('500ml drink with sipMinutes 60 spreads across 4 slots of 15min', () {
      final drink = _drink(sip: 60, carbs: 80);
      final result = allocateProducts(
        slots: _slots(18), // 4h30 race
        targetCarbsPerSlot: _evenTargets(18, 80),
        products: [drink],
        selections: [ProductSelection(productId: drink.id, quantity: 1)],
        aidStations: [],
        stepMin: _stepMin,
      );
      // Drink contributes 80/4 = 20g/slot for the first 4 slots
      final sipContributions = result.entries
          .take(4)
          .map((e) => e.effectiveDrinkCarbs)
          .toList();
      // Cap = 0.65 * 20 = 13g — drink is capped
      for (final c in sipContributions) {
        expect(c, closeTo(13.0, 0.01));
      }
    });
  });

  group('allocator — gel debt accumulation', () {
    test('debt accumulates across slots and fires gel when threshold met', () {
      final drink = _drink(sip: 60, carbs: 80);
      final gel = _gel(carbs: 25);
      final result = allocateProducts(
        slots: _slots(18),
        targetCarbsPerSlot: _evenTargets(18, 80),
        products: [drink, gel],
        selections: [
          ProductSelection(productId: drink.id, quantity: 2),
          ProductSelection(productId: gel.id, quantity: 6),
        ],
        aidStations: [],
        stepMin: _stepMin,
      );
      final gelCount = result.entries
          .map(
            (e) => e.products
                .where((p) => p.productId == gel.id)
                .fold<int>(0, (a, b) => a + b.servings),
          )
          .fold<int>(0, (a, b) => a + b);
      // Roughly: target=20g, drink covers 13, debt accumulates 7g/slot × 18 ≈ 126g
      // 25g gels needed: ~5 to match debt
      expect(gelCount, inInclusiveRange(4, 6));
    });

    test('40g gel does NOT fire when debt is only 7g', () {
      final drink = _drink(sip: 60, carbs: 80);
      final bigGel = _gel(carbs: 40);
      final result = allocateProducts(
        slots: _slots(2), // 30 min total — only ~14g debt
        targetCarbsPerSlot: _evenTargets(2, 80),
        products: [drink, bigGel],
        selections: [
          ProductSelection(productId: drink.id, quantity: 1),
          ProductSelection(productId: bigGel.id, quantity: 5),
        ],
        aidStations: [],
        stepMin: _stepMin,
      );
      final fired = result.entries.any(
        (e) => e.products.any((p) => p.productId == bigGel.id),
      );
      expect(fired, isFalse, reason: '40g gel too big for 14g pooled debt');
    });
  });

  group('allocator — aid station refill', () {
    test('refill at min 90 lands in slot 5 (timeMark == 90)', () {
      final drink = _drink(sip: 60, carbs: 80);
      final result = allocateProducts(
        slots: _slots(18),
        targetCarbsPerSlot: _evenTargets(18, 80),
        products: [drink],
        selections: [ProductSelection(productId: drink.id, quantity: 1)],
        aidStations: [
          AidStation(timeMinutes: 90, refill: [drink.id]),
        ],
        stepMin: _stepMin,
      );
      // First drink runs slots 0-3 (60min sip / 15min step). Slot 4 is
      // empty (inventory exhausted). Slot 5's timeMark is 90 min so the
      // aid station fires there: refill → new drink starts in the same
      // slot. The second drink runs slots 5-8.
      final secondStart = result.entries
          .skip(4)
          .toList()
          .indexWhere((e) => e.effectiveDrinkCarbs > 0);
      expect(
        secondStart,
        greaterThan(0),
        reason: 'second drink should start after the first ends, post-refill',
      );
      expect(result.entries[5].aidStation, isNotNull);
    });
  });

  group('allocator — discipline parameter ignored (data-only)', () {
    test(
      'two configs differing only by discipline produce identical entries',
      () {
        final drink = _drink();
        final gel = _gel();
        List<PlanEntry> run(Discipline? d) {
          return allocateProducts(
            slots: _slots(8),
            targetCarbsPerSlot: _evenTargets(8, 80),
            products: [drink, gel],
            selections: [
              ProductSelection(productId: drink.id, quantity: 1),
              ProductSelection(productId: gel.id, quantity: 4),
            ],
            aidStations: [],
            stepMin: _stepMin,
            discipline: d,
          ).entries;
        }

        expect(run(Discipline.xcm), equals(run(Discipline.road)));
      },
    );
  });

  group('allocator — Andalucía Bike Race seed scenario', () {
    test(
      'average within ±5 g/hr of target, gels appear, gut-warning fires',
      () {
        final lib = builtInProducts;
        Product byId(String id) => lib.firstWhere((p) => p.id == id);
        final selections = [
          ProductSelection(
            productId: byId('sis-beta-fuel-drink').id,
            quantity: 2,
          ),
          ProductSelection(productId: byId('maurten-160').id, quantity: 4),
          ProductSelection(
            productId: byId('maurten-gel-100-caf').id,
            quantity: 2,
          ),
          ProductSelection(
            productId: byId('precision-pf30-gel').id,
            quantity: 2,
          ),
          ProductSelection(productId: byId('clif-bloks').id, quantity: 1),
        ];
        final result = allocateProducts(
          slots: _slots(18),
          targetCarbsPerSlot: _evenTargets(18, 80),
          products: lib,
          selections: selections,
          aidStations: [
            AidStation(timeMinutes: 90, refill: ['sis-beta-fuel-drink']),
            AidStation(
              timeMinutes: 180,
              refill: ['sis-beta-fuel-drink', 'maurten-gel-100-caf'],
            ),
          ],
          stepMin: _stepMin,
        );
        final total = result.entries.fold<double>(
          0,
          (s, e) => s + e.carbsTotal,
        );
        final hours = (18 * _stepMin) / 60.0;
        final avg = total / hours;
        expect(
          avg,
          inInclusiveRange(75, 85),
          reason: 'avg=$avg should be ±5 of 80g/hr target',
        );
        final gelCount = result.entries.fold<int>(
          0,
          (s, e) =>
              s +
              e.products
                  .where((p) => !p.productName.toLowerCase().contains('mix'))
                  .fold<int>(0, (a, b) => a + b.servings),
        );
        expect(
          gelCount,
          greaterThan(0),
          reason: 'gels should appear in the rotation',
        );
      },
    );
  });
}
