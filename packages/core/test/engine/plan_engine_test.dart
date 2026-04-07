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
      final configFlat = RaceConfig(
        name: 'Flat',
        duration: Duration(hours: 2),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [ProductSelection(productId: 'gel-1', quantity: 10)],
      );
      final configMountain = RaceConfig(
        name: 'Mountain',
        duration: Duration(hours: 2),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [ProductSelection(productId: 'gel-1', quantity: 10)],
        altitudeM: 2500,
      );

      final planFlat = generatePlan(configFlat, profile, [gel]);
      final planMountain = generatePlan(configMountain, profile, [gel]);

      expect(planMountain.summary.totalCarbs,
          greaterThanOrEqualTo(planFlat.summary.totalCarbs));
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
  });
}
