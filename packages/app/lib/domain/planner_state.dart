// ABOUTME: Aggregate working state for the planner — config + profile.
// ABOUTME: Persisted as a single JSON blob; copyWith for immutable updates.
import 'package:race_fueling_core/core.dart';

class PlannerState {
  final RaceConfig raceConfig;
  final AthleteProfile athleteProfile;

  const PlannerState({required this.raceConfig, required this.athleteProfile});

  PlannerState copyWith({
    RaceConfig? raceConfig,
    AthleteProfile? athleteProfile,
  }) => PlannerState(
    raceConfig: raceConfig ?? this.raceConfig,
    athleteProfile: athleteProfile ?? this.athleteProfile,
  );

  Map<String, dynamic> toJson() => {
    'raceConfig': raceConfig.toJson(),
    'athleteProfile': athleteProfile.toJson(),
  };

  factory PlannerState.fromJson(Map<String, dynamic> json) => PlannerState(
    raceConfig: RaceConfig.fromJson(json['raceConfig'] as Map<String, dynamic>),
    athleteProfile: AthleteProfile.fromJson(
      json['athleteProfile'] as Map<String, dynamic>,
    ),
  );

  /// The Andalucía Bike Race Stage 3 seed (matches the prototype).
  factory PlannerState.seed() => const PlannerState(
    raceConfig: RaceConfig(
      name: 'Andalucía Bike Race — Stage 3',
      duration: Duration(hours: 4, minutes: 30),
      distanceKm: 90,
      timelineMode: TimelineMode.timeBased,
      intervalMinutes: 15,
      targetCarbsGPerHr: 80,
      strategy: Strategy.steady,
      discipline: Discipline.xcm,
      selectedProducts: [
        ProductSelection(productId: 'sis-beta-fuel-drink', quantity: 2),
        ProductSelection(productId: 'maurten-160', quantity: 4),
        ProductSelection(productId: 'maurten-gel-100-caf', quantity: 2),
        ProductSelection(productId: 'precision-pf30-gel', quantity: 2),
        ProductSelection(productId: 'clif-bloks', quantity: 1),
      ],
      aidStations: [
        AidStation(timeMinutes: 90, refill: ['sis-beta-fuel-drink']),
        AidStation(
          timeMinutes: 180,
          refill: ['sis-beta-fuel-drink', 'maurten-gel-100-caf'],
        ),
      ],
    ),
    athleteProfile: AthleteProfile(
      gutToleranceGPerHr: 75,
      unitSystem: UnitSystem.metric,
      bodyWeightKg: 72,
    ),
  );
}
