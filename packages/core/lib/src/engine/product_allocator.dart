// ABOUTME: Allocates products to timeline slots using sip-as-background drinks,
// ABOUTME: a 65% drink cap, and a gel-debt accumulator across slots.
import '../models/product.dart';
import '../models/race_config.dart';
import '../models/fueling_plan.dart';
import '../models/warning.dart';
import 'timeline_builder.dart';
import 'aid_station_projection.dart';

/// Drink contribution to a slot is capped at this fraction of the slot's
/// target so gels stay in the rotation. Source: design's engine.js.
const _drinkCapFraction = 0.65;

/// Gels fire only when the accumulated debt across slots is at or above
/// this threshold AND the candidate gel is a reasonable fit (see
/// [_gelOversizeFactor] and [_gelOversizeCushion]).
const _gelDebtFireThreshold = 12.0;

/// A gel is rejected as "too big" only when BOTH conditions hold:
/// `carbs > debt × _gelOversizeFactor` AND `carbs > debt + _gelOversizeCushion`.
/// If either fails, the gel fires.
const _gelOversizeFactor = 1.6;
const _gelOversizeCushion = 6.0;

/// Hard ceiling on gel picks per slot to prevent runaway loops if
/// inventory and debt math get into a degenerate state.
const _maxGelPicksPerSlot = 5;

/// Threshold below which the engine starts a new drink: only when the
/// per-hour unmet target ≥ this value.
const _drinkStartGramsPerHr = 30.0;

/// Negative-debt floor: caps how much "credit" a single oversized gel
/// can buy, so it doesn't suppress future picks for too many slots.
const _gelDebtFloorFactor = 0.5;

/// Slot-level overage advisory threshold. A debt-justified gel that
/// barely clears the oversize cutoff can push a slot above target;
/// surface that as a gut-tolerance hint.
const _slotOverageAdvisoryThreshold = 0.20;

