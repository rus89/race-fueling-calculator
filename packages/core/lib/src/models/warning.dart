// ABOUTME: Defines warning severity levels and the Warning model.
// ABOUTME: Used by the plan engine to flag nutrition issues to the user.
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'warning.g.dart';

enum Severity {
  @JsonValue('critical')
  critical,
  @JsonValue('advisory')
  advisory,
}

@JsonSerializable()
class Warning extends Equatable {
  final Severity severity;
  final String message;
  final int? entryIndex;

  const Warning({
    required this.severity,
    required this.message,
    this.entryIndex,
  });

  factory Warning.fromJson(Map<String, dynamic> json) =>
      _$WarningFromJson(json);

  Map<String, dynamic> toJson() => _$WarningToJson(this);

  @override
  List<Object?> get props => [severity, message, entryIndex];
}
