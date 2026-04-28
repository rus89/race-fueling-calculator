// ABOUTME: Converts a human name into a filesystem- and URL-safe slug by
// ABOUTME: lowercasing, collapsing non-alphanumerics to hyphens, and trimming.
String slugify(String input) {
  final lower = input.toLowerCase();
  final hyphenated = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return hyphenated.replaceAll(RegExp(r'^-+|-+$'), '');
}
