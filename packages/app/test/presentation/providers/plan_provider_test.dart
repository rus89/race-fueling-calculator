// ABOUTME: Smoke tests for plan_provider and warnings_provider.
// ABOUTME: Verifies engine wiring through PlannerNotifier with FakePlanStorage.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/data/plan_storage.dart';
import 'package:race_fueling_app/domain/planner_state.dart';
import 'package:race_fueling_app/presentation/providers/plan_provider.dart';
import 'package:race_fueling_app/presentation/providers/plan_storage_provider.dart';
import 'package:race_fueling_app/presentation/providers/planner_notifier.dart';
import 'package:race_fueling_app/presentation/providers/warnings_provider.dart';

class FakePlanStorage implements PlanStorage {
  PlannerState? loaded;
  @override
  Future<PlannerState?> load() async => loaded;
  @override
  Future<void> save(PlannerState state) async {}
  @override
  Future<void> clear() async {
    loaded = null;
  }
}

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
}
