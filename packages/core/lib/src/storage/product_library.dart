// ABOUTME: Merges built-in and user-created product lists, with user entries taking precedence by ID.
// ABOUTME: Used at load time to build the unified product catalog available to the plan engine.
import '../models/product.dart';

List<Product> mergeProducts(List<Product> builtIn, List<Product> userProducts) {
  final userIds = {for (final p in userProducts) p.id};
  final merged = <Product>[
    // Built-ins not overridden by user
    ...builtIn.where((p) => !userIds.contains(p.id)),
    // All user products
    ...userProducts,
  ];
  return merged;
}
