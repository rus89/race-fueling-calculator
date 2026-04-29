// ABOUTME: Barrel export for the race_fueling_cli package.
// ABOUTME: Re-exports commands, storage, formatting, and prompt helpers.
library;

export 'src/commands/profile_command.dart';
export 'src/commands/products_command.dart';
export 'src/commands/plan_command.dart';
export 'src/storage/file_storage_adapter.dart';
export 'src/formatting/plan_table.dart';
export 'src/formatting/summary_block.dart';
export 'src/formatting/color.dart';
export 'src/prompts/interactive.dart' show parseDuration;
