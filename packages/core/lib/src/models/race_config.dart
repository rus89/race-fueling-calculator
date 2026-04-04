// ABOUTME: Defines RaceConfig and supporting types for race plan configuration.
// ABOUTME: Includes strategy, timeline mode, product selections, and environmental conditions.
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

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

@JsonSerializable()
class ProductSelection extends Equatable {
  final String productId;
  final int quantity;
  final bool isAidStationOnly;

  const ProductSelection({
    required this.productId,
    required this.quantity,
    this.isAidStationOnly = false,
  });

  factory ProductSelection.fromJson(Map<String, dynamic> json) =>
      _$ProductSelectionFromJson(json);

  Map<String, dynamic> toJson() => _$ProductSelectionToJson(this);

  @override
  List<Object?> get props => [productId, quantity, isAidStationOnly];
}

@JsonSerializable()
class AidStation extends Equatable {
  final double? distanceKm;
  final int? timeMinutes;

  const AidStation({this.distanceKm, this.timeMinutes});

  factory AidStation.fromJson(Map<String, dynamic> json) =>
      _$AidStationFromJson(json);

  Map<String, dynamic> toJson() => _$AidStationToJson(this);

  @override
  List<Object?> get props => [distanceKm, timeMinutes];
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
  @JsonKey(fromJson: _durationFromJson, toJson: _durationToJson)
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
    this.schemaVersion = 1,
  });

  factory RaceConfig.fromJson(Map<String, dynamic> json) =>
      _$RaceConfigFromJson(json);

  Map<String, dynamic> toJson() => _$RaceConfigToJson(this);

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
      ];
}

Duration _durationFromJson(int minutes) => Duration(minutes: minutes);
int _durationToJson(Duration duration) => duration.inMinutes;
