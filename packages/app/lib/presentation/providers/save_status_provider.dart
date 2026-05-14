// ABOUTME: Tracks the most recent save attempt's outcome for UI surfacing.
// ABOUTME: Idle / inFlight / failed; F1 renders a banner when state == failed.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lifecycle of the auto-save chain. `failed` is sticky in the sense that it
/// is only cleared by a subsequent successful save (matching the user mental
/// model: "are saves working *right now*?"). The Notifier moves through
/// idle → inFlight → idle on success, idle → inFlight → failed on failure.
enum SaveStatus { idle, inFlight, failed }

/// Lifecycle controller for save attempts.
///
/// Internal API: only `PlannerNotifier._emitForce` should call `beginSave` /
/// `endSaveSuccess` / `endSaveFailure`. The methods are public to satisfy
/// Riverpod's `NotifierProvider` pattern; do not call from widgets or other
/// providers.
///
/// `_pending` is an in-flight counter so two queued saves keep the status at
/// `inFlight` until the chain fully drains. A failure mid-chain surfaces
/// `failed` immediately even with later writes still in flight — the user
/// signal "saves are not working" is more important than "still saving"
/// while a known failure is unresolved.
class SaveStatusController extends Notifier<SaveStatus> {
  int _pending = 0;
  bool _lastWasFailure = false;

  @override
  SaveStatus build() => SaveStatus.idle;

  /// Begin a new save lifecycle.
  ///
  /// Sticky-failed contract: while [state] is [SaveStatus.failed], a fresh
  /// user-edit-driven save MUST NOT clobber the failure signal with
  /// inFlight. The user mental model is "saves aren't working" — that
  /// signal stays put until a save actually succeeds (clearing it via
  /// [endSaveSuccess] once the pending chain drains).
  ///
  /// The single exception is the user-explicit retry path
  /// (`PlannerNotifier.retrySave` → `_emitForce(flushNow: true)`). The
  /// retry button must confirm the click by briefly transitioning to
  /// inFlight so the user sees their action was received. Callers on
  /// that path pass `retrying: true`.
  void beginSave({bool retrying = false}) {
    _pending++;
    if (retrying || state != SaveStatus.failed) {
      state = SaveStatus.inFlight;
    }
  }

  void endSaveSuccess() {
    if (_pending > 0) _pending--;
    _lastWasFailure = false;
    if (_pending == 0) state = SaveStatus.idle;
    // While _pending > 0, status stays at whatever beginSave set (inFlight)
    // or stays failed if a sibling save in the chain has already failed.
  }

  void endSaveFailure() {
    if (_pending > 0) _pending--;
    _lastWasFailure = true;
    state = SaveStatus.failed;
    // Even with _pending > 0, surface the failure now: a known broken save
    // beats "still saving" as the user-facing signal.
  }

  @visibleForTesting
  int get pendingCount => _pending;

  @visibleForTesting
  bool get lastWasFailure => _lastWasFailure;
}

final saveStatusProvider = NotifierProvider<SaveStatusController, SaveStatus>(
  SaveStatusController.new,
);
