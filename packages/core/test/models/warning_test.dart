// ABOUTME: Tests for the Warning model and Severity enum.
// ABOUTME: Verifies construction, equality, and serialization round-trips.
import 'package:test/test.dart';
import 'package:race_fueling_core/src/models/warning.dart';

void main() {
  group('Warning', () {
    test('creates with required fields', () {
      final warning = Warning(
        severity: Severity.critical,
        message: 'Exceeding gut tolerance',
      );
      expect(warning.severity, Severity.critical);
      expect(warning.message, 'Exceeding gut tolerance');
      expect(warning.entryIndex, isNull);
    });

    test('creates with optional entryIndex', () {
      final warning = Warning(
        severity: Severity.advisory,
        message: 'Ratio drifting',
        entryIndex: 3,
      );
      expect(warning.entryIndex, 3);
    });

    test('supports value equality', () {
      final a = Warning(severity: Severity.critical, message: 'Test');
      final b = Warning(severity: Severity.critical, message: 'Test');
      expect(a, equals(b));
    });

    test('JSON round-trip', () {
      final warning = Warning(
        severity: Severity.critical,
        message: 'Test warning',
        entryIndex: 5,
      );
      final json = warning.toJson();
      final restored = Warning.fromJson(json);
      expect(restored, equals(warning));
    });
  });

  group('Severity', () {
    test('has critical and advisory values', () {
      expect(Severity.values, contains(Severity.critical));
      expect(Severity.values, contains(Severity.advisory));
    });
  });
}
