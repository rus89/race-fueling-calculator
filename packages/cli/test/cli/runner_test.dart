// ABOUTME: In-process tests for runFuel — the helper that runs a CommandRunner
// ABOUTME: and translates UsageException into an exit code without touching exitCode.
import 'package:args/command_runner.dart';
import 'package:race_fueling_cli/src/cli/exit_codes.dart';
import 'package:race_fueling_cli/src/cli/runner.dart';
import 'package:test/test.dart';

import '../support/capture.dart';

CommandRunner<void> _buildRunner() {
  return CommandRunner<void>(
    'fuel',
    'Race Fueling Calculator — plan your race-day nutrition',
  );
}

void main() {
  group('runFuel', () {
    // CommandRunner writes --help and usage output via print(), which is not
    // routed through IOOverrides.stdout. Subprocess tests in
    // test/commands/runner_test.dart verify the actual help text against the
    // real binary; here we verify the helper's exit-code contract.

    test('returns kExitSuccess for --help', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(_buildRunner(), ['--help']);
      });

      expect(code, kExitSuccess);
      expect(captured.stderr, isEmpty);
    });

    test('returns kExitUsage for an unknown command and writes to stderr',
        () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(_buildRunner(), ['nonsense-command']);
      });

      expect(code, kExitUsage);
      expect(captured.stderr, contains('nonsense-command'));
    });

    test('returns kExitSuccess for no args', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(_buildRunner(), const []);
      });

      expect(code, kExitSuccess);
      expect(captured.stderr, isEmpty);
    });

    test('sequential invocations do not leak exitCode between calls', () async {
      // First call fails via a UsageException (unknown command). The helper
      // must restore the process's prior exitCode so the second, clean call
      // still reports kExitSuccess.
      late final int firstCode;
      late final int secondCode;
      await captureOutput(() async {
        firstCode = await runFuel(_buildRunner(), ['unknown-command']);
        secondCode = await runFuel(_buildRunner(), const []);
      });

      expect(firstCode, kExitUsage);
      expect(secondCode, kExitSuccess);
    });
  });
}
