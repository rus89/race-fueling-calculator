// ABOUTME: Tests for built-in and user product merging logic.
// ABOUTME: Verifies that user entries override built-ins by ID and that both lists combine correctly.
import 'package:test/test.dart';
import 'package:race_fueling_core/src/storage/product_library.dart';
import 'package:race_fueling_core/src/models/product.dart';

void main() {
  final builtIn = [
    Product(
        id: 'gel-1',
        name: 'Built-in Gel',
        type: ProductType.gel,
        carbsPerServing: 25,
        isBuiltIn: true),
    Product(
        id: 'drink-1',
        name: 'Built-in Drink',
        type: ProductType.liquid,
        carbsPerServing: 40,
        isBuiltIn: true),
  ];

  group('mergeProducts', () {
    test('empty user list returns all built-ins', () {
      final merged = mergeProducts(builtIn, []);
      expect(merged.length, 2);
      expect(merged.every((p) => p.isBuiltIn), true);
    });

    test('user product with same id replaces built-in', () {
      final userProducts = [
        Product(
            id: 'gel-1',
            name: 'My Custom Gel',
            type: ProductType.gel,
            carbsPerServing: 30),
      ];
      final merged = mergeProducts(builtIn, userProducts);
      expect(merged.length, 2);
      final gel = merged.firstWhere((p) => p.id == 'gel-1');
      expect(gel.name, 'My Custom Gel');
      expect(gel.carbsPerServing, 30);
    });

    test('user product with new id is added', () {
      final userProducts = [
        Product(
            id: 'custom-1',
            name: 'My Bar',
            type: ProductType.solid,
            carbsPerServing: 35),
      ];
      final merged = mergeProducts(builtIn, userProducts);
      expect(merged.length, 3);
    });

    test('user-prefixed id does NOT shadow a built-in with the bare id', () {
      // Naming convention is a CLI concern. mergeProducts must only shadow
      // built-ins when a user product reuses the built-in's exact id.
      final userProducts = [
        Product(
            id: 'user-gel-1',
            name: 'Unrelated user product',
            type: ProductType.gel,
            carbsPerServing: 30),
      ];
      final merged = mergeProducts(builtIn, userProducts);
      expect(merged.length, 3);
      expect(merged.any((p) => p.id == 'gel-1'), isTrue);
      expect(merged.any((p) => p.id == 'user-gel-1'), isTrue);
    });
  });
}
