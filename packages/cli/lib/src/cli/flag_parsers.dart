// ABOUTME: Parses numeric CLI flags (double and int), returning null for
// ABOUTME: absent flags and throwing UsageException with an actionable message.
import 'package:args/args.dart';
import 'package:args/command_runner.dart';

/// Parses a double-valued CLI flag. Returns null if the flag was not supplied.
/// Throws [UsageException] with an actionable message on parse failure.
double? parseDoubleFlag(ArgResults results, String flag) {
  final raw = results[flag] as String?;
  if (raw == null) return null;
  final parsed = double.tryParse(raw);
  if (parsed == null) {
    throw UsageException(
      'Expected a number for --$flag, got "$raw"',
      'Pass --$flag <number>.',
    );
  }
  return parsed;
}

/// Parses an int-valued CLI flag. Returns null if the flag was not supplied.
/// Throws [UsageException] with an actionable message on parse failure.
int? parseIntFlag(ArgResults results, String flag) {
  final raw = results[flag] as String?;
  if (raw == null) return null;
  final parsed = int.tryParse(raw);
  if (parsed == null) {
    throw UsageException(
      'Expected an integer for --$flag, got "$raw"',
      'Pass --$flag <integer>.',
    );
  }
  return parsed;
}
