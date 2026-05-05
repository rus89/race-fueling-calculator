// ABOUTME: Unit tests for PlannerNotifier — load + mutate + save plumbing.
// ABOUTME: Uses an in-memory FakePlanStorage to assert save side effects.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/domain/planner_state.dart';
import 'package:race_fueling_app/presentation/providers/plan_storage_provider.dart';
import 'package:race_fueling_app/presentation/providers/planner_notifier.dart';

import '../../test_helpers/fake_plan_storage.dart';

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

  test('updateAthleteProfile persists new state', () async {
    final fake = FakePlanStorage();
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    await c.read(plannerNotifierProvider.future);
    c
        .read(plannerNotifierProvider.notifier)
        .updateAthleteProfile((p) => p.copyWith(gutToleranceGPerHr: 100));
    expect(
      c
          .read(plannerNotifierProvider)
          .requireValue
          .athleteProfile
          .gutToleranceGPerHr,
      100,
    );
    // Drain pending microtasks so the chained save resolves.
    await Future<void>.delayed(Duration.zero);
    expect(fake.saveCount, 1);
    expect(fake.lastSaved!.athleteProfile.gutToleranceGPerHr, 100);
    // raceConfig must NOT have changed.
    expect(
      c.read(plannerNotifierProvider).requireValue.raceConfig.targetCarbsGPerHr,
      PlannerState.seed().raceConfig.targetCarbsGPerHr,
    );
  });

  test('emits AsyncError when storage load throws', () async {
    final fake = FakePlanStorage()..loadError = StateError('boom');
    final c = _makeContainer(fake);
    addTearDown(c.dispose);

    // Prime the notifier; expect the future to complete with an error.
    final caught = await c
        .read(plannerNotifierProvider.future)
        .then<Object?>((s) => null, onError: (Object e) => e);
    expect(caught, isA<StateError>());
    // The provider's current state should be AsyncError.
    expect(c.read(plannerNotifierProvider).hasError, isTrue);
  });
}
