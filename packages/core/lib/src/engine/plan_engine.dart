// ABOUTME: Orchestrates plan generation from race config, athlete profile, and product list.
// ABOUTME: Composes timeline building, carb distribution, product allocation, validation, and environmental adjustments.
import '../models/product.dart';
import '../models/athlete_profile.dart';
import '../models/race_config.dart';
import '../models/fueling_plan.dart';
import '../models/warning.dart';
import 'timeline_builder.dart';
import 'carb_distributor.dart';
import 'product_allocator.dart';
import 'plan_validator.dart';
import 'environmental.dart';

FuelingPlan generatePlan(
  RaceConfig config,
  AthleteProfile profile,
  List<Product> products,
) {
  // Step 1: Environmental adjustments
  final adjustments = calculateAdjustments(
    temperature: config.temperature,
    humidity: config.humidity,
    altitudeM: config.altitudeM,
  );

  // Step 2: Build timeline
  final slots = buildTimeline(config);

  // Step 3: Distribute carbs, applying altitude multiplier to the target rate
  final adjustedRate = config.targetCarbsGPerHr * adjustments.carbMultiplier;
  final targetCarbs = distributeCarbs(slots, config, adjustedRate);
  final curveCoverageWarning =
      detectCustomCurveCoverageWarning(config, adjustedRate);

  // Step 4: Allocate products
  final allocation = allocateProducts(
    slots: slots,
    targetCarbsPerSlot: targetCarbs,
    products: products,
    selections: config.selectedProducts,
  );

  // Step 5: Add environmental water adjustments to each entry
  final adjustedEntries = allocation.entries.map((entry) {
    return PlanEntry(
      timeMark: entry.timeMark,
      distanceMark: entry.distanceMark,
      products: entry.products,
      carbsGlucose: entry.carbsGlucose,
      carbsFructose: entry.carbsFructose,
      carbsTotal: entry.carbsTotal,
      cumulativeCarbs: entry.cumulativeCarbs,
      cumulativeCaffeine: entry.cumulativeCaffeine,
      waterMl: entry.waterMl + adjustments.additionalWaterMlPerSlot,
    );
  }).toList();

  // Step 6: Validate assembled entries
  final validationWarnings =
      validatePlan(adjustedEntries, profile, config.duration);

  final allWarnings = <Warning>[
    ...validationWarnings,
    ...allocation.depletionWarnings
        .map((msg) => Warning(severity: Severity.critical, message: msg)),
    if (curveCoverageWarning != null) curveCoverageWarning,
  ];

  // Step 7: Build summary
  final totalCarbs =
      adjustedEntries.isEmpty ? 0.0 : adjustedEntries.last.cumulativeCarbs;
  final totalCaffeine =
      adjustedEntries.isEmpty ? 0.0 : adjustedEntries.last.cumulativeCaffeine;
  final totalWater = adjustedEntries.fold(0.0, (sum, e) => sum + e.waterMl);
  final totalGlucose =
      adjustedEntries.fold(0.0, (sum, e) => sum + e.carbsGlucose);
  final totalFructose =
      adjustedEntries.fold(0.0, (sum, e) => sum + e.carbsFructose);
  final hours = config.duration.inMinutes / 60.0;

  final summary = PlanSummary(
    totalCarbs: totalCarbs,
    averageGPerHr: hours > 0 ? totalCarbs / hours : 0,
    totalCaffeineMg: totalCaffeine,
    glucoseFructoseRatio: totalGlucose > 0 ? totalFructose / totalGlucose : 0,
    totalWaterMl: totalWater,
    environmentalNotes: adjustments.advisories,
  );

  return FuelingPlan(
    raceConfig: config,
    entries: adjustedEntries,
    summary: summary,
    warnings: allWarnings,
  );
}
