// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'warning.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Warning _$WarningFromJson(Map<String, dynamic> json) => Warning(
      severity: $enumDecode(_$SeverityEnumMap, json['severity']),
      message: json['message'] as String,
      entryIndex: (json['entryIndex'] as num?)?.toInt(),
    );

Map<String, dynamic> _$WarningToJson(Warning instance) => <String, dynamic>{
      'severity': _$SeverityEnumMap[instance.severity]!,
      'message': instance.message,
      'entryIndex': instance.entryIndex,
    };

const _$SeverityEnumMap = {
  Severity.critical: 'critical',
  Severity.advisory: 'advisory',
};
