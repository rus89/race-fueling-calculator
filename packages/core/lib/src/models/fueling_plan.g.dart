// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fueling_plan.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductServing _$ProductServingFromJson(Map<String, dynamic> json) =>
    ProductServing(
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      servings: (json['servings'] as num).toInt(),
    );

Map<String, dynamic> _$ProductServingToJson(ProductServing instance) =>
    <String, dynamic>{
      'productId': instance.productId,
      'productName': instance.productName,
      'servings': instance.servings,
    };

PlanEntry _$PlanEntryFromJson(Map<String, dynamic> json) => PlanEntry(
  timeMark: durationFromJson((json['timeMark'] as num).toInt()),
  distanceMark: (json['distanceMark'] as num?)?.toDouble(),
  products: (json['products'] as List<dynamic>)
      .map((e) => ProductServing.fromJson(e as Map<String, dynamic>))
      .toList(),
  carbsGlucose: (json['carbsGlucose'] as num).toDouble(),
  carbsFructose: (json['carbsFructose'] as num).toDouble(),
  carbsTotal: (json['carbsTotal'] as num).toDouble(),
  cumulativeCarbs: (json['cumulativeCarbs'] as num).toDouble(),
  cumulativeCaffeine: (json['cumulativeCaffeine'] as num).toDouble(),
  waterMl: (json['waterMl'] as num).toDouble(),
  warnings:
      (json['warnings'] as List<dynamic>?)
          ?.map((e) => Warning.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  effectiveDrinkCarbs: (json['effectiveDrinkCarbs'] as num?)?.toDouble() ?? 0.0,
  aidStation: json['aidStation'] == null
      ? null
      : AidStation.fromJson(json['aidStation'] as Map<String, dynamic>),
);

Map<String, dynamic> _$PlanEntryToJson(PlanEntry instance) => <String, dynamic>{
  'timeMark': durationToJson(instance.timeMark),
  'distanceMark': instance.distanceMark,
  'products': instance.products.map((e) => e.toJson()).toList(),
  'carbsGlucose': instance.carbsGlucose,
  'carbsFructose': instance.carbsFructose,
  'carbsTotal': instance.carbsTotal,
  'cumulativeCarbs': instance.cumulativeCarbs,
  'cumulativeCaffeine': instance.cumulativeCaffeine,
  'waterMl': instance.waterMl,
  'warnings': instance.warnings.map((e) => e.toJson()).toList(),
  'effectiveDrinkCarbs': instance.effectiveDrinkCarbs,
  'aidStation': ?instance.aidStation?.toJson(),
};

PlanSummary _$PlanSummaryFromJson(Map<String, dynamic> json) => PlanSummary(
  totalCarbs: (json['totalCarbs'] as num).toDouble(),
  averageGPerHr: (json['averageGPerHr'] as num).toDouble(),
  totalCaffeineMg: (json['totalCaffeineMg'] as num).toDouble(),
  glucoseFructoseRatio: (json['glucoseFructoseRatio'] as num).toDouble(),
  totalWaterMl: (json['totalWaterMl'] as num).toDouble(),
  totalGlucose: (json['totalGlucose'] as num?)?.toDouble() ?? 0.0,
  totalFructose: (json['totalFructose'] as num?)?.toDouble() ?? 0.0,
  environmentalNotes:
      (json['environmentalNotes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$PlanSummaryToJson(PlanSummary instance) =>
    <String, dynamic>{
      'totalCarbs': instance.totalCarbs,
      'averageGPerHr': instance.averageGPerHr,
      'totalCaffeineMg': instance.totalCaffeineMg,
      'glucoseFructoseRatio': instance.glucoseFructoseRatio,
      'totalGlucose': instance.totalGlucose,
      'totalFructose': instance.totalFructose,
      'totalWaterMl': instance.totalWaterMl,
      'environmentalNotes': instance.environmentalNotes,
    };

FuelingPlan _$FuelingPlanFromJson(Map<String, dynamic> json) => FuelingPlan(
  raceConfig: RaceConfig.fromJson(json['raceConfig'] as Map<String, dynamic>),
  entries: (json['entries'] as List<dynamic>)
      .map((e) => PlanEntry.fromJson(e as Map<String, dynamic>))
      .toList(),
  summary: PlanSummary.fromJson(json['summary'] as Map<String, dynamic>),
  warnings:
      (json['warnings'] as List<dynamic>?)
          ?.map((e) => Warning.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$FuelingPlanToJson(FuelingPlan instance) =>
    <String, dynamic>{
      'raceConfig': instance.raceConfig.toJson(),
      'entries': instance.entries.map((e) => e.toJson()).toList(),
      'summary': instance.summary.toJson(),
      'warnings': instance.warnings.map((e) => e.toJson()).toList(),
    };
