// ABOUTME: Embedder-safe public API for race_fueling_cli — storage, formatters,
// ABOUTME: prompt utilities, exit-code constants, and friendly-error helpers; no package:args.
library;

export 'src/storage/file_storage_adapter.dart';
export 'src/formatting/plan_table.dart';
export 'src/formatting/summary_block.dart';
export 'src/formatting/color.dart';
export 'src/prompts/interactive.dart';
export 'src/cli/exit_codes.dart';
export 'src/cli/errors.dart';
