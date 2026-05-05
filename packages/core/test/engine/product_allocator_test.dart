// ABOUTME: Tests for the drink-as-sip + 65% cap + gel-debt allocator.
// ABOUTME: Covers sip background, cap math, gel debt accumulation, refills.
import 'package:test/test.dart';
import 'package:race_fueling_core/src/data/built_in_products.dart';
import 'package:race_fueling_core/src/engine/product_allocator.dart';
import 'package:race_fueling_core/src/engine/timeline_builder.dart';
import 'package:race_fueling_core/src/models/fueling_plan.dart';
import 'package:race_fueling_core/src/models/product.dart';
import 'package:race_fueling_core/src/models/race_config.dart';
import 'package:race_fueling_core/src/models/warning.dart';

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
      // Slots 4 onward: drink is exhausted (quantity:1, no refill). Verify
      // no continued sip contribution.
      for (var i = 4; i < result.entries.length; i++) {
        expect(
          result.entries[i].effectiveDrinkCarbs,
          0,
          reason: 'slot $i should have no drink contribution after sip ends',
        );
      }
    });

    test('synthetic drink-start serving carries isDrinkStart = true', () {
      final drink = _drink(sip: 60, carbs: 80);
      final result = allocateProducts(
        slots: _slots(18),
        targetCarbsPerSlot: _evenTargets(18, 80),
        products: [drink],
        selections: [ProductSelection(productId: drink.id, quantity: 1)],
        aidStations: [],
        stepMin: _stepMin,
      );
      final drinkStartServings = result.entries
          .expand((e) => e.products)
          .where((p) => p.productId == drink.id && p.isDrinkStart)
          .toList();
      expect(drinkStartServings, isNotEmpty);
      for (final s in drinkStartServings) {
        expect(s.productName, contains('(sip start)'));
      }
    });

    test('drink does NOT start when target rate is below 30 g/hr threshold', () {
      // target = 20 g/hr × 0.25 hr/slot = 5 g/slot. unmetPerHr = 5 / 0.25 = 20.
      // 20 < 30 → drink-start guard skips; effectiveDrinkCarbs stays 0
      // throughout, no drink ever picked.
      final drink = _drink(sip: 60, carbs: 80);
      final result = allocateProducts(
        slots: _slots(4),
        targetCarbsPerSlot: _evenTargets(4, 20), // very low target
        products: [drink],
        selections: [ProductSelection(productId: drink.id, quantity: 1)],
        aidStations: [],
        stepMin: _stepMin,
      );
      for (final entry in result.entries) {
        expect(
          entry.effectiveDrinkCarbs,
          0,
          reason: 'low-rate race should never start a sip drink',
        );
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
      expect(gelCount, inInclusiveRange(3, 8));
    });

    test('slot over-delivery surfaces advisory warning', () {
      // Construct: target = 20g/slot, drink covers 13g (cap), debt builds
      // until a 25g gel justifies and fires. The 25g gel + 13g drink = 38g
      // step total against 20g target → 90% over → advisory threshold (20%)
      // crossed; warning emitted on that slot.
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
      final overageWarnings = result.entries
          .expand((e) => e.warnings)
          .where((w) => w.message.contains('over-delivers'))
          .toList();
      expect(
        overageWarnings,
        isNotEmpty,
        reason:
            'a debt-justified gel firing on top of a sip slot should '
            'surface the slot-overage advisory at least once',
      );
    });

    test('40g gel does NOT fire when pooled debt is 14g', () {
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

  group('allocator — depletion warnings', () {
    test(
      'sip drink finishing in the last slot does NOT trip depletion warning',
      () {
        // 4-slot race × 15min = 60 min. One drink with sipMinutes=60 → 4 steps,
        // exactly fits. lastContribSlot tracking should mark the drink as
        // contributing through the final slot — no false 'ran out early'
        // warning.
        final drink = _drink(sip: 60, carbs: 80);
        final result = allocateProducts(
          slots: _slots(4),
          targetCarbsPerSlot: _evenTargets(4, 80),
          products: [drink],
          selections: [ProductSelection(productId: drink.id, quantity: 1)],
          aidStations: [],
          stepMin: _stepMin,
        );
        expect(
          result.depletionWarnings,
          isEmpty,
          reason: 'drink finishes its sip on the final slot — not a depletion',
        );
      },
    );

    test(
      'inventory exhausted before plan ends DOES trip depletion warning',
      () {
        // 12-slot race (3 hours). One bottle (60min sip) + 2 small gels.
        // The drink finishes at slot 4 with no refill; inventory empty after.
        // Depletion warning should fire on the drink (last contribution slot
        // 4 of 12).
        final drink = _drink(sip: 60, carbs: 80);
        final gel = _gel(carbs: 25);
        final result = allocateProducts(
          slots: _slots(12),
          targetCarbsPerSlot: _evenTargets(12, 80),
          products: [drink, gel],
          selections: [
            ProductSelection(productId: drink.id, quantity: 1),
            ProductSelection(productId: gel.id, quantity: 2),
          ],
          aidStations: [],
          stepMin: _stepMin,
        );
        expect(
          result.depletionWarnings.any((w) => w.contains('Test Drink')),
          isTrue,
          reason: 'drink ran out before plan ended; warning should fire',
        );
      },
    );

    test(
      'selection referencing unknown product ID emits depletion warning',
      () {
        final drink = _drink();
        final result = allocateProducts(
          slots: _slots(4),
          targetCarbsPerSlot: _evenTargets(4, 80),
          products: [drink],
          selections: [
            ProductSelection(productId: drink.id, quantity: 1),
            ProductSelection(productId: 'phantom-id', quantity: 3),
          ],
          aidStations: [],
          stepMin: _stepMin,
        );
        expect(
          result.depletionWarnings.any(
            (w) =>
                w.contains('phantom-id') &&
                w.toLowerCase().contains('not found'),
          ),
          isTrue,
        );
      },
    );
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
      expect(
        result.entries[5].aidStation,
        isNotNull,
        reason: 'aid station fires on the slot at minute 90',
      );
      expect(
        result.entries[5].effectiveDrinkCarbs,
        greaterThan(0),
        reason: 'second drink starts in the same slot as the refill',
      );
      expect(
        result.entries[4].effectiveDrinkCarbs,
        0,
        reason:
            'slot 4 (75 min) is empty — first drink finished, no refill yet',
      );
    });

    test(
      'refill on the very last slot is silently unused (A1 known limit)',
      () {
        // 4-slot race × 15min = 60 min. Aid station at minute 60 (last slot).
        // The drink-start guard `i < slots.length - 1` prevents starting a new
        // drink on the last slot, so the refilled bottle goes unused.
        // Pin this current behavior; revisit when A1 is fixed.
        final drink = _drink(sip: 60, carbs: 80);
        final result = allocateProducts(
          slots: _slots(4),
          targetCarbsPerSlot: _evenTargets(4, 80),
          products: [drink],
          selections: [ProductSelection(productId: drink.id, quantity: 1)],
          aidStations: [
            AidStation(timeMinutes: 60, refill: [drink.id]),
          ],
          stepMin: _stepMin,
        );
        // The refill happened (aidStation marker set on slot 3, the last slot).
        expect(result.entries[3].aidStation, isNotNull);
        // But no second drink started in the last slot — slot 3's drink carbs
        // are either zero (no contribution) or the same as slot 2's (the
        // first drink's last sip, not a new bottle starting).
        expect(
          result.entries[3].effectiveDrinkCarbs == 0 ||
              result.entries[3].effectiveDrinkCarbs ==
                  result.entries[2].effectiveDrinkCarbs,
          isTrue,
          reason: 'last-slot refill cannot start a new drink (known limit)',
        );
      },
    );
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
        final allEntryWarnings = result.entries
            .expand((e) => e.warnings)
            .toList();
        expect(
          allEntryWarnings.any(
            (w) =>
                w.severity == Severity.advisory &&
                (w.message.toLowerCase().contains('over-deliver') ||
                    w.message.toLowerCase().contains('gut')),
          ),
          isTrue,
          reason:
              'high-rate seed scenario should surface at least one '
              'gut-tolerance / over-delivery advisory',
        );
      },
    );
  });
}
