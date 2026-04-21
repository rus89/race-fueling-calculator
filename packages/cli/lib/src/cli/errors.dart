// ABOUTME: Error reporting helper — writes to stderr and sets the process exit code.
// ABOUTME: Used by every command's error path so scripts can detect failure.
import 'dart:io';

import 'exit_codes.dart';

void exitWith(int code, String message) {
  stderr.writeln(message);
  exitCode = code;
}

/// Wraps a future that may throw known domain errors and surfaces friendly
/// messages. Returns `true` on success, `false` on handled failure (caller
/// should bail out after checking).
Future<bool> withFriendlyErrors(Future<void> Function() action) async {
  try {
    await action();
    return true;
  } on FormatException catch (e) {
    exitWith(kExitData, 'Invalid data: ${e.message}');
  } on FileSystemException catch (e) {
    exitWith(kExitData, 'File error: ${e.message} (${e.path ?? ""})');
  } on AssertionError catch (e) {
    exitWith(kExitData, 'Invariant violated: ${e.message}');
  }
  return false;
}
