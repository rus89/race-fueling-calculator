// ABOUTME: Defines RaceConfig and supporting types for race plan configuration.
// ABOUTME: Includes strategy, timeline mode, product selections, and environmental conditions.
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'duration_converter.dart';

part 'race_config.g.dart';

enum TimelineMode {
  @JsonValue('time_based')
  timeBased,
  @JsonValue('distance_based')
  distanceBased,
}

enum Strategy {
  @JsonValue('steady')
  steady,
  @JsonValue('front_load')
  frontLoad,
  @JsonValue('back_load')
  backLoad,
  @JsonValue('custom')
  custom,
}

enum Discipline {
  @JsonValue('xcm')
  xcm,
  @JsonValue('road')
  road,
  @JsonValue('run')
  run,
  @JsonValue('tri')
  tri,
  @JsonValue('ultra')
  ultra,
}

@JsonSerializable()
class ProductSelection extends Equatable {
  final String productId;
  final int quantity;

  const ProductSelection({required this.productId, required this.quantity});

  factory ProductSelection.fromJson(Map<String, dynamic> json) =>
      _$ProductSelectionFromJson(json);

  Map<String, dynamic> toJson() => _$ProductSelectionToJson(this);

  @override
  List<Object?> get props => [productId, quantity];
}

@JsonSerializable()
class AidStation extends Equatable {
  final double? distanceKm;
  final int? timeMinutes;
  @JsonKey(defaultValue: <String>[])
  final List<String> refill;

  const AidStation({this.distanceKm, this.timeMinutes, this.refill = const []});

  factory AidStation.fromJson(Map<String, dynamic> json) =>
      _$AidStationFromJson(json);

  Map<String, dynamic> toJson() => _$AidStationToJson(this);

  @override
  List<Object?> get props => [distanceKm, timeMinutes, refill];
}

@JsonSerializable()
class CurveSegment extends Equatable {
  final int durationMinutes;
  final double targetGPerHr;

  const CurveSegment({
    required this.durationMinutes,
    required this.targetGPerHr,
  });

  factory CurveSegment.fromJson(Map<String, dynamic> json) =>
      _$CurveSegmentFromJson(json);

  Map<String, dynamic> toJson() => _$CurveSegmentToJson(this);

  @override
  List<Object?> get props => [durationMinutes, targetGPerHr];
}

@JsonSerializable(explicitToJson: true)
class RaceConfig extends Equatable {
  final String name;
  @JsonKey(fromJson: durationFromJson, toJson: durationToJson)
  final Duration duration;
  final double? distanceKm;
  final TimelineMode timelineMode;
  final int? intervalMinutes;
  final double? intervalKm;
  final double targetCarbsGPerHr;
  final Strategy strategy;
  final List<CurveSegment>? customCurve;
  final List<ProductSelection> selectedProducts;
  final List<AidStation> aidStations;
  final double? temperature;
  final double? humidity;
  final double? altitudeM;
  @JsonKey(includeIfNull: false)
  final Discipline? discipline;
  @JsonKey(name: 'schema_version', defaultValue: 1)
  final int schemaVersion;

  const RaceConfig({
    required this.name,
    required this.duration,
    this.distanceKm,
    required this.timelineMode,
    this.intervalMinutes,
    this.intervalKm,
    required this.targetCarbsGPerHr,
    required this.strategy,
    this.customCurve,
    required this.selectedProducts,
    this.aidStations = const [],
    this.temperature,
    this.humidity,
    this.altitudeM,
    this.discipline,
    this.schemaVersion = 1,
  });

  factory RaceConfig.fromJson(Map<String, dynamic> json) =>
      _$RaceConfigFromJson(json);

  Map<String, dynamic> toJson() => _$RaceConfigToJson(this);

  RaceConfig copyWith({
    String? name,
    Duration? duration,
    double? distanceKm,
    TimelineMode? timelineMode,
    int? intervalMinutes,
    double? intervalKm,
    double? targetCarbsGPerHr,
    Strategy? strategy,
    List<CurveSegment>? customCurve,
    List<ProductSelection>? selectedProducts,
    List<AidStation>? aidStations,
    double? temperature,
    double? humidity,
    double? altitudeM,
    Discipline? discipline,
  }) {
    return RaceConfig(
      name: name ?? this.name,
      duration: duration ?? this.duration,
      distanceKm: distanceKm ?? this.distanceKm,
      timelineMode: timelineMode ?? this.timelineMode,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      intervalKm: intervalKm ?? this.intervalKm,
      targetCarbsGPerHr: targetCarbsGPerHr ?? this.targetCarbsGPerHr,
      strategy: strategy ?? this.strategy,
      customCurve: customCurve ?? this.customCurve,
      selectedProducts: selectedProducts ?? this.selectedProducts,
      aidStations: aidStations ?? this.aidStations,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      altitudeM: altitudeM ?? this.altitudeM,
      discipline: discipline ?? this.discipline,
      schemaVersion: schemaVersion,
    );
  }

  @override
  List<Object?> get props => [
    name,
    duration,
    distanceKm,
    timelineMode,
    intervalMinutes,
    intervalKm,
    targetCarbsGPerHr,
    strategy,
    customCurve,
    selectedProducts,
    aidStations,
    temperature,
    humidity,
    altitudeM,
    discipline,
  ];
}
