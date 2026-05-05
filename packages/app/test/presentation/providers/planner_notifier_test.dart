// ABOUTME: Unit tests for PlannerNotifier — load + mutate + save plumbing.
// ABOUTME: Uses an in-memory FakePlanStorage to assert save side effects.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/data/plan_storage.dart';
import 'package:race_fueling_app/domain/planner_state.dart';
import 'package:race_fueling_app/presentation/providers/plan_storage_provider.dart';
import 'package:race_fueling_app/presentation/providers/planner_notifier.dart';

class FakePlanStorage implements PlanStorage {
  PlannerState? loaded;
  PlannerState? lastSaved;
  int saveCount = 0;
  // When set, load() returns a Completer-backed Future that does not resolve
  // until `loadGate.complete()` fires. Lets a test observe AsyncLoading state.
  Completer<void>? loadGate;
  // When set, load() returns Future.error(loadError) — used to assert that
  // PlannerNotifier surfaces store failures as AsyncError.
  Object? loadError;
  @override
  Future<PlannerState?> load() async {
    if (loadError != null) {
      throw loadError!;
    }
    if (loadGate != null) {
      await loadGate!.future;
    }
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

ProviderContainer _makeContainer(FakePlanStorage fake) {
  final c = ProviderContainer(
    overrides: [planStorageProvider.overrideWithValue(fake)],
  );
  return c;
}

void main() {
  test('falls back to seed when storage empty', () async {
    final fake = FakePlanStorage();
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    final state = await c.read(plannerNotifierProvider.future);
    expect(state.raceConfig.name, contains('Andalucía'));
  });

  test('updateRaceConfig persists new state', () async {
    final fake = FakePlanStorage();
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    await c.read(plannerNotifierProvider.future);
    c
        .read(plannerNotifierProvider.notifier)
        .updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 100));
    expect(
      c.read(plannerNotifierProvider).requireValue.raceConfig.targetCarbsGPerHr,
      100,
    );
    // Drain pending microtasks so the chained save resolves.
    await Future<void>.delayed(Duration.zero);
    expect(fake.saveCount, greaterThanOrEqualTo(1));
    expect(fake.lastSaved!.raceConfig.targetCarbsGPerHr, 100);
  });

  test('loaded state takes precedence over seed', () async {
    final custom = PlannerState.seed().copyWith(
      raceConfig: PlannerState.seed().raceConfig.copyWith(
        name: 'My Custom Race',
      ),
    );
    final fake = FakePlanStorage()..loaded = custom;
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    final state = await c.read(plannerNotifierProvider.future);
    expect(state.raceConfig.name, 'My Custom Race');
  });

  test('updateRaceConfig before build completes is a no-op', () async {
    final fake = FakePlanStorage()..loadGate = Completer<void>();
    final c = _makeContainer(fake);
    addTearDown(c.dispose);

    // Read the notifier without awaiting .future — state is AsyncLoading
    // because the gated load() has not resolved yet.
    final notifier = c.read(plannerNotifierProvider.notifier);
    expect(c.read(plannerNotifierProvider).isLoading, isTrue);

    // Mutator must not throw.
    expect(
      () => notifier.updateRaceConfig(
        (cfg) => cfg.copyWith(targetCarbsGPerHr: 999),
      ),
      returnsNormally,
    );
    // saveCount stays 0 because the early-return short-circuited.
    expect(fake.saveCount, 0);

    // Let the load complete and confirm state then resolves to the seed.
    fake.loadGate!.complete();
    final loaded = await c.read(plannerNotifierProvider.future);
    expect(loaded.raceConfig.targetCarbsGPerHr, isNot(999));
  });

  test('two sequential mutations save in order and both persist', () async {
    final fake = FakePlanStorage();
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    await c.read(plannerNotifierProvider.future);

    c
        .read(plannerNotifierProvider.notifier)
        .updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 90));
    c
        .read(plannerNotifierProvider.notifier)
        .updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 100));

    // Drain pending microtasks so the chained saves resolve.
    await Future<void>.delayed(Duration.zero);

    expect(fake.saveCount, 2);
    expect(fake.lastSaved!.raceConfig.targetCarbsGPerHr, 100);
  });
}
