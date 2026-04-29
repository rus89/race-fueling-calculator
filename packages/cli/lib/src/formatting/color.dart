// ABOUTME: ANSI color helpers and visible-width utilities for terminal output.
// ABOUTME: Color decision is resolved by the caller via resolveColorMode and threaded as bool.
import 'dart:io';

/// Resolves whether colored output should be emitted.
///
/// Precedence: explicit `--no-color` flag → `NO_COLOR` env var (presence
/// disables, regardless of value, per https://no-color.org/) → terminal
/// capability (`stdout.supportsAnsiEscapes`).
///
/// [env] and [ttySupportsAnsi] override the process globals for unit testing.
bool resolveColorMode({
  bool? noColorFlag,
  Map<String, String>? env,
  bool? ttySupportsAnsi,
}) {
  if (noColorFlag == true) return false;
  if ((env ?? Platform.environment).containsKey('NO_COLOR')) return false;
  return ttySupportsAnsi ?? stdout.supportsAnsiEscapes;
}

String red(String s, {required bool enabled}) =>
    enabled ? '\x1B[31m$s\x1B[0m' : s;
String yellow(String s, {required bool enabled}) =>
    enabled ? '\x1B[33m$s\x1B[0m' : s;
String green(String s, {required bool enabled}) =>
    enabled ? '\x1B[32m$s\x1B[0m' : s;
String bold(String s, {required bool enabled}) =>
    enabled ? '\x1B[1m$s\x1B[0m' : s;
String dim(String s, {required bool enabled}) =>
    enabled ? '\x1B[2m$s\x1B[0m' : s;

final _ansiSgr = RegExp(r'\x1B\[[0-9;]*m');

/// Returns the visible (printable) width of [s], stripping ANSI SGR escapes.
int visibleWidth(String s) => s.replaceAll(_ansiSgr, '').length;

/// Pads [s] on the right with spaces until its visible width reaches [width].
/// Does not truncate; callers needing truncation must do so before padding.
String padVisibleRight(String s, int width) {
  final pad = width - visibleWidth(s);
  return pad <= 0 ? s : '$s${' ' * pad}';
}
