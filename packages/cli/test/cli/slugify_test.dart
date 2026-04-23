// ABOUTME: Tests for the shared slugify helper used by CLI commands to derive
// ABOUTME: filesystem- and URL-safe identifiers from human-entered names.
import 'package:race_fueling_cli/src/cli/slugify.dart';
import 'package:test/test.dart';

void main() {
  group('slugify', () {
    test('returns empty string for empty input', () {
      expect(slugify(''), '');
    });

    test('lowercases alphanumeric input', () {
      expect(slugify('AlphaBeta42'), 'alphabeta42');
    });

    test('replaces runs of punctuation with a single hyphen', () {
      expect(slugify('Foo -- Bar!! Baz'), 'foo-bar-baz');
    });

    test('strips leading and trailing hyphens', () {
      expect(slugify('  !!foo bar!!  '), 'foo-bar');
    });

    test('returns empty string for all-punctuation input', () {
      expect(slugify('!!!'), '');
    });
  });
}
