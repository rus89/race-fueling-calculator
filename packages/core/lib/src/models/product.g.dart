// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Product _$ProductFromJson(Map<String, dynamic> json) => Product(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      type: $enumDecode(_$ProductTypeEnumMap, json['type']),
      carbsPerServing: (json['carbsPerServing'] as num).toDouble(),
      glucoseGrams: (json['glucoseGrams'] as num?)?.toDouble(),
      fructoseGrams: (json['fructoseGrams'] as num?)?.toDouble() ?? 0.0,
      caffeineMg: (json['caffeineMg'] as num?)?.toDouble() ?? 0.0,
      waterRequiredMl: (json['waterRequiredMl'] as num?)?.toDouble() ?? 0.0,
      servingDescription: json['servingDescription'] as String?,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      sipMinutes: (json['sipMinutes'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ProductToJson(Product instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'brand': instance.brand,
      'type': _$ProductTypeEnumMap[instance.type]!,
      'carbsPerServing': instance.carbsPerServing,
      'glucoseGrams': instance.glucoseGrams,
      'fructoseGrams': instance.fructoseGrams,
      'caffeineMg': instance.caffeineMg,
      'waterRequiredMl': instance.waterRequiredMl,
      'servingDescription': instance.servingDescription,
      'isBuiltIn': instance.isBuiltIn,
      'sipMinutes': instance.sipMinutes,
    };

const _$ProductTypeEnumMap = {
  ProductType.gel: 'gel',
  ProductType.liquid: 'liquid',
  ProductType.solid: 'solid',
  ProductType.chew: 'chew',
  ProductType.realFood: 'real_food',
};
