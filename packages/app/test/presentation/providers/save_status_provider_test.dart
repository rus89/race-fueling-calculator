// ABOUTME: Tests for saveStatusProvider — sticky-until-success failure semantics.
// ABOUTME: Drives status transitions through PlannerNotifier mutations.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/presentation/providers/plan_storage_provider.dart';
import 'package:race_fueling_app/presentation/providers/planner_notifier.dart';
import 'package:race_fueling_app/presentation/providers/save_status_provider.dart';

import '../../test_helpers/fake_plan_storage.dart';

ProviderContainer _makeContainer(FakePlanStorage fake) =>
    ProviderContainer(overrides: [planStorageProvider.overrideWithValue(fake)]);

void main() {
  test('initial state is idle', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(saveStatusProvider), SaveStatus.idle);
  });

  test('successful save transitions through inFlight back to idle', () async {
    final fake = FakePlanStorage();
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    await c.read(plannerNotifierProvider.future);

    c
        .read(plannerNotifierProvider.notifier)
        .updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 90));
    await Future<void>.delayed(Duration.zero);

    expect(c.read(saveStatusProvider), SaveStatus.idle);
    expect(fake.saveCount, 1);
  });

  test('failed save transitions to failed status', () async {
    final fake = FakePlanStorage();
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    await c.read(plannerNotifierProvider.future);

    fake.saveError = StateError('quota exceeded');
    c
        .read(plannerNotifierProvider.notifier)
        .updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 90));
    await Future<void>.delayed(Duration.zero);

    expect(c.read(saveStatusProvider), SaveStatus.failed);
  });

  test(
    'failed status flips back to idle after a subsequent successful save',
    () async {
      final fake = FakePlanStorage();
      final c = _makeContainer(fake);
      addTearDown(c.dispose);
      await c.read(plannerNotifierProvider.future);

      fake.saveError = StateError('boom');
      c
          .read(plannerNotifierProvider.notifier)
          .updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 90));
      await Future<void>.delayed(Duration.zero);
      expect(c.read(saveStatusProvider), SaveStatus.failed);

      fake.saveError = null;
      c
          .read(plannerNotifierProvider.notifier)
          .updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 100));
      await Future<void>.delayed(Duration.zero);

      expect(c.read(saveStatusProvider), SaveStatus.idle);
    },
  );

  test('idle re-flips to failed on the next failure', () async {
    final fake = FakePlanStorage();
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    await c.read(plannerNotifierProvider.future);

    // success
    c
        .read(plannerNotifierProvider.notifier)
        .updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 85));
    await Future<void>.delayed(Duration.zero);
    expect(c.read(saveStatusProvider), SaveStatus.idle);

    // failure
    fake.saveError = StateError('boom');
    c
        .read(plannerNotifierProvider.notifier)
        .updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 90));
    await Future<void>.delayed(Duration.zero);
    expect(c.read(saveStatusProvider), SaveStatus.failed);
  });

  test('two simultaneous saves: status reflects most recent outcome', () async {
    // Two writes back-to-back — second one fails. Status must end at failed
    // because the chained save's tail outcome wins.
    final fake = FakePlanStorage();
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    await c.read(plannerNotifierProvider.future);

    final notifier = c.read(plannerNotifierProvider.notifier);
    notifier.updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 85));
    fake.saveError = StateError('boom');
    notifier.updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 90));
    await Future<void>.delayed(Duration.zero);

    expect(c.read(saveStatusProvider), SaveStatus.failed);
  });

  test(
    'save chain remains usable after a failure (does not break subsequent writes)',
    () async {
      final fake = FakePlanStorage();
      final c = _makeContainer(fake);
      addTearDown(c.dispose);
      await c.read(plannerNotifierProvider.future);

      fake.saveError = StateError('boom');
      c
          .read(plannerNotifierProvider.notifier)
          .updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 90));
      await Future<void>.delayed(Duration.zero);
      expect(fake.saveCount, 0);

      fake.saveError = null;
      c
          .read(plannerNotifierProvider.notifier)
          .updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 100));
      await Future<void>.delayed(Duration.zero);

      // The save chain didn't deadlock: the post-failure write still landed.
      expect(fake.saveCount, 1);
      expect(fake.lastSaved!.raceConfig.targetCarbsGPerHr, 100);
    },
  );
}
