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
        selectedProducts: [
          ProductSelection(productId: 'gel-1', quantity: 8),
        ],
      );

      final plan = generatePlan(config, profile, [gel]);

      expect(plan.entries.length, 6); // 120min / 20min
      expect(plan.entries.first.carbsTotal, greaterThan(0));
      expect(plan.entries.last.cumulativeCarbs, greaterThan(0));
      expect(plan.summary.totalCarbs, greaterThan(0));
      expect(plan.summary.averageGPerHr, greaterThan(0));
      expect(
          plan.warnings.where((w) => w.severity == Severity.critical), isEmpty);
    });

    test('altitude adjustment increases total carbs vs flat race', () {
      // Use a fine-grained product (1g/serving) so the altitude carb multiplier
      // produces a measurable difference after integer ceiling arithmetic.
      // With 25g gels, both 20g and 21.33g ceil to 1 gel — the adjustment is invisible.
      final powder = Product(
        id: 'powder-1',
        name: 'Drink Mix',
        type: ProductType.liquid,
        carbsPerServing: 1.0,
        glucoseGrams: 0.6,
        fructoseGrams: 0.4,
        caffeineMg: 0.0,
        waterRequiredMl: 10.0,
      );

      final configFlat = RaceConfig(
        name: 'Flat',
        duration: Duration(hours: 2),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [
          ProductSelection(productId: 'powder-1', quantity: 300)
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
          ProductSelection(productId: 'powder-1', quantity: 300)
        ],
        altitudeM: 2500,
      );

      final planFlat = generatePlan(configFlat, profile, [powder]);
      final planMountain = generatePlan(configMountain, profile, [powder]);

      expect(planMountain.summary.totalCarbs,
          greaterThan(planFlat.summary.totalCarbs));
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
  });
}
