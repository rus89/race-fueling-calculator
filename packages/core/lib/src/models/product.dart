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
  final int? sipMinutes;

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
    this.sipMinutes,
  }) : glucoseGrams = glucoseGrams ?? carbsPerServing {
    if (!carbsPerServing.isFinite || carbsPerServing <= 0) {
      throw ArgumentError.value(
        carbsPerServing,
        'carbsPerServing',
        'must be a finite positive number',
      );
    }
    if (sipMinutes != null && sipMinutes! <= 0) {
      throw ArgumentError.value(
        sipMinutes,
        'sipMinutes',
        'must be positive when provided',
      );
    }
  }

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);

  Map<String, dynamic> toJson() => _$ProductToJson(this);

  /// Returns a copy with the given fields replaced.
  ///
  /// `id` is intentionally mutable to support promoting a built-in to a
  /// user override, where the override keeps the built-in's id but sets
  /// `isBuiltIn: false`. Do NOT call copyWith(id:) on a product already
  /// referenced by a plan's ProductSelection — it will orphan the reference.
  Product copyWith({
    String? id,
    String? name,
    String? brand,
    ProductType? type,
    double? carbsPerServing,
    double? glucoseGrams,
    double? fructoseGrams,
    double? caffeineMg,
    double? waterRequiredMl,
    String? servingDescription,
    bool? isBuiltIn,
    int? sipMinutes,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      type: type ?? this.type,
      carbsPerServing: carbsPerServing ?? this.carbsPerServing,
      glucoseGrams: glucoseGrams ?? this.glucoseGrams,
      fructoseGrams: fructoseGrams ?? this.fructoseGrams,
      caffeineMg: caffeineMg ?? this.caffeineMg,
      waterRequiredMl: waterRequiredMl ?? this.waterRequiredMl,
      servingDescription: servingDescription ?? this.servingDescription,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      sipMinutes: sipMinutes ?? this.sipMinutes,
    );
  }

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
        sipMinutes,
      ];
}
