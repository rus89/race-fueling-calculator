// ABOUTME: Tests for the Product model including glucose default logic and serialization.
// ABOUTME: Covers required fields, optional defaults, and JSON round-trips.
import 'package:test/test.dart';
import 'package:race_fueling_core/src/models/product.dart';

void main() {
  group('Product', () {
    test('creates with required fields only, defaults applied', () {
      final product = Product(
        id: 'gel-1',
        name: 'Basic Gel',
        type: ProductType.gel,
        carbsPerServing: 25.0,
      );
      expect(product.glucoseGrams, 25.0); // defaults to carbsPerServing
      expect(product.fructoseGrams, 0.0);
      expect(product.caffeineMg, 0.0);
      expect(product.waterRequiredMl, 0.0);
      expect(product.brand, isNull);
      expect(product.servingDescription, isNull);
      expect(product.isBuiltIn, false);
    });

    test('creates with all fields', () {
      final product = Product(
        id: 'maurten-320',
        name: 'Maurten 320',
        brand: 'Maurten',
        type: ProductType.liquid,
        carbsPerServing: 80.0,
        glucoseGrams: 44.0,
        fructoseGrams: 36.0,
        caffeineMg: 0.0,
        waterRequiredMl: 500.0,
        servingDescription: '500ml bottle',
        isBuiltIn: true,
      );
      expect(product.brand, 'Maurten');
      expect(product.glucoseGrams, 44.0);
      expect(product.fructoseGrams, 36.0);
    });

    test('supports value equality', () {
      final a = Product(
          id: 'x', name: 'X', type: ProductType.gel, carbsPerServing: 25);
      final b = Product(
          id: 'x', name: 'X', type: ProductType.gel, carbsPerServing: 25);
      expect(a, equals(b));
    });

    test('JSON round-trip', () {
      final product = Product(
        id: 'test',
        name: 'Test Gel',
        brand: 'TestBrand',
        type: ProductType.gel,
        carbsPerServing: 30.0,
        glucoseGrams: 20.0,
        fructoseGrams: 10.0,
        caffeineMg: 40.0,
        waterRequiredMl: 150.0,
        servingDescription: '1 gel',
        isBuiltIn: true,
      );
      final json = product.toJson();
      final restored = Product.fromJson(json);
      expect(restored, equals(product));
    });
  });

  group('ProductType', () {
    test('has all expected values', () {
      expect(
          ProductType.values,
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
