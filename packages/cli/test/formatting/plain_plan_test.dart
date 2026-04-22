// ABOUTME: Tests for the plain-text FuelingPlan formatter — empty plans,
// ABOUTME: populated plans, and warning rendering.
import 'package:race_fueling_cli/src/formatting/plain_plan.dart';
import 'package:race_fueling_core/core.dart';
import 'package:test/test.dart';

void main() {
  final config = RaceConfig(
    name: 'Test Race',
    duration: const Duration(hours: 2),
    timelineMode: TimelineMode.timeBased,
    intervalMinutes: 20,
    targetCarbsGPerHr: 75.0,
    strategy: Strategy.steady,
    selectedProducts: const [],
  );

  test('empty plan includes summary but no timeline entries', () {
    final plan = FuelingPlan(
      raceConfig: config,
      entries: const [],
      summary: const PlanSummary(
        totalCarbs: 0.0,
        averageGPerHr: 0.0,
        totalCaffeineMg: 0.0,
        glucoseFructoseRatio: 0.0,
        totalWaterMl: 0.0,
      ),
    );

    final text = formatPlanText(plan);
    expect(text, contains('Summary:'));
    expect(text, contains('Total carbs:'));
    expect(text, contains('Warnings:       0'));
    // No entries means no product serving lines.
    expect(text, isNot(contains(' x')));
  });

  test('plan with entries includes each product name and clock time', () {
    final plan = FuelingPlan(
      raceConfig: config,
      entries: const [
        PlanEntry(
          timeMark: Duration(minutes: 20),
          products: [
            ProductServing(
              productId: 'gel-1',
              productName: 'Test Gel',
              servings: 1,
            ),
          ],
          carbsGlucose: 15.0,
          carbsFructose: 10.0,
          carbsTotal: 25.0,
          cumulativeCarbs: 25.0,
          cumulativeCaffeine: 0.0,
          waterMl: 100.0,
        ),
        PlanEntry(
          timeMark: Duration(hours: 1, minutes: 40),
          products: [
            ProductServing(
              productId: 'gel-1',
              productName: 'Test Gel',
              servings: 2,
            ),
          ],
          carbsGlucose: 30.0,
          carbsFructose: 20.0,
          carbsTotal: 50.0,
          cumulativeCarbs: 75.0,
          cumulativeCaffeine: 0.0,
          waterMl: 200.0,
        ),
      ],
      summary: const PlanSummary(
        totalCarbs: 75.0,
        averageGPerHr: 37.5,
        totalCaffeineMg: 0.0,
        glucoseFructoseRatio: 0.67,
        totalWaterMl: 300.0,
      ),
    );

    final text = formatPlanText(plan);
    expect(text, contains('Test Gel'));
    expect(text, contains('0:20'));
    expect(text, contains('1:40'));
    expect(text, contains('x2'));
  });

  test('plan with warnings lists them in the output', () {
    final plan = FuelingPlan(
      raceConfig: config,
      entries: const [],
      summary: const PlanSummary(
        totalCarbs: 0.0,
        averageGPerHr: 0.0,
        totalCaffeineMg: 0.0,
        glucoseFructoseRatio: 0.0,
        totalWaterMl: 0.0,
      ),
      warnings: const [
        Warning(
          severity: Severity.critical,
          message: 'Carb intake exceeds gut tolerance.',
        ),
        Warning(
          severity: Severity.advisory,
          message: 'Caffeine timing is aggressive.',
        ),
      ],
    );

    final text = formatPlanText(plan);
    expect(text, contains('Warnings:       2'));
    expect(text, contains('Carb intake exceeds gut tolerance.'));
    expect(text, contains('Caffeine timing is aggressive.'));
    expect(text, contains('[critical]'));
    expect(text, contains('[advisory]'));
  });
}
