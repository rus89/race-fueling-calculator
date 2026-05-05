// ABOUTME: Defines the FuelingPlan output model with timeline entries and aggregate stats.
// ABOUTME: Produced by the plan engine and rendered by the CLI formatter.
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'duration_converter.dart';
import 'race_config.dart';
import 'warning.dart';

part 'fueling_plan.g.dart';

@JsonSerializable()
class ProductServing extends Equatable {
  final String productId;
  final String productName;
  final int servings;

  /// Marks the synthetic entry the allocator emits when a sip-bottle drink
  /// starts. UIs use this to render a "drink start" affordance without
  /// string-matching the product name.
  @JsonKey(defaultValue: false)
  final bool isDrinkStart;

  const ProductServing({
    required this.productId,
    required this.productName,
    required this.servings,
    this.isDrinkStart = false,
  });

  factory ProductServing.fromJson(Map<String, dynamic> json) =>
      _$ProductServingFromJson(json);

  Map<String, dynamic> toJson() => _$ProductServingToJson(this);

  ProductServing copyWith({
    String? productId,
    String? productName,
    int? servings,
    bool? isDrinkStart,
  }) => ProductServing(
    productId: productId ?? this.productId,
    productName: productName ?? this.productName,
    servings: servings ?? this.servings,
    isDrinkStart: isDrinkStart ?? this.isDrinkStart,
  );

  @override
  List<Object?> get props => [productId, productName, servings, isDrinkStart];
}

@JsonSerializable(explicitToJson: true)
class PlanEntry extends Equatable {
  @JsonKey(fromJson: durationFromJson, toJson: durationToJson)
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
  @JsonKey(defaultValue: 0.0)
  final double effectiveDrinkCarbs;
  @JsonKey(includeIfNull: false)
  final AidStation? aidStation;

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
    this.effectiveDrinkCarbs = 0.0,
    this.aidStation,
  });

  factory PlanEntry.fromJson(Map<String, dynamic> json) =>
      _$PlanEntryFromJson(json);

  Map<String, dynamic> toJson() => _$PlanEntryToJson(this);

  /// Returns a copy with the given fields replaced. Passing `null` for a
  /// nullable field (e.g., `distanceMark`, `aidStation`) preserves the
  /// existing value — there is no way to clear a nullable field via this
  /// method.
  PlanEntry copyWith({
    Duration? timeMark,
    double? distanceMark,
    List<ProductServing>? products,
    double? carbsGlucose,
    double? carbsFructose,
    double? carbsTotal,
    double? cumulativeCarbs,
    double? cumulativeCaffeine,
    double? waterMl,
    List<Warning>? warnings,
    double? effectiveDrinkCarbs,
    AidStation? aidStation,
  }) => PlanEntry(
    timeMark: timeMark ?? this.timeMark,
    distanceMark: distanceMark ?? this.distanceMark,
    products: products ?? this.products,
    carbsGlucose: carbsGlucose ?? this.carbsGlucose,
    carbsFructose: carbsFructose ?? this.carbsFructose,
    carbsTotal: carbsTotal ?? this.carbsTotal,
    cumulativeCarbs: cumulativeCarbs ?? this.cumulativeCarbs,
    cumulativeCaffeine: cumulativeCaffeine ?? this.cumulativeCaffeine,
    waterMl: waterMl ?? this.waterMl,
    warnings: warnings ?? this.warnings,
    effectiveDrinkCarbs: effectiveDrinkCarbs ?? this.effectiveDrinkCarbs,
    aidStation: aidStation ?? this.aidStation,
  );

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
    effectiveDrinkCarbs,
    aidStation,
  ];
}

@JsonSerializable()
class PlanSummary extends Equatable {
  final double totalCarbs;
  final double averageGPerHr;
  final double totalCaffeineMg;
  final double glucoseFructoseRatio;
  @JsonKey(defaultValue: 0.0)
  final double totalGlucose;
  @JsonKey(defaultValue: 0.0)
  final double totalFructose;
  final double totalWaterMl;
  final List<String> environmentalNotes;

  const PlanSummary({
    required this.totalCarbs,
    required this.averageGPerHr,
    required this.totalCaffeineMg,
    required this.glucoseFructoseRatio,
    required this.totalWaterMl,
    this.totalGlucose = 0.0,
    this.totalFructose = 0.0,
    this.environmentalNotes = const [],
  });

  /// glucose / fructose. Inverse of [glucoseFructoseRatio]. Returns 0.0 when
  /// fructose is 0 to keep the math safe and let UIs render an em-dash.
  double get glucoseToFructoseRatio =>
      totalFructose <= 0 ? 0.0 : totalGlucose / totalFructose;

  factory PlanSummary.fromJson(Map<String, dynamic> json) =>
      _$PlanSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$PlanSummaryToJson(this);

  @override
  List<Object?> get props => [
    totalCarbs,
    averageGPerHr,
    totalCaffeineMg,
    glucoseFructoseRatio,
    totalGlucose,
    totalFructose,
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
