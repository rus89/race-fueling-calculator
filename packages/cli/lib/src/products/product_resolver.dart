// ABOUTME: Resolves a product query to a single Product using precedence rules
// ABOUTME: (exact id, exact name, unique substring) and formats ambiguity help.
import 'package:race_fueling_core/core.dart';

/// Result of looking up a product by user-supplied query.
sealed class ProductMatch {
  const ProductMatch();
}

/// A single product matched the query unambiguously.
class ProductMatchSingle extends ProductMatch {
  const ProductMatchSingle(this.product);
  final Product product;
}

/// No product matched the query.
class ProductMatchNone extends ProductMatch {
  const ProductMatchNone();
}

/// More than one product matched the query by substring.
class ProductMatchMultiple extends ProductMatch {
  const ProductMatchMultiple(this.candidates);
  final List<Product> candidates;
}

/// Looks up a product by query using precedence: exact ID → exact name
/// (case-insensitive) → unique case-insensitive substring. Returns a
/// [ProductMatchMultiple] when the substring match is ambiguous.
ProductMatch resolveProduct(List<Product> products, String query) {
  final q = query.toLowerCase().trim();
  if (q.isEmpty) return const ProductMatchNone();

  for (final p in products) {
    if (p.id == query) return ProductMatchSingle(p);
  }
  for (final p in products) {
    if (p.name.toLowerCase() == q) return ProductMatchSingle(p);
  }
  final substringMatches =
      products.where((p) => p.name.toLowerCase().contains(q)).toList();
  if (substringMatches.isEmpty) return const ProductMatchNone();
  if (substringMatches.length == 1) {
    return ProductMatchSingle(substringMatches.first);
  }
  return ProductMatchMultiple(substringMatches);
}

/// Writes the "Did you mean one of: ..." help for an ambiguous match,
/// name-first with the id in parens, and a suggestion to re-run with quotes.
void writeCandidates(StringSink out, List<Product> candidates) {
  out.writeln('Did you mean one of:');
  final widest = candidates
      .map((p) => p.name.length)
      .fold<int>(0, (a, b) => a > b ? a : b);
  for (final p in candidates) {
    final paddedName = p.name.padRight(widest);
    out.writeln('  $paddedName  (id: ${p.id})');
  }
  out.writeln('');
  out.writeln('Re-run with the exact name in quotes.');
}
