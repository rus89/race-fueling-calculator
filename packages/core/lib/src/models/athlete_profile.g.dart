// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'athlete_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AthleteProfile _$AthleteProfileFromJson(Map<String, dynamic> json) =>
    AthleteProfile(
      gutToleranceGPerHr: (json['gutToleranceGPerHr'] as num).toDouble(),
      unitSystem: $enumDecode(_$UnitSystemEnumMap, json['unitSystem']),
      bodyWeightKg: (json['bodyWeightKg'] as num?)?.toDouble(),
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
    );

Map<String, dynamic> _$AthleteProfileToJson(AthleteProfile instance) =>
    <String, dynamic>{
      'gutToleranceGPerHr': instance.gutToleranceGPerHr,
      'unitSystem': _$UnitSystemEnumMap[instance.unitSystem]!,
      'bodyWeightKg': instance.bodyWeightKg,
      'schema_version': instance.schemaVersion,
    };

const _$UnitSystemEnumMap = {
  UnitSystem.metric: 'metric',
  UnitSystem.imperial: 'imperial',
};
