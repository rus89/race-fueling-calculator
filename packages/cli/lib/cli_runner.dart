// ABOUTME: Public surface for callers driving the CLI command tree directly.
// ABOUTME: Re-exports cli_api plus the args-based command classes (transitively pulls package:args).
library;

export 'cli_api.dart';
export 'src/commands/profile_command.dart';
export 'src/commands/products_command.dart';
export 'src/commands/plan_command.dart';
