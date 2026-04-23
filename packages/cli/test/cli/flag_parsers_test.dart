// ABOUTME: Tests for the shared numeric flag parsers (parseDoubleFlag and
// ABOUTME: parseIntFlag) used across CLI commands for consistent UX.
import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:race_fueling_cli/src/cli/flag_parsers.dart';
import 'package:test/test.dart';

ArgResults _parse(List<String> args) {
  final parser = ArgParser()
    ..addOption('target')
    ..addOption('interval');
  return parser.parse(args);
}

void main() {
  group('parseDoubleFlag', () {
    test('returns null when the flag is not supplied', () {
      final results = _parse([]);
      expect(parseDoubleFlag(results, 'target'), isNull);
    });

    test('parses a valid numeric value', () {
      final results = _parse(['--target', '75']);
      expect(parseDoubleFlag(results, 'target'), 75.0);
    });

    test('throws UsageException naming the flag and raw value on bad input',
        () {
      final results = _parse(['--target', 'banana']);
      expect(
        () => parseDoubleFlag(results, 'target'),
        throwsA(
          isA<UsageException>()
              .having((e) => e.message, 'message', contains('--target'))
              .having((e) => e.message, 'message', contains('banana')),
        ),
      );
    });
  });

  group('parseIntFlag', () {
    test('returns null when the flag is not supplied', () {
      final results = _parse([]);
      expect(parseIntFlag(results, 'interval'), isNull);
    });

    test('parses a valid integer', () {
      final results = _parse(['--interval', '20']);
      expect(parseIntFlag(results, 'interval'), 20);
    });

    test('throws UsageException naming the flag and raw value on bad input',
        () {
      final results = _parse(['--interval', '1.5']);
      expect(
        () => parseIntFlag(results, 'interval'),
        throwsA(
          isA<UsageException>()
              .having((e) => e.message, 'message', contains('--interval'))
              .having((e) => e.message, 'message', contains('1.5')),
        ),
      );
    });
  });
}