class _ActiveDrink {
  final String productId;
  final double carbsPerStep;
  final double glucosePerStep;
  final double fructosePerStep;
  final double caffeinePerStep;
  final double waterPerStep;
  int stepsRemaining;
  _ActiveDrink({
    required this.productId,
    required this.carbsPerStep,
    required this.glucosePerStep,
    required this.fructosePerStep,
    required this.caffeinePerStep,
    required this.waterPerStep,
    required this.stepsRemaining,
  });
}

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
  required List<AidStation> aidStations,
  required int stepMin,
  Discipline? discipline,
  double? totalKm,
  int? durationMin,
}) {
  final productMap = {for (final p in products) p.id: p};
  final inventory = <String, int>{
    for (final s in selections) s.productId: s.quantity,
  };
  final entries = <PlanEntry>[];
  final activeDrinks = <_ActiveDrink>[];
  // Track the last slot index a sip drink actually contributed carbs to,
  // not just the slot it started in. Used by the depletion warning so a
  // bottle that finishes its sip in the final slot doesn't trip a false
  // "ran out early" warning.
  final lastContribSlot = <String, int>{};
  var cumulativeCarbs = 0.0;
  var cumulativeCaffeine = 0.0;
  var gelDebt = 0.0;

  // Pre-project aid stations to their effective minute marks. Multiple
  // stations may project to the same minute; aggregate them so all
  // refill lists are honored at that slot.
  final stationByMin = <int, List<AidStation>>{};
  for (final s in aidStations) {
    final m = projectAidStationMin(
      s,
      totalKm: totalKm,
      durationMin: durationMin ?? slots.length * stepMin,
    );
    if (m != null) {
      stationByMin.putIfAbsent(m, () => <AidStation>[]).add(s);
    }
  }

  for (var i = 0; i < slots.length; i++) {
    final slot = slots[i];
    // Slot timeMark is the END of the window — matches timeline_builder's
    // convention where slot[i].timeMark == (i + 1) * stepMin. The window
    // is (tStart, tEnd]; an AidStation at minute M lands in the slot
    // whose timeMark == M (i.e., the moment the rider arrives).
    final tEnd = slot.timeMark.inMinutes;
    final tStart = tEnd - stepMin;
    final target = targetCarbsPerSlot[i];
    final servings = <ProductServing>[];
    final slotWarnings = <Warning>[];

    // 1. Aid station refill at slot start. When several stations project
    // to the same minute, merge all their refill lists into the inventory
    // and surface an advisory so the collision is visible.
    AidStation? aidHere;
    for (final entry in stationByMin.entries) {
      if (entry.key > tStart && entry.key <= tEnd) {
        final stations = entry.value;
        aidHere = stations.first;
        for (final s in stations) {
          for (final pid in s.refill) {
            inventory[pid] = (inventory[pid] ?? 0) + 1;
          }
        }
        if (stations.length > 1) {
          slotWarnings.add(
            Warning(
              severity: Severity.advisory,
              message:
                  'Multiple aid stations at minute $tEnd — refill lists merged',
              entryIndex: i,
            ),
          );
        }
        break;
      }
    }

    // 2. Background drink sips (advance and contribute)
    var drinkCarbs = 0.0,
        drinkGlu = 0.0,
        drinkFru = 0.0,
        drinkCaf = 0.0,
        drinkWater = 0.0;
    activeDrinks.removeWhere((a) => a.stepsRemaining <= 0);
    for (final a in activeDrinks) {
      drinkCarbs += a.carbsPerStep;
      drinkGlu += a.glucosePerStep;
      drinkFru += a.fructosePerStep;
      drinkCaf += a.caffeinePerStep;
      drinkWater += a.waterPerStep;
      lastContribSlot[a.productId] = i;
      a.stepsRemaining -= 1;
    }

    // 3. Start a new drink if needed.
    // Only one drink active at a time — multiple overlapping sip bottles
    // would over-count water and per-slot carbs. The last-slot guard is a
    // known limitation: a refill landing on the final slot cannot start a
    // new drink, so its inventory is wasted (see plan-review 2026-04-30).
    final stepHrs = stepMin / 60.0;
    if (activeDrinks.isEmpty && i < slots.length - 1) {
      final unmetPerHr = (target - drinkCarbs) / stepHrs;
      if (unmetPerHr >= _drinkStartGramsPerHr) {
        final pick =
            inventory.entries
                .where((e) => e.value > 0)
                .map((e) => productMap[e.key])
                .where((p) {
                  if (p == null) return false;
                  if (p.type != ProductType.liquid) return false;
                  final sm = p.sipMinutes;
                  return sm != null && sm > 0;
                })
                .cast<Product>()
                .toList()
              ..sort((a, b) => b.carbsPerServing.compareTo(a.carbsPerServing));
        if (pick.isNotEmpty) {
          final p = pick.first;
          inventory[p.id] = (inventory[p.id] ?? 0) - 1;
          final sipMin = p.sipMinutes;
          final drinkSteps = sipMin == null
              ? 1
              : (sipMin / stepMin).round().clamp(1, 1 << 30);
          final ad = _ActiveDrink(
            productId: p.id,
            carbsPerStep: p.carbsPerServing / drinkSteps,
            glucosePerStep: p.glucoseGrams / drinkSteps,
            fructosePerStep: p.fructoseGrams / drinkSteps,
            caffeinePerStep: p.caffeineMg / drinkSteps,
            waterPerStep: p.waterRequiredMl / drinkSteps,
            stepsRemaining: drinkSteps,
          );
          activeDrinks.add(ad);
          drinkCarbs += ad.carbsPerStep;
          drinkGlu += ad.glucosePerStep;
          drinkFru += ad.fructosePerStep;
          drinkCaf += ad.caffeinePerStep;
          drinkWater += ad.waterPerStep;
          servings.add(
            ProductServing(
              productId: p.id,
              productName: '${p.name} (sip start)',
              servings: 1,
            ),
          );
          lastContribSlot[p.id] = i;
          ad.stepsRemaining -= 1;
        }
      }
    }

    // 4. Cap drink at 65% of target; pool unmet into gel debt
    final drinkCap = target * _drinkCapFraction;
    final effectiveDrink = drinkCarbs == 0
        ? 0.0
        : (drinkCarbs < drinkCap ? drinkCarbs : drinkCap);
    final scale = drinkCarbs > 0 ? effectiveDrink / drinkCarbs : 0.0;
    final effGlu = drinkGlu * scale;
    final effFru = drinkFru * scale;
    final effCaf = drinkCaf * scale;
    final effWater = drinkWater * scale;
    gelDebt += (target - effectiveDrink).clamp(0.0, double.infinity);

    // 5. Pick gels until debt below threshold or no candidates
    var solidCarbs = 0.0,
        solidGlu = 0.0,
        solidFru = 0.0,
        solidCaf = 0.0,
        solidWater = 0.0;
    var picks = 0;
    while (gelDebt >= _gelDebtFireThreshold && picks < _maxGelPicksPerSlot) {
      picks++;
      final candidates =
          inventory.entries
              .where((e) => e.value > 0)
              .map((e) => productMap[e.key])
              .where((p) => p != null && p.type != ProductType.liquid)
              .cast<Product>()
              .toList()
            ..sort(
              (a, b) => (a.carbsPerServing - gelDebt).abs().compareTo(
                (b.carbsPerServing - gelDebt).abs(),
              ),
            );
      if (candidates.isEmpty) break;
      final pick = candidates.first;
      if (pick.carbsPerServing > gelDebt * _gelOversizeFactor &&
          pick.carbsPerServing > gelDebt + _gelOversizeCushion) {
        break;
      }
      inventory[pick.id] = (inventory[pick.id] ?? 0) - 1;
      servings.add(
        ProductServing(productId: pick.id, productName: pick.name, servings: 1),
      );
      solidCarbs += pick.carbsPerServing;
      solidGlu += pick.glucoseGrams;
      solidFru += pick.fructoseGrams;
      solidCaf += pick.caffeineMg;
      solidWater += pick.waterRequiredMl;
      lastContribSlot[pick.id] = i;
      gelDebt -= pick.carbsPerServing;
    }
    if (gelDebt < -target * _gelDebtFloorFactor) {
      gelDebt = -target * _gelDebtFloorFactor;
    }

    final stepCarbs = effectiveDrink + solidCarbs;
    final stepGlucose = effGlu + solidGlu;
    final stepFructose = effFru + solidFru;
    final stepCaffeine = effCaf + solidCaf;
    final stepWater = effWater + solidWater;
    cumulativeCarbs += stepCarbs;
    cumulativeCaffeine += stepCaffeine;

    final overageDelta = stepCarbs - target;
    if (target > 0 && overageDelta > target * _slotOverageAdvisoryThreshold) {
      slotWarnings.add(
        Warning(
          severity: Severity.advisory,
          message:
              'Product mix over-delivers '
              '${overageDelta.toStringAsFixed(0)}g '
              '(${(overageDelta / target * 100).toStringAsFixed(0)}%) above target',
          entryIndex: i,
        ),
      );
    }

    entries.add(
      PlanEntry(
        timeMark: slot.timeMark,
        distanceMark: slot.distanceMark,
        products: servings,
        carbsGlucose: stepGlucose,
        carbsFructose: stepFructose,
        carbsTotal: stepCarbs,
        cumulativeCarbs: cumulativeCarbs,
        cumulativeCaffeine: cumulativeCaffeine,
        waterMl: stepWater,
        warnings: slotWarnings,
        effectiveDrinkCarbs: effectiveDrink,
        aidStation: aidHere,
      ),
    );
  }

  // Depletion warnings — products that ran out before plan ended.
  // For sip drinks, lastContribSlot tracks the actual final-contribution slot
  // (not just the start), so a bottle that finishes sipping in the last slot
  // does not trip a false "ran out early" warning.
  final depletionWarnings = <String>[];
  for (final s in selections) {
    final p = productMap[s.productId];
    if (p == null) {
      depletionWarnings.add(
        'Product ID "${s.productId}" not found in library — skipped',
      );
      continue;
    }
    if ((inventory[s.productId] ?? 0) <= 0) {
      final lastUsed =
          lastContribSlot[s.productId] ??
          entries.lastIndexWhere(
            (e) => e.products.any((sv) => sv.productId == s.productId),
          );
      if (lastUsed >= 0 && lastUsed < slots.length - 1) {
        depletionWarnings.add(
          'Ran out of ${p.name} at slot ${lastUsed + 1} of ${slots.length}',
        );
      }
    }
  }

  return AllocationResult(
    entries: entries,
    depletionWarnings: depletionWarnings,
  );
}
