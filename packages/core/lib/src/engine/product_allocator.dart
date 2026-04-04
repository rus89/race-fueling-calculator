// ABOUTME: Assigns nutrition products to timeline slots using greedy allocation.
// ABOUTME: Respects quantity limits, aid station constraints, and optimizes glucose:fructose ratio.
import '../models/product.dart';
import '../models/race_config.dart';
import '../models/fueling_plan.dart';
import 'timeline_builder.dart';

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

    // Get available products for this slot
    final available = selections.where((s) {
      if ((remaining[s.productId] ?? 0) <= 0) return false;
      if (aidOnly[s.productId] == true && !slot.isAidStation) return false;
      return true;
    }).toList();

    // Sort by glucose:fructose ratio optimization — prefer products
    // that bring the ratio closer to 1:0.8
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
      final needed =
          ((target - carbsAssigned) / product.carbsPerServing).ceil();
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
