// ABOUTME: AsyncNotifier holding the working PlannerState; loads from storage.
// ABOUTME: Mutators emit a new state and trigger save (debouncing comes in F2).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/domain.dart';
import '../../domain/planner_state.dart';
import 'plan_storage_provider.dart';

class PlannerNotifier extends AsyncNotifier<PlannerState> {
  // Chain saves so they land in mutation order even if individual writes
  // resolve out-of-order on the underlying store (e.g. Web IndexedDB).
  Future<void> _lastSave = Future.value();

  @override
  Future<PlannerState> build() async {
    final storage = ref.watch(planStorageProvider);
    try {
      final loaded = await storage.load();
      if (loaded != null) {
        // Defensive: a loaded blob is by definition a real plan, never a
        // first-run fallback — strip the flag in case a future codepath
        // ever sets it on persisted state.
        return loaded.copyWith(isSeedFallback: false);
      }
      // Empty drive: synthesise the seed and flag it so the UI can offer
      // a quickstart treatment (PB-UX-5 in F1).
      return PlannerState.seed();
    } catch (e, st) {
      // L1 observability for load failures (mirrors the save-path debugPrint).
      debugPrint('PlanStorage.load failed: $e\n$st');
      rethrow;
    }
  }

  // Returns the current state, or null if `build()` has not yet resolved
  // (or has resolved to AsyncError). Mutators no-op in that case so a race
  // condition (deeplink fired before load completes, hot-reload, etc.) does
  // not crash with AsyncValueIsLoadingException from `requireValue`.
  //
  // In Riverpod 3.x `state.value` returns the current AsyncData payload, or
  // null for AsyncLoading and AsyncError-without-prior-data. AsyncError that
  // carries a previous AsyncData (e.g. via unwrapPrevious upstream) still
  // returns null here because the *direct* state value is the error frame.
  PlannerState? _currentOrNull() => state.value;

  // Refuses to emit while the prior state is AsyncError so a stealth save
  // cannot overwrite a recoverable corrupted blob with an in-memory seed.
  // The user must explicitly opt in via `acceptSeedAfterError`.
  void _emit(PlannerState next) {
    if (state is AsyncError) return;
    _emitForce(next);
  }

  // Emits unconditionally and schedules a save. Used internally by `_emit`
  // after the AsyncError guard, and by `acceptSeedAfterError` to escape it.
  void _emitForce(PlannerState next) {
    state = AsyncData(next);
    final storage = ref.read(planStorageProvider);
    _lastSave = _lastSave.then((_) => storage.save(next)).onError((e, st) {
      // L1 observability: log the failure. L3 (UI surfacing via SaveStatus)
      // is wired through saveStatusProvider — see save_status_provider.dart.
      debugPrint('PlanStorage.save failed: $e');
    });
    unawaited(_lastSave);
  }

  /// User-driven retry: rebuilds the notifier so the storage adapter is
  /// reconsulted. Wired by F1's "Try recovery" button. No-op when state is
  /// already AsyncData (nothing to retry) or AsyncLoading (already in flight).
  Future<void> retryLoad() async {
    final cur = state;
    if (cur is AsyncData || cur is AsyncLoading) return;
    ref.invalidateSelf();
    await future;
  }

  /// User-driven recovery: clear the prior AsyncError and accept the seed
  /// as the working state. Saves the seed (which overwrites the unreadable
  /// blob — only call this when the user explicitly opts into "Start fresh").
  void acceptSeedAfterError() {
    if (state is! AsyncError) return;
    _emitForce(PlannerState.seed());
  }

  /// Test-only re-emit hook so the AsyncError guard in `_emit` is reachable
  /// from unit tests without provoking an artificial AsyncError. Mirrors
  /// the public mutator API but bypasses the lambda.
  @visibleForTesting
  void debugEmit(PlannerState next) => _emit(next);

  void updateRaceConfig(RaceConfig Function(RaceConfig) edit) {
    final cur = _currentOrNull();
    if (cur == null) return;
    _emit(cur.copyWith(raceConfig: edit(cur.raceConfig)));
  }

  void updateAthleteProfile(AthleteProfile Function(AthleteProfile) edit) {
    final cur = _currentOrNull();
    if (cur == null) return;
    _emit(cur.copyWith(athleteProfile: edit(cur.athleteProfile)));
  }
}

final plannerNotifierProvider =
    AsyncNotifierProvider<PlannerNotifier, PlannerState>(PlannerNotifier.new);
