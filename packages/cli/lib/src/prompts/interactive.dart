// ABOUTME: Stdin/stdout prompt helpers with retry-on-error, EOF handling, and
// ABOUTME: a read/write injection seam (readLine/out) so tests can drive them.
import 'dart:io';

/// Max retries before a prompt gives up and throws [PromptAbortedException].
const int _kPromptRetryCap = 3;

/// Thrown by prompt helpers when the user fails to provide valid input after
/// [_kPromptRetryCap] attempts. Commands translate this to exit 64.
class PromptAbortedException implements Exception {
  final String message;
  PromptAbortedException(this.message);

  @override
  String toString() => 'PromptAbortedException: $message';
}

/// Thrown by [requireTerminal] when stdin is not a TTY and the caller depends
/// on interactive input. The [message] explains which flags the user can pass
/// instead. Commands translate this to exit 66.
class NoTerminalException implements Exception {
  final String message;
  NoTerminalException(this.message);

  @override
  String toString() => 'NoTerminalException: $message';
}

/// Signature for an injectable line reader. Returning `null` signals EOF
/// (e.g. piped stdin exhausted). Tests pass a queue-backed closure.
typedef LineReader = String? Function();

String? _defaultReadLine() => stdin.readLineSync()?.trim();

StringSink _resolveOut(StringSink? out) => out ?? stderr;
LineReader _resolveReader(LineReader? reader) => reader ?? _defaultReadLine;

void _writePrompt(StringSink out, String prompt, String? defaultHint) {
  final hint = defaultHint == null ? '' : ' [$defaultHint]';
  out.write('$prompt$hint: ');
}

/// Throws [NoTerminalException] when stdin has no TTY. Commands call this
/// before falling back to interactive prompts so they can surface a helpful
/// message listing the flags the user could pass instead.
void requireTerminal({required String flagHint}) {
  if (!stdin.hasTerminal) {
    throw NoTerminalException(
      'Interactive input requires a TTY; $flagHint.',
    );
  }
}

/// Prompts for a free-form string. Returns [defaultValue] (or `''`) on empty
/// input, or the trimmed input otherwise. EOF behaves like empty input.
String promptString(
  String prompt, {
  String? defaultValue,
  LineReader? readLine,
  StringSink? out,
}) {
  final sink = _resolveOut(out);
  final read = _resolveReader(readLine);
  _writePrompt(sink, prompt, defaultValue);
  final input = read() ?? '';
  return input.isEmpty ? (defaultValue ?? '') : input;
}

/// Prompts for a double. Re-prompts up to 3 times on parse failure or
/// out-of-range values. Returns `null` on EOF (readLine returns null).
/// Throws [PromptAbortedException] after the retry cap.
double? promptDouble(
  String prompt, {
  double? defaultValue,
  double? min,
  double? max,
  LineReader? readLine,
  StringSink? out,
}) {
  final sink = _resolveOut(out);
  final read = _resolveReader(readLine);

  for (var attempt = 0; attempt < _kPromptRetryCap; attempt++) {
    _writePrompt(sink, prompt, defaultValue?.toString());
    final raw = read();
    if (raw == null) return null;
    if (raw.isEmpty) {
      if (defaultValue != null) return defaultValue;
      sink.writeln('Value is required.');
      continue;
    }
    final parsed = double.tryParse(raw);
    if (parsed == null || parsed.isNaN) {
      sink.writeln('"$raw" is not a valid number. Try again.');
      continue;
    }
    if (min != null && parsed < min) {
      sink.writeln('Value must be between $min and ${max ?? '∞'}.');
      continue;
    }
    if (max != null && parsed > max) {
      sink.writeln('Value must be between ${min ?? '-∞'} and $max.');
      continue;
    }
    return parsed;
  }
  throw PromptAbortedException(
    'No valid number after $_kPromptRetryCap attempts.',
  );
}

/// Prompts for an int. Same retry/EOF/range semantics as [promptDouble].
int? promptInt(
  String prompt, {
  int? defaultValue,
  int? min,
  int? max,
  LineReader? readLine,
  StringSink? out,
}) {
  final sink = _resolveOut(out);
  final read = _resolveReader(readLine);

  for (var attempt = 0; attempt < _kPromptRetryCap; attempt++) {
    _writePrompt(sink, prompt, defaultValue?.toString());
    final raw = read();
    if (raw == null) return null;
    if (raw.isEmpty) {
      if (defaultValue != null) return defaultValue;
      sink.writeln('Value is required.');
      continue;
    }
    final parsed = int.tryParse(raw);
    if (parsed == null) {
      sink.writeln('"$raw" is not a valid integer. Try again.');
      continue;
    }
    if (min != null && parsed < min) {
      sink.writeln('Value must be between $min and ${max ?? '∞'}.');
      continue;
    }
    if (max != null && parsed > max) {
      sink.writeln('Value must be between ${min ?? '-∞'} and $max.');
      continue;
    }
    return parsed;
  }
  throw PromptAbortedException(
    'No valid integer after $_kPromptRetryCap attempts.',
  );
}

