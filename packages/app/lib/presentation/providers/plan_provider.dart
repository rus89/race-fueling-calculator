// ABOUTME: Computes the FuelingPlan as an AsyncValue mirroring planner state.
// ABOUTME: Preserves prior AsyncData through transient AsyncError (PB-ARCH-10).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/domain.dart';
import 'planner_notifier.dart';
import 'product_library_provider.dart';

// PB-ARCH-10: an auto-saving planner should keep showing the working plan
// while a banner surfaces the error, rather than blanking the canvas. The
// unwrapPrevious() pipe carries the last AsyncData forward under a transient
// AsyncError so the UI can branch on (hasError, hasValue) independently.
// On the very first error (no prior data) this still surfaces AsyncError.
final planProvider = Provider<AsyncValue<FuelingPlan>>((ref) {
  final asyncState = ref.watch(plannerNotifierProvider);
  final library = ref.watch(productLibraryProvider);
  return asyncState.unwrapPrevious().whenData(
    (state) => generatePlan(state.raceConfig, state.athleteProfile, library),
  );
});
