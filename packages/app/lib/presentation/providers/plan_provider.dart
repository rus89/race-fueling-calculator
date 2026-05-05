// ABOUTME: Computes the FuelingPlan as an AsyncValue mirroring planner state.
// ABOUTME: Preserves AsyncLoading and AsyncError so the UI can branch on each.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/domain.dart';
import 'planner_notifier.dart';
import 'product_library_provider.dart';

final planProvider = Provider<AsyncValue<FuelingPlan>>((ref) {
  final asyncState = ref.watch(plannerNotifierProvider);
  return asyncState.whenData((state) {
    final library = ref.watch(productLibraryProvider);
    return generatePlan(state.raceConfig, state.athleteProfile, library);
  });
});
