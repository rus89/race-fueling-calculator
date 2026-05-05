// ABOUTME: Test fake for PlanStorage with optional load gate / load error / corrupt blob.
// ABOUTME: Tracks lastSaved + saveCount so notifier wiring tests can assert.
import 'dart:async';

import 'package:race_fueling_app/data/plan_storage.dart';
import 'package:race_fueling_app/domain/planner_state.dart';

class FakePlanStorage implements PlanStorage {
  PlannerState? loaded;
  PlannerState? lastSaved;
  int saveCount = 0;

  /// When non-null, `load()` throws this raw object instead of returning
  /// [loaded]. Use for arbitrary platform-init failures (StateError,
  /// MissingPluginException, etc.).
  Object? loadError;

  /// When non-null, `load()` throws a [PlanStorageException] carrying these
  /// bytes as `rawBytes` — mimics the realistic "corrupted localStorage blob"
  /// vector the production loader detects.
  String? corruptBlob;

  /// When non-null, `load()` awaits this completer before returning.
  /// Use to test the AsyncLoading branch of the planner notifier.
  Completer<void>? loadGate;

  /// When non-null, `save()` throws this object instead of recording the call.
  Object? saveError;

  /// When non-null, `save()` awaits this completer before completing, so the
  /// caller can observe `inFlight` state mid-save. Tests should call
  /// `saveGate!.complete()` to let the save resolve.
  Completer<void>? saveGate;

  @override
  Future<PlannerState?> load() async {
    if (loadGate != null) await loadGate!.future;
    if (corruptBlob != null) {
      throw PlanStorageException(
        'Stored plan JSON is malformed',
        rawBytes: corruptBlob,
      );
    }
    if (loadError != null) throw loadError!;
    return loaded;
  }

  @override
  Future<void> save(PlannerState state) async {
    if (saveGate != null) await saveGate!.future;
    if (saveError != null) throw saveError!;
    lastSaved = state;
    saveCount++;
  }

  @override
  Future<void> clear() async {
    loaded = null;
  }
}
