// ABOUTME: Merges built-in and user-created product lists; user entries take
// ABOUTME: precedence by id, including the 'user-<base-id>' override prefix.
import '../models/product.dart';

/// Built-ins may be shadowed either by a user product that reuses the
/// built-in's id directly, or by one whose id is `user-<built-in-id>`.
/// The prefix form exists so the CLI can create a copy-on-write override of
/// a built-in without mutating the original entry.
const String _userOverridePrefix = 'user-';

List<Product> mergeProducts(
  List<Product> builtIn,
  List<Product> userProducts,
) {
  final shadowedIds = <String>{};
  for (final p in userProducts) {
    shadowedIds.add(p.id);
    if (p.id.startsWith(_userOverridePrefix)) {
      shadowedIds.add(p.id.substring(_userOverridePrefix.length));
    }
  }
  return <Product>[
    ...builtIn.where((p) => !shadowedIds.contains(p.id)),
    ...userProducts,
  ];
}
