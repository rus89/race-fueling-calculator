// ABOUTME: Tests for the fuel CLI CommandRunner scaffold.
// ABOUTME: Invokes bin/fuel.dart via Process.run to verify --help, unknown
// commands, and no-args behavior end-to-end.
import 'dart:io';

import 'package:test/test.dart';

void main() {
  final binary = 'bin/fuel.dart';

  Future<ProcessResult> runFuel(List<String> args) {
    return Process.run(
      Platform.resolvedExecutable,
      ['run', binary, ...args],
      // Test runner sets cwd to the package root (packages/cli), so the
      // relative binary path resolves correctly.
    );
  }

  group('fuel CommandRunner', () {
    test('--help prints the description and exits 0', () async {
      final result = await runFuel(['--help']);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('Race Fueling Calculator'));
    });

    test('unknown command writes to stderr and exits with usage code',
        () async {
      final result = await runFuel(['nonsense-command']);

      expect(result.exitCode, 64);
      expect(result.stderr, isNotEmpty);
      // CommandRunner's UsageException typically mentions the bad input.
      expect(
        result.stderr,
        anyOf(
          contains('nonsense-command'),
          contains('Could not find'),
        ),
      );
    });

    test('no args prints usage to stdout and exits 0', () async {
      final result = await runFuel(const []);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('Race Fueling Calculator'));
      // Default CommandRunner behavior: prints usage, no commands = just help.
      expect(result.stdout, contains('Usage:'));
    });
  });
}
