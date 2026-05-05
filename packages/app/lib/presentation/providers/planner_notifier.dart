// ABOUTME: AsyncNotifier holding the working PlannerState; loads from storage.
// ABOUTME: Mutators emit a new state and trigger save (debouncing comes in F2).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/domain.dart';
import '../../domain/planner_state.dart';
import 'plan_storage_provider.dart';
import 'save_status_provider.dart';

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
        // The persisted isSeedFallback bit (default false on legacy keys)
        // is authoritative — a saved post-recovery seed survives until the
        // first user edit flips the flag in `_emit`.
        return loaded;
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

  // Returns the current state for mutators, or null when no usable state
  // exists yet (initial AsyncLoading, or first-load AsyncError without a
  // prior value). Mutators short-circuit on null so a race condition
  // (deeplink fired before load completes, hot-reload, etc.) does not crash
  // with AsyncValueIsLoadingException from `requireValue`.
  //
  // In Riverpod 3.x `state.value` returns the most recent AsyncData payload,
  // including through an AsyncError that retains a previous value (Riverpod
  // 3.x preserves prior data by default). The AsyncError-vs-AsyncData
  // distinction is enforced separately by the `state is AsyncError` guard
  // in `_emit` — that's the line that refuses to save during error.
  PlannerState? _currentOrNull() => state.value;

  // Refuses to emit while the prior state is AsyncError so a stealth save
  // cannot overwrite a recoverable corrupted blob with an in-memory seed.
  // The user must explicitly opt in via `discardCorruptedAndUseSeed`.
  //
  // Any user-driven mutation flips `isSeedFallback` off — by definition
  // the working state is no longer a fallback once the user has touched it.
  void _emit(PlannerState next) {
    if (state is AsyncError) return;
    final flipped = next.isSeedFallback
        ? next.copyWith(isSeedFallback: false)
        : next;
    _emitForce(flipped);
  }

  // Emits unconditionally and schedules a save. Used internally by `_emit`
  // after the AsyncError guard, and by `discardCorruptedAndUseSeed` to
  // escape it.
  void _emitForce(PlannerState next) {
    state = AsyncData(next);
    final storage = ref.read(planStorageProvider);
    final statusCtrl = ref.read(saveStatusProvider.notifier);
    statusCtrl.beginSave();
    _lastSave = _lastSave.then((_) async {
      try {
        await storage.save(next);
        statusCtrl.endSaveSuccess();
      } catch (e, st) {
        // L1 observability: log the failure. L3 surfacing flows through
        // saveStatusProvider so F1 can render a banner.
        debugPrint('PlanStorage.save failed: $e\n$st');
        statusCtrl.endSaveFailure();
        // Do NOT rethrow — the chain stays resolvable for subsequent writes.
      }
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

  /// Destructive recovery: writes the seed over an unreadable blob and
  /// clears the AsyncError. PlanStorageLocal auto-backs up the prior bytes
  /// to `${_key}.bak` once before the first overwrite, so the corrupted
  /// payload remains recoverable post-mortem. Only call this from a
  /// confirmed user action ("Start fresh"). No-op outside AsyncError.
  void discardCorruptedAndUseSeed() {
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
