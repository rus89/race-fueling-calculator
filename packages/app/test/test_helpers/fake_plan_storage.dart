// ABOUTME: Test fake for PlanStorage with optional load gate / load error.
// ABOUTME: Tracks lastSaved + saveCount so notifier wiring tests can assert.
import 'dart:async';

import 'package:race_fueling_app/data/plan_storage.dart';
import 'package:race_fueling_app/domain/planner_state.dart';

class FakePlanStorage implements PlanStorage {
  PlannerState? loaded;
  PlannerState? lastSaved;
  int saveCount = 0;

  /// When non-null, `load()` returns Future.error(loadError) instead of `loaded`.
  Object? loadError;

  /// When non-null, `load()` awaits this completer before returning.
  /// Use to test the AsyncLoading branch of the planner notifier.
  Completer<void>? loadGate;

  @override
  Future<PlannerState?> load() async {
    if (loadGate != null) await loadGate!.future;
    if (loadError != null) throw loadError!;
    return loaded;
  }

  @override
  Future<void> save(PlannerState state) async {
    lastSaved = state;
    saveCount++;
  }

  @override
  Future<void> clear() async {
    loaded = null;
  }
}
