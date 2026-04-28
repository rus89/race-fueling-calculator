// ABOUTME: Merges built-in and user-created product lists; user entries take
// ABOUTME: precedence by id so a user product with the same id shadows a built-in.
import '../models/product.dart';

List<Product> mergeProducts(
  List<Product> builtIn,
  List<Product> userProducts,
) {
  final shadowedIds = {for (final p in userProducts) p.id};
  return <Product>[
    ...builtIn.where((p) => !shadowedIds.contains(p.id)),
    ...userProducts,
  ];
}
