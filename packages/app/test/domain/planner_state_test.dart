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
  });

  group('PlannerState JSON', () {
    test('fromJson(toJson()) preserves all fields', () {
      final original = PlannerState.seed();
      final round = PlannerState.fromJson(original.toJson());
      expect(round.toJson(), equals(original.toJson()));
    });

    test('toJson produces a stable two-key structure', () {
      final json = PlannerState.seed().toJson();
      expect(json.keys.toSet(), {'raceConfig', 'athleteProfile'});
    });
  });
}
