// ABOUTME: CLI entry point for the Race Fueling Calculator.
// ABOUTME: Wires up commands and delegates execution to runFuel.
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:race_fueling_cli/src/cli/exit_codes.dart';
import 'package:race_fueling_cli/src/cli/runner.dart';
import 'package:race_fueling_cli/src/commands/profile_command.dart';
import 'package:race_fueling_cli/src/storage/file_storage_adapter.dart';

Future<void> main(List<String> args) async {
  // Clean shutdown on Ctrl+C: exit 130 per POSIX convention (128 + SIGINT).
  // Holding the subscription so we can cancel it after the runner finishes,
  // otherwise the stream keeps the isolate alive indefinitely.
  final sigintSub = ProcessSignal.sigint.watch().listen((_) {
    exitCode = 130;
    exit(130);
  });

  try {
    final storage = FileStorageAdapter();
    final runner = CommandRunner<void>(
      'fuel',
      'Race Fueling Calculator — plan your race-day nutrition',
    )..addCommand(ProfileCommand(storage));
    exitCode = await runFuel(runner, args);
  } catch (e) {
    stderr.writeln('Internal error: $e');
    exitCode = kExitInternal;
  } finally {
    await sigintSub.cancel();
  }
}
