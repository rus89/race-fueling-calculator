// ABOUTME: Direct unit tests for resolveProduct (precedence rules) and
// ABOUTME: writeCandidates (ambiguity help formatting).
import 'package:race_fueling_cli/src/products/product_resolver.dart';
import 'package:race_fueling_core/core.dart';
import 'package:test/test.dart';

Product _p({
  required String id,
  required String name,
  ProductType type = ProductType.gel,
  double carbs = 25,
}) {
  return Product(
    id: id,
    name: name,
    type: type,
    carbsPerServing: carbs,
    glucoseGrams: carbs,
    fructoseGrams: 0,
  );
}

void main() {
  group('resolveProduct', () {
    final products = <Product>[
      _p(id: 'maurten-gel-100', name: 'Maurten Gel 100'),
      _p(id: 'maurten-gel-100-caf', name: 'Maurten Gel 100 CAF 100'),
      _p(id: 'sis-gel', name: 'SiS Beta Fuel Gel'),
      _p(
        id: 'clif-bar',
        name: 'Clif Bar',
        type: ProductType.solid,
      ),
    ];

    test('returns ProductMatchNone for an empty query', () {
      final match = resolveProduct(products, '');
      expect(match, isA<ProductMatchNone>());
    });

    test('returns ProductMatchSingle for an exact id match', () {
      final match = resolveProduct(products, 'maurten-gel-100');
      expect(match, isA<ProductMatchSingle>());
      expect(
        (match as ProductMatchSingle).product.id,
        'maurten-gel-100',
      );
    });

    test(
        'returns ProductMatchSingle for an exact name match (case-insensitive)',
        () {
      final match = resolveProduct(products, 'clif bar');
      expect(match, isA<ProductMatchSingle>());
      expect((match as ProductMatchSingle).product.name, 'Clif Bar');
    });

    test('returns ProductMatchSingle when substring uniquely matches one name',
        () {
      final match = resolveProduct(products, 'Beta');
      expect(match, isA<ProductMatchSingle>());
      expect(
        (match as ProductMatchSingle).product.name,
        'SiS Beta Fuel Gel',
      );
    });

    test(
        'returns ProductMatchMultiple listing all candidates on ambiguous '
        'substring', () {
      final match = resolveProduct(products, 'Gel');
      expect(match, isA<ProductMatchMultiple>());
      final candidates = (match as ProductMatchMultiple).candidates;
      expect(candidates, hasLength(3));
      expect(
        candidates.map((p) => p.name),
        containsAll([
          'Maurten Gel 100',
          'Maurten Gel 100 CAF 100',
          'SiS Beta Fuel Gel',
        ]),
      );
    });

    test('returns ProductMatchNone when nothing matches', () {
      final match = resolveProduct(products, 'nonexistent');
      expect(match, isA<ProductMatchNone>());
    });
  });

  group('writeCandidates', () {
    test('emits a header, name-first rows with ids, and the re-run hint', () {
      final buffer = StringBuffer();
      writeCandidates(buffer, [
        _p(id: 'a', name: 'Alpha'),
        _p(id: 'bb', name: 'BetaBravo'),
      ]);
      final out = buffer.toString();
      expect(out, contains('Did you mean one of:'));
      expect(out, contains('Alpha'));
      expect(out, contains('(id: a)'));
      expect(out, contains('BetaBravo'));
      expect(out, contains('(id: bb)'));
      expect(out, contains('Re-run with the exact name in quotes.'));
    });
  });
}
