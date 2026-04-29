// ABOUTME: Tests for ANSI color helpers and visible-width utilities.
// ABOUTME: Verifies enabled/disabled paths, ANSI stripping, and visible-width measurement.
import 'package:test/test.dart';
import 'package:race_fueling_cli/src/formatting/color.dart';

void main() {
  group('color helpers — enabled', () {
    test('red wraps with \\x1B[31m and reset', () {
      expect(red('x', enabled: true), '\x1B[31mx\x1B[0m');
    });
    test('yellow wraps with \\x1B[33m', () {
      expect(yellow('x', enabled: true), '\x1B[33mx\x1B[0m');
    });
    test('green wraps with \\x1B[32m', () {
      expect(green('x', enabled: true), '\x1B[32mx\x1B[0m');
    });
    test('bold wraps with \\x1B[1m', () {
      expect(bold('x', enabled: true), '\x1B[1mx\x1B[0m');
    });
    test('dim wraps with \\x1B[2m', () {
      expect(dim('x', enabled: true), '\x1B[2mx\x1B[0m');
    });
  });

  group('color helpers — disabled', () {
    test('red returns plain string', () {
      expect(red('x', enabled: false), 'x');
    });
    test('all helpers return plain when enabled: false', () {
      expect(yellow('x', enabled: false), 'x');
      expect(green('x', enabled: false), 'x');
      expect(bold('x', enabled: false), 'x');
      expect(dim('x', enabled: false), 'x');
    });
  });

  group('visibleWidth', () {
    test('measures plain string by length', () {
      expect(visibleWidth('hello'), 5);
    });
    test('strips ANSI SGR sequences before measuring', () {
      expect(visibleWidth('\x1B[31mhello\x1B[0m'), 5);
      expect(visibleWidth('\x1B[1;33mwarn\x1B[0m'), 4);
    });
    test('returns 0 for empty string', () {
      expect(visibleWidth(''), 0);
    });
  });

  group('padVisibleRight', () {
    test('pads plain string to target width', () {
      expect(padVisibleRight('ab', 5), 'ab   ');
    });
    test('pads colored string by visible width, not byte length', () {
      final s = '\x1B[31mab\x1B[0m';
      final padded = padVisibleRight(s, 5);
      expect(visibleWidth(padded), 5);
      expect(padded.endsWith('   '), true);
    });
    test('does not truncate when input exceeds width', () {
      expect(padVisibleRight('abcdef', 3), 'abcdef');
    });
  });

  group('resolveColorMode precedence', () {
    test('--no-color flag wins over env and tty', () {
      expect(
        resolveColorMode(
          noColorFlag: true,
          env: const {},
          ttySupportsAnsi: true,
        ),
        false,
      );
    });
    test('NO_COLOR with value "1" disables color', () {
      expect(
        resolveColorMode(
          env: const {'NO_COLOR': '1'},
          ttySupportsAnsi: true,
        ),
        false,
      );
    });
    test('NO_COLOR present but empty disables color (spec compliance)', () {
      expect(
        resolveColorMode(
          env: const {'NO_COLOR': ''},
          ttySupportsAnsi: true,
        ),
        false,
      );
    });
    test('no NO_COLOR and tty supports ANSI returns true', () {
      expect(
        resolveColorMode(env: const {}, ttySupportsAnsi: true),
        true,
      );
    });
    test('no NO_COLOR and tty does not support ANSI returns false', () {
      expect(
        resolveColorMode(env: const {}, ttySupportsAnsi: false),
        false,
      );
    });
    test('falls through to real stdout capability when nothing injected', () {
      expect(resolveColorMode(), isA<bool>());
    });
  });
}
