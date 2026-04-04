// ABOUTME: Defines the Product model with nutritional data for race fueling products.
// ABOUTME: Supports built-in defaults and user-created products with minimal required data.
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'product.g.dart';

@JsonEnum(fieldRename: FieldRename.snake)
enum ProductType {
  gel,
  liquid,
  solid,
  chew,
  @JsonValue('real_food')
  realFood,
}

@JsonSerializable()
class Product extends Equatable {
  final String id;
  final String name;
  final String? brand;
  final ProductType type;
  final double carbsPerServing;
  final double glucoseGrams;
  final double fructoseGrams;
  final double caffeineMg;
  final double waterRequiredMl;
  final String? servingDescription;
  final bool isBuiltIn;

  Product({
    required this.id,
    required this.name,
    this.brand,
    required this.type,
    required this.carbsPerServing,
    double? glucoseGrams,
    this.fructoseGrams = 0.0,
    this.caffeineMg = 0.0,
    this.waterRequiredMl = 0.0,
    this.servingDescription,
    this.isBuiltIn = false,
  }) : glucoseGrams = glucoseGrams ?? carbsPerServing;

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);

  Map<String, dynamic> toJson() => _$ProductToJson(this);

  @override
  List<Object?> get props => [
        id,
        name,
        brand,
        type,
        carbsPerServing,
        glucoseGrams,
        fructoseGrams,
        caffeineMg,
        waterRequiredMl,
        servingDescription,
        isBuiltIn,
      ];
}
