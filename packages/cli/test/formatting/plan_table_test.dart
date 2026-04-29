// ABOUTME: Tests for plan table rendering with explicit useColor contract.
// ABOUTME: Covers shape, distance-mode column, ANSI stripping, truncation, and alignment.
import 'package:test/test.dart';
import 'package:race_fueling_cli/src/formatting/color.dart';
import 'package:race_fueling_cli/src/formatting/plan_table.dart';
import 'package:race_fueling_core/core.dart';

void main() {
  final testConfig = RaceConfig(
    name: 'Test Race',
    duration: Duration(hours: 2),
    timelineMode: TimelineMode.timeBased,
    intervalMinutes: 20,
    targetCarbsGPerHr: 75.0,
    strategy: Strategy.steady,
    selectedProducts: [],
  );

  PlanEntry entry({
    Duration timeMark = const Duration(minutes: 20),
    double? distanceMark,
    List<ProductServing> products = const [],
    double carbsTotal = 25.0,
    double cumulativeCarbs = 25.0,
    double cumulativeCaffeine = 0.0,
    double waterMl = 100.0,
  }) {
    return PlanEntry(
      timeMark: timeMark,
      distanceMark: distanceMark,
      products: products,
      carbsGlucose: 15.0,
      carbsFructose: 10.0,
      carbsTotal: carbsTotal,
      cumulativeCarbs: cumulativeCarbs,
      cumulativeCaffeine: cumulativeCaffeine,
      waterMl: waterMl,
    );
  }

  PlanSummary summary() => PlanSummary(
        totalCarbs: 50.0,
        averageGPerHr: 75.0,
        totalCaffeineMg: 0.0,
        glucoseFructoseRatio: 0.67,
        totalWaterMl: 200.0,
      );

  group('formatPlanTable — shape (time-based)', () {
    test('emits headers, divider, and one row per entry', () {
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          entry(products: [
            ProductServing(
                productId: 'gel-1', productName: 'Test Gel', servings: 1),
          ]),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: false);

      expect(output, contains('Time'));
      expect(output, contains('Product'));
      expect(output, contains('Carbs'));
      expect(output, contains('Cumul.'));
      expect(output, contains('Caffeine'));
      expect(output, contains('Water'));
      expect(output, contains('0:20'));
      expect(output, contains('Test Gel'));
      expect(output, isNot(contains('Dist'))); // time-based plan: no Dist col
    });
  });

  group('formatPlanTable — distance mode', () {
    test('inserts Dist column when any entry has distanceMark != null', () {
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          entry(distanceMark: 10.0, products: [
            ProductServing(
                productId: 'gel-1', productName: 'Test Gel', servings: 1),
          ]),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: false);

      expect(output, contains('Dist'));
      expect(output, contains('10km'));
    });
  });

  group('formatPlanTable — color contract', () {
    test('useColor: false output contains zero ANSI escapes', () {
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          entry(products: [
            ProductServing(
                productId: 'gel-1', productName: 'Test Gel', servings: 1),
          ]),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: false);

      expect(output.contains('\x1B'), isFalse);
    });
  });

  group('formatPlanTable — truncation', () {
    test('truncates Product cell to 24 visible chars + ellipsis', () {
      final longName = 'A' * 40;
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          entry(products: [
            ProductServing(productId: 'p1', productName: longName, servings: 1),
          ]),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: false);

      expect(output, contains('${'A' * 24}…'));
      expect(output, isNot(contains('A' * 25)));
    });
  });

  group('formatPlanTable — alignment with colored content', () {
    test('divider line and content row have matching visible width', () {
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          entry(products: [
            ProductServing(
                productId: 'gel-1', productName: 'Test Gel', servings: 1),
          ]),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: true);
      final lines = output.split('\n').where((l) => l.isNotEmpty).toList();
      // Find the divider (made entirely of '─') and the first content row.
      final dividerIdx = lines.indexWhere((l) => l.startsWith('─'));
      expect(dividerIdx, greaterThan(0));
      final dividerWidth = visibleWidth(lines[dividerIdx]);
      final headerWidth = visibleWidth(lines[dividerIdx - 1]);
      final rowWidth = visibleWidth(lines[dividerIdx + 1]);
      expect(headerWidth, dividerWidth);
      expect(rowWidth, dividerWidth);
    });
  });
}
