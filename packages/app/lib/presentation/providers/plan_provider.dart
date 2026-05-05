// ABOUTME: Computes FuelingPlan from PlannerState; exposes only engine output.
// ABOUTME: F1 reads plannerNotifierProvider for isSeedFallback (quickstart UX).
// ABOUTME: AsyncValue<FuelingPlan> preserves error surface for the recovery banner.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/domain.dart';
import 'planner_notifier.dart';
import 'product_library_provider.dart';

// PB-ARCH-10: an auto-saving planner should fail loudly when state goes
// AsyncError rather than render stale plan data under a banner. unwrapPrevious()
// strips the cached prior value off AsyncError, leaving a clean
// AsyncError(error, stack) for consumers — F1's recovery banner is the
// recovery primitive here, not silent stale-data carryover. The UI branches
// on (hasError, hasValue) independently.
final planProvider = Provider<AsyncValue<FuelingPlan>>((ref) {
  final asyncState = ref.watch(plannerNotifierProvider);
  final library = ref.watch(productLibraryProvider);
  return asyncState.unwrapPrevious().whenData(
    (state) => generatePlan(state.raceConfig, state.athleteProfile, library),
  );
});
