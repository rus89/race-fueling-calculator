// ABOUTME: Smoke tests for plan_provider and warnings_provider.
// ABOUTME: Verifies engine wiring through PlannerNotifier with FakePlanStorage.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/presentation/providers/plan_provider.dart';
import 'package:race_fueling_app/presentation/providers/plan_storage_provider.dart';
import 'package:race_fueling_app/presentation/providers/planner_notifier.dart';
import 'package:race_fueling_app/presentation/providers/warnings_provider.dart';

import '../../test_helpers/fake_plan_storage.dart';

ProviderContainer _makeContainer(FakePlanStorage fake) =>
    ProviderContainer(overrides: [planStorageProvider.overrideWithValue(fake)]);

void main() {
  test('planProvider is AsyncLoading while planner state is still loading', () {
    final fake = FakePlanStorage()..loadGate = Completer<void>();
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    final async = c.read(planProvider);
    expect(async.isLoading, isTrue);
    expect(async.hasValue, isFalse);
    expect(async.hasError, isFalse);
  });

  test('planProvider returns AsyncData(plan) once seed loads', () async {
    final fake = FakePlanStorage();
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    await c.read(plannerNotifierProvider.future);
    final async = c.read(planProvider);
    expect(async.hasValue, isTrue);
    expect(async.requireValue.entries, isNotEmpty);
  });

  test('planProvider preserves AsyncError when storage load throws', () async {
    final fake = FakePlanStorage()..loadError = StateError('boom');
    final c = _makeContainer(fake);
    addTearDown(c.dispose);

    await c
        .read(plannerNotifierProvider.future)
        .then<Object?>((s) => null, onError: (Object e) => e);

    final async = c.read(planProvider);
    expect(async.hasError, isTrue);
    expect(async.error, isA<StateError>());
  });

  test('warningsProvider returns const [] for AsyncLoading', () {
    final fake = FakePlanStorage()..loadGate = Completer<void>();
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    expect(c.read(warningsProvider), isEmpty);
  });

  test('warningsProvider returns const [] for AsyncError', () async {
    final fake = FakePlanStorage()..loadError = StateError('boom');
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    await c
        .read(plannerNotifierProvider.future)
        .then<Object?>((s) => null, onError: (Object e) => e);
    expect(c.read(warningsProvider), isEmpty);
  });

  test('warningsProvider returns plan.warnings for AsyncData', () async {
    final fake = FakePlanStorage();
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    await c.read(plannerNotifierProvider.future);
    final warnings = c.read(warningsProvider);
    final plan = c.read(planProvider).requireValue;
    expect(warnings, equals(plan.warnings));
  });

  test('planProvider recomputes after raceConfig mutation', () async {
    final fake = FakePlanStorage();
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    await c.read(plannerNotifierProvider.future);
    final initialTotal = c.read(planProvider).requireValue.summary.totalCarbs;

    c
        .read(plannerNotifierProvider.notifier)
        .updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 120));
    await Future<void>.delayed(Duration.zero);

    // 120 g/hr × 4.5h ≈ 540g vs the seed's 80 × 4.5 = 360g. Allocator
    // quantization keeps the exact value vague, but totals must differ.
    expect(
      c.read(planProvider).requireValue.summary.totalCarbs,
      isNot(equals(initialTotal)),
    );
  });

  test('warningsProvider re-derives after state mutation', () async {
    final fake = FakePlanStorage();
    final c = _makeContainer(fake);
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
