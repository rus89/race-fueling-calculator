// ABOUTME: AsyncNotifier holding the working PlannerState; loads from storage.
// ABOUTME: Mutators emit a new state and trigger a debounced save.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/domain.dart';
import '../../domain/planner_state.dart';
import 'debounced_save.dart';
import 'plan_storage_provider.dart';
import 'save_status_provider.dart';

class PlannerNotifier extends AsyncNotifier<PlannerState> {
  // Chain saves so they land in mutation order even if individual writes
  // resolve out-of-order on the underlying store (e.g. Web IndexedDB).
  Future<void> _lastSave = Future.value();

  // Debounces storage writes so rapid drags/typing coalesce into one save.
  // The 500 ms window is the standard "stopped editing" quiescence used by
  // every other auto-save UI in the codebase.
  final _saveDebouncer = Debouncer<PlannerState>(
    const Duration(milliseconds: 500),
  );

  @override
  Future<PlannerState> build() async {
    ref.onDispose(() {
      // Discard pending edits — flushing here would read disposed providers
      // (planStorageProvider / saveStatusProvider). Container teardown
      // already implies "the user is gone"; treating the last 500 ms like a
      // crash is consistent and avoids the disposal-order trap.
      _saveDebouncer.dispose();
    });
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
      // Debug-only so release builds don't leak rawBytes via PlanStorageException.
      if (kDebugMode) debugPrint('PlanStorage.load failed: $e\n$st');
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

  /// [_emit] is the user-mutation path: it (a) refuses to emit during AsyncError,
  /// (b) flips `isSeedFallback` to false on any state change (a real user edit
  /// means the working state is no longer the seed fallback). Callers that
  /// need to preserve the seed flag (e.g. resetToSeed) or escape AsyncError
  /// (e.g. discardCorruptedAndUseSeed) must use [_emitForce] directly.
  void _emit(PlannerState next) {
    if (state is AsyncError) return;
    final flipped = next.isSeedFallback
        ? next.copyWith(isSeedFallback: false)
        : next;
    _emitForce(flipped);
  }

  /// [_emitForce] bypasses both the AsyncError guard and the seed-flag flip.
  /// Used by `discardCorruptedAndUseSeed` (must escape the guard) and
  /// `resetToSeed` (must preserve `isSeedFallback: true`).
  ///
  /// State emission is synchronous (UI is snappy) and `beginSave` fires on
  /// the first dirty tick of a debounce window so the Topbar flips to
  /// `inFlight` while the user is still typing. The actual storage call is
  /// deferred to [_flushSave] via [_saveDebouncer], which only enqueues onto
  /// the [_lastSave] chain once the 500 ms quiescent window settles.
  ///
  /// Pass `flushNow: true` from user-explicit recovery paths (Discard, Retry
  /// save) so the write lands immediately without a 500 ms wait — the
  /// destructive recovery guarantees the corrupted blob on disk is
  /// overwritten before the user can reload.
  void _emitForce(PlannerState next, {bool flushNow = false}) {
    state = AsyncData(next);
    final statusCtrl = ref.read(saveStatusProvider.notifier);
    // First dirty tick of a debounce window: mark inFlight immediately so the
    // Topbar flips to "· saving…" while the user is still typing. Subsequent
    // ticks within the same window keep the existing inFlight lifecycle.
    //
    // `flushNow` paths (retrySave, discardCorruptedAndUseSeed) always begin a
    // fresh save lifecycle even when a debounce tick is already pending —
    // the user clicked a button and expects "saving…" feedback regardless of
    // what's queued. The pendingCount counter on SaveStatusController keeps
    // chained saves accounted for. `retrying: flushNow` also clobbers the
    // sticky-failed status (HIGH #5 contract) so the retry click visibly
    // confirms before resolving back to idle or failed.
    if (flushNow || !_saveDebouncer.hasPending) {
      statusCtrl.beginSave(retrying: flushNow);
    }
    _saveDebouncer.run(next, _flushSave);
    if (flushNow) {
      _saveDebouncer.flush();
    }
  }

  /// Enqueues the actual storage write on the serialized [_lastSave] chain.
  /// Called by the debouncer once the quiescent window settles (or
  /// synchronously via `flush()` from a user-explicit recovery path).
  ///
  /// SAFETY: ref.read happens synchronously before the .then closure. The
  /// closure captures the resolved provider instances as locals, so the
  /// chain can outlive the notifier's disposal without touching ref —
  /// teardown is already protected by `Debouncer.dispose()` cancelling the
  /// pending timer plus the post-disposal `run`/`flush` no-op guards in
  /// `debounced_save.dart`.
  void _flushSave(PlannerState payload) {
    final storage = ref.read(planStorageProvider);
    final statusCtrl = ref.read(saveStatusProvider.notifier);
    _lastSave = _lastSave.then((_) async {
      try {
        await storage.save(payload);
        statusCtrl.endSaveSuccess();
      } catch (e, st) {
        // L1 observability: log the failure. L3 surfacing flows through
        // saveStatusProvider so F1 can render a banner. Debug-only so
        // release builds don't leak storage internals.
        if (kDebugMode) debugPrint('PlanStorage.save failed: $e\n$st');
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
    // flushNow: destructive recovery must overwrite the corrupted blob on
    // disk immediately — no 500 ms window where the bad payload is still
    // recoverable to a confused user.
    _emitForce(PlannerState.seed(), flushNow: true);
  }

  /// Restores the seed plan. v1.1 has no UI consumer (the empty-plan CTA
  /// is non-destructive) — wired for a future Start-over affordance.
  /// Honors the AsyncError guard so users on a broken-storage state must go
  /// through `discardCorruptedAndUseSeed` instead. Uses `_emitForce` so the
  /// seed's `isSeedFallback: true` flag survives the emission — the explicit
  /// "Reset" intent restores the quickstart treatment rather than silently
  /// advancing past it.
  ///
  /// flushNow: explicit Reset is a user-facing immediacy signal (same
  /// shape as `discardCorruptedAndUseSeed`). The seed lands on the next
  /// microtask so the user doesn't wonder whether their click registered.
  void resetToSeed() {
    final cur = _currentOrNull();
    if (cur == null) return;
    if (state is AsyncError) return;
    _emitForce(PlannerState.seed(), flushNow: true);
  }

  /// Test-only re-emit hook so the AsyncError guard in `_emit` is reachable
  /// from unit tests without provoking an artificial AsyncError. Mirrors
  /// the public mutator API but bypasses the lambda.
  @visibleForTesting
  void debugEmit(PlannerState next) => _emit(next);

  /// Re-emit the current state to retrigger the save chain. Wired by F1b's
  /// "Retry save" affordance after a transient save failure. No-op when
  /// no current state is available (initial AsyncLoading, or post-error
  /// without a prior value).
  void retrySave() {
    final cur = _currentOrNull();
    if (cur == null) return;
    // flushNow: the user explicitly clicked "Retry save" because the
    // previous save failed. They expect an immediate retry, not a 500 ms
    // debounce wait.
    _emitForce(cur, flushNow: true);
  }

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
