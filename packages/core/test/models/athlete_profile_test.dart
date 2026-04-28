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

    test('copyWith with no args returns an equal instance', () {
      final profile = AthleteProfile(
        gutToleranceGPerHr: 60.0,
        unitSystem: UnitSystem.metric,
        bodyWeightKg: 70.0,
      );
      expect(profile.copyWith(), equals(profile));
    });

    test('copyWith updates a single field', () {
      final profile = AthleteProfile(
        gutToleranceGPerHr: 60.0,
        unitSystem: UnitSystem.metric,
        bodyWeightKg: 70.0,
      );
      final updated = profile.copyWith(gutToleranceGPerHr: 90.0);
      expect(updated.gutToleranceGPerHr, 90.0);
      expect(updated.unitSystem, UnitSystem.metric);
      expect(updated.bodyWeightKg, 70.0);
    });

    test('copyWith preserves nullable bodyWeightKg when omitted', () {
      final profile = AthleteProfile(
        gutToleranceGPerHr: 60.0,
        unitSystem: UnitSystem.metric,
        bodyWeightKg: 70.0,
      );
      final updated = profile.copyWith(unitSystem: UnitSystem.imperial);
      expect(updated.bodyWeightKg, 70.0);
    });

    test('rejects zero gut tolerance', () {
      expect(
        () => AthleteProfile(
          gutToleranceGPerHr: 0,
          unitSystem: UnitSystem.metric,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects negative gut tolerance', () {
      expect(
        () => AthleteProfile(
          gutToleranceGPerHr: -10,
          unitSystem: UnitSystem.metric,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects zero body weight when provided', () {
      expect(
        () => AthleteProfile(
          gutToleranceGPerHr: 60,
          unitSystem: UnitSystem.metric,
          bodyWeightKg: 0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects negative body weight when provided', () {
      expect(
        () => AthleteProfile(
          gutToleranceGPerHr: 60,
          unitSystem: UnitSystem.metric,
          bodyWeightKg: -50,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('allows null body weight', () {
      expect(
        () => AthleteProfile(
          gutToleranceGPerHr: 60,
          unitSystem: UnitSystem.metric,
        ),
        returnsNormally,
      );
    });

    test('rejects gut tolerance above 200 g/hr', () {
      expect(
        () => AthleteProfile(
          gutToleranceGPerHr: 250,
          unitSystem: UnitSystem.metric,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('fromJson throws FormatException when gutToleranceGPerHr is 0', () {
      expect(
        () => AthleteProfile.fromJson(const {
          'gutToleranceGPerHr': 0,
          'unitSystem': 'metric',
          'schema_version': 1,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson throws FormatException when gutToleranceGPerHr is negative',
        () {
      expect(
        () => AthleteProfile.fromJson(const {
          'gutToleranceGPerHr': -10,
          'unitSystem': 'metric',
          'schema_version': 1,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson throws FormatException when gutToleranceGPerHr exceeds 200',
        () {
      expect(
        () => AthleteProfile.fromJson(const {
          'gutToleranceGPerHr': 250,
          'unitSystem': 'metric',
          'schema_version': 1,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson throws FormatException when bodyWeightKg is 0', () {
      expect(
        () => AthleteProfile.fromJson(const {
          'gutToleranceGPerHr': 60,
          'unitSystem': 'metric',
          'bodyWeightKg': 0,
          'schema_version': 1,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson accepts valid data and round-trips', () {
      final profile = AthleteProfile(
        gutToleranceGPerHr: 90.0,
        unitSystem: UnitSystem.metric,
        bodyWeightKg: 70.0,
      );
      final restored = AthleteProfile.fromJson(profile.toJson());
      expect(restored, equals(profile));
    });

    test('copyWith preserves schemaVersion', () {
      final profile = AthleteProfile(
        gutToleranceGPerHr: 60.0,
        unitSystem: UnitSystem.metric,
      );
      expect(profile.copyWith().schemaVersion, profile.schemaVersion);
    });

    test('copyWith preserves bodyWeightKg when null is passed explicitly', () {
      final profile = AthleteProfile(
        gutToleranceGPerHr: 60.0,
        unitSystem: UnitSystem.metric,
        bodyWeightKg: 70.0,
      );
      expect(profile.copyWith(bodyWeightKg: null).bodyWeightKg, 70.0);
    });

    test('copyWith updates unitSystem to imperial', () {
      final profile = AthleteProfile(
        gutToleranceGPerHr: 60.0,
        unitSystem: UnitSystem.metric,
      );
      expect(profile.copyWith(unitSystem: UnitSystem.imperial).unitSystem,
          UnitSystem.imperial);
    });
  });
}
