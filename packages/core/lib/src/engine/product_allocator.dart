// ABOUTME: Assigns nutrition products to timeline slots using greedy allocation.
// ABOUTME: Respects quantity limits, aid station constraints, and optimizes glucose:fructose ratio.
import '../models/product.dart';
import '../models/race_config.dart';
import '../models/fueling_plan.dart';
import '../models/warning.dart';
import 'timeline_builder.dart';

/// Slot-level overage advisory threshold. When delivered carbs exceed the
/// slot target by more than this fraction, an advisory warning is attached
/// to the slot to surface the gut-tolerance risk caused by coarse serving
/// sizes.
const _slotOverageAdvisoryThreshold = 0.20;

class AllocationResult {
  final List<PlanEntry> entries;
  final List<String> depletionWarnings;

  const AllocationResult({
    required this.entries,
    this.depletionWarnings = const [],
  });
}

AllocationResult allocateProducts({
  required List<TimeSlot> slots,
  required List<double> targetCarbsPerSlot,
  required List<Product> products,
  required List<ProductSelection> selections,
}) {
  final productMap = {for (final p in products) p.id: p};
  final remaining = {for (final s in selections) s.productId: s.quantity};
  final aidOnly = {for (final s in selections) s.productId: s.isAidStationOnly};
  final entries = <PlanEntry>[];
  final depletionWarnings = <String>[];

  var cumulativeCarbs = 0.0;
  var cumulativeCaffeine = 0.0;

  for (var i = 0; i < slots.length; i++) {
    final slot = slots[i];
    final target = targetCarbsPerSlot[i];
    var carbsAssigned = 0.0;
    var glucoseAssigned = 0.0;
    var fructoseAssigned = 0.0;
    var caffeineAssigned = 0.0;
    var waterAssigned = 0.0;
    final servings = <ProductServing>[];

    // Skip allocation entirely when the slot has no carb target. Avoids
    // emitting a meaningless overage warning for slots whose strategy
    // assigns zero carbs.
    if (target <= 0) {
      entries.add(PlanEntry(
        timeMark: slot.timeMark,
        distanceMark: slot.distanceMark,
        products: servings,
        carbsGlucose: glucoseAssigned,
        carbsFructose: fructoseAssigned,
        carbsTotal: carbsAssigned,
        cumulativeCarbs: cumulativeCarbs,
        cumulativeCaffeine: cumulativeCaffeine,
        waterMl: waterAssigned,
      ));
      continue;
    }

    // Get available products for this slot
    final available = selections.where((s) {
      if ((remaining[s.productId] ?? 0) <= 0) return false;
      if (aidOnly[s.productId] == true && !slot.isAidStation) return false;
      return true;
    }).toList();

    // Prioritize dual-source products (those with both glucose and fructose)
    available.sort((a, b) {
      final pA = productMap[a.productId];
      final pB = productMap[b.productId];
      // Products missing from library sort to the end
      if (pA == null) return 1;
      if (pB == null) return -1;
      // Prefer dual-source products
      final aScore = pA.fructoseGrams > 0 ? 1 : 0;
      final bScore = pB.fructoseGrams > 0 ? 1 : 0;
      return bScore.compareTo(aScore);
    });

    for (final selection in available) {
      if (carbsAssigned >= target) break;
      final product = productMap[selection.productId];
      if (product == null) {
        continue; // product removed from library since plan was saved
      }
      // Round to nearest whole serving so a 20g target served by a 25g
      // product picks 1 serving (closest), not 1 forced upward by .ceil().
      // The post-allocation overage check below surfaces any resulting
      // gut-tolerance risk to the user.
      final needed =
          ((target - carbsAssigned) / product.carbsPerServing).round();
      final canUse = remaining[selection.productId] ?? 0;
      final use = needed.clamp(0, canUse);

      if (use > 0) {
        servings.add(ProductServing(
          productId: product.id,
          productName: product.name,
          servings: use,
        ));
        carbsAssigned += product.carbsPerServing * use;
        glucoseAssigned += product.glucoseGrams * use;
        fructoseAssigned += product.fructoseGrams * use;
        caffeineAssigned += product.caffeineMg * use;
        waterAssigned += product.waterRequiredMl * use;
        remaining[selection.productId] =
            (remaining[selection.productId] ?? 0) - use;
      }
    }

    cumulativeCarbs += carbsAssigned;
    cumulativeCaffeine += caffeineAssigned;

    // Slot-level over-delivery advisory: coarse serving sizes can push
    // delivered carbs above target, increasing gut-tolerance risk.
    final slotWarnings = <Warning>[];
    final overageDelta = carbsAssigned - target;
    if (overageDelta > 0) {
      final overage = overageDelta / target;
      if (overage > _slotOverageAdvisoryThreshold) {
        slotWarnings.add(Warning(
          severity: Severity.advisory,
          message: 'Product mix over-delivers '
              '${overageDelta.toStringAsFixed(0)}g '
              '(${(overage * 100).toStringAsFixed(0)}%) above target',
          entryIndex: i,
        ));
      }
    }

    entries.add(PlanEntry(
      timeMark: slot.timeMark,
      distanceMark: slot.distanceMark,
      products: servings,
      carbsGlucose: glucoseAssigned,
      carbsFructose: fructoseAssigned,
      carbsTotal: carbsAssigned,
      cumulativeCarbs: cumulativeCarbs,
      cumulativeCaffeine: cumulativeCaffeine,
      waterMl: waterAssigned,
      warnings: slotWarnings,
    ));
  }

  // Check for depleted products and missing products
  for (final selection in selections) {
    final product = productMap[selection.productId];
    if (product == null) {
      depletionWarnings.add(
          'Product ID "${selection.productId}" not found in library — skipped');
      continue;
    }
    if ((remaining[selection.productId] ?? 0) <= 0) {
      // Check if all quantity was used before the last slot
      final lastUsed = entries.lastIndexWhere(
          (e) => e.products.any((p) => p.productId == selection.productId));
      if (lastUsed >= 0 && lastUsed < slots.length - 1) {
        depletionWarnings.add(
            'Ran out of ${product.name} at slot ${lastUsed + 1} of ${slots.length}');
      }
    }
  }

  return AllocationResult(
      entries: entries, depletionWarnings: depletionWarnings);
}
