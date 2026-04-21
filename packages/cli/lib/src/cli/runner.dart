// ABOUTME: Runs a CommandRunner and translates UsageException to an exit code.
// ABOUTME: Shared by bin/fuel.dart and in-process tests so error handling is tested directly.
import 'dart:io';

import 'package:args/command_runner.dart';

import 'exit_codes.dart';

/// Runs [runner] with [args] and returns an exit code.
///
/// Returns [kExitUsage] when the runner throws [UsageException] (unknown
/// command, bad flag, etc.). Otherwise returns whatever the global
/// `exitCode` was set to during the run (defaulting to [kExitSuccess] if
/// untouched). The global `exitCode` is reset to its prior value before
/// returning so in-process callers can compose without polluting process
/// state across invocations.
Future<int> runFuel(CommandRunner<void> runner, List<String> args) async {
  final prior = exitCode;
  exitCode = kExitSuccess;
  try {
    await runner.run(args);
    return exitCode;
  } on UsageException catch (e) {
    stderr.writeln(e);
    return kExitUsage;
  } finally {
    exitCode = prior;
  }
}
