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

/// Threshold for the under-delivery advisory: when an altitude-adjusted
/// plan delivers below this fraction of the adjusted carb target,
/// surface an advisory so the user knows the altitude compensation is
/// not actually reflected in the product mix. Ratios at or above this
/// fraction are treated as on-target.
const _underDeliveryThreshold = 0.90;

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
  final curveCoverageWarning = detectCustomCurveCoverageWarning(
    config,
    adjustedRate,
  );

  // Step 4: Allocate products
  final stepMin = slots.length >= 2
      ? slots[1].timeMark.inMinutes - slots[0].timeMark.inMinutes
      : (slots.isNotEmpty
            ? slots[0].timeMark.inMinutes
            : (config.intervalMinutes ?? 20));
  final allocation = allocateProducts(
    slots: slots,
    targetCarbsPerSlot: targetCarbs,
    products: products,
    selections: config.selectedProducts,
    aidStations: config.aidStations,
    stepMin: stepMin,
    discipline: config.discipline,
    totalKm: config.distanceKm,
    durationMin: config.duration.inMinutes,
  );

  // Step 5: Add environmental water adjustments to each entry
  final adjustedEntries = allocation.entries
      .map(
        (entry) => entry.copyWith(
          waterMl: entry.waterMl + adjustments.additionalWaterMlPerSlot,
        ),
      )
      .toList();

  // Step 6: Validate assembled entries
  final validationWarnings = validatePlan(
    adjustedEntries,
    profile,
    config.duration,
  );
  final aidStationWarnings = validateAidStationDefinitions(config);

  // Step 6b: Detect under-delivery vs. altitude-adjusted carb target.
  // Without this, the altitude carb multiplier scales the target rate
  // but its effect can be invisible if the available product mix can't
  // reach the boosted target — the user would think the plan compensates
  // when it doesn't. Heat affects water only (not carbs), so it does not
  // gate this warning.
  final carbTargetAdjusted = adjustments.carbMultiplier > 1.0;
  final adjustedTargetTotal = targetCarbs.fold<double>(
    0.0,
    (sum, t) => sum + t,
  );
  final actualTotal = adjustedEntries.fold<double>(
    0.0,
    (sum, e) => sum + e.carbsTotal,
  );
  Warning? underDeliveryWarning;
  if (carbTargetAdjusted && adjustedTargetTotal > 0) {
    final ratio = actualTotal / adjustedTargetTotal;
    if (ratio < _underDeliveryThreshold) {
      underDeliveryWarning = Warning(
        severity: Severity.advisory,
        message:
            'Plan delivers only ${(ratio * 100).toStringAsFixed(0)}% '
            'of altitude-adjusted carb target — add more product to fully '
            'compensate.',
      );
    }
  }

  final allWarnings = <Warning>[
    ...aidStationWarnings,
    ...validationWarnings,
    ...allocation.depletionWarnings.map(
      (msg) => Warning(severity: Severity.critical, message: msg),
    ),
    if (curveCoverageWarning != null) curveCoverageWarning,
    if (underDeliveryWarning != null) underDeliveryWarning,
  ];

  // Step 7: Build summary
  final totalCarbs = adjustedEntries.isEmpty
      ? 0.0
      : adjustedEntries.last.cumulativeCarbs;
  final totalCaffeine = adjustedEntries.isEmpty
      ? 0.0
      : adjustedEntries.last.cumulativeCaffeine;
  final totalWater = adjustedEntries.fold(0.0, (sum, e) => sum + e.waterMl);
  final totalGlucose = adjustedEntries.fold(
    0.0,
    (sum, e) => sum + e.carbsGlucose,
  );
  final totalFructose = adjustedEntries.fold(
    0.0,
    (sum, e) => sum + e.carbsFructose,
  );
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
