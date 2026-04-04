// ABOUTME: Tests for the AthleteProfile model construction and serialization.
// ABOUTME: Verifies gut tolerance, unit system, and optional body weight fields.
import 'package:test/test.dart';
import 'package:race_fueling_core/src/models/athlete_profile.dart';

void main() {
  group('AthleteProfile', () {
    test('creates with required fields', () {
      final profile = AthleteProfile(
        gutToleranceGPerHr: 60.0,
        unitSystem: UnitSystem.metric,
      );
      expect(profile.gutToleranceGPerHr, 60.0);
      expect(profile.unitSystem, UnitSystem.metric);
      expect(profile.bodyWeightKg, isNull);
    });

    test('creates with optional body weight', () {
      final profile = AthleteProfile(
        gutToleranceGPerHr: 90.0,
        unitSystem: UnitSystem.imperial,
        bodyWeightKg: 75.0,
      );
      expect(profile.bodyWeightKg, 75.0);
    });

    test('JSON round-trip', () {
      final profile = AthleteProfile(
        gutToleranceGPerHr: 75.0,
        unitSystem: UnitSystem.metric,
        bodyWeightKg: 70.0,
      );
      final json = profile.toJson();
      expect(json['schema_version'], 1);
      final restored = AthleteProfile.fromJson(json);
      expect(restored, equals(profile));
    });
  });
}
