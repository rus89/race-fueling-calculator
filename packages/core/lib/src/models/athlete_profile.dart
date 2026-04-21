// ABOUTME: Defines the AthleteProfile model with gut tolerance and unit preferences.
// ABOUTME: Used by the plan engine to validate carb intake against trained capacity.
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'athlete_profile.g.dart';

enum UnitSystem {
  @JsonValue('metric')
  metric,
  @JsonValue('imperial')
  imperial,
}

@JsonSerializable()
class AthleteProfile extends Equatable {
  final double gutToleranceGPerHr;
  final UnitSystem unitSystem;
  final double? bodyWeightKg;
  @JsonKey(name: 'schema_version', defaultValue: 1)
  final int schemaVersion;

  const AthleteProfile({
    required this.gutToleranceGPerHr,
    required this.unitSystem,
    this.bodyWeightKg,
    this.schemaVersion = 1,
  })  : assert(gutToleranceGPerHr > 0 && gutToleranceGPerHr <= 200,
            'gutToleranceGPerHr must be in (0, 200]'),
        assert(bodyWeightKg == null || bodyWeightKg > 0,
            'bodyWeightKg must be positive when provided');

  factory AthleteProfile.fromJson(Map<String, dynamic> json) {
    final gut = (json['gutToleranceGPerHr'] as num?)?.toDouble();
    if (gut == null || gut <= 0 || gut > 200) {
      throw FormatException(
        'gutToleranceGPerHr must be in (0, 200] g/hr, got $gut',
      );
    }
    final weightJson = json['bodyWeightKg'];
    if (weightJson != null) {
      final weight = (weightJson as num).toDouble();
      if (weight <= 0) {
        throw FormatException(
          'bodyWeightKg must be positive when provided, got $weight',
        );
      }
    }
    return _$AthleteProfileFromJson(json);
  }

  Map<String, dynamic> toJson() => _$AthleteProfileToJson(this);

  AthleteProfile copyWith({
    double? gutToleranceGPerHr,
    UnitSystem? unitSystem,
    double? bodyWeightKg,
  }) {
    return AthleteProfile(
      gutToleranceGPerHr: gutToleranceGPerHr ?? this.gutToleranceGPerHr,
      unitSystem: unitSystem ?? this.unitSystem,
      bodyWeightKg: bodyWeightKg ?? this.bodyWeightKg,
      schemaVersion: schemaVersion,
    );
  }

  @override
  List<Object?> get props => [gutToleranceGPerHr, unitSystem, bodyWeightKg];
}
