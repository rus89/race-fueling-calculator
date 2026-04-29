// ABOUTME: Tests that trigger every critical and advisory warning condition.
// ABOUTME: Verifies gut tolerance, caffeine limits, fuel gaps, and G:F ratio checks.
import 'package:test/test.dart';
import 'package:race_fueling_core/src/engine/plan_validator.dart';
import 'package:race_fueling_core/src/models/fueling_plan.dart';
import 'package:race_fueling_core/src/models/athlete_profile.dart';
import 'package:race_fueling_core/src/models/warning.dart';

PlanEntry _entry({
  required int minutes,
  double glucose = 20,
  double fructose = 10,
  double caffeine = 0,
}) =>
    PlanEntry(
      timeMark: Duration(minutes: minutes),
      products: [],
      carbsGlucose: glucose,
      carbsFructose: fructose,
      carbsTotal: glucose + fructose,
      cumulativeCarbs: 0, // not used by validator directly
      cumulativeCaffeine: caffeine,
      waterMl: 0,
    );

void main() {
  final profile = AthleteProfile(
    gutToleranceGPerHr: 60.0,
    unitSystem: UnitSystem.metric,
    bodyWeightKg: 70.0,
  );

  group('validatePlan', () {
    test('no warnings for a clean plan', () {
      final entries = [
        _entry(minutes: 20, glucose: 12, fructose: 8),
        _entry(minutes: 40, glucose: 12, fructose: 8),
        _entry(minutes: 60, glucose: 12, fructose: 8),
      ];

      final warnings = validatePlan(entries, profile, Duration(hours: 1));
      expect(warnings, isEmpty);
    });

    test('critical: gut tolerance exceeded by >15%', () {
      // 3 entries in 60 min with 30g each = 90g/hr (150% of 60g tolerance)
      final entries = [
        _entry(minutes: 20, glucose: 20, fructose: 10),
        _entry(minutes: 40, glucose: 20, fructose: 10),
        _entry(minutes: 60, glucose: 20, fructose: 10),
      ];

      final warnings = validatePlan(entries, profile, Duration(hours: 1));
      expect(
        warnings.any((w) =>
            w.severity == Severity.critical &&
            w.message.contains('gut tolerance')),
        true,
      );
    });

    test('critical: single-source >60g/hr', () {
      final entries = [
        _entry(minutes: 20, glucose: 25, fructose: 0),
        _entry(minutes: 40, glucose: 25, fructose: 0),
        _entry(minutes: 60, glucose: 25, fructose: 0),
      ];

      final warnings = validatePlan(entries, profile, Duration(hours: 1));
      expect(
        warnings.any((w) =>
            w.severity == Severity.critical &&
            w.message.contains('single-source')),
        true,
      );
    });

    test('critical: caffeine >400mg', () {
      // cumulativeCaffeine must be the running total, not per-entry value.
      // 3 x 150mg = 450mg cumulative, which exceeds the 400mg threshold.
      final entries = [
        _entry(minutes: 20, caffeine: 150),
        PlanEntry(
          timeMark: Duration(minutes: 40),
          products: [],
          carbsGlucose: 20,
          carbsFructose: 10,
          carbsTotal: 30,
          cumulativeCarbs: 0,
          cumulativeCaffeine: 300,
          waterMl: 0,
        ),
        PlanEntry(
          timeMark: Duration(minutes: 60),
          products: [],
          carbsGlucose: 20,
          carbsFructose: 10,
          carbsTotal: 30,
          cumulativeCarbs: 0,
          cumulativeCaffeine: 450,
          waterMl: 0,
        ),
      ];

      final warnings = validatePlan(entries, profile, Duration(hours: 1));
      expect(
        warnings.any((w) =>
            w.severity == Severity.critical && w.message.contains('caffeine')),
        true,
      );
    });

    test('critical: caffeine exceeds 6mg/kg body weight', () {
      // 60kg athlete, 370mg caffeine = 6.17mg/kg (above 6mg/kg threshold)
      // 370mg is under the absolute 400mg limit, so only per-kg check fires
      final lightProfile = AthleteProfile(
        gutToleranceGPerHr: 60.0,
        unitSystem: UnitSystem.metric,
        bodyWeightKg: 60.0,
      );
      final entries = [
        _entry(minutes: 20),
        PlanEntry(
          timeMark: Duration(minutes: 40),
          products: [],
          carbsGlucose: 20,
          carbsFructose: 10,
          carbsTotal: 30,
          cumulativeCarbs: 0,
          cumulativeCaffeine: 200,
          waterMl: 0,
        ),
        PlanEntry(
          timeMark: Duration(minutes: 60),
          products: [],
          carbsGlucose: 20,
          carbsFructose: 10,
          carbsTotal: 30,
          cumulativeCarbs: 0,
          cumulativeCaffeine: 370,
          waterMl: 0,
        ),
      ];

      final warnings = validatePlan(entries, lightProfile, Duration(hours: 1));
      expect(
        warnings.any((w) =>
            w.severity == Severity.critical && w.message.contains('caffeine')),
        true,
      );
    });

    test('advisory: gap >30 min with no fuel', () {
      final entries = [
        _entry(minutes: 20, glucose: 15, fructose: 5),
        // 40-min gap with nothing
        _entry(minutes: 60, glucose: 15, fructose: 5),
      ];

      final warnings = validatePlan(entries, profile, Duration(hours: 1));
      expect(
        warnings.any((w) =>
            w.severity == Severity.advisory && w.message.contains('gap')),
        true,
      );
    });

    test('advisory: glucose:fructose ratio outside range', () {
      // Ratio > 1.0 (all glucose, no fructose, but above 60g/hr)
      final entries = [
        _entry(minutes: 20, glucose: 30, fructose: 2),
        _entry(minutes: 40, glucose: 30, fructose: 2),
        _entry(minutes: 60, glucose: 30, fructose: 2),
      ];

      final warnings = validatePlan(entries, profile, Duration(hours: 1));
      expect(
        warnings.any((w) =>
            w.severity == Severity.advisory && w.message.contains('ratio')),
        true,
      );
    });

    test('no ratio warning at lower bound G:F = 0.5', () {
      // 60g/hr split as 40g glucose + 20g fructose → ratio = 0.5 (boundary)
      // Above 50g/hr threshold so the ratio check engages.
      final highGutProfile = AthleteProfile(
        gutToleranceGPerHr: 90.0,
        unitSystem: UnitSystem.metric,
        bodyWeightKg: 70.0,
      );
      final entries = [
        _entry(minutes: 20, glucose: 14, fructose: 7),
        _entry(minutes: 40, glucose: 14, fructose: 7),
        _entry(minutes: 60, glucose: 12, fructose: 6),
      ];

      final warnings =
          validatePlan(entries, highGutProfile, Duration(hours: 1));
      expect(
        warnings.any((w) => w.message.contains('ratio')),
        false,
      );
    });

    test('advisory: ratio below new lower bound (G:F = 0.45)', () {
      // 58g/hr split: 40g glucose + 18g fructose → ratio ≈ 0.45 (below 0.5)
      final highGutProfile = AthleteProfile(
        gutToleranceGPerHr: 90.0,
        unitSystem: UnitSystem.metric,
        bodyWeightKg: 70.0,
      );
      final entries = [
        _entry(minutes: 20, glucose: 14, fructose: 6),
        _entry(minutes: 40, glucose: 14, fructose: 6),
        _entry(minutes: 60, glucose: 12, fructose: 6),
      ];

      final warnings =
          validatePlan(entries, highGutProfile, Duration(hours: 1));
      expect(
        warnings.any((w) =>
            w.severity == Severity.advisory && w.message.contains('ratio')),
        true,
      );
    });

    test('no ratio warning at G:F = 0.7 (mid-range)', () {
      // 51g/hr: 30g glucose + 21g fructose → ratio = 0.7
      final highGutProfile = AthleteProfile(
        gutToleranceGPerHr: 90.0,
        unitSystem: UnitSystem.metric,
        bodyWeightKg: 70.0,
      );
      final entries = [
        _entry(minutes: 20, glucose: 10, fructose: 7),
        _entry(minutes: 40, glucose: 10, fructose: 7),
        _entry(minutes: 60, glucose: 10, fructose: 7),
      ];

      final warnings =
          validatePlan(entries, highGutProfile, Duration(hours: 1));
      expect(
        warnings.any((w) => w.message.contains('ratio')),
        false,
      );
    });

    test('no ratio warning at upper bound G:F = 1.0', () {
      // 60g/hr: 30g glucose + 30g fructose → ratio = 1.0 (boundary)
      final highGutProfile = AthleteProfile(
        gutToleranceGPerHr: 90.0,
        unitSystem: UnitSystem.metric,
        bodyWeightKg: 70.0,
      );
      final entries = [
        _entry(minutes: 20, glucose: 10, fructose: 10),
        _entry(minutes: 40, glucose: 10, fructose: 10),
        _entry(minutes: 60, glucose: 10, fructose: 10),
      ];

      final warnings =
          validatePlan(entries, highGutProfile, Duration(hours: 1));
      expect(
        warnings.any((w) => w.message.contains('ratio')),
        false,
      );
    });

    test('advisory: ratio above upper bound (G:F = 1.05)', () {
      // 51.25g/hr: 25g glucose + 26.25g fructose → ratio = 1.05 (above 1.0)
      final highGutProfile = AthleteProfile(
        gutToleranceGPerHr: 90.0,
        unitSystem: UnitSystem.metric,
        bodyWeightKg: 70.0,
      );
      final entries = [
        _entry(minutes: 20, glucose: 8.33, fructose: 8.75),
        _entry(minutes: 40, glucose: 8.33, fructose: 8.75),
        _entry(minutes: 60, glucose: 8.34, fructose: 8.75),
      ];

      final warnings =
          validatePlan(entries, highGutProfile, Duration(hours: 1));
      expect(
        warnings.any((w) =>
            w.severity == Severity.advisory && w.message.contains('ratio')),
        true,
      );
    });

    test('no ratio warning when glucose is zero (divide-by-zero guard)', () {
      // Pure fructose above threshold; ratio check requires both > 0.
      final highGutProfile = AthleteProfile(
        gutToleranceGPerHr: 90.0,
        unitSystem: UnitSystem.metric,
        bodyWeightKg: 70.0,
      );
      final entries = [
        _entry(minutes: 20, glucose: 0, fructose: 20),
        _entry(minutes: 40, glucose: 0, fructose: 20),
        _entry(minutes: 60, glucose: 0, fructose: 20),
      ];

      final warnings =
          validatePlan(entries, highGutProfile, Duration(hours: 1));
      expect(
        warnings.any((w) => w.message.contains('ratio')),
        false,
      );
    });

    test('advisory: significant carb drop in second half', () {
      // First half: 3 entries x 30g = 90g; second half: 3 entries x 10g = 30g
      // 30g < 90g * 0.8 = 72g → should warn
      final entries = [
        _entry(minutes: 20, glucose: 20, fructose: 10),
        _entry(minutes: 40, glucose: 20, fructose: 10),
        _entry(minutes: 60, glucose: 20, fructose: 10),
        _entry(minutes: 80, glucose: 6, fructose: 4),
        _entry(minutes: 100, glucose: 6, fructose: 4),
        _entry(minutes: 120, glucose: 6, fructose: 4),
      ];

      final warnings = validatePlan(entries, profile, Duration(hours: 2));
      expect(
        warnings.any((w) =>
            w.severity == Severity.advisory &&
            w.message.contains('second half')),
        true,
      );
    });

    test('no carb drop warning when distribution is even', () {
      final entries = [
        _entry(minutes: 20, glucose: 20, fructose: 10),
        _entry(minutes: 40, glucose: 20, fructose: 10),
        _entry(minutes: 60, glucose: 20, fructose: 10),
        _entry(minutes: 80, glucose: 20, fructose: 10),
        _entry(minutes: 100, glucose: 20, fructose: 10),
        _entry(minutes: 120, glucose: 20, fructose: 10),
      ];

      final warnings = validatePlan(entries, profile, Duration(hours: 2));
      expect(
        warnings.any((w) => w.message.contains('second half')),
        false,
      );
    });

    test('empty plan produces no warnings', () {
      final warnings = validatePlan([], profile, Duration(hours: 2));
      expect(warnings, isEmpty);
    });
  });
}
