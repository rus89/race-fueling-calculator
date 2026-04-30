// ABOUTME: Tests for schema version checking and migration of stored JSON data.
// ABOUTME: Verifies that unsupported versions throw and that current-version data passes through.
import 'package:test/test.dart';
import 'package:race_fueling_core/src/storage/schema_migration.dart';

void main() {
  group('validateSchemaVersion', () {
    test('version 1 passes through unchanged', () {
      final json = {'schema_version': 1, 'data': 'test'};
      final result = validateSchemaVersion(json, currentVersion: 1);
      expect(result, json);
    });

    test('missing version throws', () {
      final json = {'data': 'test'};
      expect(
        () => validateSchemaVersion(json, currentVersion: 1),
        throwsA(isA<SchemaVersionException>()),
      );
    });

    test('future version throws', () {
      final json = {'schema_version': 99, 'data': 'test'};
      expect(
        () => validateSchemaVersion(json, currentVersion: 1),
        throwsA(isA<SchemaVersionException>()),
      );
    });

    test('non-integer version throws', () {
      final json = {'schema_version': '1', 'data': 'test'};
      expect(
        () => validateSchemaVersion(json, currentVersion: 1),
        throwsA(isA<SchemaVersionException>()),
      );
    });

    test('older version passes through unchanged', () {
      // Migration logic is not yet implemented; older versions pass through.
      final json = {'schema_version': 0, 'data': 'test'};
      final result = validateSchemaVersion(json, currentVersion: 1);
      expect(result, json);
    });
  });

  group('migrateRaceConfig', () {
    test('v1 RaceConfig with isAidStationOnly migrates to v2', () {
      final v1Json = {
        'name': 'Legacy',
        'duration': 'PT2H',
        'timelineMode': 'time_based',
        'intervalMinutes': 20,
        'targetCarbsGPerHr': 60.0,
        'strategy': 'steady',
        'selectedProducts': [
          {'productId': 'p1', 'quantity': 2, 'isAidStationOnly': true},
        ],
        'aidStations': [],
        'schema_version': 1,
      };
      final migrated = migrateRaceConfig(v1Json);
      expect(migrated['schema_version'], 2);
      expect(
        (migrated['selectedProducts'] as List).first.containsKey(
          'isAidStationOnly',
        ),
        isFalse,
      );
    });

    test(
      'v1 with no aid-station refills produces v2 with empty refill arrays',
      () {
        final v1Json = {
          'name': 'Legacy',
          'duration': 'PT2H',
          'timelineMode': 'time_based',
          'intervalMinutes': 20,
          'targetCarbsGPerHr': 60.0,
          'strategy': 'steady',
          'selectedProducts': [],
          'aidStations': [
            {'timeMinutes': 60},
          ],
          'schema_version': 1,
        };
        final migrated = migrateRaceConfig(v1Json);
        expect((migrated['aidStations'] as List).first['refill'], isEmpty);
      },
    );

    test('v2 input passes through unchanged', () {
      final v2Json = {
        'name': 'Current',
        'duration': 'PT2H',
        'timelineMode': 'time_based',
        'intervalMinutes': 20,
        'targetCarbsGPerHr': 60.0,
        'strategy': 'steady',
        'selectedProducts': [
          {'productId': 'p1', 'quantity': 2},
        ],
        'aidStations': [],
        'discipline': 'xcm',
        'schema_version': 2,
      };
      expect(migrateRaceConfig(v2Json), equals(v2Json));
    });

    test('v1 missing schema_version (legacy default) migrates to v2', () {
      final v1Json = {
        'name': 'Older',
        'duration': 'PT2H',
        'timelineMode': 'time_based',
        'intervalMinutes': 20,
        'targetCarbsGPerHr': 60.0,
        'strategy': 'steady',
        'selectedProducts': [
          {'productId': 'p1', 'quantity': 2, 'isAidStationOnly': false},
        ],
        'aidStations': [
          {'timeMinutes': 90},
        ],
      };
      final migrated = migrateRaceConfig(v1Json);
      expect(migrated['schema_version'], 2);
      expect(
        (migrated['selectedProducts'] as List).first.containsKey(
          'isAidStationOnly',
        ),
        isFalse,
      );
      expect((migrated['aidStations'] as List).first['refill'], isEmpty);
    });
  });
}
