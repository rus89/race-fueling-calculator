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

    test('copyWith with no args returns an equal instance', () {
      final product = Product(
        id: 'gel-1',
        name: 'Gel',
        type: ProductType.gel,
        carbsPerServing: 25.0,
      );
      expect(product.copyWith(), equals(product));
    });

    test('copyWith updates a single field', () {
      final product = Product(
        id: 'gel-1',
        name: 'Gel',
        type: ProductType.gel,
        carbsPerServing: 25.0,
        caffeineMg: 40.0,
      );
      final updated = product.copyWith(caffeineMg: 80.0);
      expect(updated.caffeineMg, 80.0);
      expect(updated.id, 'gel-1');
      expect(updated.carbsPerServing, 25.0);
    });

    test('copyWith preserves isBuiltIn flag', () {
      final builtIn = Product(
        id: 'gel-1',
        name: 'Gel',
        type: ProductType.gel,
        carbsPerServing: 25.0,
        isBuiltIn: true,
      );
      final updated = builtIn.copyWith(name: 'Renamed Gel');
      expect(updated.isBuiltIn, true);
    });

    test('copyWith can promote a built-in to a user override', () {
      final builtIn = Product(
        id: 'gel-1',
        name: 'Gel',
        type: ProductType.gel,
        carbsPerServing: 25.0,
        isBuiltIn: true,
      );
      final override = builtIn.copyWith(
        id: 'user-gel-1',
        isBuiltIn: false,
        carbsPerServing: 30.0,
      );
      expect(override.id, 'user-gel-1');
      expect(override.isBuiltIn, false);
      expect(override.carbsPerServing, 30.0);
    });

    // The standard `?? this.field` pattern means passing null explicitly is
    // indistinguishable from omitting the argument.
    test('copyWith preserves brand when null is passed explicitly', () {
      final product = Product(
        id: 'gel-1',
        name: 'Gel',
        brand: 'Acme',
        type: ProductType.gel,
        carbsPerServing: 25.0,
      );
      expect(product.copyWith(brand: null).brand, 'Acme');
    });

    test('copyWith preserves servingDescription when null is passed explicitly',
        () {
      final product = Product(
        id: 'gel-1',
        name: 'Gel',
        type: ProductType.gel,
        carbsPerServing: 25.0,
        servingDescription: '1 gel',
      );
      expect(product.copyWith(servingDescription: null).servingDescription,
          '1 gel');
    });

    test('copyWith updates brand', () {
      final product = Product(
        id: 'gel-1',
        name: 'Gel',
        type: ProductType.gel,
        carbsPerServing: 25.0,
      );
      expect(product.copyWith(brand: 'Brand').brand, 'Brand');
    });

    test('copyWith updates type', () {
      final product = Product(
        id: 'gel-1',
        name: 'Gel',
        type: ProductType.gel,
        carbsPerServing: 25.0,
      );
      expect(
          product.copyWith(type: ProductType.liquid).type, ProductType.liquid);
    });

    test('copyWith updates glucoseGrams', () {
      final product = Product(
        id: 'gel-1',
        name: 'Gel',
        type: ProductType.gel,
        carbsPerServing: 25.0,
      );
      expect(product.copyWith(glucoseGrams: 20.0).glucoseGrams, 20.0);
    });

    test('copyWith updates fructoseGrams', () {
      final product = Product(
        id: 'gel-1',
        name: 'Gel',
        type: ProductType.gel,
        carbsPerServing: 25.0,
      );
      expect(product.copyWith(fructoseGrams: 10.0).fructoseGrams, 10.0);
    });

    test('copyWith updates waterRequiredMl', () {
      final product = Product(
        id: 'gel-1',
        name: 'Gel',
        type: ProductType.gel,
        carbsPerServing: 25.0,
      );
      expect(product.copyWith(waterRequiredMl: 200.0).waterRequiredMl, 200.0);
    });

    test('copyWith updates servingDescription', () {
      final product = Product(
        id: 'gel-1',
        name: 'Gel',
        type: ProductType.gel,
        carbsPerServing: 25.0,
      );
      expect(product.copyWith(servingDescription: 'bottle').servingDescription,
          'bottle');
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

  group('Product carbsPerServing validation', () {
    Product build({required double carbsPerServing}) => Product(
          id: 'p',
          name: 'P',
          type: ProductType.gel,
          carbsPerServing: carbsPerServing,
        );

    test('constructor rejects zero carbsPerServing', () {
      expect(() => build(carbsPerServing: 0), throwsArgumentError);
    });

    test('constructor rejects negative carbsPerServing', () {
      expect(() => build(carbsPerServing: -1), throwsArgumentError);
    });

    test('constructor rejects NaN carbsPerServing', () {
      expect(() => build(carbsPerServing: double.nan), throwsArgumentError);
    });

    test('constructor rejects infinite carbsPerServing', () {
      expect(
          () => build(carbsPerServing: double.infinity), throwsArgumentError);
    });

    test('fromJson rejects zero carbsPerServing', () {
      final json = {
        'id': 'p',
        'name': 'P',
        'type': 'gel',
        'carbsPerServing': 0,
      };
      expect(() => Product.fromJson(json), throwsArgumentError);
    });

    test('fromJson rejects negative carbsPerServing', () {
      final json = {
        'id': 'p',
        'name': 'P',
        'type': 'gel',
        'carbsPerServing': -25.0,
      };
      expect(() => Product.fromJson(json), throwsArgumentError);
    });
  });
}
