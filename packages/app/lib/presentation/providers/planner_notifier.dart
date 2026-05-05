// ABOUTME: AsyncNotifier holding the working PlannerState; loads from storage.
// ABOUTME: Mutators emit a new state and trigger save (debouncing comes in F2).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/domain.dart';
import '../../domain/planner_state.dart';
import 'plan_storage_provider.dart';

class PlannerNotifier extends AsyncNotifier<PlannerState> {
  @override
  Future<PlannerState> build() async {
    final storage = ref.watch(planStorageProvider);
    final loaded = await storage.load();
    return loaded ?? PlannerState.seed();
  }

  PlannerState _current() => state.requireValue;

  void _emit(PlannerState next) {
    state = AsyncData(next);
    unawaited(
      ref.read(planStorageProvider).save(next).onError((e, st) {
        // L1 observability: log the failure. L3 (UI surfacing via SaveStatus)
        // is a Phase F prerequisite — see PB-DATA-1 in JOURNAL.
        debugPrint('PlanStorage.save failed: $e');
      }),
    );
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