/// Parses a human-entered duration. Accepts `3h`, `3h30m`, `45m`, `1:30`
/// (h:mm), and `2:45:00` (h:mm:ss). Returns `null` for any other input.
Duration? parseDuration(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  // Colon form: 1:30 or 2:45:00.
  if (trimmed.contains(':')) {
    final parts = trimmed.split(':');
    if (parts.length < 2 || parts.length > 3) return null;
    final nums = <int>[];
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null || n < 0) return null;
      nums.add(n);
    }
    final hours = nums[0];
    final minutes = nums[1];
    final seconds = nums.length == 3 ? nums[2] : 0;
    if (minutes >= 60 || seconds >= 60) return null;
    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }

  // Suffix form: 3h, 30m, 3h30m, 45s combinations.
  final regex = RegExp(r'^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?$');
  final match = regex.firstMatch(trimmed);
  if (match == null) return null;
  final h = int.tryParse(match.group(1) ?? '0') ?? 0;
  final m = int.tryParse(match.group(2) ?? '0') ?? 0;
  final s = int.tryParse(match.group(3) ?? '0') ?? 0;
  if (h == 0 && m == 0 && s == 0) return null;
  return Duration(hours: h, minutes: m, seconds: s);
}

/// Prompts for a duration using [parseDuration]. Retries up to 3 times on
/// parse failure. Returns `null` on EOF. Throws [PromptAbortedException]
/// after the retry cap.
Duration? promptDuration(
  String prompt, {
  Duration? defaultValue,
  LineReader? readLine,
  StringSink? out,
}) {
  final sink = _resolveOut(out);
  final read = _resolveReader(readLine);
  final defaultHint =
      defaultValue == null ? null : _formatDuration(defaultValue);

  for (var attempt = 0; attempt < _kPromptRetryCap; attempt++) {
    _writePrompt(sink, prompt, defaultHint);
    final raw = read();
    if (raw == null) return null;
    if (raw.isEmpty) {
      if (defaultValue != null) return defaultValue;
      sink.writeln('Duration is required.');
      continue;
    }
    final parsed = parseDuration(raw);
    if (parsed != null) return parsed;
    sink.writeln('"$raw" is not a valid duration (try 3h30m or 2:45:00).');
  }
  throw PromptAbortedException(
    'No valid duration after $_kPromptRetryCap attempts.',
  );
}

/// Prompts for y/n. Accepts `y`, `yes`, `n`, `no` case-insensitive. Empty
/// input returns [defaultValue]. Retries up to 3 times; throws
/// [PromptAbortedException] after the cap.
bool promptBool(
  String prompt, {
  bool defaultValue = false,
  LineReader? readLine,
  StringSink? out,
}) {
  final sink = _resolveOut(out);
  final read = _resolveReader(readLine);
  final hint = defaultValue ? 'Y/n' : 'y/N';

  for (var attempt = 0; attempt < _kPromptRetryCap; attempt++) {
    sink.write('$prompt [$hint]: ');
    final raw = read();
    if (raw == null) return defaultValue;
    final lower = raw.trim().toLowerCase();
    if (lower.isEmpty) return defaultValue;
    if (lower == 'y' || lower == 'yes') return true;
    if (lower == 'n' || lower == 'no') return false;
    sink.writeln('Please answer y or n.');
  }
  throw PromptAbortedException(
    'No valid y/n answer after $_kPromptRetryCap attempts.',
  );
}

/// Prompts the user to pick one of [options] by number. Re-prompts on invalid
/// input; never silently picks option 1. Empty input selects [defaultOption]
/// if provided. Throws [PromptAbortedException] after 3 bad attempts.
T promptChoice<T>(
  String prompt,
  List<T> options, {
  required String Function(T) describe,
  T? defaultOption,
  LineReader? readLine,
  StringSink? out,
}) {
  if (options.isEmpty) {
    throw ArgumentError('promptChoice needs at least one option');
  }
  final sink = _resolveOut(out);
  final read = _resolveReader(readLine);

  for (var attempt = 0; attempt < _kPromptRetryCap; attempt++) {
    sink.writeln(prompt);
    for (var i = 0; i < options.length; i++) {
      sink.writeln('  ${i + 1}. ${describe(options[i])}');
    }
    final defaultHint = defaultOption == null ? null : describe(defaultOption);
    _writePrompt(sink, 'Choice', defaultHint);
    final raw = read();
    if (raw == null) {
      if (defaultOption != null) return defaultOption;
      throw PromptAbortedException('No choice entered (EOF).');
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty && defaultOption != null) return defaultOption;
    final index = int.tryParse(trimmed);
    if (index != null && index >= 1 && index <= options.length) {
      return options[index - 1];
    }
    sink.writeln('Invalid choice. Enter a number between 1 and '
        '${options.length}.');
  }
  throw PromptAbortedException(
    'No valid choice after $_kPromptRetryCap attempts.',
  );
}

String _formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0 && m > 0) return '${h}h${m}m';
  if (h > 0) return '${h}h';
  return '${m}m';
}
