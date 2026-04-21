// ABOUTME: Runs a CommandRunner and translates UsageException to an exit code.
// ABOUTME: Shared by bin/fuel.dart and in-process tests so error handling is tested directly.
import 'dart:io';

import 'package:args/command_runner.dart';

import 'exit_codes.dart';

/// Runs [runner] with [args] and returns an exit code.
///
/// Returns [kExitSuccess] when the command completes, or [kExitUsage] when
/// the runner throws [UsageException] (unknown command, bad flag, etc.).
/// Returns an int rather than mutating the global `exitCode` so callers
/// (including in-process tests) can compose without polluting process state.
Future<int> runFuel(CommandRunner<void> runner, List<String> args) async {
  try {
    await runner.run(args);
    return kExitSuccess;
  } on UsageException catch (e) {
    stderr.writeln(e);
    return kExitUsage;
  }
}
