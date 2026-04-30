// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'race_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductSelection _$ProductSelectionFromJson(Map<String, dynamic> json) =>
    ProductSelection(
      productId: json['productId'] as String,
      quantity: (json['quantity'] as num).toInt(),
      isAidStationOnly: json['isAidStationOnly'] as bool? ?? false,
    );

Map<String, dynamic> _$ProductSelectionToJson(ProductSelection instance) =>
    <String, dynamic>{
      'productId': instance.productId,
      'quantity': instance.quantity,
      'isAidStationOnly': instance.isAidStationOnly,
    };

AidStation _$AidStationFromJson(Map<String, dynamic> json) => AidStation(
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      timeMinutes: (json['timeMinutes'] as num?)?.toInt(),
    );

Map<String, dynamic> _$AidStationToJson(AidStation instance) =>
    <String, dynamic>{
      'distanceKm': instance.distanceKm,
      'timeMinutes': instance.timeMinutes,
    };

CurveSegment _$CurveSegmentFromJson(Map<String, dynamic> json) => CurveSegment(
      durationMinutes: (json['durationMinutes'] as num).toInt(),
      targetGPerHr: (json['targetGPerHr'] as num).toDouble(),
    );

Map<String, dynamic> _$CurveSegmentToJson(CurveSegment instance) =>
    <String, dynamic>{
      'durationMinutes': instance.durationMinutes,
      'targetGPerHr': instance.targetGPerHr,
    };

RaceConfig _$RaceConfigFromJson(Map<String, dynamic> json) => RaceConfig(
      name: json['name'] as String,
      duration: durationFromJson((json['duration'] as num).toInt()),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      timelineMode: $enumDecode(_$TimelineModeEnumMap, json['timelineMode']),
      intervalMinutes: (json['intervalMinutes'] as num?)?.toInt(),
      intervalKm: (json['intervalKm'] as num?)?.toDouble(),
      targetCarbsGPerHr: (json['targetCarbsGPerHr'] as num).toDouble(),
      strategy: $enumDecode(_$StrategyEnumMap, json['strategy']),
      customCurve: (json['customCurve'] as List<dynamic>?)
          ?.map((e) => CurveSegment.fromJson(e as Map<String, dynamic>))
          .toList(),
      selectedProducts: (json['selectedProducts'] as List<dynamic>)
          .map((e) => ProductSelection.fromJson(e as Map<String, dynamic>))
          .toList(),
      aidStations: (json['aidStations'] as List<dynamic>?)
              ?.map((e) => AidStation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      temperature: (json['temperature'] as num?)?.toDouble(),
      humidity: (json['humidity'] as num?)?.toDouble(),
      altitudeM: (json['altitudeM'] as num?)?.toDouble(),
      discipline: $enumDecodeNullable(_$DisciplineEnumMap, json['discipline']),
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
    );

Map<String, dynamic> _$RaceConfigToJson(RaceConfig instance) =>
    <String, dynamic>{
      'name': instance.name,
      'duration': durationToJson(instance.duration),
      'distanceKm': instance.distanceKm,
      'timelineMode': _$TimelineModeEnumMap[instance.timelineMode]!,
      'intervalMinutes': instance.intervalMinutes,
      'intervalKm': instance.intervalKm,
      'targetCarbsGPerHr': instance.targetCarbsGPerHr,
      'strategy': _$StrategyEnumMap[instance.strategy]!,
      'customCurve': instance.customCurve?.map((e) => e.toJson()).toList(),
      'selectedProducts':
          instance.selectedProducts.map((e) => e.toJson()).toList(),
      'aidStations': instance.aidStations.map((e) => e.toJson()).toList(),
      'temperature': instance.temperature,
      'humidity': instance.humidity,
      'altitudeM': instance.altitudeM,
      'discipline': _$DisciplineEnumMap[instance.discipline],
      'schema_version': instance.schemaVersion,
    };

const _$TimelineModeEnumMap = {
  TimelineMode.timeBased: 'time_based',
  TimelineMode.distanceBased: 'distance_based',
};

const _$StrategyEnumMap = {
  Strategy.steady: 'steady',
  Strategy.frontLoad: 'front_load',
  Strategy.backLoad: 'back_load',
  Strategy.custom: 'custom',
};

const _$DisciplineEnumMap = {
  Discipline.xcm: 'xcm',
  Discipline.road: 'road',
  Discipline.run: 'run',
  Discipline.tri: 'tri',
  Discipline.ultra: 'ultra',
};
