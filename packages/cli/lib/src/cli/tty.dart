// ABOUTME: Probes whether stdin is connected to a terminal; shared by commands
// ABOUTME: so tests can inject a deterministic value instead of touching stdin.
import 'dart:io';

/// Returns `true` when stdin is connected to an interactive terminal.
typedef IsTtyProbe = bool Function();

/// Default probe that reads [Stdin.hasTerminal] at call time.
bool defaultIsTty() => stdin.hasTerminal;
