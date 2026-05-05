// ABOUTME: Computes the FuelingPlan from current PlannerState + product library.
// ABOUTME: Recomputes automatically when state changes; engine call is sync.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/domain.dart';
import 'planner_notifier.dart';
import 'product_library_provider.dart';

final planProvider = Provider<FuelingPlan?>((ref) {
  final asyncState = ref.watch(plannerNotifierProvider);
  final state = asyncState.value;
  if (state == null) return null;
  final library = ref.watch(productLibraryProvider);
  return generatePlan(state.raceConfig, state.athleteProfile, library);
});
