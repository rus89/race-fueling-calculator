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
}
