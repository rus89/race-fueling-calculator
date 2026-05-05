// ABOUTME: Smoke tests for plan_provider and warnings_provider.
// ABOUTME: Verifies engine wiring through PlannerNotifier with FakePlanStorage.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/presentation/providers/plan_provider.dart';
import 'package:race_fueling_app/presentation/providers/plan_storage_provider.dart';
import 'package:race_fueling_app/presentation/providers/planner_notifier.dart';
import 'package:race_fueling_app/presentation/providers/warnings_provider.dart';

import '../../test_helpers/fake_plan_storage.dart';

void main() {
  test('planProvider is null while planner state is still loading', () {
    final fake = FakePlanStorage();
    final c = ProviderContainer(
      overrides: [planStorageProvider.overrideWithValue(fake)],
    );
    addTearDown(c.dispose);
    expect(c.read(planProvider), isNull);
  });

  test('planProvider returns a plan once seed loads', () async {
    final fake = FakePlanStorage();
    final c = ProviderContainer(
      overrides: [planStorageProvider.overrideWithValue(fake)],
    );
    addTearDown(c.dispose);
    await c.read(plannerNotifierProvider.future);
    final plan = c.read(planProvider);
    expect(plan, isNotNull);
    expect(plan!.entries, isNotEmpty);
  });

  test('warningsProvider returns const [] when planProvider is null', () {
    final fake = FakePlanStorage();
    final c = ProviderContainer(
      overrides: [planStorageProvider.overrideWithValue(fake)],
    );
    addTearDown(c.dispose);
    expect(c.read(warningsProvider), isEmpty);
  });

  test('warningsProvider returns the loaded plan warnings', () async {
    final fake = FakePlanStorage();
    final c = ProviderContainer(
      overrides: [planStorageProvider.overrideWithValue(fake)],
    );
    addTearDown(c.dispose);
    await c.read(plannerNotifierProvider.future);
    final warnings = c.read(warningsProvider);
    final plan = c.read(planProvider)!;
    expect(warnings, equals(plan.warnings));
  });

  test('planProvider recomputes after raceConfig mutation', () async {
    final fake = FakePlanStorage();
    final c = ProviderContainer(
      overrides: [planStorageProvider.overrideWithValue(fake)],
    );
    addTearDown(c.dispose);
    await c.read(plannerNotifierProvider.future);
    final initial = c.read(planProvider);
    expect(initial, isNotNull);
    final initialTotal = initial!.summary.totalCarbs;

    c
        .read(plannerNotifierProvider.notifier)
        .updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 120));
    await Future<void>.delayed(Duration.zero);

    final updated = c.read(planProvider);
    expect(updated, isNotNull);
    // 120 g/hr × 4.5h ≈ 540g vs the seed's 80 × 4.5 = 360g. Allocator
    // quantization keeps the exact value vague, but totals must differ.
    expect(updated!.summary.totalCarbs, isNot(equals(initialTotal)));
  });

  test('warningsProvider re-derives after state mutation', () async {
    final fake = FakePlanStorage();
    final c = ProviderContainer(
      overrides: [planStorageProvider.overrideWithValue(fake)],
    );
    addTearDown(c.dispose);
    await c.read(plannerNotifierProvider.future);
    final initialWarnings = c.read(warningsProvider);

    c
        .read(plannerNotifierProvider.notifier)
        .updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 200));
    await Future<void>.delayed(Duration.zero);

    // Driving carb target far past the gut-tolerance ceiling fires
    // additional warnings. The list must not equal the seed warnings.
    final updatedWarnings = c.read(warningsProvider);
    expect(updatedWarnings, isNot(equals(initialWarnings)));
  });
}
