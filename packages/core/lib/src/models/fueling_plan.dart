// ABOUTME: Defines the FuelingPlan output model with timeline entries and aggregate stats.
// ABOUTME: Produced by the plan engine and rendered by the CLI formatter.
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'race_config.dart';
import 'warning.dart';

part 'fueling_plan.g.dart';

@JsonSerializable()
class ProductServing extends Equatable {
  final String productId;
  final String productName;
  final int servings;

  const ProductServing({
    required this.productId,
    required this.productName,
    required this.servings,
  });

  factory ProductServing.fromJson(Map<String, dynamic> json) =>
      _$ProductServingFromJson(json);

  Map<String, dynamic> toJson() => _$ProductServingToJson(this);

  @override
  List<Object?> get props => [productId, productName, servings];
}

@JsonSerializable(explicitToJson: true)
class PlanEntry extends Equatable {
  @JsonKey(fromJson: _durationFromJson, toJson: _durationToJson)
  final Duration timeMark;
  final double? distanceMark;
  final List<ProductServing> products;
  final double carbsGlucose;
  final double carbsFructose;
  final double carbsTotal;
  final double cumulativeCarbs;
  final double cumulativeCaffeine;
  final double waterMl;
  final List<Warning> warnings;

  const PlanEntry({
    required this.timeMark,
    this.distanceMark,
    required this.products,
    required this.carbsGlucose,
    required this.carbsFructose,
    required this.carbsTotal,
    required this.cumulativeCarbs,
    required this.cumulativeCaffeine,
    required this.waterMl,
    this.warnings = const [],
  });

  factory PlanEntry.fromJson(Map<String, dynamic> json) =>
      _$PlanEntryFromJson(json);

  Map<String, dynamic> toJson() => _$PlanEntryToJson(this);

  @override
  List<Object?> get props => [
        timeMark,
        distanceMark,
        products,
        carbsGlucose,
        carbsFructose,
        carbsTotal,
        cumulativeCarbs,
        cumulativeCaffeine,
        waterMl,
        warnings,
      ];
}

@JsonSerializable()
class PlanSummary extends Equatable {
  final double totalCarbs;
  final double averageGPerHr;
  final double totalCaffeineMg;
  final double glucoseFructoseRatio;
  final double totalWaterMl;
  final List<String> environmentalNotes;

  const PlanSummary({
    required this.totalCarbs,
    required this.averageGPerHr,
    required this.totalCaffeineMg,
    required this.glucoseFructoseRatio,
    required this.totalWaterMl,
    this.environmentalNotes = const [],
  });

  factory PlanSummary.fromJson(Map<String, dynamic> json) =>
      _$PlanSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$PlanSummaryToJson(this);

  @override
  List<Object?> get props => [
        totalCarbs,
        averageGPerHr,
        totalCaffeineMg,
        glucoseFructoseRatio,
        totalWaterMl,
        environmentalNotes,
      ];
}

@JsonSerializable(explicitToJson: true)
class FuelingPlan extends Equatable {
  final RaceConfig raceConfig;
  final List<PlanEntry> entries;
  final PlanSummary summary;
  final List<Warning> warnings;

  const FuelingPlan({
    required this.raceConfig,
    required this.entries,
    required this.summary,
    this.warnings = const [],
  });

  factory FuelingPlan.fromJson(Map<String, dynamic> json) =>
      _$FuelingPlanFromJson(json);

  Map<String, dynamic> toJson() => _$FuelingPlanToJson(this);

  @override
  List<Object?> get props => [raceConfig, entries, summary, warnings];
}

Duration _durationFromJson(int minutes) => Duration(minutes: minutes);
int _durationToJson(Duration duration) => duration.inMinutes;
