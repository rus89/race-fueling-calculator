// ABOUTME: CLI entry point for the Race Fueling Calculator.
// ABOUTME: Wires up commands, storage, and the CommandRunner.
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:race_fueling_cli/src/cli/exit_codes.dart';
import 'package:race_fueling_cli/src/storage/file_storage_adapter.dart';

Future<void> main(List<String> args) async {
  // Clean shutdown on Ctrl+C: exit 130 per POSIX convention (128 + SIGINT).
  // Holding the subscription so we can cancel it after the runner finishes,
  // otherwise the stream keeps the isolate alive indefinitely.
  final sigintSub = ProcessSignal.sigint.watch().listen((_) {
    exitCode = 130;
    exit(130);
  });

  // Storage auto-resolves FUEL_HOME / $HOME/.race-fueling. Subcommands added
  // in later tasks (6.2, 6.3, 6.4) take this instance as a constructor arg.
  // ignore: unused_local_variable
  final storage = FileStorageAdapter();

  final runner = CommandRunner<void>(
    'fuel',
    'Race Fueling Calculator — plan your race-day nutrition',
  );

  try {
    await runner.run(args);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exitCode = kExitUsage;
  } finally {
    await sigintSub.cancel();
  }
}
