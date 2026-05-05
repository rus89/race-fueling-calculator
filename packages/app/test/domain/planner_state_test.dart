// ABOUTME: Direct tests for the PlannerState aggregate root.
// ABOUTME: Covers copyWith branches, seed pinning, and JSON identity.
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/domain/planner_state.dart';
import 'package:race_fueling_core/core.dart';

void main() {
  group('PlannerState.copyWith', () {
    test('with no args returns a state with identical field references', () {
      final original = PlannerState.seed();
      final copy = original.copyWith();
      expect(copy.raceConfig, same(original.raceConfig));
      expect(copy.athleteProfile, same(original.athleteProfile));
    });

    test('with only raceConfig replaces config and preserves profile', () {
      final original = PlannerState.seed();
      final newConfig = original.raceConfig.copyWith(name: 'Test Race');
      final copy = original.copyWith(raceConfig: newConfig);
      expect(copy.raceConfig.name, 'Test Race');
      expect(copy.athleteProfile, same(original.athleteProfile));
    });

    test('with only athleteProfile replaces profile and preserves config', () {
      final original = PlannerState.seed();
      final newProfile = original.athleteProfile.copyWith(bodyWeightKg: 80);
      final copy = original.copyWith(athleteProfile: newProfile);
      expect(copy.athleteProfile.bodyWeightKg, 80);
      expect(copy.raceConfig, same(original.raceConfig));
    });
  });

  group('PlannerState.seed()', () {
    test('matches the documented Andalucía Bike Race Stage 3 fixture', () {
      final s = PlannerState.seed();
      expect(s.raceConfig.name, contains('Andalucía'));
      expect(s.raceConfig.duration, const Duration(hours: 4, minutes: 30));
      expect(s.raceConfig.targetCarbsGPerHr, 80);
      expect(s.raceConfig.discipline, Discipline.xcm);
      expect(s.raceConfig.aidStations.length, 2);
      expect(s.athleteProfile.gutToleranceGPerHr, 75);
      expect(s.athleteProfile.bodyWeightKg, 72);
    });

    test('seed() flags isSeedFallback true', () {
      expect(PlannerState.seed().isSeedFallback, isTrue);
    });
  });

  group('PlannerState.isSeedFallback', () {
    test('default constructor leaves isSeedFallback false', () {
      const s = PlannerState(
        raceConfig: RaceConfig(
          name: 'X',
          duration: Duration(hours: 1),
          targetCarbsGPerHr: 60,
          intervalMinutes: 15,
          timelineMode: TimelineMode.timeBased,
          strategy: Strategy.steady,
          discipline: Discipline.xcm,
          selectedProducts: [],
        ),
        athleteProfile: AthleteProfile(
          gutToleranceGPerHr: 60,
          unitSystem: UnitSystem.metric,
        ),
      );
      expect(s.isSeedFallback, isFalse);
    });

    test('copyWith(isSeedFallback: false) flips the flag off the seed', () {
      final s = PlannerState.seed().copyWith(isSeedFallback: false);
      expect(s.isSeedFallback, isFalse);
    });
  });

  group('PlannerState JSON', () {
    test('fromJson(toJson()) preserves all fields', () {
      final original = PlannerState.seed();
      final round = PlannerState.fromJson(original.toJson());
      expect(round.toJson(), equals(original.toJson()));
    });

    test('toJson includes isSeedFallback so the bit survives a save', () {
      final json = PlannerState.seed().toJson();
      expect(json['isSeedFallback'], isTrue);
      expect(json.keys.toSet(), {
        'raceConfig',
        'athleteProfile',
        'isSeedFallback',
      });
    });

    test('fromJson honours an explicit isSeedFallback: true', () {
      // A user who clicks "Start fresh" lands on a saved seed; reloading the
      // app must keep that fact visible until they actually edit something.
      final json = PlannerState.seed().toJson();
      final round = PlannerState.fromJson(json);
      expect(round.isSeedFallback, isTrue);
    });

    test('fromJson honours an explicit isSeedFallback: false', () {
      final json = PlannerState.seed().toJson();
      json['isSeedFallback'] = false;
      final round = PlannerState.fromJson(json);
      expect(round.isSeedFallback, isFalse);
    });

    test('fromJson defaults isSeedFallback to false when key is absent', () {
      // Legacy blobs (pre-PB-DATA-1) lack the key. Treat them as customised.
      final json = PlannerState.seed().toJson();
      json.remove('isSeedFallback');
      final round = PlannerState.fromJson(json);
      expect(round.isSeedFallback, isFalse);
    });
  });
}
