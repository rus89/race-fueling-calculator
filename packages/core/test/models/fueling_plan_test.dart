// ABOUTME: Tests for FuelingPlan, PlanEntry, and PlanSummary model construction and serialization.
// ABOUTME: Verifies raceConfig round-trip, warnings attachment, and cumulative stats fields.
import 'package:test/test.dart';
import 'package:race_fueling_core/src/models/fueling_plan.dart';
import 'package:race_fueling_core/src/models/race_config.dart';
import 'package:race_fueling_core/src/models/warning.dart';

void main() {
  group('ProductServing', () {
    test('creates correctly', () {
      final serving = ProductServing(
          productId: 'gel-1', productName: 'Test Gel', servings: 1);
      expect(serving.productId, 'gel-1');
      expect(serving.servings, 1);
    });
  });

  group('PlanEntry', () {
    test('creates with all fields', () {
      final entry = PlanEntry(
        timeMark: Duration(minutes: 20),
        products: [
          ProductServing(productId: 'gel-1', productName: 'Gel', servings: 1)
        ],
        carbsGlucose: 20.0,
        carbsFructose: 5.0,
        carbsTotal: 25.0,
        cumulativeCarbs: 25.0,
        cumulativeCaffeine: 40.0,
        waterMl: 150.0,
      );
      expect(entry.carbsTotal, 25.0);
      expect(entry.distanceMark, isNull);
      expect(entry.warnings, isEmpty);
    });
  });

  group('PlanSummary', () {
    test('creates correctly', () {
      final summary = PlanSummary(
        totalCarbs: 200.0,
        averageGPerHr: 66.7,
        totalCaffeineMg: 120.0,
        glucoseFructoseRatio: 0.8,
        totalWaterMl: 1500.0,
        environmentalNotes: ['Altitude adjustment: +5%'],
      );
      expect(summary.averageGPerHr, 66.7);
    });
  });

  final testConfig = RaceConfig(
    name: 'Test Race',
    duration: Duration(hours: 1),
    timelineMode: TimelineMode.timeBased,
    intervalMinutes: 20,
    targetCarbsGPerHr: 60.0,
    strategy: Strategy.steady,
    selectedProducts: [],
  );

  group('FuelingPlan', () {
    test('JSON round-trip', () {
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          PlanEntry(
            timeMark: Duration(minutes: 20),
            products: [
              ProductServing(productId: 'g1', productName: 'Gel', servings: 1)
            ],
            carbsGlucose: 20.0,
            carbsFructose: 5.0,
            carbsTotal: 25.0,
            cumulativeCarbs: 25.0,
            cumulativeCaffeine: 0.0,
            waterMl: 100.0,
          ),
        ],
        summary: PlanSummary(
          totalCarbs: 25.0,
          averageGPerHr: 75.0,
          totalCaffeineMg: 0.0,
          glucoseFructoseRatio: 0.8,
          totalWaterMl: 100.0,
        ),
        warnings: [Warning(severity: Severity.advisory, message: 'Test')],
      );
      final json = plan.toJson();
      final restored = FuelingPlan.fromJson(json);
      expect(restored.raceConfig.name, 'Test Race');
      expect(restored.entries.length, 1);
      expect(restored.warnings.length, 1);
    });
  });
}
