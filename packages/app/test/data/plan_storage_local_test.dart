// ABOUTME: Round-trip + corrupted-blob + v1 migration tests for PlanStorageLocal.
// ABOUTME: Uses SharedPreferences in-memory mock (setMockInitialValues).
import 'dart:convert';

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
    expect(loaded!.toJson(), equals(original.toJson()));
  });

  test('clear() removes the saved state', () async {
    final storage = PlanStorageLocal();
    await storage.save(PlannerState.seed());
    await storage.clear();
    expect(await storage.load(), isNull);
  });

  test('returns null when stored value is not valid JSON', () async {
    SharedPreferences.setMockInitialValues({
      'bonk_v1.working_plan': 'not-json',
    });
    final storage = PlanStorageLocal();
    expect(await storage.load(), isNull);
  });

  test('returns null when stored JSON is not a Map', () async {
    SharedPreferences.setMockInitialValues({'bonk_v1.working_plan': '[1,2,3]'});
    final storage = PlanStorageLocal();
    expect(await storage.load(), isNull);
  });

  test('returns null when stored Map is missing required keys', () async {
    SharedPreferences.setMockInitialValues({'bonk_v1.working_plan': '{}'});
    final storage = PlanStorageLocal();
    expect(await storage.load(), isNull);
  });

  test('migrates a v1-shaped raceConfig blob through load', () async {
    // Hand-rolled v1 blob — no `discipline`, `selectedProducts` carrying the
    // dropped `isAidStationOnly` flag, `aidStations` without `refill`.
    // Duration is stored as integer minutes (durationFromJson contract).
    final v1RaceConfig = <String, dynamic>{
      'name': 'Legacy Race',
      'duration': 270,
      'timelineMode': 'time_based',
      'intervalMinutes': 15,
      'targetCarbsGPerHr': 80.0,
      'strategy': 'steady',
      'selectedProducts': [
        {
          'productId': 'sis-beta-fuel-drink',
          'quantity': 2,
          'isAidStationOnly': true,
        },
      ],
      'aidStations': [
        {'timeMinutes': 90},
      ],
      'schema_version': 1,
    };
    final v1Profile = <String, dynamic>{
      'gutToleranceGPerHr': 75.0,
      'unitSystem': 'metric',
      'bodyWeightKg': 72.0,
      'schema_version': 1,
    };
    final blob = jsonEncode({
      'raceConfig': v1RaceConfig,
      'athleteProfile': v1Profile,
    });
    SharedPreferences.setMockInitialValues({'bonk_v1.working_plan': blob});

    final loaded = await PlanStorageLocal().load();
    expect(loaded, isNotNull);
    expect(loaded!.raceConfig.schemaVersion, 2);
    // The migrator does not inject a discipline; v1 blobs lacked the field
    // so the loaded RaceConfig has discipline == null.
    expect(loaded.raceConfig.discipline, isNull);
    expect(loaded.raceConfig.aidStations.first.refill, const <String>[]);
    expect(
      loaded.raceConfig.selectedProducts.first.productId,
      'sis-beta-fuel-drink',
    );
    expect(loaded.raceConfig.selectedProducts.first.quantity, 2);
  });
}
