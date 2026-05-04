// ABOUTME: Round-trip + null-load tests for PlanStorageLocal.
// ABOUTME: Uses SharedPreferences in-memory mock (setMockInitialValues).
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/data/plan_storage_local.dart';
import 'package:race_fueling_app/domain/planner_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('returns null when no value stored', () async {
    final storage = PlanStorageLocal();
    expect(await storage.load(), isNull);
  });

  test('round-trips PlannerState through save/load', () async {
    final storage = PlanStorageLocal();
    final original = PlannerState.seed();
    await storage.save(original);
    final loaded = await storage.load();
    expect(loaded, isNotNull);
    expect(loaded!.raceConfig.name, original.raceConfig.name);
    expect(loaded.raceConfig.targetCarbsGPerHr, 80);
    expect(loaded.athleteProfile.gutToleranceGPerHr, 75);
  });

  test('clear() removes the saved state', () async {
    final storage = PlanStorageLocal();
    await storage.save(PlannerState.seed());
    await storage.clear();
    expect(await storage.load(), isNull);
  });
}
