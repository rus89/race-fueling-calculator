// ABOUTME: Verifies the built-in product catalog has correct structure and no data errors.
// ABOUTME: Checks required fields, ID uniqueness, and carb value sanity for all products.
import 'package:test/test.dart';
import 'package:race_fueling_core/src/data/built_in_products.dart';
import 'package:race_fueling_core/src/models/product.dart';

void main() {
  group('builtInProducts', () {
    test('contains at least 20 products', () {
      expect(builtInProducts.length, greaterThanOrEqualTo(20));
    });

    test('all products have valid data', () {
      for (final p in builtInProducts) {
        expect(p.carbsPerServing, greaterThan(0), reason: '${p.name} carbs');
        expect(p.glucoseGrams + p.fructoseGrams,
            lessThanOrEqualTo(p.carbsPerServing + 0.1),
            reason: '${p.name} glucose+fructose <= total');
        expect(p.caffeineMg, greaterThanOrEqualTo(0),
            reason: '${p.name} caffeine');
        expect(p.isBuiltIn, true, reason: '${p.name} isBuiltIn');
        expect(p.id, isNotEmpty, reason: '${p.name} id');
      }
    });

    test('all product IDs are unique', () {
      final ids = builtInProducts.map((p) => p.id).toSet();
      expect(ids.length, builtInProducts.length);
    });

    test('covers all product types', () {
      final types = builtInProducts.map((p) => p.type).toSet();
      expect(
          types,
          containsAll([
            ProductType.gel,
            ProductType.liquid,
            ProductType.solid,
            ProductType.chew,
            ProductType.realFood,
          ]));
    });
  });
}
