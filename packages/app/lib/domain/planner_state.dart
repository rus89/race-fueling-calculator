// ABOUTME: Aggregate working state for the planner — config + profile.
// ABOUTME: Persisted as a single JSON blob; copyWith for immutable updates.
import 'domain.dart';

class PlannerState {
  final RaceConfig raceConfig;
  final AthleteProfile athleteProfile;

  /// True when this state was synthesised from `seed()` because storage was
  /// empty (first run) — never persisted, set by the notifier on a fresh
  /// drive. Loaded blobs always materialise with this flag false.
  final bool isSeedFallback;

  const PlannerState({
    required this.raceConfig,
    required this.athleteProfile,
    this.isSeedFallback = false,
  });

  PlannerState copyWith({
    RaceConfig? raceConfig,
    AthleteProfile? athleteProfile,
    bool? isSeedFallback,
  }) => PlannerState(
    raceConfig: raceConfig ?? this.raceConfig,
    athleteProfile: athleteProfile ?? this.athleteProfile,
    isSeedFallback: isSeedFallback ?? this.isSeedFallback,
  );

  // WHY: isSeedFallback is a runtime-only flag. A saved blob is by definition
  // a real plan, so reloading one always yields isSeedFallback == false.
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
    isSeedFallback: true,
  );
}
