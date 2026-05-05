// ABOUTME: Aggregate working state for the planner — config + profile.
// ABOUTME: Persisted as a single JSON blob; copyWith for immutable updates.
import 'domain.dart';

class PlannerState {
  final RaceConfig raceConfig;
  final AthleteProfile athleteProfile;

  /// True when this state is a seed (either synthesised on first run or
  /// written by `acceptSeedAfterError` during destructive recovery) and the
  /// user has not yet edited it. Persisted across reloads so the UI can keep
  /// surfacing a quickstart treatment until the first real edit. Auto-flipped
  /// to false by [PlannerNotifier] on any user-driven mutation.
  ///
  /// Legacy blobs (pre-PB-DATA-1) lack this key; [fromJson] defaults to
  /// `false` because by definition those blobs represent a saved customised
  /// plan, not a fallback.
  // TODO(PB-DATA-2): consider field-bound validation in fromJson — today
  // only structural casts are checked; semantic invariants (e.g. positive
  // body mass, monotonically increasing aid station times) flow through.
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

  Map<String, dynamic> toJson() => {
    'raceConfig': raceConfig.toJson(),
    'athleteProfile': athleteProfile.toJson(),
    'isSeedFallback': isSeedFallback,
  };

  factory PlannerState.fromJson(Map<String, dynamic> json) => PlannerState(
    raceConfig: RaceConfig.fromJson(json['raceConfig'] as Map<String, dynamic>),
    athleteProfile: AthleteProfile.fromJson(
      json['athleteProfile'] as Map<String, dynamic>,
    ),
    isSeedFallback: (json['isSeedFallback'] as bool?) ?? false,
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
