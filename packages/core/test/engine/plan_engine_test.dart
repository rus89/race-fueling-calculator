// ABOUTME: Integration tests for the full plan generation pipeline.
// ABOUTME: Verifies that generatePlan produces correct timelines, totals, and warnings.
import 'package:test/test.dart';
import 'package:race_fueling_core/src/engine/plan_engine.dart';
import 'package:race_fueling_core/src/models/product.dart';
import 'package:race_fueling_core/src/models/athlete_profile.dart';
import 'package:race_fueling_core/src/models/race_config.dart';
import 'package:race_fueling_core/src/models/warning.dart';

void main() {
  final gel = Product(
    id: 'gel-1',
    name: 'Test Gel',
    type: ProductType.gel,
    carbsPerServing: 25.0,
    glucoseGrams: 14.0,
    fructoseGrams: 11.0,
    caffeineMg: 30.0,
    waterRequiredMl: 100.0,
  );

  final profile = AthleteProfile(
    gutToleranceGPerHr: 80.0,
    unitSystem: UnitSystem.metric,
  );

  group('generatePlan', () {
    test('simple 2-hour race with steady strategy', () {
      final config = RaceConfig(
        name: 'Test Race',
        duration: Duration(hours: 2),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [ProductSelection(productId: 'gel-1', quantity: 8)],
      );

      final plan = generatePlan(config, profile, [gel]);

      expect(plan.entries.length, 6); // 120min / 20min
      expect(plan.entries.first.carbsTotal, greaterThan(0));
      expect(plan.entries.last.cumulativeCarbs, greaterThan(0));
      expect(plan.summary.totalCarbs, greaterThan(0));
      expect(plan.summary.averageGPerHr, greaterThan(0));
      expect(
        plan.warnings.where((w) => w.severity == Severity.critical),
        isEmpty,
      );
    });

    test('altitude adjustment increases total carbs vs flat race', () {
      // The drink cap scales linearly with the per-slot target, so a sip
      // drink with ample supply makes the altitude carb multiplier
      // measurable. With 25g gels, debt-driven picks quantize and can hide
      // a 5% target bump.
      final drink = Product(
        id: 'sip-drink',
        name: 'Sip Drink',
        type: ProductType.liquid,
        carbsPerServing: 80.0,
        glucoseGrams: 44.0,
        fructoseGrams: 36.0,
        sipMinutes: 60,
      );

      final configFlat = RaceConfig(
        name: 'Flat',
        duration: Duration(hours: 2),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [
          ProductSelection(productId: 'sip-drink', quantity: 4),
        ],
      );
      final configMountain = RaceConfig(
        name: 'Mountain',
        duration: Duration(hours: 2),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [
          ProductSelection(productId: 'sip-drink', quantity: 4),
        ],
        altitudeM: 2500,
      );

      final planFlat = generatePlan(configFlat, profile, [drink]);
      final planMountain = generatePlan(configMountain, profile, [drink]);

      expect(
        planMountain.summary.totalCarbs,
        greaterThan(planFlat.summary.totalCarbs),
      );
      expect(planMountain.summary.environmentalNotes, isNotEmpty);
    });

    test('insufficient products triggers a warning', () {
      final config = RaceConfig(
        name: 'Long Race',
        duration: Duration(hours: 4),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 80.0,
        strategy: Strategy.steady,
        selectedProducts: [ProductSelection(productId: 'gel-1', quantity: 3)],
      );

      final plan = generatePlan(config, profile, [gel]);

      expect(plan.warnings, isNotEmpty);
    });

    test('zero-duration race produces an empty plan', () {
      final config = RaceConfig(
        name: 'Zero',
        duration: Duration.zero,
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [ProductSelection(productId: 'gel-1', quantity: 4)],
      );

      final plan = generatePlan(config, profile, [gel]);

      expect(plan.entries, isEmpty);
      expect(plan.summary.totalCarbs, 0);
      expect(plan.summary.averageGPerHr, 0);
      expect(plan.summary.totalWaterMl, 0);
    });

    test('empty product catalog produces entries with no servings', () {
      final config = RaceConfig(
        name: 'Starved',
        duration: Duration(hours: 2),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [ProductSelection(productId: 'gel-1', quantity: 4)],
      );

      final plan = generatePlan(config, profile, const []);

      expect(plan.entries, isNotEmpty);
      expect(plan.entries.every((e) => e.products.isEmpty), true);
      expect(plan.summary.totalCarbs, 0);
    });

    test('empty selectedProducts produces entries with no servings', () {
      final config = RaceConfig(
        name: 'Unpacked',
        duration: Duration(hours: 2),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: const [],
      );

      final plan = generatePlan(config, profile, [gel]);

      expect(plan.entries, isNotEmpty);
      expect(plan.entries.every((e) => e.products.isEmpty), true);
      expect(plan.summary.totalCarbs, 0);
    });

    test('zero-duration race emits no warnings', () {
      final config = RaceConfig(
        name: 'Zero',
        duration: Duration.zero,
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [ProductSelection(productId: 'gel-1', quantity: 4)],
      );

      final plan = generatePlan(config, profile, [gel]);

      expect(plan.warnings, isEmpty);
    });

    test('empty product catalog with selections warns product not found', () {
      final config = RaceConfig(
        name: 'Starved',
        duration: Duration(hours: 2),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [ProductSelection(productId: 'gel-1', quantity: 4)],
      );

      final plan = generatePlan(config, profile, const []);

      // Selected product not found in catalog -> depletion-style warning.
      expect(plan.warnings, hasLength(1));
      expect(plan.warnings.first.message, contains('not found in library'));
    });

    test('empty selectedProducts with non-empty catalog emits no warnings', () {
      final config = RaceConfig(
        name: 'Unpacked',
        duration: Duration(hours: 2),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: const [],
      );

      final plan = generatePlan(config, profile, [gel]);

      expect(plan.warnings, isEmpty);
    });

    test('altitude under-delivery triggers advisory warning', () {
      // 2-hour race at 2500m altitude → 5% carb boost, target 63g/hr,
      // total adjusted target ≈ 126g. Provide only 4 gels × 25g = 100g supply,
      // so allocator can deliver at most 100g — below 90% of 126g (113g).
      // The under-delivery warning must fire.
      final config = RaceConfig(
        name: 'Mountain Short',
        duration: Duration(hours: 2),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [ProductSelection(productId: 'gel-1', quantity: 4)],
        altitudeM: 2500,
      );

      final plan = generatePlan(config, profile, [gel]);

      expect(
        plan.warnings.any(
          (w) =>
              w.severity == Severity.advisory &&
              w.message.contains('altitude-adjusted carb target'),
        ),
        true,
        reason: 'altitude-adjusted plan with insufficient supply must warn',
      );
    });

    test(
      'altitude with sufficient product emits no under-delivery warning',
      () {
        // 2-hour race at 2500m, plenty of gels. Plan should reach the
        // boosted target → no under-delivery advisory.
        final config = RaceConfig(
          name: 'Mountain Stocked',
          duration: Duration(hours: 2),
          timelineMode: TimelineMode.timeBased,
          intervalMinutes: 20,
          targetCarbsGPerHr: 60.0,
          strategy: Strategy.steady,
          selectedProducts: [
            ProductSelection(productId: 'gel-1', quantity: 12),
          ],
          altitudeM: 2500,
        );

        final plan = generatePlan(config, profile, [gel]);

        expect(
          plan.warnings.any(
            (w) => w.message.contains('altitude-adjusted carb target'),
          ),
          false,
          reason: 'sufficient supply must not emit under-delivery advisory',
        );
      },
    );

    test(
      'plan surfaces aid-station warning for station with no time/distance',
      () {
        final config = RaceConfig(
          name: 'X',
          duration: Duration(hours: 4),
          timelineMode: TimelineMode.timeBased,
          intervalMinutes: 20,
          targetCarbsGPerHr: 80.0,
          strategy: Strategy.steady,
          selectedProducts: const [],
          aidStations: const [AidStation()],
        );

        final plan = generatePlan(config, profile, [gel]);

        expect(
          plan.warnings.any(
            (w) =>
                w.severity == Severity.critical &&
                w.message.contains('Aid station #1') &&
                w.message.contains('no time or distance'),
          ),
          isTrue,
        );
      },
    );

    test('plan surfaces aid-station warning for time beyond race duration', () {
      final config = RaceConfig(
        name: 'X',
        duration: Duration(hours: 2), // 120 min
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 80.0,
        strategy: Strategy.steady,
        selectedProducts: const [],
        aidStations: const [AidStation(timeMinutes: 200)],
      );

      final plan = generatePlan(config, profile, [gel]);

      expect(
        plan.warnings.any(
          (w) =>
              w.severity == Severity.critical &&
              w.message.toLowerCase().contains('beyond'),
        ),
        isTrue,
      );
    });

    test('valid aid stations produce no aid-station warnings in the plan', () {
      final config = RaceConfig(
        name: 'X',
        duration: Duration(hours: 4),
        distanceKm: 100,
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 80.0,
        strategy: Strategy.steady,
        selectedProducts: const [],
        aidStations: const [
          AidStation(timeMinutes: 60),
          AidStation(distanceKm: 50),
        ],
      );

      final plan = generatePlan(config, profile, [gel]);

      final aidWarnings = plan.warnings
          .where((w) => w.message.contains('Aid station #'))
          .toList();
      expect(aidWarnings, isEmpty);
    });

    test('engine populates summary.totalGlucose and totalFructose', () {
      final config = RaceConfig(
        name: 'Macro split',
        duration: Duration(hours: 2),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [ProductSelection(productId: 'gel-1', quantity: 8)],
      );

      final plan = generatePlan(config, profile, [gel]);

      final expectedGlucose = plan.entries.fold<double>(
        0,
        (a, e) => a + e.carbsGlucose,
      );
      final expectedFructose = plan.entries.fold<double>(
        0,
        (a, e) => a + e.carbsFructose,
      );
      expect(plan.summary.totalGlucose, closeTo(expectedGlucose, 1e-9));
      expect(plan.summary.totalFructose, closeTo(expectedFructose, 1e-9));
    });

    test(
      'heat-only under-delivery does not trigger altitude-carb advisory',
      () {
        // 2-hour race at 35°C / 80% RH (Danger heat zone) but altitude 0.
        // Heat affects water only — carb target stays at baseline 60g/hr.
        // Even with insufficient supply, the altitude-adjusted-carb-target
        // advisory must NOT fire because no carb adjustment is in effect.
        final config = RaceConfig(
          name: 'Hot Flat',
          duration: Duration(hours: 2),
          timelineMode: TimelineMode.timeBased,
          intervalMinutes: 20,
          targetCarbsGPerHr: 60.0,
          strategy: Strategy.steady,
          selectedProducts: [ProductSelection(productId: 'gel-1', quantity: 4)],
          temperature: 35.0,
          humidity: 80.0,
        );

        final plan = generatePlan(config, profile, [gel]);

        expect(
          plan.warnings.any(
            (w) => w.message.contains('altitude-adjusted carb target'),
          ),
          false,
          reason:
              'heat without altitude must not emit a carb-target advisory '
              '(heat scales water only, not carbs)',
        );
      },
    );
  });
}
