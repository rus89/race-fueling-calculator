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
    final loaded = await storage.load();
    return loaded ?? PlannerState.seed();
  }

  PlannerState _current() => state.requireValue;

  void _emit(PlannerState next) {
    state = AsyncData(next);
    final storage = ref.read(planStorageProvider);
    _lastSave = _lastSave.then((_) => storage.save(next)).onError((e, st) {
      // L1 observability: log the failure. L3 (UI surfacing via SaveStatus)
      // is a Phase F prerequisite — see PB-DATA-1 in JOURNAL.
      debugPrint('PlanStorage.save failed: $e');
    });
    unawaited(_lastSave);
  }

  void updateRaceConfig(RaceConfig Function(RaceConfig) edit) {
    _emit(_current().copyWith(raceConfig: edit(_current().raceConfig)));
  }

  void updateAthleteProfile(AthleteProfile Function(AthleteProfile) edit) {
    _emit(_current().copyWith(athleteProfile: edit(_current().athleteProfile)));
  }
}

final plannerNotifierProvider =
    AsyncNotifierProvider<PlannerNotifier, PlannerState>(PlannerNotifier.new);
